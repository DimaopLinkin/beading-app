import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Строки списка материалов: числа, артикулы и текст для «Поделиться».
///
/// Одно место для экрана и текста сообщения, чтобы на экране и в сообщении цифры совпадали. Показывает либо
/// количество по схеме, либо с запасом ([withReserve]): переключатель экрана действует на оба.
class MaterialsFormat {
  MaterialsFormat(this.l10n, this.estimate, {required this.withReserve});

  final AppLocalizations l10n;
  final BeadEstimate estimate;
  final bool withReserve;

  static final NumberFormat _integers = NumberFormat('#,##0', 'ru');
  static final NumberFormat _grams = NumberFormat('#,##0.0', 'ru');

  /// Вес меньше этого значения (граммы) показываем как «< 0,1»: одна десятая — точность весов для бисера.
  static const double _minShownGrams = 0.05;

  /// Запас в процентах для подписей (0,1 → 10).
  int get reservePercent => (estimate.reserve * 100).round();

  int pieces(BeadMaterialLine line) => withReserve ? line.piecesWithReserve : line.pieces;

  double grams(BeadMaterialLine line) => withReserve ? line.gramsWithReserve : line.grams;

  int get totalPieces => withReserve ? estimate.totalPiecesWithReserve : estimate.totalPieces;

  double get totalGrams => withReserve ? estimate.totalGramsWithReserve : estimate.totalGrams;

  /// «Delica 11/0» или «рокайль 11/0».
  String get beadSizeLabel {
    final BeadSize size = estimate.beadSize;
    final String shape = switch (size.shape) {
      BeadShape.delica => l10n.beadShapeDelica,
      BeadShape.rocaille => l10n.beadShapeRocaille,
    };
    return '$shape ${size.sizeCode}';
  }

  String piecesText(int value) => l10n.materialsPieces(_integers.format(value));

  String gramsText(double value) {
    final String number = value > 0 && value < _minShownGrams ? '< 0,1' : _grams.format(value);
    return l10n.materialsGrams(number);
  }

  /// Бренд и артикул из каталога («Miyuki DB0010»); у смешанной нити — обе позиции через « + ».
  String articleLabel(PatternColor color) => color.components.join(' + ');

  /// Текст для сообщений и заметок: название работы, размер бисера, строки по цветам и итог.
  String shareText(String projectName) {
    final StringBuffer text = StringBuffer()
      ..writeln(l10n.materialsShareHeader(projectName))
      ..writeln(l10n.materialsShareBeads(beadSizeLabel))
      ..writeln();
    int number = 1;
    for (final BeadMaterialLine line in estimate.lines) {
      final String symbol = line.color.symbol == null ? '' : '${line.color.symbol} ';
      final String color = '$symbol${articleLabel(line.color)} ${line.color.name}';
      text.writeln(l10n.materialsShareLine(number++, color, piecesText(pieces(line)), gramsText(grams(line))));
    }
    text
      ..writeln()
      ..writeln(l10n.materialsShareTotal(piecesText(totalPieces), gramsText(totalGrams)));
    if (withReserve) text.writeln(l10n.materialsShareReserve(reservePercent));
    text.write(l10n.materialsShareApprox);
    return text.toString();
  }
}
