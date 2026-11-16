import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/steps/step_edit_page.dart';
import 'package:beading/presentation/steps/step_widgets.dart';
import 'package:beading/presentation/steps/steps_editor_cubit.dart';
import 'package:beading/presentation/steps/steps_editor_state.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Редактор инструкции: секции и шаги, перетаскивание шагов, автосохранение без кнопки «Сохранить».
/// [StepsEditorCubit] берётся из контекста.
class StepsEditorScreen extends StatelessWidget {
  const StepsEditorScreen({required this.files, required this.photos, required this.loadCatalog, super.key});

  final FileStore files;
  final BookImageSource photos;

  /// Цвета каталога бисера для выбора в шаге.
  final Future<List<PatternColor>> Function() loadCatalog;

  static const String routePath = '/steps-edit/:projectId';

  static String locationFor(String projectId) => '/steps-edit/$projectId';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<StepsEditorCubit, StepsEditorState>(
      builder: (context, state) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(state.projectName, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (state.isReady) _SaveLine(status: state.save),
            ],
          ),
        ),
        child: switch (state.status) {
          StepsEditorStatus.loading => const Center(child: CupertinoActivityIndicator()),
          StepsEditorStatus.failed => Center(child: Text(l10n.stepsLoadFailed, textAlign: TextAlign.center)),
          StepsEditorStatus.ready => _Body(state: state, files: files, photos: photos, loadCatalog: loadCatalog),
        },
      ),
    );
  }
}

/// «Сохранено» с галочкой; при ошибке — текстом и значком, не только цветом.
class _SaveLine extends StatelessWidget {
  const _SaveLine({required this.status});

  final StepsSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (IconData icon, String text, Color color) = switch (status) {
      StepsSaveStatus.saved => (
        CupertinoIcons.checkmark_alt,
        l10n.stepsSaved,
        CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      StepsSaveStatus.pending => (
        CupertinoIcons.ellipsis,
        l10n.stepsSaving,
        CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      StepsSaveStatus.failed => (AppIcons.warning, l10n.stepsSaveError, CupertinoColors.systemRed.resolveFrom(context)),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          key: const ValueKey<String>('steps-save-line'),
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.files, required this.photos, required this.loadCatalog});

  final StepsEditorState state;
  final FileStore files;
  final BookImageSource photos;
  final Future<List<PatternColor>> Function() loadCatalog;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    final List<StepSection> sections = state.pattern!.sections;
    return SafeArea(
      child: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(tokens.spacing.l, tokens.spacing.m, tokens.spacing.l, 96),
            children: <Widget>[
              for (final (int i, StepSection section) in sections.indexed)
                _SectionCard(
                  key: ValueKey<String>('section-${section.id}'),
                  section: section,
                  index: i,
                  count: sections.length,
                  firstStepNumber: sections.take(i).fold<int>(0, (n, s) => n + s.steps.length) + 1,
                  files: files,
                  photos: photos,
                  loadCatalog: loadCatalog,
                ),
              CupertinoButton(
                key: const ValueKey<String>('steps-add-section'),
                onPressed: cubit.addSection,
                child: Text(l10n.stepsAddSection),
              ),
            ],
          ),
          if (state.deleted != null)
            Positioned(
              left: tokens.spacing.l,
              right: tokens.spacing.l,
              bottom: tokens.spacing.m,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.surface2.resolveFrom(context),
                  borderRadius: BorderRadius.circular(tokens.radius.m),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(l10n.stepsStepDeleted, key: const ValueKey<String>('steps-deleted'))),
                      CupertinoButton(
                        key: const ValueKey<String>('steps-undo'),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.square(tokens.minTapTarget),
                        onPressed: cubit.undoDelete,
                        child: Text(l10n.stepsUndo),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.section,
    required this.index,
    required this.count,
    required this.firstStepNumber,
    required this.files,
    required this.photos,
    required this.loadCatalog,
    super.key,
  });

