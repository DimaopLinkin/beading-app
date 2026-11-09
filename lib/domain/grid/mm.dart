import 'package:equatable/equatable.dart';

/// Точка в миллиметрах от левого верхнего угла схемы.
final class MmPoint extends Equatable {
  const MmPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  List<Object?> get props => <Object?>[x, y];
}

/// Размер в миллиметрах.
final class MmSize extends Equatable {
  const MmSize(this.width, this.height);

  final double width;
  final double height;

  @override
  List<Object?> get props => <Object?>[width, height];
}
