import 'package:beading/domain/image_to_grid/generation_stamp.dart';
import 'package:beading/domain/image_to_grid/image_recipe.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

/// Диалог «Сведения о генерации» (T103): версия приложения и генератора, сборка и короткие хэши параметров и фото.
/// [recipe] `null` — рецепта нет; у старого рецепта отпечатка нет.
Future<void> showGenerationInfoDialog(BuildContext context, String name, ImageRecipe? recipe) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final GenerationStamp? stamp = recipe?.stamp;
  final ImageToGridSettings? settings = recipe?.settings;
  final List<String> lines = <String>[
    if (recipe == null) l10n.generationInfoNone,
    if (recipe != null && stamp == null) l10n.generationInfoUnknownVersion,
    if (settings != null)
      l10n.generationInfoSummary(
        settings.columns,
        settings.rows?.toString() ?? l10n.generationInfoRowsAuto,
        settings.maxColors,
      ),
    if (stamp != null) ...<String>[
      if (stamp.app.isNotEmpty) l10n.generationInfoApp(stamp.app),
      if (stamp.commit.isNotEmpty) l10n.generationInfoCommit(stamp.commit),
      l10n.generationInfoAlgo(stamp.algo),
      if (stamp.cfg.isNotEmpty) l10n.generationInfoConfig(stamp.cfg),
      if (stamp.src.isNotEmpty) l10n.generationInfoPhoto(stamp.src),
      l10n.generationInfoNote,
    ],
  ];
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(name),
      content: Text(lines.join('\n')),
      actions: <Widget>[
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}
