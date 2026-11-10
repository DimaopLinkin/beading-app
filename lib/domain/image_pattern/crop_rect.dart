import 'package:equatable/equatable.dart';

/// Область обрезки в долях изображения (0…1), считается после поворота.
class CropRect extends Equatable {
  const CropRect({required this.left, required this.top, required this.right, required this.bottom})
    : assert(left >= 0 && top >= 0 && right <= 1 && bottom <= 1, 'Область выходит за изображение'),
      assert(left < right && top < bottom, 'Область должна иметь площадь');

  /// Всё изображение, без обрезки.
  static const CropRect full = CropRect(left: 0, top: 0, right: 1, bottom: 1);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;

  double get height => bottom - top;

  bool get isFull => this == full;

  @override
  List<Object?> get props => <Object?>[left, top, right, bottom];
}
