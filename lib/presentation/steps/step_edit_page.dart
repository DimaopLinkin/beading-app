import 'dart:typed_data';

import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/pattern_template/template_color_sheet.dart';
import 'package:beading/presentation/steps/step_widgets.dart';
import 'package:beading/presentation/steps/steps_editor_cubit.dart';
import 'package:beading/presentation/steps/steps_editor_state.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Правка одного шага: текст, фото, бусины, повтор. Автосохранение общее с редактором ([StepsEditorCubit]).
class StepEditPage extends StatefulWidget {
  const StepEditPage({
    required this.stepId,
    required this.files,
    required this.photos,
    required this.loadCatalog,
    super.key,
  });

  final String stepId;
  final FileStore files;
  final BookImageSource photos;
  final Future<List<PatternColor>> Function() loadCatalog;

  @override
  State<StepEditPage> createState() => _StepEditPageState();
}

class _StepEditPageState extends State<StepEditPage> {
  late final TextEditingController _text = TextEditingController(
    text: context.read<StepsEditorCubit>().state.stepById(widget.stepId)?.text ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    final bool? camera = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popup) => CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popup).pop(true),
            child: Text(l10n.stepsNewTakePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popup).pop(false),
            child: Text(l10n.stepsNewPickPhotos),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(popup).pop(), child: Text(l10n.cancel)),
      ),
    );
    if (camera == null) {
      return;
    }
    final result = camera ? await widget.photos.takePhoto() : await widget.photos.pickPhotos();
    final List<PickedBookFile> picked = result.valueOrNull ?? const <PickedBookFile>[];
    if (result.isFailure) {
      cubit.photoPickFailed();
      return;
    }
    await cubit.addPhotos(widget.stepId, <Uint8List>[for (final PickedBookFile f in picked) f.bytes]);
  }

  Future<void> _addBeads(BuildContext context) async {
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    final List<PatternColor> catalog = await widget.loadCatalog();
    if (!context.mounted) {
      return;
    }
    final TemplateColorChoice? choice = await showTemplateColorSheet(context, catalog: catalog, removable: false);
    if (choice is TemplateColorPicked) {
      cubit.addBead(widget.stepId, choice.color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsEditorCubit cubit = context.read<StepsEditorCubit>();
    return BlocBuilder<StepsEditorCubit, StepsEditorState>(
      builder: (context, state) {
        final InstructionStep? step = state.stepById(widget.stepId);
        final StepPattern? pattern = state.pattern;
        if (step == null || pattern == null) {
          return const CupertinoPageScaffold(child: SizedBox.shrink());
        }
        final List<StepImage> images = <StepImage>[
          for (final String id in step.imageIds)
            for (final StepImage i in pattern.images)
              if (i.id == id) i,
        ];
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(l10n.stepsStepTitle),
            trailing: CupertinoButton(
              key: const ValueKey<String>('step-delete'),
              padding: EdgeInsets.zero,
              minimumSize: Size.square(tokens.minTapTarget),
              onPressed: () {
                cubit.deleteStep(widget.stepId);
                Navigator.of(context).pop();
              },
              child: Semantics(
                label: l10n.stepsDelete,
                child: Icon(CupertinoIcons.delete, color: CupertinoColors.systemRed.resolveFrom(context)),
              ),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.all(tokens.spacing.l),
              children: <Widget>[
                CupertinoTextField(
                  key: const ValueKey<String>('step-text'),
                  controller: _text,
                  placeholder: l10n.stepsTextPlaceholder,
                  minLines: 3,
                  maxLines: null,
                  style: tokens.typography.body,
                  onChanged: (v) => cubit.setStepText(widget.stepId, v),
                ),
                _Header(l10n.stepsPhotos),
                SizedBox(
                  height: 96,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ReorderableList(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          onReorder: (from, to) => cubit.reorderImages(widget.stepId, from, to),
                          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
                            key: ValueKey<String>('photo-${images[i].id}'),
                            index: i,
                            child: _PhotoTile(
                              number: i + 1,
                              total: images.length,
                              files: widget.files,
                              image: images[i],
                              onRemove: () => cubit.removeImage(widget.stepId, images[i].id),
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        key: const ValueKey<String>('step-add-photo'),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(96, 96),
                        onPressed: () => _addPhoto(context),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[const Icon(AppIcons.photo), Text(l10n.stepsAddPhoto)],
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.photoFailed)
                  Text(
                    l10n.stepsPhotoFailed,
                    key: const ValueKey<String>('step-photo-failed'),
                    style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                  ),
                _Header(l10n.stepsBeads),
                for (final StepBead b in step.beads)
                  if (b.colorIndex < pattern.palette.length)
                    _BeadRow(
                      key: ValueKey<String>('bead-${b.colorIndex}'),
                      bead: b,
                      color: pattern.palette[b.colorIndex],
                      onCount: (n) => cubit.setBeadCount(widget.stepId, b.colorIndex, n),
                    ),
                CupertinoButton(
                  key: const ValueKey<String>('step-add-beads'),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  onPressed: () => _addBeads(context),
                  child: Text(l10n.stepsAddBeads),
                ),
                _Header(l10n.stepsRepeat),
                RepeatEditor(repeat: step.repeat, onChanged: (r) => cubit.setStepRepeat(widget.stepId, r)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: context.tokens.spacing.l, bottom: context.tokens.spacing.s),
    child: Text(text, style: context.tokens.typography.headline),
  );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.number,
    required this.total,
    required this.files,
    required this.image,
    required this.onRemove,
  });

  final int number;
  final int total;
  final FileStore files;
  final StepImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.stepsPhotoOf(number, total),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox.square(
          dimension: 96,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: StepImageView(files: files, image: image, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text('$number', style: const TextStyle(color: CupertinoColors.white, fontSize: 13)),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: CupertinoButton(
                  key: ValueKey<String>('photo-remove-${image.id}'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(44),
                  onPressed: onRemove,
                  child: Semantics(
                    label: l10n.stepsRemovePhoto,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xAA000000), shape: BoxShape.circle),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(CupertinoIcons.xmark, size: 14, color: CupertinoColors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeadRow extends StatelessWidget {
  const _BeadRow({required this.bead, required this.color, required this.onCount, super.key});

  final StepBead bead;
  final PatternColor color;
  final ValueChanged<int> onCount;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Row(
      children: <Widget>[
        ColorSwatchView(rgb: color.rgb, size: 28),
        SizedBox(width: tokens.spacing.s),
        Expanded(
          child: Text(
            '${paletteLetter(bead.colorIndex)} · ${color.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.body,
          ),
        ),
        CountStepper(value: bead.count, min: 0, onChanged: onCount),
      ],
    );
  }
}
