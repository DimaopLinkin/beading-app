import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
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

/// Системный лист (`showCupertinoSheet`, закрывается свайпом вниз) с выбором цвета из каталога: поиск по артикулу
/// и названию; для полос — ещё «Убрать этот цвет».
Future<TemplateColorChoice?> showTemplateColorSheet(
  BuildContext context, {
  required List<PatternColor> catalog,
  required bool removable,
}) => showCupertinoSheet<TemplateColorChoice>(
  context: context,
  builder: (_) => TemplateColorSheet(catalog: catalog, removable: removable),
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
    final List<PatternColor> shown = widget.catalog.where(_matches).toList(growable: false);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.templatePickColorTitle),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.templateCancel),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoSearchTextField(
                key: const ValueKey<String>('template-color-search'),
                placeholder: l10n.catalogSearchPlaceholder,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (widget.removable)
                    CupertinoListSection.insetGrouped(
                      children: <Widget>[
                        CupertinoListTile.notched(
                          key: const ValueKey<String>('template-remove-color'),
                          title: Text(
                            l10n.templateRemoveColor,
                            style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                          ),
                          onTap: () => Navigator.of(context).pop<TemplateColorChoice>(const TemplateColorRemoved()),
                        ),
                      ],
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.templateColorEmpty)),
                    )
                  else
                    CupertinoListSection.insetGrouped(
                      children: <Widget>[
                        for (final PatternColor color in shown)
                          CupertinoListTile.notched(
                            key: ValueKey<String>('template-pick-${color.components.first.code}'),
                            leading: ColorSwatchView(rgb: color.rgb, size: 28),
                            title: Text(color.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            additionalInfo: Text(color.components.first.code),
                            onTap: () => Navigator.of(context).pop<TemplateColorChoice>(TemplateColorPicked(color)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
