import 'dart:typed_data';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_geometry_codec.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:equatable/equatable.dart';

/// Слои вышивки (частичные стежки, бэкстич, узелки) в закодированном виде.
///
/// Домен T14 их не разбирает: пишет и читает T37/T38 своим кодеком. Репозиторий лишь сохраняет байты и версию кодека
/// как есть, поэтому правка сетки или палитры слои не теряет.
final class GridLayersBlob extends Equatable {
  const GridLayersBlob({required this.codecVersion, required this.bytes});

  final int codecVersion;
  final Uint8List bytes;

  @override
  List<Object?> get props => <Object?>[codecVersion, bytes];
}

/// Сеточная схема проекта с `contentKind = grid`: форма, размер ячейки, сетка индексов и палитра-снимок.
///
/// Значение сетки `0` — пусто, `n` — цвет `palette[n - 1]`.
final class GridPattern extends Equatable {
  const GridPattern({
    required this.id,
    required this.projectId,
    required this.geometry,
    required this.metrics,
    required this.grid,
    required this.palette,
    this.layers,
  });

  final String id;
  final String projectId;
  final GridGeometry geometry;
  final CellMetrics metrics;
  final Grid grid;
  final PaletteSnapshot palette;

  /// Слои вышивки; у бисерных схем `null`.
  final GridLayersBlob? layers;

  GridPattern copyWith({
    GridGeometry? geometry,
    CellMetrics? metrics,
    Grid? grid,
    PaletteSnapshot? palette,
    GridLayersBlob? layers,
    bool clearLayers = false,
  }) => GridPattern(
    id: id,
    projectId: projectId,
    geometry: geometry ?? this.geometry,
    metrics: metrics ?? this.metrics,
    grid: grid ?? this.grid,
    palette: palette ?? this.palette,
    layers: clearLayers ? null : (layers ?? this.layers),
  );

  /// Копия с новыми идентификаторами схемы и проекта (для дублирования).
  GridPattern withIds({required String id, required String projectId}) => GridPattern(
    id: id,
    projectId: projectId,
    geometry: geometry,
    metrics: metrics,
    grid: grid,
    palette: palette,
    layers: layers,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    projectId,
    GridGeometryCodec.encode(geometry),
    metrics,
    grid,
    palette,
    layers,
  ];
}

/// Лёгкая сводка схемы без самой сетки: чтобы проверять номера рядов и не читать весь BLOB.
final class GridPatternSummary extends Equatable {
  const GridPatternSummary({required this.id, required this.projectId, required this.width, required this.height});

  final String id;
  final String projectId;
  final int width;
  final int height;

  @override
  List<Object?> get props => <Object?>[id, projectId, width, height];
}
