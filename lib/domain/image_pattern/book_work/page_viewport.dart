import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Зум и сдвиг страницы: экранная точка = [scale] · точка страницы + ([dx], [dy]).
/// Точки страницы — в логических пикселях при масштабе 1, когда страница вписана по ширине.
class PageViewport extends Equatable {
  const PageViewport({required this.scale, required this.dx, required this.dy});

  static const PageViewport identity = PageViewport(scale: 1, dx: 0, dy: 0);

  /// Предел зума схемы.
  static const double maxScale = 8;

  final double scale;
  final double dx;
  final double dy;

  /// Сдвигает вид так, чтобы линейка [rulerTop]…[rulerBottom] (в тех же единицах, что и страница) была видна
  /// в окне высотой [viewHeight] между [topInset] и [bottomInset] (панели поверх картинки).
  ///
  /// Если линейка уже видна целиком — вид не меняется. Иначе она встаёт на треть видимой области сверху.
  /// [contentHeight] ограничивает сдвиг: за край страницы вид не уезжает.
  PageViewport revealing({
    required double rulerTop,
    required double rulerBottom,
    required double viewHeight,
    required double contentHeight,
    double topInset = 0,
    double bottomInset = 0,
  }) {
    final double visibleTop = topInset;
    final double visibleBottom = viewHeight - bottomInset;
    final double screenTop = scale * rulerTop + dy;
    final double screenBottom = scale * rulerBottom + dy;
    if (screenTop >= visibleTop && screenBottom <= visibleBottom) {
      return this;
    }
    final double visibleHeight = math.max(0, visibleBottom - visibleTop);
    final double wanted = visibleTop + visibleHeight / 3 - scale * rulerTop;
    // Страница не уезжает: верх не ниже верхней панели, низ не выше нижней границы окна.
    final double highest = visibleTop;
    final double lowest = math.min(highest, visibleBottom - scale * contentHeight);
    return PageViewport(scale: scale, dx: dx, dy: wanted.clamp(lowest, highest));
  }

  @override
  List<Object?> get props => <Object?>[scale, dx, dy];
}
