import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Показывает системный iOS-лист «Новый проект»: сначала ремесло, затем способы создания из [registry].
/// Лист тянется пальцем и закрывается свайпом вниз. Выбранный пункт запускается после закрытия листа
/// с [context] экрана-владельца.
Future<void> showNewProjectSheet(BuildContext context, NewProjectRegistry registry, {Craft? initialCraft}) async {
  final NewProjectEntry? chosen = await showCupertinoSheet<NewProjectEntry>(
    context: context,
    pageBuilder: (_) => NewProjectSheet(registry: registry, initialCraft: initialCraft),
  );
  if (chosen != null && context.mounted) {
    await chosen.onSelected(context);
  }
}

class NewProjectSheet extends StatefulWidget {
  const NewProjectSheet({required this.registry, this.initialCraft, super.key});

  final NewProjectRegistry registry;
  final Craft? initialCraft;

  @override
  State<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<NewProjectSheet> {
  late Craft? _craft = _initial();

  Craft? _initial() {
    final List<Craft> crafts = widget.registry.crafts;
    if (crafts.isEmpty) {
      return null;
    }
    return crafts.contains(widget.initialCraft) ? widget.initialCraft : crafts.first;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final List<Craft> crafts = widget.registry.crafts;
    final Craft? craft = _craft;
    final List<NewProjectEntry> entries = craft == null ? const <NewProjectEntry>[] : widget.registry.entriesFor(craft);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: Text(l10n.libraryNewProject),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            if (crafts.length > 1 && craft != null)
              Padding(
                padding: EdgeInsets.fromLTRB(tokens.spacing.l, tokens.spacing.m, tokens.spacing.l, tokens.spacing.s),
                child: CupertinoSlidingSegmentedControl<Craft>(
                  groupValue: craft,
                  children: <Craft, Widget>{
                    for (final Craft c in crafts)
                      c: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: tokens.minTapTarget - 4),
                        child: Center(child: Text(c.label(l10n))),
                      ),
                  },
                  onValueChanged: (value) => setState(() => _craft = value),
                ),
              ),
            if (entries.isEmpty)
              Padding(
                padding: EdgeInsets.all(tokens.spacing.xl),
                child: Text(
                  l10n.newProjectNoEntries,
                  textAlign: TextAlign.center,
                  style: base.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              )
            else
              CupertinoListSection.insetGrouped(
                children: <Widget>[
                  for (final NewProjectEntry entry in entries)
                    CupertinoListTile(
                      leading: Icon(entry.icon),
                      title: Text(entry.title(l10n)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).pop(entry),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
