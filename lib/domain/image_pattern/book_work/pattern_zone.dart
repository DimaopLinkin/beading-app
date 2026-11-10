import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Где на фото страницы лежит схема: прямоугольник в пикселях картинки. Всё вокруг (поля, текст, подписи)
/// линейка обходит. Не зависит от размера окна и зума, как и сама линейка.
class PatternZone extends Equatable {
  const PatternZone({required this.top, required this.bottom, required this.left, required this.right});

  /// Зона на всю страницу.
  const PatternZone.full(double width, double height) : this(top: 0, bottom: height, left: 0, right: width);

  /// Меньше этого зона не бывает, px: иначе в неё не поместится даже самая тонкая линейка.
  static const double minSpan = 4;

  final double top;
  final double bottom;
  final double left;
  final double right;

  double get height => bottom - top;

  double get width => right - left;

  /// Зона внутри страницы [width] × [height]: края не выходят за страницу, зона не тоньше [minSpan].
  /// Если [width] неизвестна, по горизонтали остаётся как есть.
  PatternZone fitted({required double height, double? width}) {
    final double pageHeight = math.max(minSpan, height);
    final double newTop = top.clamp(0, pageHeight - minSpan);
    final double newBottom = bottom.clamp(newTop + minSpan, pageHeight);
    if (width == null) {
      return PatternZone(top: newTop, bottom: newBottom, left: left, right: right);
    }
    final double pageWidth = math.max(minSpan, width);
    final double newLeft = left.clamp(0, pageWidth - minSpan);
    final double newRight = right.clamp(newLeft + minSpan, pageWidth);
    return PatternZone(top: newTop, bottom: newBottom, left: newLeft, right: newRight);
  }

  PatternZone copyWith({double? top, double? bottom, double? left, double? right}) => PatternZone(
    top: top ?? this.top,
    bottom: bottom ?? this.bottom,
    left: left ?? this.left,
    right: right ?? this.right,
  );

  @override
  List<Object?> get props => <Object?>[top, bottom, left, right];
}
