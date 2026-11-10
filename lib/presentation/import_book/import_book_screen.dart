import 'dart:io' show Platform;

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/import_book/crop_editor.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Схема из книги». Закрывается с id созданного проекта.
class ImportBookScreen extends StatelessWidget {
  const ImportBookScreen({this.cameraAvailable, super.key});

  /// Адрес экрана в роутере.
  static const String routePath = '/import/book';

  /// Камера есть только на iPhone: на Mac `image_picker` её не поддерживает. `null` — решить по платформе.
  final bool? cameraAvailable;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocConsumer<ImportBookCubit, ImportBookState>(
      listenWhen: (previous, current) => current.step == ImportStep.done && previous.step != ImportStep.done,
      listener: (context, state) => Navigator.of(context).maybePop(state.projectId),
      builder: (context, state) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.importBookTitle),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: state.step == ImportStep.importing ? null : () => Navigator.of(context).maybePop(),
            child: Text(l10n.importBookCancel),
          ),
        ),
        child: SafeArea(
          child: switch (state.step) {
            ImportStep.pickSource || ImportStep.done => _PickSource(
              state: state,
              cameraAvailable: cameraAvailable ?? Platform.isIOS,
            ),
            ImportStep.choosePdfPages => _ChoosePdfPages(state: state),
            ImportStep.review => _Review(state: state),
            ImportStep.importing => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CupertinoActivityIndicator(),
                  SizedBox(height: context.tokens.spacing.m),
                  Text(l10n.importSaving),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}

String _problemText(AppLocalizations l10n, ImportProblem problem) => switch (problem) {
  ImportProblem.sourceUnavailable => l10n.importProblemSourceUnavailable,
  ImportProblem.unreadable => l10n.importProblemUnreadable,
  ImportProblem.pdfFailed => l10n.importProblemPdfFailed,
  ImportProblem.saveFailed => l10n.importProblemSaveFailed,
  ImportProblem.noPages => l10n.importProblemNoPages,
  ImportProblem.emptyName => l10n.importProblemEmptyName,
};

class _Problem extends StatelessWidget {
  const _Problem(this.problem);

  final ImportProblem? problem;

  @override
  Widget build(BuildContext context) {
    final ImportProblem? value = problem;
    if (value == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: context.tokens.spacing.m),
      child: Text(
        _problemText(AppLocalizations.of(context), value),
        textAlign: TextAlign.center,
        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
      ),
    );
  }
}

class _PickSource extends StatelessWidget {
  const _PickSource({required this.state, required this.cameraAvailable});

  final ImportBookState state;
  final bool cameraAvailable;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportBookCubit cubit = context.read<ImportBookCubit>();
    final double gap = context.tokens.spacing.m;
    return ListView(
      padding: EdgeInsets.all(context.tokens.spacing.l),
      children: <Widget>[
        Text(l10n.importPickHint, textAlign: TextAlign.center),
        SizedBox(height: gap),
        _Problem(state.problem),
        if (cameraAvailable) CupertinoButton.filled(onPressed: cubit.takePhoto, child: Text(l10n.importSourceCamera)),
        SizedBox(height: gap),
        CupertinoButton.tinted(onPressed: cubit.pickPhotos, child: Text(l10n.importSourcePhotos)),
        SizedBox(height: gap),
        CupertinoButton.tinted(onPressed: cubit.pickFiles, child: Text(l10n.importSourceFiles)),
        if (state.pages.isNotEmpty) ...<Widget>[
          SizedBox(height: gap),
          CupertinoButton(onPressed: cubit.backToReview, child: Text(l10n.importReviewTitle)),
        ],
      ],
    );
  }
}

class _ChoosePdfPages extends StatelessWidget {
  const _ChoosePdfPages({required this.state});

