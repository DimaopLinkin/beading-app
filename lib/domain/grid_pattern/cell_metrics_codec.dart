import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Произвольный размер ячейки, заданный в миллиметрах (когда нет ни бусины из списка, ни канвы).
final class CustomCellMetrics extends Equatable implements CellMetrics {
  const CustomCellMetrics({required this.widthMm, required this.heightMm});

  @override
  final double widthMm;

  @override
  final double heightMm;

  @override
  List<Object?> get props => <Object?>[widthMm, heightMm];
}

/// Запись размера ячейки в одну строку: JSON `{"kind": …, …параметры}`.
///
/// Виды: `bead` (`shape`, `size` — размер из [BeadSize.values]), `custom` (`widthMm`, `heightMm`) и `fabric` (канва для
/// вышивки: `fabric` — вид, `count`, `over`, `color`). Имена видов менять нельзя.
abstract final class CellMetricsCodec {
  static const String bead = 'bead';
  static const String custom = 'custom';
  static const String fabric = 'fabric';

  static Result<String> encode(CellMetrics metrics) {
    switch (metrics) {
      case BeadSize(:final BeadShape shape, :final String sizeCode):
        return Success<String>(jsonEncode(<String, Object?>{'kind': bead, 'shape': shape.name, 'size': sizeCode}));
      case CustomCellMetrics(:final double widthMm, :final double heightMm):
        return Success<String>(jsonEncode(<String, Object?>{'kind': custom, 'widthMm': widthMm, 'heightMm': heightMm}));
      case Fabric(:final FabricKind kind, :final int count, :final int overCount, :final Rgb color):
        return Success<String>(
          jsonEncode(<String, Object?>{
            'kind': fabric,
            'fabric': kind.name,
            'count': count,
            'over': overCount,
            'color': color.hex,
          }),
        );
      default:
        return Err<String>(ValidationFailure('Нельзя сохранить размер ячейки ${metrics.runtimeType}'));
    }
  }

  static Result<CellMetrics> decode(String stored) {
    final Object? parsed;
    try {
      parsed = jsonDecode(stored);
    } on FormatException {
      return const Err<CellMetrics>(ValidationFailure('Размер ячейки записан неверно'));
    }
    if (parsed is! Map<String, Object?>) {
      return const Err<CellMetrics>(ValidationFailure('Размер ячейки записан неверно'));
    }
    switch (parsed['kind']) {
      case bead:
        for (final BeadSize size in BeadSize.values) {
          if (size.shape.name == parsed['shape'] && size.sizeCode == parsed['size']) {
            return Success<CellMetrics>(size);
          }
        }
        return Err<CellMetrics>(ValidationFailure('Неизвестная бусина: ${parsed['shape']} ${parsed['size']}'));
      case custom:
        final Object? width = parsed['widthMm'];
        final Object? height = parsed['heightMm'];
        if (width is num && height is num && width > 0 && height > 0 && width.isFinite && height.isFinite) {
          return Success<CellMetrics>(CustomCellMetrics(widthMm: width.toDouble(), heightMm: height.toDouble()));
        }
        return const Err<CellMetrics>(ValidationFailure('Размеры ячейки должны быть положительными'));
      case fabric:
        return _decodeFabric(parsed);
      default:
        return Err<CellMetrics>(ValidationFailure('Неизвестный вид размера ячейки: ${parsed['kind']}'));
    }
  }

  static Result<CellMetrics> _decodeFabric(Map<String, Object?> parsed) {
    const Err<CellMetrics> broken = Err<CellMetrics>(ValidationFailure('Канва записана неверно'));
    FabricKind? kind;
    for (final FabricKind candidate in FabricKind.values) {
      if (candidate.name == parsed['fabric']) {
        kind = candidate;
      }
    }
    final Object? count = parsed['count'];
    final Object? over = parsed['over'];
    final Object? color = parsed['color'];
    if (kind == null || count is! int || over is! int || color is! String) {
      return broken;
    }
    final Rgb rgb;
    try {
      rgb = Rgb.fromHex(color);
    } on FormatException {
      return broken;
    }
    return Fabric.create(kind: kind, count: count, overCount: over, color: rgb);
  }
}
