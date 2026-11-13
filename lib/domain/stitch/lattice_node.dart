import 'package:equatable/equatable.dart';

/// Узел полушаговой решётки `(2w+1)×(2h+1)` схемы шириной `w` и высотой `h` клеток.
///
/// Чётные `x` и `y` — углы клеток, нечётные — середины: `(2c+1, 2r+1)` — центр клетки `(c, r)`, смешанные — середины
/// её сторон. По такой решётке проходят бэкстич через середины клеток (для ¾ крестика и «через 2») и узелки.
final class LatticeNode extends Equatable implements Comparable<LatticeNode> {
  const LatticeNode(this.x, this.y) : assert(x >= 0 && y >= 0, 'координаты узла неотрицательны');

  /// Угол клетки: левый верхний угол клетки `(column, row)`.
  const LatticeNode.corner(int column, int row) : this(column * 2, row * 2);

  /// Центр клетки `(column, row)`.
  const LatticeNode.center(int column, int row) : this(column * 2 + 1, row * 2 + 1);

  final int x;
  final int y;

  /// Угол клеток (на пересечении линий сетки).
  bool get isCorner => x.isEven && y.isEven;

  /// Центр клетки.
  bool get isCenter => x.isOdd && y.isOdd;

  LatticeNode shifted(int dx, int dy) => LatticeNode(x + dx, y + dy);

  @override
  int compareTo(LatticeNode other) => y != other.y ? y.compareTo(other.y) : x.compareTo(other.x);

  @override
  List<Object?> get props => <Object?>[x, y];

  @override
  String toString() => 'Node($x, $y)';
}
