import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:flutter/cupertino.dart';

/// Итог выбора в листе цвета.
sealed class TemplateColorChoice {
  const TemplateColorChoice();
}

class TemplateColorPicked extends TemplateColorChoice {
  const TemplateColorPicked(this.color);

  final PatternColor color;
}

class TemplateColorRemoved extends TemplateColorChoice {
  const TemplateColorRemoved();
}

/// Лист выбора цвета из каталога: поиск по артикулу и названию; для полос — ещё «Убрать этот цвет».
Future<TemplateColorChoice?> showTemplateColorSheet(
  BuildContext context, {
  required List<PatternColor> catalog,
  required bool removable,
}) => showCupertinoModalPopup<TemplateColorChoice>(
  context: context,
  builder: (_) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: TemplateColorSheet(catalog: catalog, removable: removable),
    ),
  ),
);

class TemplateColorSheet extends StatefulWidget {
  const TemplateColorSheet({required this.catalog, required this.removable, super.key});

  final List<PatternColor> catalog;
  final bool removable;

  @override
  State<TemplateColorSheet> createState() => _TemplateColorSheetState();
}

class _TemplateColorSheetState extends State<TemplateColorSheet> {
  String _query = '';

  bool _matches(PatternColor color) {
    final String q = _query.trim().toLowerCase();
    return q.isEmpty ||
        color.name.toLowerCase().contains(q) ||
        color.components.any((c) => c.code.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final List<PatternColor> shown = widget.catalog.where(_matches).toList(growable: false);
    return GlassSheet(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.templatePickColorTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: tokens.spacing.m),
            CupertinoSearchTextField(
              key: const ValueKey<String>('template-color-search'),
              placeholder: l10n.catalogSearchPlaceholder,
              onChanged: (value) => setState(() => _query = value),
            ),
            SizedBox(height: tokens.spacing.s),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(l10n.templateColorEmpty))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final PatternColor color = shown[index];
                        return GestureDetector(
                          key: ValueKey<String>('template-pick-${color.components.first.code}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop<TemplateColorChoice>(TemplateColorPicked(color)),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: tokens.minTapTarget),
                            child: Row(
                              children: <Widget>[
                                ColorSwatchView(rgb: color.rgb),
                                SizedBox(width: tokens.spacing.m),
                                Expanded(child: Text(color.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                SizedBox(width: tokens.spacing.s),
                                Text(
                                  color.components.first.code,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (widget.removable)
              CupertinoButton(
                key: const ValueKey<String>('template-remove-color'),
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: () => Navigator.of(context).pop<TemplateColorChoice>(const TemplateColorRemoved()),
                child: Text(
                  l10n.templateRemoveColor,
                  style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
