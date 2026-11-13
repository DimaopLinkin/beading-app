import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';

/// Канвы на выбор: самые частые в наборах. Цвет канвы берётся у текущей.
List<Fabric> fabricChoices(Fabric current) {
  Fabric make(FabricKind kind, int count) => Fabric.create(kind: kind, count: count, color: current.color).valueOrNull!;
  return <Fabric>[
    for (final int count in <int>[11, 14, 16, 18, 20]) make(FabricKind.aida, count),
    make(FabricKind.evenweave, 25),
    make(FabricKind.evenweave, 28),
    make(FabricKind.evenweave, 32),
    make(FabricKind.linen, 28),
    make(FabricKind.linen, 32),
  ];
}

/// «Аида 14», «Равномерка 28, через 2», «Лён 32, через 2».
String fabricLabel(AppLocalizations l10n, Fabric fabric) => switch (fabric.kind) {
  FabricKind.aida => l10n.imageWizardFabricAida(fabric.count),
  FabricKind.evenweave => l10n.imageWizardFabricEvenweave(fabric.count, fabric.overCount),
  FabricKind.linen => l10n.imageWizardFabricLinen(fabric.count, fabric.overCount),
};

/// Цвета канвы на выбор.
const List<Rgb> canvasColors = <Rgb>[
  Rgb(255, 255, 255),
  Rgb(245, 239, 224),
  Rgb(227, 213, 184),
  Rgb(150, 150, 150),
  Rgb(20, 20, 20),
];

String canvasName(AppLocalizations l10n, Rgb color) => switch (canvasColors.indexOf(color)) {
  0 => l10n.imageWizardCanvasWhite,
  1 => l10n.imageWizardCanvasCream,
  2 => l10n.imageWizardCanvasLinen,
  3 => l10n.imageWizardCanvasGray,
  4 => l10n.imageWizardCanvasBlack,
  _ => color.hex,
};
