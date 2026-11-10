import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Цвета ячеек после ресэмплинга: `null` — ячейка прозрачна, бусины в ней не будет.
final class SampledCells {
  SampledCells({required this.columns, required this.rows, required List<Rgb?> colors, required this.importance})
    : colors = List<Rgb?>.unmodifiable(colors);

  final int columns;
  final int rows;

  /// Цвета по рядам, слева направо.
  final List<Rgb?> colors;

  /// Средний вес важности ячейки (маска из входа; без маски везде 1).
  final Float32List importance;
}

/// Подбор размера сетки под пропорции картинки и форму бусины.
abstract final class GridSizing {
  /// Число рядов, при котором схема из [columns] столбцов повторяет пропорции картинки.
  ///
  /// Учитывает форму ячейки и сдвиг рядов геометрии: смотрит на габариты схемы в миллиметрах.
  static int rowsForColumns({
    required int imageWidth,
    required int imageHeight,
    required GridGeometry geometry,
    required CellMetrics metrics,
    required int columns,
  }) {
    if (imageWidth < 1 || imageHeight < 1) throw ArgumentError('Картинка пустая');
    if (columns < 1) throw ArgumentError.value(columns, 'columns', 'не меньше 1');
    final double aspect = imageWidth / imageHeight;
    final MmSize cell = geometry.cellSize(metrics);
    final int guess = math.max(1, (columns * cell.width / aspect / cell.height).round());
    int best = guess;
    double bestError = double.infinity;
    for (int rows = math.max(1, guess - 2); rows <= guess + 2; rows++) {
      final MmSize extent = geometry.extent(metrics, columns: columns, rows: rows);
      final double error = (extent.width / extent.height / aspect - 1).abs();
      if (error < bestError) {
        bestError = error;
        best = rows;
      }
    }
    return best;
  }
}

/// Шаг 1 конвейера: ресэмплинг. Каждая ячейка получает средний цвет пикселей под ней (по площади).
///
/// Картинка растягивается на габариты схемы в миллиметрах, поэтому форма бусины и сдвиг рядов пейота и кирпичного
/// стежка учитываются сами: ячейка берёт именно тот участок картинки, который под ней лежит.
final class CellSampler {
  const CellSampler();

  /// Ячейка с долей непрозрачности ниже этой считается пустой.
  static const double emptyBelowAlpha = 0.5;

  SampledCells sample({
    required SourceImage image,
    required GridGeometry geometry,
    required CellMetrics metrics,
    required int columns,
    required int rows,
    Float32List? importance,
  }) {
    if (columns < 1 || rows < 1) throw ArgumentError('Размер сетки не меньше 1×1');
    if (importance != null && importance.length != image.width * image.height) {
      throw ArgumentError.value(importance.length, 'importance', 'ожидалось ${image.width * image.height} весов');
    }
    final MmSize extent = geometry.extent(metrics, columns: columns, rows: rows);
    final MmSize cell = geometry.cellSize(metrics);
    final double scaleX = image.width / extent.width;
    final double scaleY = image.height / extent.height;

    final List<Rgb?> colors = List<Rgb?>.filled(columns * rows, null);
    final Float32List weights = Float32List(columns * rows);
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final MmPoint center = geometry.cellCenter(metrics, CellPosition(column, row));
        final int index = row * columns + column;
        final (Rgb?, double) result = _average(
          image,
          importance,
          left: (center.x - cell.width / 2) * scaleX,
          top: (center.y - cell.height / 2) * scaleY,
          right: (center.x + cell.width / 2) * scaleX,
          bottom: (center.y + cell.height / 2) * scaleY,
        );
        colors[index] = result.$1;
        weights[index] = result.$2;
      }
    }
    return SampledCells(columns: columns, rows: rows, colors: colors, importance: weights);
  }

  (Rgb?, double) _average(
    SourceImage image,
    Float32List? importance, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final double x0 = math.max(0, left);
    final double y0 = math.max(0, top);
    final double x1 = math.min(image.width.toDouble(), right);
    final double y1 = math.min(image.height.toDouble(), bottom);
    if (x1 - x0 <= 1e-9 || y1 - y0 <= 1e-9) return (null, 1);

    final Uint8List rgba = image.rgba;
    double area = 0;
    double alphaSum = 0;
    double rSum = 0;
    double gSum = 0;
    double bSum = 0;
    double importanceSum = 0;
    final int lastX = math.min(image.width - 1, x1.ceil() - 1);
    final int lastY = math.min(image.height - 1, y1.ceil() - 1);
    for (int y = y0.floor(); y <= lastY; y++) {
      final double coverY = math.min(y1, y + 1.0) - math.max(y0, y.toDouble());
      if (coverY <= 0) continue;
      for (int x = x0.floor(); x <= lastX; x++) {
        final double coverX = math.min(x1, x + 1.0) - math.max(x0, x.toDouble());
        if (coverX <= 0) continue;
        final double cover = coverX * coverY;
        final int pixel = y * image.width + x;
        final int offset = pixel * 4;
        final double alpha = cover * rgba[offset + 3] / 255;
        area += cover;
        alphaSum += alpha;
        rSum += alpha * rgba[offset];
        gSum += alpha * rgba[offset + 1];
        bSum += alpha * rgba[offset + 2];
        importanceSum += cover * (importance?[pixel] ?? 1);
      }
    }
    final double weight = area > 0 ? importanceSum / area : 1;
    if (area <= 0 || alphaSum / area < emptyBelowAlpha || alphaSum <= 0) return (null, weight);
    return (Rgb((rSum / alphaSum).round(), (gSum / alphaSum).round(), (bSum / alphaSum).round()), weight);
  }
}
