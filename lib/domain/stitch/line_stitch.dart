import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:equatable/equatable.dart';

/// Вид линейного стежка.
enum LineKind {
  /// Бэкстич: контур «назад иголкой» по решётке.
  backstitch,

  /// Прямой (длинный) стежок произвольной длины: усики, лучи.
  straight,
}

/// Отрезок между узлами полушаговой решётки. Без направления: концы хранятся по порядку, `from` раньше `to`.
final class LineStitch extends Equatable implements Comparable<LineStitch> {
  factory LineStitch({
    required LatticeNode a,
    required LatticeNode b,
    required LineKind kind,
    required int color,
  }) {
    if (a == b) throw ArgumentError('отрезок нулевой длины в $a');
    if (color < 1 || color > 0xFFFF) throw ArgumentError.value(color, 'color', 'от 1 до 65535');
    final bool ordered = a.compareTo(b) < 0;
    return LineStitch._(ordered ? a : b, ordered ? b : a, kind, color);
  }

  const LineStitch._(this.from, this.to, this.kind, this.color);

  final LatticeNode from;
  final LatticeNode to;
  final LineKind kind;
  final int color;

  /// Один и тот же отрезок независимо от вида и цвета.
  (LatticeNode, LatticeNode) get key => (from, to);

  @override
  int compareTo(LineStitch other) {
    final int byFrom = from.compareTo(other.from);
    return byFrom != 0 ? byFrom : to.compareTo(other.to);
  }

  @override
  List<Object?> get props => <Object?>[from, to, kind, color];
}
