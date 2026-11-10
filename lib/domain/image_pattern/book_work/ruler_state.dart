import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Цвет подсветки линейки. Сохраняется по имени; оттенки задаёт слой представления.
enum RulerHighlight { yellow, green, blue, pink }

/// Куда идут ряды на странице: в книгах нумеруют и сверху вниз, и снизу вверх. Сохраняется по имени.
enum RowDirection { topDown, bottomUp }

/// Линейка на одной странице схемы. Все размеры — в пикселях картинки страницы, а не экрана:
/// так положение не зависит от размера окна и зума.
class RulerState extends Equatable {
  const RulerState({
    required this.top,
    required this.height,
    required this.step,
    required this.highlight,
    required this.row,
    this.direction = RowDirection.topDown,
  });

  /// Линейка у начала страницы (сверху или снизу, по [direction]): высота — 3 % страницы, шаг равен высоте, ряд первый.
  factory RulerState.initial(double imageHeight, {RowDirection direction = RowDirection.topDown}) {
    final double height = math.max(minHeight, imageHeight * 0.03).clamp(minHeight, math.max(minHeight, imageHeight));
    return RulerState(
      top: direction == RowDirection.topDown ? 0 : math.max(0, imageHeight - height),
      height: height,
      step: height,
      highlight: RulerHighlight.yellow,
      row: 1,
      direction: direction,
    );
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

  /// В какую сторону страницы идут ряды: «следующий ряд» сдвигает линейку туда.
  final RowDirection direction;

  bool get isBottomUp => direction == RowDirection.bottomUp;

  double get bottom => top + height;

  /// Можно ли перейти к следующему ряду: линейка ещё не дошла до конца страницы в своём направлении.
  bool canAdvance(double imageHeight) => isBottomUp ? canMoveUp : canMoveDown(imageHeight);

  /// Можно ли вернуться к предыдущему ряду.
  bool canRetreat(double imageHeight) => isBottomUp ? canMoveDown(imageHeight) : canMoveUp;

  /// Линейка стоит на последнем ряду страницы.
  bool isLastRow(double imageHeight) => !canAdvance(imageHeight);

  /// Следующий ряд: сдвиг к концу страницы по направлению рядов. Ряд растёт, только если линейка сдвинулась.
  RulerState next(double imageHeight) => isBottomUp ? _up(row + 1) : _down(imageHeight, row + 1);

  /// Предыдущий ряд: сдвиг к началу страницы. Ряд убывает, только если линейка сдвинулась.
  RulerState previous(double imageHeight) =>
      isBottomUp ? _down(imageHeight, math.max(1, row - 1)) : _up(math.max(1, row - 1));

  /// Направление рядов. Пока не начали (ряд 1), линейка встаёт к новому началу страницы; иначе остаётся на месте.
  RulerState withDirection(RowDirection value, double imageHeight) {
    if (value == direction) {
      return this;
    }
    if (row == 1) {
      final double fitted = height.clamp(minHeight, math.max(minHeight, imageHeight));
      final double edge = value == RowDirection.topDown ? 0 : math.max(0, imageHeight - fitted);
      return _copy(top: edge, height: fitted, direction: value);
    }
    return _copy(direction: value);
  }

  /// Можно ли сдвинуть вниз на странице высотой [imageHeight].
  bool canMoveDown(double imageHeight) => top < _maxTop(imageHeight) - _eps;

  bool get canMoveUp => top > _eps;

  /// Сдвиг вниз на шаг, но не за нижний край страницы.
  RulerState _down(double imageHeight, int newRow) {
    final double next = math.min(top + step, _maxTop(imageHeight));
    if (next <= top + _eps) {
      return this;
    }
    return _copy(top: next, row: newRow);
  }

  /// Сдвиг вверх на шаг, но не выше верха страницы.
  RulerState _up(int newRow) {
    final double next = math.max(top - step, 0);
    if (next >= top - _eps) {
      return this;
    }
    return _copy(top: next, row: newRow);
  }

  /// Новая высота в пределах страницы; линейка не выходит за страницу.
  RulerState withHeight(double value, double imageHeight) {
    final double limit = math.max(minHeight, imageHeight);
    final double next = value.clamp(minHeight, limit);
    // Линейка растёт от начала ряда: при ходе снизу вверх неподвижен низ, а не верх.
    // Шаг идёт за высотой, пока его не задали отдельно: иначе при любой высоте ряд сдвигается на прежнее значение.
    final bool stepFollowsHeight = (step - height).abs() < _eps;
    return _copy(top: isBottomUp ? bottom - next : top, height: next, step: stepFollowsHeight ? next : step)
        .fit(imageHeight);
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

  RulerState _copy({
    double? top,
    double? height,
    double? step,
    RulerHighlight? highlight,
    int? row,
    RowDirection? direction,
  }) => RulerState(
    top: top ?? this.top,
    height: height ?? this.height,
    step: step ?? this.step,
    highlight: highlight ?? this.highlight,
    row: row ?? this.row,
    direction: direction ?? this.direction,
  );

  /// Погрешность сравнения положений, px.
  static const double _eps = 1e-6;

  @override
  List<Object?> get props => <Object?>[top, height, step, highlight, row, direction];
}
