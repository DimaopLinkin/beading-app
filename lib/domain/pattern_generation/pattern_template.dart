import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Ось, вдоль которой меняется цвет в полосах и градиенте.
enum PatternAxis {
  /// Цвет меняется слева направо (вертикальные полосы).
  x,

  /// Цвет меняется сверху вниз (горизонтальные полосы).
  y,
}

/// Зеркальная симметрия готового узора: первая половина отражается на вторую.
enum PatternSymmetry {
  none,

  /// Левая половина отражается вправо.
  horizontal,

  /// Верхняя половина отражается вниз.
  vertical,

  /// Обе оси.
  both,
}

/// Шаблон узора: чистая функция «положение ячейки → номер цвета в списке цветов узора».
///
/// Координаты [colorIndexAt] — в ячейках, с учётом сдвига геометрии: для пейота и кирпичного стежка `x` или `y`
/// сдвинуты на 0,5 у сдвинутых ячеек, поэтому диагонали выглядят ровными, а не «ступеньками». Размер ячейки
/// (соотношение сторон бусины) не учитывается: узор строится в ячейках.
sealed class PatternTemplate extends Equatable {
  const PatternTemplate();

  /// Сколько цветов нужно шаблону минимум.
  int get minColors => 2;

  /// Сколько цветов шаблон принимает максимум; `null` — без предела.
  int? get maxColors => 2;

  /// Описание ошибки параметров или `null`.
  String? get parameterError;

  /// Размер раппорта (повторяющегося фрагмента) в ячейках, ширина × высота, или `null`, если узор не повторяется.
  (int, int)? get rapport;

  /// Номер цвета (с нуля) для ячейки с левым верхним углом в `(x, y)` в сетке `width × height`.
  ///
  /// [paletteLength] — сколько цветов в итоговом списке; градиенту это нужно для раскладки по полосам.
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength});
}

/// Полосы одинаковой ширины; цвета идут по кругу.
final class StripesTemplate extends PatternTemplate {
  const StripesTemplate({this.stripeWidth = 2, this.axis = PatternAxis.y});

  /// Ширина одной полосы, ячеек.
  final int stripeWidth;
  final PatternAxis axis;

  @override
  int? get maxColors => null;

  @override
  String? get parameterError => stripeWidth < 1 ? 'ширина полосы должна быть не меньше 1' : null;

  /// Для полос раппорт зависит от числа цветов, поэтому генератор считает его сам по [rapportFor].
  @override
  (int, int)? get rapport => rapportFor(2);

  (int, int) rapportFor(int colors) => axis == PatternAxis.y ? (1, stripeWidth * colors) : (stripeWidth * colors, 1);

  @override
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength}) =>
      ((axis == PatternAxis.y ? y : x) / stripeWidth).floor() % paletteLength;

  @override
  List<Object?> get props => <Object?>[stripeWidth, axis];
}

/// Зигзаг: ломаная линия второго цвета на фоне первого, линии повторяются вниз.
final class ZigzagTemplate extends PatternTemplate {
  const ZigzagTemplate({this.amplitude = 3, this.thickness = 1, this.gap = 2});

  /// Высота излома и длина одного «зуба» по горизонтали, ячеек.
  final int amplitude;

  /// Толщина линии по вертикали, ячеек.
  final int thickness;

  /// Просвет между соседними линиями, ячеек.
  final int gap;

  int get pitch => amplitude + thickness + gap;

  @override
  String? get parameterError {
    if (amplitude < 1) return 'амплитуда зигзага должна быть не меньше 1';
    if (thickness < 1) return 'толщина линии должна быть не меньше 1';
    if (gap < 0) return 'просвет не может быть отрицательным';
    return null;
  }

  @override
  (int, int)? get rapport => (2 * amplitude, pitch);

  @override
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength}) {
    final double phase = x % (2 * amplitude);
    final double wave = phase < amplitude ? phase : 2 * amplitude - phase;
    final double offset = (y - wave.floorToDouble()) % pitch;
    return offset < thickness ? 1 : 0;
  }

  @override
  List<Object?> get props => <Object?>[amplitude, thickness, gap];
}

/// Ромбы второго цвета на фоне первого, по сетке с шагом `2 * size`.
final class DiamondsTemplate extends PatternTemplate {
  const DiamondsTemplate({this.size = 3});

  /// Полуширина ромба, ячеек.
  final int size;

  @override
  String? get parameterError => size < 1 ? 'размер ромба должен быть не меньше 1' : null;

  @override
  (int, int)? get rapport => (2 * size, 2 * size);

  @override
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength}) {
    final double dx = ((x + 0.5) % (2 * size) - size).abs();
    final double dy = ((y + 0.5) % (2 * size) - size).abs();
    return dx + dy < size ? 1 : 0;
  }

  @override
  List<Object?> get props => <Object?>[size];
}

/// Шахматка из квадратов по [cellSize] ячеек.
final class CheckerTemplate extends PatternTemplate {
  const CheckerTemplate({this.cellSize = 2});

  final int cellSize;

  @override
  String? get parameterError => cellSize < 1 ? 'сторона клетки должна быть не меньше 1' : null;

  @override
  (int, int)? get rapport => (2 * cellSize, 2 * cellSize);

  @override
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength}) =>
      ((x / cellSize).floor() + (y / cellSize).floor()) % 2;

  @override
  List<Object?> get props => <Object?>[cellSize];
}

/// Градиент от первого цвета ко второму по Lab; промежуточные цвета подбираются из каталога.
final class GradientTemplate extends PatternTemplate {
  const GradientTemplate({this.steps = 8, this.axis = PatternAxis.x});

  static const int maxSteps = 64;

  /// Сколько ступеней в идеальном градиенте. В узоре их может быть меньше, если каталог беднее.
  final int steps;
  final PatternAxis axis;

  @override
  String? get parameterError => steps < 2 || steps > maxSteps ? 'ступеней градиента от 2 до $maxSteps' : null;

  @override
  (int, int)? get rapport => null;

  @override
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength}) {
    final double length = (axis == PatternAxis.x ? width : height).toDouble();
    final double position = (axis == PatternAxis.x ? x : y) + 0.5;
    return math.min(paletteLength - 1, math.max(0, (position / length * paletteLength).floor()));
  }

  @override
  List<Object?> get props => <Object?>[steps, axis];
}

/// Бордюр: рамка первого цвета вдоль краёв, внутри второй.
final class BorderTemplate extends PatternTemplate {
  const BorderTemplate({this.thickness = 2});

  final int thickness;

  @override
  String? get parameterError => thickness < 1 ? 'толщина бордюра должна быть не меньше 1' : null;

  @override
  (int, int)? get rapport => null;

  @override
  int colorIndexAt(double x, double y, {required int width, required int height, required int paletteLength}) {
    final double edge = math.min(math.min(x, y), math.min(width - (x + 1), height - (y + 1)));
    return edge < thickness ? 0 : 1;
  }

  @override
  List<Object?> get props => <Object?>[thickness];
}
