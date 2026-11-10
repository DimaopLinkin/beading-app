import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:flutter/cupertino.dart';

/// Показывает лист «Новый проект»: сначала ремесло, затем способы создания из [registry].
/// Выбранный пункт запускается после закрытия листа с [context] экрана-владельца.
Future<void> showNewProjectSheet(BuildContext context, NewProjectRegistry registry, {Craft? initialCraft}) async {
  final NewProjectEntry? chosen = await showCupertinoModalPopup<NewProjectEntry>(
    context: context,
    builder: (_) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: NewProjectSheet(registry: registry, initialCraft: initialCraft),
      ),
    ),
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

    return GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.libraryNewProject,
            textAlign: TextAlign.center,
            style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: tokens.spacing.m),
          if (crafts.length > 1 && craft != null) ...<Widget>[
            CupertinoSlidingSegmentedControl<Craft>(
              groupValue: craft,
              children: <Craft, Widget>{
                for (final Craft c in crafts)
                  c: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
                    child: Text(c.label(l10n)),
                  ),
              },
              onValueChanged: (value) => setState(() => _craft = value),
            ),
            SizedBox(height: tokens.spacing.m),
          ],
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.xl),
              child: Text(
                l10n.newProjectNoEntries,
                textAlign: TextAlign.center,
                style: base.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            )
          else
            for (final NewProjectEntry entry in entries)
              CupertinoButton(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.m, horizontal: tokens.spacing.s),
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: () => Navigator.of(context).pop(entry),
                child: Row(
                  children: <Widget>[
                    Icon(entry.icon),
                    SizedBox(width: tokens.spacing.m),
                    Expanded(
                      child: Text(
                        entry.title(l10n),
                        style: base.copyWith(color: CupertinoColors.label.resolveFrom(context)),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
