import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Цвет подсветки линейки. Сохраняется по имени; оттенки задаёт слой представления.
enum RulerHighlight { yellow, green, blue, pink }

/// Линейка на одной странице схемы. Все размеры — в пикселях картинки страницы, а не экрана:
/// так положение не зависит от размера окна и зума.
class RulerState extends Equatable {
  const RulerState({
    required this.top,
    required this.height,
    required this.step,
    required this.highlight,
    required this.row,
  });

  /// Линейка у верхнего края страницы: высота — 3 % страницы, шаг равен высоте, ряд первый.
  factory RulerState.initial(double imageHeight) {
    final double height = math.max(minHeight, imageHeight * 0.03).clamp(minHeight, math.max(minHeight, imageHeight));
    return RulerState(top: 0, height: height, step: height, highlight: RulerHighlight.yellow, row: 1);
  }

  /// Нижняя граница высоты и шага, px: тоньше линейку не разглядеть и не поймать пальцем.
  static const double minHeight = 4;
  static const double minStep = 1;

  /// Верхний край линейки от верха картинки.
  final double top;
  final double height;

  /// На сколько сдвигают кнопки «назад» и «следующий ряд».
  final double step;
  final RulerHighlight highlight;

  /// Номер текущего ряда на этой странице, с 1.
  final int row;

  double get bottom => top + height;

  /// Можно ли сдвинуть вниз на странице высотой [imageHeight].
  bool canMoveDown(double imageHeight) => top < _maxTop(imageHeight) - _eps;

  bool get canMoveUp => top > _eps;

  /// Сдвиг вниз на шаг, но не за нижний край страницы. Ряд растёт, только если линейка сдвинулась.
  RulerState moveDown(double imageHeight) {
    final double next = math.min(top + step, _maxTop(imageHeight));
    if (next <= top + _eps) {
      return this;
    }
    return _copy(top: next, row: row + 1);
  }

  /// Сдвиг вверх на шаг, но не выше верха страницы. Ряд убывает, только если линейка сдвинулась.
  RulerState moveUp() {
    final double next = math.max(top - step, 0);
    if (next >= top - _eps) {
      return this;
    }
    return _copy(top: next, row: math.max(1, row - 1));
  }

  /// Новая высота в пределах страницы; низ линейки не выходит за страницу.
  RulerState withHeight(double value, double imageHeight) {
    final double limit = math.max(minHeight, imageHeight);
    return _copy(height: value.clamp(minHeight, limit)).fit(imageHeight);
  }

  RulerState withStep(double value, double imageHeight) =>
      _copy(step: value.clamp(minStep, math.max(minStep, imageHeight)));

  RulerState withHighlight(RulerHighlight value) => _copy(highlight: value);

  /// Приводит линейку к странице [imageHeight] (например, после замены картинки).
  RulerState fit(double imageHeight) {
    final double height = this.height.clamp(minHeight, math.max(minHeight, imageHeight));
    final double top = this.top.clamp(0, math.max(0, imageHeight - height));
    return _copy(top: top, height: height);
  }

  double _maxTop(double imageHeight) => math.max(0, imageHeight - height);

  RulerState _copy({double? top, double? height, double? step, RulerHighlight? highlight, int? row}) => RulerState(
    top: top ?? this.top,
    height: height ?? this.height,
    step: step ?? this.step,
    highlight: highlight ?? this.highlight,
    row: row ?? this.row,
  );

  /// Погрешность сравнения положений, px.
  static const double _eps = 1e-6;

  @override
  List<Object?> get props => <Object?>[top, height, step, highlight, row];
}