  final ImportBookState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportBookCubit cubit = context.read<ImportBookCubit>();
    final double gap = context.tokens.spacing.m;
    final Color accent = CupertinoColors.activeBlue.resolveFrom(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(gap),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.importPdfSelected(state.selectedPdfPages.length, state.pdfPageCount),
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: cubit.selectAllPdfPages,
                child: Text(l10n.importPdfSelectAll),
              ),
              SizedBox(width: gap),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: cubit.clearPdfPages,
                child: Text(l10n.importPdfClear),
              ),
            ],
          ),
        ),
        _Problem(state.problem),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(gap),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 88,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: state.pdfPageCount,
            itemBuilder: (context, index) {
              final bool selected = state.selectedPdfPages.contains(index);
              return Semantics(
                button: true,
                selected: selected,
                label: l10n.importPdfPageLabel(index + 1),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => cubit.togglePdfPage(index),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? accent : CupertinoColors.secondarySystemFill.resolveFrom(context),
                      borderRadius: BorderRadius.circular(context.tokens.radius.m),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(gap),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: state.selectedPdfPages.isEmpty ? null : cubit.confirmPdfPages,
              child: Text(l10n.importPdfContinue),
            ),
          ),
        ),
      ],
    );
  }
}

class _Review extends StatefulWidget {
  const _Review({required this.state});

  final ImportBookState state;

  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  late final TextEditingController _name = TextEditingController(text: widget.state.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportBookCubit cubit = context.read<ImportBookCubit>();
    final ImportBookState state = widget.state;
    final double gap = context.tokens.spacing.m;
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(gap),
          child: Column(
            children: <Widget>[
              CupertinoTextField(
                controller: _name,
                placeholder: l10n.importNameLabel,
                onChanged: cubit.setName,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: gap),
              CupertinoSlidingSegmentedControl<Craft>(
                groupValue: state.craft,
                children: <Craft, Widget>{
                  Craft.beading: Padding(padding: const EdgeInsets.all(6), child: Text(l10n.importCraftBeading)),
                  Craft.crossStitch: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(l10n.importCraftCrossStitch),
                  ),
                },
                onValueChanged: (craft) => cubit.setCraft(craft ?? state.craft),
              ),
              SizedBox(height: gap),
              _Problem(state.problem),
            ],
          ),
        ),
        Expanded(
          child: ReorderableList(
            itemCount: state.pages.length,
            onReorder: (oldIndex, newIndex) => cubit.move(oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex),
            itemBuilder: (context, index) {
              final PageDraft page = state.pages[index];
              return _PageRow(key: ValueKey<int>(page.id), index: index, page: page);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(gap),
          child: Column(
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(onPressed: cubit.submit, child: Text(l10n.importSubmit)),
              ),
              CupertinoButton(onPressed: cubit.addMore, child: Text(l10n.importAddMore)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({required this.index, required this.page, super.key});

  final int index;
  final PageDraft page;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportBookCubit cubit = context.read<ImportBookCubit>();
    final double gap = context.tokens.spacing.m;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gap, vertical: gap / 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.tokens.radius.s),
              child: RotatedBox(
                quarterTurns: page.quarterTurns,
                child: Image.memory(page.bytes, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 144),
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.importPageNumber(index + 1)),
                if (!page.crop.isFull)
                  Text(
                    l10n.importCropped,
                    style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  ),
              ],
            ),
          ),
          _IconAction(
            icon: CupertinoIcons.rotate_right,
            label: l10n.importRotate,
            onPressed: () => cubit.rotate(page.id),
          ),
          _IconAction(
            icon: CupertinoIcons.crop,
            label: l10n.importCrop,
            onPressed: () async {
              final CropRect? crop = await showCropEditor(
                context,
                bytes: page.bytes,
                quarterTurns: page.quarterTurns,
                initial: page.crop,
              );
              if (crop != null) {
                cubit.setCrop(page.id, crop);
              }
            },
          ),
          _IconAction(
            icon: CupertinoIcons.delete,
            label: l10n.importRemove,
            onPressed: () => cubit.remove(page.id),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(padding: EdgeInsets.all(8), child: Icon(CupertinoIcons.line_horizontal_3)),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.square(context.tokens.minTapTarget),
    onPressed: onPressed,
    child: Semantics(label: label, child: Icon(icon)),
  );
}
