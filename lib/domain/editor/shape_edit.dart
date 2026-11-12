import 'package:equatable/equatable.dart';

/// Ось вставки или удаления: ряд сетки или её столбец.
enum ShapeAxis { row, column }

/// Правка формы схемы: вставка или удаление ряда или столбца [at]. Нужна, чтобы отметки прогресса следовали за клетками.
final class ShapeEdit extends Equatable {
  const ShapeEdit({required this.axis, required this.at, required this.insert});

  final ShapeAxis axis;
  final int at;

  /// `true` — вставка, `false` — удаление.
  final bool insert;

  /// Обратная правка: так отменяется вставка (удаление того же ряда) и удаление (пустой ряд на том же месте).
  ShapeEdit get inverse => ShapeEdit(axis: axis, at: at, insert: !insert);

  @override
  List<Object?> get props => <Object?>[axis, at, insert];
}
