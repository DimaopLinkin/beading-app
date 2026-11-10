import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_codec.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_geometry_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Переводит схему и цвета между доменом и строками таблиц. Ничего не знает о транзакциях.
abstract final class GridPatternMapper {
  static int rgbToInt(Rgb rgb) => (rgb.r << 16) | (rgb.g << 8) | rgb.b;

  static Rgb rgbFromInt(int value) => Rgb((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);

  static String componentsToJson(List<CatalogRef> components) => jsonEncode(<Map<String, String>>[
    for (final CatalogRef ref in components) <String, String>{'brand': ref.brand, 'code': ref.code},
  ]);

  static Result<List<CatalogRef>> componentsFromJson(String stored) {
    final Object? parsed;
    try {
      parsed = jsonDecode(stored);
    } on FormatException {
      return const Err<List<CatalogRef>>(StorageFailure('Состав цвета записан неверно'));
    }
    if (parsed is! List<Object?> || parsed.isEmpty || parsed.length > PatternColor.maxComponents) {
      return const Err<List<CatalogRef>>(StorageFailure('Состав цвета записан неверно'));
    }
    final List<CatalogRef> refs = <CatalogRef>[];
    for (final Object? item in parsed) {
      if (item is! Map<String, Object?> || item['brand'] is! String || item['code'] is! String) {
        return const Err<List<CatalogRef>>(StorageFailure('Состав цвета записан неверно'));
      }
      refs.add(CatalogRef(brand: item['brand']! as String, code: item['code']! as String));
    }
    return Success<List<CatalogRef>>(refs);
  }

  /// Собирает схему из строки, цветов и (необязательных) слоёв. Любая нечитаемая часть — ошибка, не исключение.
  static Result<GridPattern> toDomain(GridPatternRow row, List<PatternColorRow> colorRows) {
    final Result<GridGeometry> geometry = GridGeometryCodec.decode(kind: row.geometry, drop: row.geometryDrop);
    if (geometry case Err<GridGeometry>(:final Failure failure)) {
      return Err<GridPattern>(failure);
    }
    final Result<CellMetrics> metrics = CellMetricsCodec.decode(row.cellMetrics);
    if (metrics case Err<CellMetrics>(:final Failure failure)) {
      return Err<GridPattern>(failure);
    }
    if (row.cellsCodecVersion != GridCodec.version) {
      return Err<GridPattern>(StorageFailure('Неизвестная версия сетки: ${row.cellsCodecVersion}'));
    }
    final Result<Grid> grid = GridCodec.decode(row.cells);
    if (grid case Err<Grid>(:final Failure failure)) {
      return Err<GridPattern>(failure);
    }
    final Grid cells = grid.valueOrNull!;
    if (cells.width != row.width || cells.height != row.height) {
      return const Err<GridPattern>(StorageFailure('Размер сетки не совпадает с записью'));
    }

    final List<PatternColor> colors = <PatternColor>[];
    for (final PatternColorRow color in colorRows) {
      final Result<List<CatalogRef>> components = componentsFromJson(color.components);
      if (components case Err<List<CatalogRef>>(:final Failure failure)) {
        return Err<GridPattern>(failure);
      }
      colors.add(
        PatternColor(
          rgb: rgbFromInt(color.rgb),
          name: color.name,
          components: components.valueOrNull!,
          finish: color.finish,
          symbol: color.symbol,
        ),
      );
    }

    final Uint8List? layers = row.layers;
    final int? layersVersion = row.layersCodecVersion;
    return Success<GridPattern>(
      GridPattern(
        id: row.id,
        projectId: row.projectId,
        geometry: geometry.valueOrNull!,
        metrics: metrics.valueOrNull!,
        grid: cells,
        palette: PaletteSnapshot(colors),
        layers: layers == null || layersVersion == null
            ? null
            : GridLayersBlob(codecVersion: layersVersion, bytes: layers),
      ),
    );
  }
}
