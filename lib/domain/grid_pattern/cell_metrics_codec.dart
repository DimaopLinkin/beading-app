import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
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
/// Виды: `bead` (`shape`, `size` — размер из [BeadSize.values]) и `custom` (`widthMm`, `heightMm`).
/// Канву для вышивки (`fabric`, T36) добавит своя задача новым видом; формат уже расширяем. Имена видов менять нельзя.
abstract final class CellMetricsCodec {
  static const String bead = 'bead';
  static const String custom = 'custom';

  static Result<String> encode(CellMetrics metrics) {
    switch (metrics) {
      case BeadSize(:final BeadShape shape, :final String sizeCode):
        return Success<String>(jsonEncode(<String, Object?>{'kind': bead, 'shape': shape.name, 'size': sizeCode}));
      case CustomCellMetrics(:final double widthMm, :final double heightMm):
        return Success<String>(jsonEncode(<String, Object?>{'kind': custom, 'widthMm': widthMm, 'heightMm': heightMm}));
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
      default:
        return Err<CellMetrics>(ValidationFailure('Неизвестный вид размера ячейки: ${parsed['kind']}'));
    }
  }
}
