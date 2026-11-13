import 'dart:math' as math;

import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
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
    this.zone,
    this.rowCount,
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

  /// Где на странице схема. `null` — вся страница. Линейка не выходит за верх и низ зоны.
  final PatternZone? zone;

  /// Сколько рядов в зоне. Если задано, высота и шаг считаются сами: зона делится поровну. `null` — высоту и шаг
  /// задают вручную.
  final int? rowCount;

  bool get isBottomUp => direction == RowDirection.bottomUp;

  double get bottom => top + height;

  /// Верх и низ области, по которой ходит линейка: зона или вся страница.
  double _start(double imageHeight) => zone?.top ?? 0;

  double _end(double imageHeight) => zone?.bottom ?? imageHeight;

  /// Можно ли перейти к следующему ряду: линейка ещё не дошла до конца зоны в своём направлении.
  bool canAdvance(double imageHeight) {
    final int? count = rowCount;
    if (count != null) {
      return row < count;
    }
    return isBottomUp ? canMoveUp : canMoveDown(imageHeight);
  }

  /// Можно ли вернуться к предыдущему ряду.
  bool canRetreat(double imageHeight) => isBottomUp ? canMoveDown(imageHeight) : canMoveUp;

  /// Линейка стоит на последнем ряду зоны.
  bool isLastRow(double imageHeight) => !canAdvance(imageHeight);

  /// Следующий ряд: сдвиг к концу зоны по направлению рядов. Ряд растёт, только если линейка сдвинулась.
  RulerState next(double imageHeight) {
    if (rowCount != null) {
      return canAdvance(imageHeight) ? _atRow(row + 1, imageHeight) : this;
    }
    return isBottomUp ? _up(imageHeight, row + 1) : _down(imageHeight, row + 1);
  }

  /// Предыдущий ряд: сдвиг к началу зоны. Ряд убывает, только если линейка сдвинулась.
  RulerState previous(double imageHeight) {
    final int back = math.max(1, row - 1);
    if (rowCount != null) {
      return row > 1 ? _atRow(back, imageHeight) : this;
    }
    return isBottomUp ? _down(imageHeight, back) : _up(imageHeight, back);
  }

  /// Направление рядов. Пока не начали (ряд 1), линейка встаёт к новому началу зоны; иначе остаётся на месте.
  RulerState withDirection(RowDirection value, double imageHeight) {
    if (value == direction) {
      return this;
    }
    final RulerState turned = _copy(direction: value);
    if (row == 1) {
      return turned._atRow(1, imageHeight);
    }
    return turned;
  }

  /// Можно ли сдвинуть вниз на странице высотой [imageHeight].
  bool canMoveDown(double imageHeight) => top < _maxTop(imageHeight) - _eps;

  bool get canMoveUp => top > (zone?.top ?? 0) + _eps;

  /// Ставит линейку на ряд [newRow] (с 1) по направлению рядов. Положение считается от начала зоны, а не накапливается
  /// шагами, поэтому на последнем ряду линейка ровно у края зоны.
  RulerState _atRow(int newRow, double imageHeight) {
    final double offset = (newRow - 1) * step;
    final double raw = isBottomUp ? _end(imageHeight) - height - offset : _start(imageHeight) + offset;
    final double clamped = raw.clamp(_start(imageHeight), math.max(_start(imageHeight), _maxTop(imageHeight)));
    return _copy(top: clamped, row: newRow);
  }

  /// Сдвиг вниз на шаг, но не за низ зоны.
  RulerState _down(double imageHeight, int newRow) {
    final double next = math.min(top + step, _maxTop(imageHeight));
    if (next <= top + _eps) {
      return this;
    }
    return _copy(top: next, row: newRow);
  }

  /// Сдвиг вверх на шаг, но не выше верха зоны.
  RulerState _up(double imageHeight, int newRow) {
    final double next = math.max(top - step, _start(imageHeight));
    if (next >= top - _eps) {
      return this;
    }
    return _copy(top: next, row: newRow);
  }

  /// Новая высота в пределах зоны. Ручная высота снимает число рядов: оно считало высоту само.
  RulerState withHeight(double value, double imageHeight) {
    final double limit = math.max(minHeight, _span(imageHeight));
    final double next = value.clamp(minHeight, limit);
    // Линейка растёт от начала ряда: при ходе снизу вверх неподвижен низ, а не верх.
    // Шаг идёт за высотой, пока его не задали отдельно: иначе при любой высоте ряд сдвигается на прежнее значение.
    final bool stepFollowsHeight = (step - height).abs() < _eps;
    return _copy(
      top: isBottomUp ? bottom - next : top,
      height: next,
      step: stepFollowsHeight ? next : step,
      clearRowCount: true,
    ).fit(imageHeight);
  }

  RulerState withStep(double value, double imageHeight) =>
      _copy(step: value.clamp(minStep, math.max(minStep, imageHeight)), clearRowCount: true);

  RulerState withHighlight(RulerHighlight value) => _copy(highlight: value);

  /// Зона схемы на странице [imageHeight] (и шириной [imageWidth], если известна). Если число рядов задано, высота и
  /// шаг пересчитываются. На первом ряду линейка встаёт к началу новой зоны, дальше остаётся, где стоит.
  RulerState withZone(PatternZone value, double imageHeight, {double? imageWidth}) {
    final RulerState moved = _copy(
      zone: value.fitted(height: imageHeight, width: imageWidth),
    );
    return moved._relaid(imageHeight, keepRow: row);
  }

  /// Схема занимает всю страницу: зона и число рядов снимаются.
  RulerState withoutZone(double imageHeight) =>
      _copy(clearZone: true, clearRowCount: true)._relaid(imageHeight, keepRow: row);

  /// Сколько рядов в зоне. Высота и шаг становятся равны зоне, делённой на [count]; номер текущего ряда сохраняется
  /// (но не больше [count]). `null` снимает число: линейка остаётся как есть. Без зоны считает от всей страницы.
  RulerState withRowCount(int? count, double imageHeight) {
    if (count == null) {
      return _copy(clearRowCount: true);
    }
    final int most = math.max(1, (_span(imageHeight) / minHeight).floor());
    final int rows = count.clamp(1, most);
    final double each = _span(imageHeight) / rows;
    return _copy(
      height: each,
      step: each,
      rowCount: rows,
      row: math.min(row, rows),
    )._atRow(math.min(row, rows), imageHeight);
  }

  /// Приводит линейку к странице [imageHeight] (например, после замены картинки).
  RulerState fit(double imageHeight, {double? imageWidth}) {
    final PatternZone? fitted = zone?.fitted(height: imageHeight, width: imageWidth);
    final RulerState inZone = _copy(zone: fitted);
    if (rowCount != null) {
      return inZone.withRowCount(rowCount, imageHeight);
    }
    final double height = this.height.clamp(minHeight, math.max(minHeight, inZone._span(imageHeight)));
    final double low = inZone._start(imageHeight);
    final double top = this.top.clamp(low, math.max(low, inZone._end(imageHeight) - height));
    return inZone._copy(top: top, height: height);
  }

  /// После смены зоны: высота и шаг не больше зоны, при числе рядов считаются заново; на первом ряду линейка у начала.
  RulerState _relaid(double imageHeight, {required int keepRow}) {
    final int? count = rowCount;
    if (count != null) {
      return withRowCount(count, imageHeight);
    }
    final double limit = math.max(minHeight, _span(imageHeight));
    final RulerState fitted = _copy(height: height.clamp(minHeight, limit), step: step.clamp(minStep, limit));
    return keepRow == 1 ? fitted._atRow(1, imageHeight) : fitted.fit(imageHeight);
  }

  /// Высота области, по которой ходит линейка.
  double _span(double imageHeight) => _end(imageHeight) - _start(imageHeight);

  double _maxTop(double imageHeight) => math.max(_start(imageHeight), _end(imageHeight) - height);

  RulerState _copy({
    double? top,
    double? height,
    double? step,
    RulerHighlight? highlight,
    int? row,
    RowDirection? direction,
    PatternZone? zone,
    bool clearZone = false,
    int? rowCount,
    bool clearRowCount = false,
  }) => RulerState(
    top: top ?? this.top,
    height: height ?? this.height,
    step: step ?? this.step,
    highlight: highlight ?? this.highlight,
    row: row ?? this.row,
    direction: direction ?? this.direction,
    zone: clearZone ? null : zone ?? this.zone,
    rowCount: clearRowCount ? null : rowCount ?? this.rowCount,
  );

  /// Погрешность сравнения положений, px.
  static const double _eps = 1e-6;

  @override
  List<Object?> get props => <Object?>[top, height, step, highlight, row, direction, zone, rowCount];
}
