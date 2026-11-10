import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/grid_patterns_dao.dart';
import 'package:beading/data/grid_pattern/grid_pattern_mapper.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/grid/grid_codec.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_geometry_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Схемы в таблицах `grid_patterns` и `pattern_colors`. Сам ставит служебные колонки.
class DriftGridPatternRepository implements GridPatternRepository {
  DriftGridPatternRepository({
    required GridPatternsDao dao,
    required DeviceIdProvider deviceIds,
    required Clock clock,
    required IdGenerator ids,
  }) : _dao = dao,
       _deviceIds = deviceIds,
       _clock = clock,
       _ids = ids;

  final GridPatternsDao _dao;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Future<Result<GridPattern>> getByProject(String projectId) => _guard<GridPattern>(() async {
    final GridPatternRow? row = await _dao.findAliveByProject(projectId);
    if (row == null) {
      return Err<GridPattern>(NotFoundFailure('У проекта $projectId нет сетки'));
    }
    return GridPatternMapper.toDomain(row, await _dao.aliveColors(row.id));
  });

  @override
  Future<Result<GridPatternSummary>> summaryByProject(String projectId) => _guard<GridPatternSummary>(() async {
    final ({String id, int width, int height, String geometry, int drop})? found = await _dao.summaryByProject(
      projectId,
    );
    if (found == null) {
      return Err<GridPatternSummary>(NotFoundFailure('У проекта $projectId нет сетки'));
    }
    final Result<GridGeometry> geometry = GridGeometryCodec.decode(kind: found.geometry, drop: found.drop);
    if (geometry case Err<GridGeometry>(:final Failure failure)) {
      return Err<GridPatternSummary>(failure);
    }
    return Success<GridPatternSummary>(
      GridPatternSummary(
        id: found.id,
        projectId: projectId,
        width: found.width,
        height: found.height,
        geometry: geometry.valueOrNull!,
      ),
    );
  });

