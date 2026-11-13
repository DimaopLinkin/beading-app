import 'dart:convert';

import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:equatable/equatable.dart';

/// Вид точечного стежка.
enum PointKind { frenchKnot, colonialKnot, bead }

/// Узелок или бусина в узле полушаговой решётки. В узле не больше одной точки.
///
/// Узелок — цвет палитры [color] и число оборотов [wraps]; бусина — позиция каталога бисера [bead].
final class PointStitch extends Equatable implements Comparable<PointStitch> {
  PointStitch.knot({required this.node, required this.kind, required this.color, this.wraps = defaultWraps})
    : bead = null {
    if (kind == PointKind.bead) throw ArgumentError('бусина создаётся через PointStitch.bead');
    if (color < 1 || color > 0xFFFF) throw ArgumentError.value(color, 'color', 'от 1 до 65535');
    if (wraps < 1 || wraps > maxWraps) throw ArgumentError.value(wraps, 'wraps', 'от 1 до $maxWraps');
  }

  PointStitch.bead({required this.node, required CatalogRef this.bead}) : kind = PointKind.bead, color = 0, wraps = 0 {
    if (utf8.encode(bead!.brand).length > maxRefLength || utf8.encode(bead!.code).length > maxRefLength) {
      throw ArgumentError('бренд и артикул бусины не длиннее $maxRefLength байт');
    }
  }

  static const int defaultWraps = 2;
  static const int maxWraps = 4;

  /// Наибольшая длина бренда и артикула бусины в байтах UTF-8 (предел формата `StitchLayersCodec`).
  static const int maxRefLength = 256;

  final LatticeNode node;
  final PointKind kind;

  /// Цвет палитры (с 1) у узелка; у бусины `0`.
  final int color;

  /// Обороты нити у узелка; у бусины `0`.
  final int wraps;

  /// Позиция каталога бисера у бусины; у узелка `null`.
  final CatalogRef? bead;

  @override
  int compareTo(PointStitch other) => node.compareTo(other.node);

  @override
  List<Object?> get props => <Object?>[node, kind, color, wraps, bead];
}