  final StepSection section;
  final int index;
  final int count;
  final int firstStepNumber;
  final FileStore files;
  final BookImageSource photos;
  final Future<List<PatternColor>> Function() loadCatalog;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late final TextEditingController _title = TextEditingController(text: widget.section.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _menu(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    final String id = widget.section.id;
    final String? action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (popup) => CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(onPressed: () => Navigator.of(popup).pop('repeat'), child: Text(l10n.stepsRepeat)),
          if (widget.index > 0)
            CupertinoActionSheetAction(onPressed: () => Navigator.of(popup).pop('up'), child: Text(l10n.stepsMoveUp)),
          if (widget.index < widget.count - 1)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(popup).pop('down'),
              child: Text(l10n.stepsMoveDown),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popup).pop('copy'),
            child: Text(l10n.stepsDuplicate),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(popup).pop('delete'),
            child: Text(l10n.stepsDelete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(popup).pop(), child: Text(l10n.cancel)),
      ),
    );
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case 'repeat':
        await showCupertinoModalPopup<void>(
          context: context,
          builder: (popup) => BlocProvider<StepsEditorCubit>.value(
            value: cubit,
            child: _RepeatPopup(sectionId: id),
          ),
        );
      case 'up':
        cubit.moveSection(id, -1);
      case 'down':
        cubit.moveSection(id, 1);
      case 'copy':
        cubit.duplicateSection(id);
      case 'delete':
        cubit.deleteSection(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    final StepSection section = widget.section;
    final String repeat = section.repeat.isUntilDone
        ? l10n.stepsRepeatUntilDone
        : section.repeat.passes > 1
        ? l10n.stepsRepeatTimes(section.repeat.passes)
        : '';
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.l),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface.resolveFrom(context),
          borderRadius: BorderRadius.circular(tokens.radius.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: tokens.spacing.m),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoTextField(
                      key: ValueKey<String>('section-title-${section.id}'),
                      controller: _title,
                      placeholder: l10n.stepsSectionDefaultTitle(widget.index + 1),
                      decoration: null,
                      style: tokens.typography.headline,
                      onChanged: (v) => cubit.renameSection(section.id, v),
                    ),
                  ),
                  if (repeat.isNotEmpty)
                    Text(
                      repeat,
                      key: ValueKey<String>('section-repeat-${section.id}'),
                      style: tokens.typography.caption,
                    ),
                  CupertinoButton(
                    key: ValueKey<String>('section-menu-${section.id}'),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.square(tokens.minTapTarget),
                    onPressed: () => _menu(context),
                    child: Semantics(label: l10n.stepsSectionMenu, child: const Icon(CupertinoIcons.ellipsis_circle)),
                  ),
                ],
              ),
            ),
            if (section.steps.isEmpty)
              Padding(
                padding: EdgeInsets.all(tokens.spacing.m),
                child: Text(l10n.stepsEmptySection, style: tokens.typography.caption),
              ),
            ReorderableList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.steps.length,
              onReorder: (from, to) => cubit.reorderSteps(section.id, from, to),
              itemBuilder: (context, i) {
                final InstructionStep step = section.steps[i];
                return _StepRow(
                  key: ValueKey<String>('step-${step.id}'),
                  step: step,
                  index: i,
                  number: widget.firstStepNumber + i,
                  files: widget.files,
                  photos: widget.photos,
                  loadCatalog: widget.loadCatalog,
                );
              },
            ),
            CupertinoButton(
              key: ValueKey<String>('add-step-${section.id}'),
              onPressed: () => cubit.addStep(section.id),
              child: Text(l10n.stepsAddStep),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatPopup extends StatelessWidget {
  const _RepeatPopup({required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return BlocBuilder<StepsEditorCubit, StepsEditorState>(
      builder: (context, state) {
        final StepSection? section = state.pattern?.sections.where((s) => s.id == sectionId).firstOrNull;
        return CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (section != null)
                    RepeatEditor(
                      repeat: section.repeat,
                      onChanged: (r) => context.read<StepsEditorCubit>().setSectionRepeat(sectionId, r),
                    ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).stepsDone),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.number,
    required this.files,
    required this.photos,
    required this.loadCatalog,
    super.key,
  });

  final InstructionStep step;
  final int index;
  final int number;
  final FileStore files;
  final BookImageSource photos;
  final Future<List<PatternColor>> Function() loadCatalog;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    final List<String> info = <String>[
      if (step.imageIds.isNotEmpty) l10n.stepsPhotoCount(step.imageIds.length),
      if (step.beads.isNotEmpty) l10n.stepsBeadsCount(step.beads.length),
      if (step.repeat.isUntilDone)
        l10n.stepsRepeatUntilDone
      else if (step.repeat.passes > 1)
        l10n.stepsRepeatTimes(step.repeat.passes),
    ];
    return Dismissible(
      key: ValueKey<String>('dismiss-${step.id}'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: CupertinoColors.systemRed.resolveFrom(context),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Icon(CupertinoIcons.delete, color: CupertinoColors.white),
          ),
        ),
      ),
      onDismissed: (_) => cubit.deleteStep(step.id),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => BlocProvider<StepsEditorCubit>.value(
              value: cubit,
              child: StepEditPage(stepId: step.id, files: files, photos: photos, loadCatalog: loadCatalog),
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.minTapTarget + 12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m, vertical: tokens.spacing.s),
            child: Row(
              children: <Widget>[
                SizedBox(width: 28, child: Text('$number', style: tokens.typography.callout)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        step.text.isEmpty ? l10n.stepsNoText : step.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.body,
                      ),
                      if (info.isNotEmpty) Text(info.join(' · '), style: tokens.typography.caption),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: SizedBox.square(
                    dimension: tokens.minTapTarget,
                    child: Semantics(
                      label: l10n.stepsDragHandle,
                      child: const Icon(CupertinoIcons.line_horizontal_3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
