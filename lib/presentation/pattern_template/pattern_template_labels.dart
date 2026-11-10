import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/pattern_generation/pattern_template.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/pattern_template/pattern_template_state.dart';

extension TemplateKindLabel on TemplateKind {
  String label(AppLocalizations l10n) => switch (this) {
    TemplateKind.stripes => l10n.templateKindStripes,
    TemplateKind.zigzag => l10n.templateKindZigzag,
    TemplateKind.diamonds => l10n.templateKindDiamonds,
    TemplateKind.checker => l10n.templateKindChecker,
    TemplateKind.gradient => l10n.templateKindGradient,
    TemplateKind.border => l10n.templateKindBorder,
  };
}

extension SymmetryLabel on PatternSymmetry {
  String label(AppLocalizations l10n) => switch (this) {
    PatternSymmetry.none => l10n.templateSymmetryNone,
    PatternSymmetry.horizontal => l10n.templateSymmetryHorizontal,
    PatternSymmetry.vertical => l10n.templateSymmetryVertical,
    PatternSymmetry.both => l10n.templateSymmetryBoth,
  };
}

extension BeadSizeLabel on BeadSize {
  String label(AppLocalizations l10n) => l10n.templateBeadSize(
    switch (shape) {
      BeadShape.delica => l10n.beadShapeDelica,
      BeadShape.rocaille => l10n.beadShapeRocaille,
    },
    sizeCode,
  );
}

String templateProblemText(AppLocalizations l10n, TemplateProblem problem) => switch (problem) {
  TemplateProblem.catalogUnavailable => l10n.templateProblemCatalog,
  TemplateProblem.invalidParameters => l10n.templateProblemParameters,
  TemplateProblem.saveFailed => l10n.templateProblemSave,
};
