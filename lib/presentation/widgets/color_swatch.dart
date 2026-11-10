import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter/cupertino.dart';

/// Образец цвета бисера: сам цвет без тонировки и тонкая обводка, чтобы светлый бисер не терялся на светлом фоне.
///
/// Только для картинки: подпись цвета (артикул, название) рисует вызывающий экран.
class ColorSwatchView extends StatelessWidget {
  const ColorSwatchView({required this.rgb, this.size = 32, this.radius, super.key});

  final Rgb rgb;
  final double size;

  /// Радиус скругления; по умолчанию круг.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.fromARGB(255, rgb.r, rgb.g, rgb.b),
            shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: radius == null ? null : BorderRadius.circular(radius!),
            border: Border.all(color: CupertinoColors.separator.resolveFrom(context), width: 0.5),
          ),
        ),
      ),
    );
  }
}
