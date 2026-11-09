import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:equatable/equatable.dart';

/// Форма бусины.
enum BeadShape {
  /// Цилиндр с тонкими стенками: длина вдоль отверстия близка к диаметру.
  delica,

  /// Круглая бусина: длина вдоль отверстия заметно меньше диаметра.
  rocaille,
}

/// Размер бусины: диаметр, длина вдоль отверстия и вес.
///
/// Реализует [CellMetrics]: бусина лежит отверстием вдоль ряда: ширина ячейки равна длине вдоль отверстия, высота —
/// диаметру. Кирпичный стежок меняет их местами в самой геометрии.
///
/// Значения приблизительные (каталожные данные производителей, у реальных бусин разброс ±0,1 мм).
final class BeadSize extends Equatable implements CellMetrics {
  const BeadSize._({
    required this.shape,
    required this.sizeCode,
    required this.diameterMm,
    required this.holeLengthMm,
    required this.weightGrams,
  });

  /// Miyuki Delica 15/0.
  static const BeadSize delica15 = BeadSize._(
    shape: BeadShape.delica,
    sizeCode: '15/0',
    diameterMm: 1.3,
    holeLengthMm: 1.2,
    weightGrams: 0.0029,
  );

  /// Miyuki Delica 11/0.
  static const BeadSize delica11 = BeadSize._(
    shape: BeadShape.delica,
    sizeCode: '11/0',
    diameterMm: 1.6,
    holeLengthMm: 1.3,
    weightGrams: 0.0050,
  );

  /// Miyuki Delica 10/0.
  static const BeadSize delica10 = BeadSize._(
    shape: BeadShape.delica,
    sizeCode: '10/0',
    diameterMm: 2.2,
    holeLengthMm: 1.7,
    weightGrams: 0.0100,
  );

  /// Рокайль 15/0.
  static const BeadSize rocaille15 = BeadSize._(
    shape: BeadShape.rocaille,
    sizeCode: '15/0',
    diameterMm: 1.5,
    holeLengthMm: 1.0,
    weightGrams: 0.0021,
  );

  /// Рокайль 11/0.
  static const BeadSize rocaille11 = BeadSize._(
    shape: BeadShape.rocaille,
    sizeCode: '11/0',
    diameterMm: 2.1,
    holeLengthMm: 1.4,
    weightGrams: 0.0060,
  );

  /// Рокайль 8/0.
  static const BeadSize rocaille8 = BeadSize._(
    shape: BeadShape.rocaille,
    sizeCode: '8/0',
    diameterMm: 3.0,
    holeLengthMm: 2.0,
    weightGrams: 0.0230,
  );

  /// Все поддерживаемые размеры: сначала Delica, затем рокайль, по возрастанию размера внутри каждого семейства.
  static const List<BeadSize> values = <BeadSize>[delica15, delica11, delica10, rocaille15, rocaille11, rocaille8];

  final BeadShape shape;

  /// Обозначение размера, например `11/0`.
  final String sizeCode;

  /// Диаметр бусины, мм.
  final double diameterMm;

  /// Длина бусины вдоль отверстия, мм.
  final double holeLengthMm;

  /// Вес одной бусины, граммы (для оценки расхода).
  final double weightGrams;

  @override
  double get widthMm => holeLengthMm;

  @override
  double get heightMm => diameterMm;

  @override
  List<Object?> get props => <Object?>[shape, sizeCode, diameterMm, holeLengthMm, weightGrams];

  @override
  String toString() => 'BeadSize(${shape.name} $sizeCode)';
}
