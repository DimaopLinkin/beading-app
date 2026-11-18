import 'dart:math' as math;

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:beading/domain/image_pattern/crop_fit.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:equatable/equatable.dart';

/// Как фото ложится в схему заданного размера (T88a): какая часть фото берётся и где внутри полной сетки стоит
/// внутренняя, по которой считается схема.
final class FramePlan extends Equatable {
  const FramePlan({
    required this.effectiveCrop,
    required this.innerColumns,
    required this.innerRows,
    required this.offsetColumn,
    required this.offsetRow,
    required this.columns,
    required this.rows,
  });

  /// Рамка обрезки, по которой берётся фото (в долях повёрнутого изображения).
  final CropRect effectiveCrop;

  /// Размер внутренней сетки, по которой считается схема.
  final int innerColumns;
  final int innerRows;

  /// Смещение внутренней сетки в полной, клеток.
  final int offsetColumn;
  final int offsetRow;

  /// Размер полной сетки (с полями).
  final int columns;
  final int rows;

  /// Есть ли поля: внутренняя сетка меньше полной.
  bool get hasMargins => innerColumns != columns || innerRows != rows;

  @override
  List<Object?> get props => <Object?>[effectiveCrop, innerColumns, innerRows, offsetColumn, offsetRow, columns, rows];
}

/// Чистый расчёт [FramePlan] по размеру фото, рамке и настройкам.
abstract final class FramePlanner {
  /// [sourceWidth] и [sourceHeight] — размер фото после поворота, [crop] — рамка пользовательницы.
  static FramePlan plan({
    required int sourceWidth,
    required int sourceHeight,
    required CropRect crop,
    required ImageToGridSettings settings,
  }) {
    if (sourceWidth < 1 || sourceHeight < 1) throw ArgumentError('Картинка пустая');
    final GridGeometry geometry = settings.geometry;
    final CellMetrics metrics = settings.metrics;
    final int columns = math.min(settings.columns, Grid.maxSide);
    final double imageAspect = sourceWidth / sourceHeight;
    final double photoAspect = imageAspect * crop.width / crop.height;
    final int? fixedRows = settings.rows;

    // Высота по фото: прежнее поведение, полей и подгонки рамки нет.
    if (fixedRows == null) {
      final int rows = math.min(
        Grid.maxSide,
        GridSizing.rowsForAspect(aspect: photoAspect, geometry: geometry, metrics: metrics, columns: columns),
      );
      return FramePlan(
        effectiveCrop: crop,
        innerColumns: columns,
        innerRows: rows,
        offsetColumn: 0,
        offsetRow: 0,
        columns: columns,
        rows: rows,
      );
    }

    final int rows = fixedRows.clamp(1, Grid.maxSide);
    if (settings.fit == FrameFit.crop) {
      final MmSize extent = geometry.extent(metrics, columns: columns, rows: rows);
      return FramePlan(
        effectiveCrop: CropFit.fitAspect(crop, imageAspect, extent.width / extent.height),
        innerColumns: columns,
        innerRows: rows,
        offsetColumn: 0,
        offsetRow: 0,
        columns: columns,
        rows: rows,
      );
    }

    // Поля: всё фото вписывается в полную сетку по физическим размерам.
    final MmSize full = geometry.extent(metrics, columns: columns, rows: rows);
    int innerColumns = columns;
    int innerRows = rows;
    if (photoAspect >= full.width / full.height) {
      innerRows = math.min(
        rows,
        GridSizing.rowsForAspect(aspect: photoAspect, geometry: geometry, metrics: metrics, columns: columns),
      );
    } else {
      innerColumns = math.min(
        columns,
        GridSizing.columnsForAspect(aspect: photoAspect, geometry: geometry, metrics: metrics, rows: rows),
      );
    }
    return FramePlan(
      effectiveCrop: crop,
      innerColumns: innerColumns,
      innerRows: innerRows,
      offsetColumn: _centered(columns - innerColumns, geometry is PeyoteGeometry ? 2 * geometry.drop : 1),
      offsetRow: _centered(rows - innerRows, geometry is BrickGeometry ? 2 : 1),
      columns: columns,
      rows: rows,
    );
  }

  /// Смещение по центру, округлённое вниз до кратного [step]: так не меняется, какие столбцы пейота (или ряды
  /// кирпичного стежка) сдвинуты на полклетки.
  static int _centered(int free, int step) => (free ~/ 2) ~/ step * step;
}
