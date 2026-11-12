import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Строки экрана мулине и текст для «Поделиться»: одно место, чтобы цифры на экране и в сообщении совпадали.
class FlossFormat {
  FlossFormat(this.l10n, this.estimate, {required this.withReserve});

  final AppLocalizations l10n;
  final FlossEstimate estimate;
  final bool withReserve;

  static final NumberFormat _integers = NumberFormat('#,##0', 'ru');
  static final NumberFormat _cm = NumberFormat('#,##0.#', 'ru');

  int get reservePercent => (estimate.reserve * 100).round();

  int skeins(FlossMaterialLine line) => withReserve ? line.skeinsWithReserve : line.skeins;

  int purchaseSkeins(FlossPurchaseLine line) => withReserve ? line.skeinsWithReserve : line.skeins;

  int beadPieces(BeadPurchaseLine line) => withReserve ? line.piecesWithReserve : line.pieces;

  int get totalSkeins => withReserve ? estimate.totalSkeinsWithReserve : estimate.totalSkeins;

  String skeinsText(int count) => l10n.flossSkeins(count);

  String count(int value) => _integers.format(value);

  /// «Аида 14» или «Равномерка 28, через 2».
  String get fabricLabel {
    final Fabric fabric = estimate.fabric;
    return switch (fabric.kind) {
      FabricKind.aida => l10n.imageWizardFabricAida(fabric.count),
      FabricKind.evenweave => l10n.imageWizardFabricEvenweave(fabric.count, fabric.overCount),
      FabricKind.linen => l10n.imageWizardFabricLinen(fabric.count, fabric.overCount),
    };
  }

  String get fabricNeedText {
    final FabricNeed need = estimate.fabricNeed;
    return l10n.flossFabricNeed(
      _cm.format(need.widthCm),
      _cm.format(need.heightCm),
      _cm.format(need.stitchedWidthCm),
      _cm.format(need.stitchedHeightCm),
      _cm.format(need.marginCm),
    );
  }

  /// Бренд и номер; у смешанной нити — обе нитки через « + ».
  String articleLabel(PatternColor color) => color.components.join(' + ');

  /// Что ещё, кроме полных крестиков, есть у цвета: неполные, бэкстич, узелки.
  String? extrasText(FlossMaterialLine line) {
    final List<String> parts = <String>[
      if (line.partialStitches > 0) l10n.flossPartials(count(line.partialStitches)),
      if (line.backstitchCells > 0) l10n.flossBackstitch(_cm.format(line.backstitchCells)),
      if (line.knots > 0) l10n.flossKnots(count(line.knots)),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  String shareText(String projectName) {
    final StringBuffer text = StringBuffer()
      ..writeln(l10n.flossShareHeader(projectName))
      ..writeln(
        l10n.flossShareFabric(
          fabricLabel,
          _cm.format(estimate.fabricNeed.widthCm),
          _cm.format(estimate.fabricNeed.heightCm),
        ),
      )
      ..writeln();
    int number = 1;
    for (final FlossPurchaseLine line in estimate.purchases) {
      final String name = line.name == null ? '' : ' ${line.name}';
      text.writeln(l10n.flossShareLine(number++, '${line.ref}$name', skeinsText(purchaseSkeins(line))));
    }
    if (estimate.beads.isNotEmpty) {
      text
        ..writeln()
        ..writeln(l10n.flossBeadsTitle);
      for (final BeadPurchaseLine line in estimate.beads) {
        text.writeln(l10n.flossShareBeadLine('${line.ref}', l10n.flossBeadPieces(beadPieces(line))));
      }
    }
    text
      ..writeln()
      ..writeln(l10n.flossTotal(skeinsText(totalSkeins)));
    if (withReserve) text.writeln(l10n.flossShareReserve(reservePercent));
    text.write(l10n.flossEstimateHint);
    return text.toString();
  }
}
