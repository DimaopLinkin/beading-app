import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/presentation/grid_pattern/grid_colors.dart';
import 'package:flutter/cupertino.dart';

/// Превью схемы на карточке: цвета клеток по сетке, без линий и знаков. У больших схем берётся не каждая клетка,
/// а выборка не больше [maxSamples] по длинной стороне.
class GridThumbnail extends StatelessWidget {
  const GridThumbnail({required this.pattern, super.key});

  static const int maxSamples = 64;

  final GridPattern pattern;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      child: CustomPaint(
        painter: GridThumbnailPainter(pattern),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class GridThumbnailPainter extends CustomPainter {
  GridThumbnailPainter(this.pattern);

  final GridPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final int width = pattern.grid.width;
    final int height = pattern.grid.height;
    if (width == 0 || height == 0) {
      return;
    }
    final int step = ((width > height ? width : height) / GridThumbnail.maxSamples).ceil().clamp(1, 1 << 20);
    final int columns = (width / step).ceil();
    final int rows = (height / step).ceil();
    // Схема вписывается в квадрат по центру с сохранением пропорций.
    final double cell = (size.width / columns) < (size.height / rows) ? size.width / columns : size.height / rows;
    final double left = (size.width - cell * columns) / 2;
    final double top = (size.height - cell * rows) / 2;
    final Paint paint = Paint()..isAntiAlias = false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final int value = pattern.grid.at(c * step, r * step);
        if (value == 0) {
          continue;
        }
        final rgb = pattern.palette.colorAt(value)?.rgb;
        paint.color = rgb == null ? GridColors.unknown.color : Color.fromARGB(255, rgb.r, rgb.g, rgb.b);
        // Небольшой нахлёст, чтобы между клетками не просвечивали щели.
        canvas.drawRect(Rect.fromLTWH(left + c * cell, top + r * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(GridThumbnailPainter old) => old.pattern != pattern;
}
