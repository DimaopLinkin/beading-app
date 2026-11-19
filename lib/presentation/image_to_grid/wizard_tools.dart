import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Группы параметров мастера (макет 18): внизу экрана показана одна, остальные выбираются в полосе инструментов.
enum WizardTool {
  base(CupertinoIcons.square_stack_3d_up),
  size(CupertinoIcons.arrow_up_left_arrow_down_right),
  colors(CupertinoIcons.color_filter),
  details(CupertinoIcons.sparkles),
  stitches(CupertinoIcons.scribble),
  total(CupertinoIcons.list_bullet)
  ;

  const WizardTool(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    base => l10n.imageWizardToolBase,
    size => l10n.imageWizardToolSize,
    colors => l10n.imageWizardToolColors,
    details => l10n.imageWizardToolDetails,
    stitches => l10n.imageWizardToolStitches,
    total => l10n.imageWizardToolTotal,
  };

  /// Группы, доступные для ремесла: «Стежков» у бисера нет.
  static List<WizardTool> of(Craft craft) => <WizardTool>[
    for (final WizardTool tool in values)
      if (tool != stitches || craft == Craft.crossStitch) tool,
  ];

  /// Изменена ли группа относительно параметров, с которыми мастер открылся.
  bool changed({
    required ImageToGridSettings from,
    required ImageToGridSettings to,
    required CropRect fromCrop,
    required CropRect toCrop,
    required bool brushChanged,
  }) => switch (this) {
    base =>
      from.craft != to.craft ||
          from.technique != to.technique ||
          from.beadSize != to.beadSize ||
          from.fabric != to.fabric,
    size => from.columns != to.columns || from.rows != to.rows || from.fit != to.fit || fromCrop != toCrop,
    colors =>
      from.maxColors != to.maxColors ||
          from.paletteSource != to.paletteSource ||
          from.onlyStash != to.onlyStash ||
          from.otherBrands != to.otherBrands ||
          from.otherBrandsOnly != to.otherBrandsOnly ||
          from.shadows != to.shadows ||
          from.beadSeries != to.beadSeries ||
          from.finishGroups != to.finishGroups,
    details =>
      from.preset != to.preset ||
          from.background != to.background ||
          from.outline != to.outline ||
          from.useMasks != to.useMasks ||
          brushChanged,
    stitches => from.backstitch != to.backstitch || from.mixedStitches != to.mixedStitches || from.blends != to.blends,
    total => false,
  };
}

/// Полоса инструментов: значок и подпись, у изменённой группы точка. Прокручивается, если не помещается (крупный шрифт).
class WizardToolStrip extends StatelessWidget {
  const WizardToolStrip({
    required this.tools,
    required this.selected,
    required this.changed,
    required this.onSelected,
    super.key,
  });

  final List<WizardTool> tools;
  final WizardTool selected;
  final Set<WizardTool> changed;
  final ValueChanged<WizardTool> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final Color accent = CupertinoTheme.of(context).primaryColor;
    final Color idle = CupertinoColors.secondaryLabel.resolveFrom(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final WizardTool tool in tools)
            CupertinoButton(
              key: ValueKey<String>('wizard-tool-${tool.name}'),
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s, vertical: tokens.spacing.xs),
              minimumSize: Size.square(tokens.minTapTarget),
              onPressed: () => onSelected(tool),
              child: Semantics(
                selected: tool == selected,
                button: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Icon(tool.icon, color: tool == selected ? accent : idle),
                        if (changed.contains(tool))
                          Positioned(
                            top: -2,
                            right: -4,
                            child: Container(
                              key: ValueKey<String>('wizard-tool-dot-${tool.name}'),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.label(l10n),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: tool == selected ? FontWeight.w600 : FontWeight.w400,
                        color: tool == selected ? accent : idle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
