import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/grid_geometry.dart';

/// Как геометрия записывается в хранилище: имя вида и параметр `drop`.
typedef StoredGeometry = ({String kind, int drop});

/// Имена видов геометрии на устройствах менять нельзя.
abstract final class GridGeometryCodec {
  static const String rectangular = 'rectangular';
  static const String peyote = 'peyote';
  static const String brick = 'brick';

  static StoredGeometry encode(GridGeometry geometry) => switch (geometry) {
    RectangularGeometry() => (kind: rectangular, drop: 1),
    PeyoteGeometry(:final int drop) => (kind: peyote, drop: drop),
    BrickGeometry() => (kind: brick, drop: 1),
  };

  static Result<GridGeometry> decode({required String kind, required int drop}) {
    switch (kind) {
      case rectangular:
        return const Success<GridGeometry>(GridGeometry.rectangular());
      case peyote:
        if (drop < 1) {
          return Err<GridGeometry>(ValidationFailure('Недопустимый drop пейота: $drop'));
        }
        return Success<GridGeometry>(GridGeometry.peyote(drop: drop));
      case brick:
        return const Success<GridGeometry>(GridGeometry.brick());
      default:
        return Err<GridGeometry>(ValidationFailure('Неизвестная геометрия схемы: $kind'));
    }
  }
}