  /// Каждое изменение схемы, палитры или прогресса приводит к повторному чтению; одинаковые подряд схемы
  /// отбрасываются, так что отметка ряда подписчика на схему не будит.
  @override
  Stream<GridPattern?> watchByProject(String projectId) => Stream<GridPattern?>.multi((controller) {
    GridPattern? previous;
    bool first = true;
    final StreamSubscription<Result<GridPattern?>> subscription = _dao
        .watchAliveIdByProject(projectId)
        .asyncMap<Result<GridPattern?>>(_read)
        .listen(
          (result) {
            switch (result) {
              case Err<GridPattern?>(:final Failure failure):
                controller.addError(StateError(failure.message));
              case Success<GridPattern?>(:final GridPattern? value):
                if (first || value != previous) {
                  first = false;
                  previous = value;
                  controller.add(value);
                }
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );
    controller.onCancel = subscription.cancel;
  });

  Future<Result<GridPattern?>> _read(String? id) async {
    if (id == null) {
      return const Success<GridPattern?>(null);
    }
    final GridPatternRow? row = await _dao.findAlive(id);
    if (row == null) {
      return const Success<GridPattern?>(null);
    }
    return GridPatternMapper.toDomain(row, await _dao.aliveColors(id)).map<GridPattern?>((p) => p);
  }

  @override
  Future<Result<void>> save(GridPattern pattern) async {
    final Result<String> metrics = CellMetricsCodec.encode(pattern.metrics);
    if (metrics case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    return _guard<void>(
      () => _dao.transaction(() => _write(pattern, metrics: metrics.valueOrNull!, deviceId: deviceId.valueOrNull!)),
    );
  }

  Future<Result<void>> _write(GridPattern pattern, {required String metrics, required String deviceId}) async {
    final int now = _clock.now().millisecondsSinceEpoch;
    final StoredGeometry geometry = GridGeometryCodec.encode(pattern.geometry);
    final Uint8List cells = GridCodec.encode(pattern.grid);
    final int width = pattern.grid.width;
    final int height = pattern.grid.height;
    final GridLayersBlob? layers = pattern.layers;

    final GridPatternRow? existing = await _dao.find(pattern.id);
    if (existing == null) {
      await _dao
          .into(_dao.gridPatterns)
          .insert(
            GridPatternsCompanion.insert(
              id: pattern.id,
              projectId: pattern.projectId,
              geometry: geometry.kind,
              geometryDrop: Value<int>(geometry.drop),
              width: width,
              height: height,
              cellMetrics: metrics,
              cells: cells,
              cellsCodecVersion: GridCodec.version,
              layers: Value<Uint8List?>(layers?.bytes),
              layersCodecVersion: Value<int?>(layers?.codecVersion),
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
          );
    } else if (existing.deletedAt != null || existing.projectId != pattern.projectId) {
      return Err<void>(NotFoundFailure('Сетка ${pattern.id} не найдена'));
    } else {
      // Номера рядов прогресса — ряды плетения: у пейота это столбцы, у станка и кирпича — ряды сетки.
      final ReadingOrder order = ReadingOrder.of(pattern.geometry, columns: width, rows: height);
      final int readingRows = order.rowCount;
      final int? currentRow = existing.currentRow;
      final bool rowGone = currentRow != null && currentRow >= readingRows;
      final int? currentBead = existing.currentBead;
      await (_dao.update(_dao.gridPatterns)..where((t) => t.id.equals(pattern.id))).write(
        GridPatternsCompanion(
          geometry: Value<String>(geometry.kind),
          geometryDrop: Value<int>(geometry.drop),
          width: Value<int>(width),
          height: Value<int>(height),
          cellMetrics: Value<String>(metrics),
          cells: Value<Uint8List>(cells),
          cellsCodecVersion: const Value<int>(GridCodec.version),
          layers: Value<Uint8List?>(layers?.bytes),
          layersCodecVersion: Value<int?>(layers?.codecVersion),
          currentRow: rowGone ? const Value<int?>(null) : const Value<int?>.absent(),
          currentBead: rowGone || (currentBead != null && currentBead >= order.maxRowLength)
              ? const Value<int?>(null)
              : const Value<int?>.absent(),
          updatedAt: Value<int>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
      await (_dao.update(_dao.gridProgressRows)..where(
            (t) =>
                t.gridPatternId.equals(pattern.id) &
                t.rowIndex.isBiggerOrEqualValue(readingRows) &
                t.deletedAt.isNull(),
          ))
          .write(
            GridProgressRowsCompanion(
              updatedAt: Value<int>(now),
              deletedAt: Value<int?>(now),
              deviceId: Value<String>(deviceId),
            ),
          );
    }
    await _writePalette(pattern, existing: existing != null, now: now, deviceId: deviceId);
    return const Success<void>(null);
  }

  Future<void> _writePalette(
    GridPattern pattern, {
    required bool existing,
    required int now,
    required String deviceId,
  }) async {
    final Map<int, PatternColorRow> rows = existing
        ? <int, PatternColorRow>{for (final PatternColorRow row in await _dao.allColors(pattern.id)) row.position: row}
        : const <int, PatternColorRow>{};
    final List<PatternColor> colors = pattern.palette.colors;
    for (final (int position, PatternColor color) in colors.indexed) {
      final int rgb = GridPatternMapper.rgbToInt(color.rgb);
      final String components = GridPatternMapper.componentsToJson(color.components);
      final PatternColorRow? old = rows[position];
      if (old == null) {
        await _dao
            .into(_dao.patternColors)
            .insert(
              PatternColorsCompanion.insert(
                id: _ids.next(),
                gridPatternId: pattern.id,
                position: position,
                rgb: rgb,
                name: color.name,
                components: components,
                finish: Value<String?>(color.finish),
                symbol: Value<String?>(color.symbol),
                createdAt: now,
                updatedAt: now,
                deviceId: deviceId,
              ),
            );
      } else if (old.deletedAt != null ||
          old.rgb != rgb ||
          old.name != color.name ||
          old.components != components ||
          old.finish != color.finish ||
          old.symbol != color.symbol) {
        await (_dao.update(_dao.patternColors)..where((t) => t.id.equals(old.id))).write(
          PatternColorsCompanion(
            rgb: Value<int>(rgb),
            name: Value<String>(color.name),
            components: Value<String>(components),
            finish: Value<String?>(color.finish),
            symbol: Value<String?>(color.symbol),
            updatedAt: Value<int>(now),
            deletedAt: const Value<int?>(null),
            deviceId: Value<String>(deviceId),
          ),
        );
      }
    }
    // Цвета, которых больше нет в палитре, получают надгробие.
    for (final PatternColorRow old in rows.values.where((r) => r.position >= colors.length && r.deletedAt == null)) {
      await (_dao.update(_dao.patternColors)..where((t) => t.id.equals(old.id))).write(
        PatternColorsCompanion(
          updatedAt: Value<int>(now),
          deletedAt: Value<int?>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteByProject(String projectId) async {
    final Result<String> deviceId = await _deviceIds.deviceId();
    if (deviceId case Err<String>(:final Failure failure)) {
      return Err<void>(failure);
    }
    return guardStorage<void>(
      () => _dao.tombstoneByProject(
        projectId: projectId,
        nowMs: _clock.now().millisecondsSinceEpoch,
        deviceId: deviceId.valueOrNull!,
      ),
    );
  }
}

/// Ошибки хранилища становятся [StorageFailure], а собственная ошибка действия остаётся как есть.
Future<Result<T>> _guard<T>(Future<Result<T>> Function() action) async {
  final Result<Result<T>> guarded = await guardStorage<Result<T>>(action);
  return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<T>.new);
}
