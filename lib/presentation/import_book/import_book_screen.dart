import 'dart:io' show Platform;

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/import_book/crop_editor.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
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
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  if (state.stepNumber case final int number)
                    Padding(
                      padding: EdgeInsets.only(top: context.tokens.spacing.s),
                      child: Text(
                        l10n.importStep(number, state.stepCount),
                        key: const ValueKey<String>('import-step'),
                        style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                      ),
                    ),
                  Expanded(
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
                ],
              ),
              if (state.busy case final ImportBusy busy) _BusyOverlay(busy: busy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ожидание открытия файла или отрисовки страниц: системный индикатор и текст; экран под ним не нажимается.
class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.busy});

  final ImportBusy busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double gap = context.tokens.spacing.m;
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          key: const ValueKey<String>('import-busy'),
          color: CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CupertinoActivityIndicator(radius: 14),
                SizedBox(height: gap),
                Semantics(
                  liveRegion: true,
                  child: Text(busy == ImportBusy.opening ? l10n.importOpening : l10n.importRendering),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _problemText(AppLocalizations l10n, ImportProblem problem) => switch (problem) {
  ImportProblem.sourceUnavailable => l10n.importProblemSourceUnavailable,
  ImportProblem.unreadable => l10n.importProblemUnreadable,
  ImportProblem.pdfFailed => l10n.importProblemPdfFailed,
  ImportProblem.pdfEmpty => l10n.importProblemPdfEmpty,
  ImportProblem.saveFailed => l10n.importProblemSaveFailed,
  ImportProblem.noPages => l10n.importProblemNoPages,
  ImportProblem.emptyName => l10n.importProblemEmptyName,
};

/// Ошибка: значок, текст и, если файл не годится, кнопка «Выбрать другой файл». Цвет не единственный признак.
class _Problem extends StatelessWidget {
  const _Problem(this.problem, {this.offerAnother = true});

  final ImportProblem? problem;

  /// Показывать кнопку выбора другого файла; на экране выбора источника она не нужна: способы выбора рядом.
  final bool offerAnother;

  static bool _fileProblem(ImportProblem problem) =>
      problem == ImportProblem.pdfFailed || problem == ImportProblem.pdfEmpty || problem == ImportProblem.unreadable;

  @override
  Widget build(BuildContext context) {
    final ImportProblem? value = problem;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color color = CupertinoColors.systemRed.resolveFrom(context);
    final AppTokensData tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.m),
      child: Semantics(
        liveRegion: true,
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(CupertinoIcons.exclamationmark_triangle, color: color, size: 20),
                SizedBox(width: tokens.spacing.s),
                Flexible(
                  child: Text(_problemText(l10n, value), style: TextStyle(color: color)),
                ),
              ],
            ),
            if (offerAnother && _fileProblem(value))
              CupertinoButton(
                key: const ValueKey<String>('pick-another'),
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: context.read<ImportBookCubit>().addMore,
                child: Text(l10n.importPickAnother),
              ),
          ],
        ),
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
        _Problem(state.problem, offerAnother: false),
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

/// Нижняя стеклянная панель с главной кнопкой над содержимым. Список под ней получает нижний отступ
/// [_bottomBarClearance], чтобы последний ряд миниатюр не прятался под панелью.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double gap = context.tokens.spacing.m;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: GlassPanel(density: GlassDensity.dense, padding: EdgeInsets.all(gap / 2), child: child),
      ),
    );
  }
}

/// Высота нижней панели с запасом под крупный шрифт: нижний отступ прокрутки.
const double _bottomBarClearance = 150;

class _ChoosePdfPages extends StatelessWidget {
  const _ChoosePdfPages({required this.state});

  final ImportBookState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportBookCubit cubit = context.read<ImportBookCubit>();
    final double gap = context.tokens.spacing.m;
    return Stack(
      children: <Widget>[
        Column(
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
                    minimumSize: Size.square(context.tokens.minTapTarget),
                    onPressed: cubit.selectAllPdfPages,
                    child: Text(l10n.importPdfSelectAll),
                  ),
                  SizedBox(width: gap),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.square(context.tokens.minTapTarget),
                    onPressed: cubit.clearPdfPages,
                    child: Text(l10n.importPdfClear),
                  ),
                ],
              ),
            ),
            _Problem(state.problem),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(gap, gap, gap, _bottomBarClearance),
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
                    excludeSemantics: true,
                    onTap: () => cubit.togglePdfPage(index),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => cubit.togglePdfPage(index),
                      child: _SelectableTile(
                        selected: selected,
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        _BottomBar(
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

/// Непрозрачная плитка выбора: выбранная отмечена кольцом акцента и галочкой, а не только цветом.
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color accent = tokens.accent.resolveFrom(context);
    return DecoratedBox(
      key: ValueKey<bool>(selected),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(tokens.radius.m),
        border: Border.all(
          color: selected ? accent : CupertinoColors.separator.resolveFrom(context),
          width: selected ? 2.5 : 1,
        ),
      ),
      child: Stack(
        children: <Widget>[
          child,
          if (selected)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(AppIcons.selected, size: 20, color: accent),
            ),
        ],
      ),
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
    return Stack(
      children: <Widget>[
        Column(
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
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _CraftTile(
                          label: l10n.importCraftBeading,
                          selected: state.craft == Craft.beading,
                          onTap: () => cubit.setCraft(Craft.beading),
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _CraftTile(
                          label: l10n.importCraftCrossStitch,
                          selected: state.craft == Craft.crossStitch,
                          onTap: () => cubit.setCraft(Craft.crossStitch),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gap),
                  _Problem(state.problem),
                ],
              ),
            ),
            Expanded(
              child: ReorderableList(
                padding: const EdgeInsets.only(bottom: _bottomBarClearance),
                itemCount: state.pages.length,
                onReorder: (oldIndex, newIndex) => cubit.move(oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex),
                itemBuilder: (context, index) {
                  final PageDraft page = state.pages[index];
                  return _PageRow(key: ValueKey<int>(page.id), index: index, page: page);
                },
              ),
            ),
          ],
        ),
        _BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(onPressed: cubit.submit, child: Text(l10n.importSubmit)),
              ),
              CupertinoButton(
                minimumSize: Size.square(context.tokens.minTapTarget),
                onPressed: cubit.addMore,
                child: Text(l10n.importAddMore),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Плитка выбора техники: выбранная отмечена кольцом и галочкой (как миниатюры и остальные выборы в приложении).
class _CraftTile extends StatelessWidget {
  const _CraftTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.tokens.minTapTarget + 8),
          child: _SelectableTile(
            selected: selected,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
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
