import 'dart:async';
import 'dart:io' show Platform;

import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/face_size_advisor.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/size_purpose.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/settings/floss_brands.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/image_to_grid/full_preview_screen.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_state.dart';
import 'package:beading/presentation/image_to_grid/importance_brush_mode.dart';
import 'package:beading/presentation/import_book/crop_editor.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_list_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Мастер «Схема из картинки». Закрывается с id созданного проекта.
class ImageWizardScreen extends StatelessWidget {
  const ImageWizardScreen({this.cameraAvailable, super.key});

  /// Адрес экрана в роутере.
  static const String routePath = '/generate/image';

  /// Камера есть только на iPhone: на Mac `image_picker` её не поддерживает. `null` — решить по платформе.
  final bool? cameraAvailable;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocConsumer<ImageWizardCubit, ImageWizardState>(
      listenWhen: (previous, current) => current.step == ImageWizardStep.done && previous.step != ImageWizardStep.done,
      listener: (context, state) => Navigator.of(context).maybePop(state.projectId),
      builder: (context, state) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.imageWizardTitle),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: state.step == ImageWizardStep.saving ? null : () => Navigator.of(context).maybePop(),
            child: Text(l10n.imageWizardCancel),
          ),
        ),
        child: SafeArea(
          child: switch (state.step) {
            ImageWizardStep.pickSource || ImageWizardStep.done => Stack(
              children: <Widget>[
                _PickSource(state: state, cameraAvailable: cameraAvailable ?? Platform.isIOS),
                if (state.opening) _Busy(text: l10n.imageWizardOpening),
              ],
            ),
            ImageWizardStep.edit || ImageWizardStep.saving => Stack(
              children: <Widget>[
                if (state.brushing) ImportanceBrushMode(state: state) else _Edit(state: state),
                if (state.step == ImageWizardStep.saving) _Busy(text: l10n.imageWizardSaving),
              ],
            ),
          },
        ),
      ),
    );
  }
}

String _problemText(AppLocalizations l10n, ImageWizardProblem problem) => switch (problem) {
  ImageWizardProblem.sourceUnavailable => l10n.imageWizardProblemSourceUnavailable,
  ImageWizardProblem.unreadable => l10n.imageWizardProblemUnreadable,
  ImageWizardProblem.calculationFailed => l10n.imageWizardProblemCalculation,
  ImageWizardProblem.saveFailed => l10n.imageWizardProblemSave,
  ImageWizardProblem.invalidName => l10n.imageWizardProblemName,
};

/// Лицо на схеме слишком мелкое (T54): предупреждение и два действия.
class _FaceWarning extends StatelessWidget {
  const _FaceWarning({required this.advice, required this.onCrop, required this.onWiden});

  final FaceSizeAdvice advice;
  final VoidCallback? onCrop;
  final VoidCallback? onWiden;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey<String>('wizard-face-warning'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.imageWizardFaceSmall(advice.faceCells.floor(), const FaceSizeAdvisor().minFaceCells),
          style: TextStyle(fontSize: 13, color: CupertinoColors.systemOrange.resolveFrom(context)),
        ),
        Wrap(
          spacing: 8,
          children: <Widget>[
            if (onCrop != null)
              CupertinoButton.tinted(
                key: const ValueKey<String>('wizard-face-crop'),
                onPressed: onCrop,
                child: Text(l10n.imageWizardFaceCrop),
              ),
            if (onWiden != null)
              CupertinoButton.tinted(
                key: const ValueKey<String>('wizard-face-wider'),
                onPressed: onWiden,
                child: Text(l10n.imageWizardFaceWider),
              ),
          ],
        ),
      ],
    );
  }
}

/// Размер по назначению и подсказка по фото (T61).
class _SizeAssist extends StatelessWidget {
  const _SizeAssist({required this.state, required this.cubit});

  final ImageWizardState state;
  final ImageWizardCubit cubit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageToGridSettings settings = state.settings;
    final bool stitch = settings.craft == Craft.crossStitch;
    final TextStyle caption = TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context));
    final SizeSuggestion? hint = state.sizeHint;
    String purposeLabel(SizePurpose purpose) => stitch
        ? l10n.imageWizardCm(_cm(purpose.stitchCm))
        : switch (purpose) {
            SizePurpose.small => l10n.imageWizardPurposeBracelet,
            SizePurpose.medium => l10n.imageWizardPurposePanel,
            SizePurpose.large => l10n.imageWizardPurposePicture,
          };
    SizePurpose? current;
    for (final SizePurpose p in SizePurpose.values) {
      if (p.columnsFor(settings) == settings.columns) current = p;
    }
    return _Section(
      title: l10n.imageWizardPurpose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CupertinoSlidingSegmentedControl<SizePurpose>(
            key: const ValueKey<String>('wizard-purpose'),
            groupValue: current,
            children: <SizePurpose, Widget>{
              for (final SizePurpose p in SizePurpose.values) p: _SegmentLabel(purposeLabel(p)),
            },
            onValueChanged: (value) {
              if (value != null) cubit.setPurpose(value);
            },
          ),
          if (!stitch)
            Padding(
              padding: EdgeInsets.only(top: context.tokens.spacing.s),
              child: Text(
                l10n.imageWizardPurposeBeads(
                  settings.columns,
                  _cm(SizeSuggester.centimetres(settings.columns, settings.metrics)),
                ),
                style: caption,
              ),
            ),
          if (hint != null) ...<Widget>[
            SizedBox(height: context.tokens.spacing.s),
            Text(
              key: const ValueKey<String>('wizard-size-hint'),
              stitch
                  ? l10n.imageWizardSizeHintStitch(
                      _fabricLabel(l10n, settings.fabric),
                      _cm(SizeSuggester.centimetres(hint.columns, settings.fabric)),
                      hint.columns,
                      hint.colors,
                    )
                  : l10n.imageWizardSizeHintBeads(
                      hint.columns,
                      hint.colors,
                      _cm(SizeSuggester.centimetres(hint.columns, settings.metrics)),
                    ),
              style: caption,
            ),
            if (!hint.reached) Text(l10n.imageWizardSizeHintLimit, style: caption),
            if (state.sizeHintApplied)
              Text(
                l10n.imageWizardSizeHintApplied,
                key: const ValueKey<String>('wizard-size-hint-applied'),
                style: caption,
              )
            else
              CupertinoButton.tinted(
                key: const ValueKey<String>('wizard-size-hint-apply'),
                onPressed: cubit.applySizeHint,
                child: Text(l10n.imageWizardSizeHintApply),
              ),
          ],
          if (state.beadsTooSmallForFace) ...<Widget>[
            SizedBox(height: context.tokens.spacing.s),
            Text(
              l10n.imageWizardBeadsFewForFace(settings.columns),
              key: const ValueKey<String>('wizard-beads-few'),
              style: TextStyle(fontSize: 13, color: CupertinoColors.systemOrange.resolveFrom(context)),
            ),
            CupertinoButton.tinted(
              key: const ValueKey<String>('wizard-beads-to-stitch'),
              onPressed: () => cubit.setCraft(Craft.crossStitch),
              child: Text(l10n.imageWizardToStitch),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ошибка: значок и текст, цвет не единственный признак.
class _Problem extends StatelessWidget {
  const _Problem(this.problem);

  final ImageWizardProblem? problem;

  @override
  Widget build(BuildContext context) {
    final ImageWizardProblem? value = problem;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final Color color = CupertinoColors.systemRed.resolveFrom(context);
    final AppTokensData tokens = context.tokens;
    return Padding(
      key: const ValueKey<String>('wizard-problem'),
      padding: EdgeInsets.only(bottom: tokens.spacing.m),
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(AppIcons.warning, color: color, size: 20),
            SizedBox(width: tokens.spacing.s),
            Flexible(
              child: Text(_problemText(AppLocalizations.of(context), value), style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ожидание: индикатор и текст; экран под ним не нажимается.
class _Busy extends StatelessWidget {
  const _Busy({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: AbsorbPointer(
      child: ColoredBox(
        key: const ValueKey<String>('wizard-busy'),
        color: CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CupertinoActivityIndicator(radius: 14),
              SizedBox(height: context.tokens.spacing.m),
              Semantics(liveRegion: true, child: Text(text)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PickSource extends StatelessWidget {
  const _PickSource({required this.state, required this.cameraAvailable});

  final ImageWizardState state;
  final bool cameraAvailable;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageWizardCubit cubit = context.read<ImageWizardCubit>();
    final double gap = context.tokens.spacing.m;
    return ListView(
      padding: EdgeInsets.all(context.tokens.spacing.l),
      children: <Widget>[
        Text(l10n.imageWizardPickHint, textAlign: TextAlign.center),
        SizedBox(height: gap),
        _Problem(state.problem),
        if (cameraAvailable)
          CupertinoButton.filled(
            minimumSize: Size.square(context.tokens.minTapTarget),
            onPressed: cubit.takePhoto,
            child: Text(l10n.imageWizardSourceCamera),
          ),
        SizedBox(height: gap),
        CupertinoButton.tinted(
          minimumSize: Size.square(context.tokens.minTapTarget),
          onPressed: cubit.pickPhotos,
          child: Text(l10n.imageWizardSourcePhotos),
        ),
        SizedBox(height: gap),
        CupertinoButton.tinted(
          minimumSize: Size.square(context.tokens.minTapTarget),
          onPressed: cubit.pickFiles,
          child: Text(l10n.imageWizardSourceFiles),
        ),
      ],
    );
  }
}

class _Edit extends StatefulWidget {
  const _Edit({required this.state});

  final ImageWizardState state;

  @override
  State<_Edit> createState() => _EditState();
}

class _EditState extends State<_Edit> {
  late final TextEditingController _name = TextEditingController(text: widget.state.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageWizardCubit cubit = context.read<ImageWizardCubit>();
    final ImageWizardState state = widget.state;
    final ImageToGridSettings settings = state.settings;
    final AppTokensData tokens = context.tokens;
    final double gap = tokens.spacing.m;
    final TextStyle caption = TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context));
    final double previewHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(180, 380);

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(tokens.spacing.l),
            children: <Widget>[
              _Preview(state: state, height: previewHeight),
              SizedBox(height: gap),
              Text(l10n.imageWizardCompareHint, textAlign: TextAlign.center, style: caption),
              SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _IconAction(
                    icon: CupertinoIcons.rotate_right,
                    label: l10n.imageWizardRotate,
                    onPressed: cubit.rotate,
                  ),
                  SizedBox(width: gap),
                  _IconAction(
                    icon: CupertinoIcons.crop,
                    label: l10n.imageWizardCrop,
                    onPressed: () async {
                      final CropRect? crop = await showCropEditor(
                        context,
                        bytes: state.source!,
                        quarterTurns: state.quarterTurns,
                        initial: state.crop,
                      );
                      if (crop != null) {
                        await cubit.setCrop(crop);
                      }
                    },
                  ),
                ],
              ),
              if (!state.brush.isEmpty) ...<Widget>[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  key: const ValueKey<String>('wizard-brush-crop-hint'),
                  l10n.imageWizardBrushCropHint,
                  textAlign: TextAlign.center,
                  style: caption,
                ),
              ],
              SizedBox(height: gap),
              _Section(
                title: l10n.imageWizardCraft,
                child: CupertinoSlidingSegmentedControl<Craft>(
                  key: const ValueKey<String>('wizard-craft'),
                  groupValue: settings.craft,
                  children: <Craft, Widget>{
                    Craft.beading: _SegmentLabel(l10n.imageWizardCraftBeading),
                    Craft.crossStitch: _SegmentLabel(l10n.imageWizardCraftStitch),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      cubit.setCraft(value);
                    }
                  },
                ),
              ),
              AppListSection(
                margin: EdgeInsets.zero,
                children: <Widget>[
                  CupertinoListTile.notched(
                    key: const ValueKey<String>('wizard-technique'),
                    title: Text(l10n.imageWizardTechnique),
                    additionalInfo: Text(settings.technique.label(l10n)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () async {
                      final Technique? chosen = await _pick<Technique>(
                        context,
                        title: l10n.imageWizardTechnique,
                        values: ImageToGridSettings.techniquesOf(settings.craft),
                        label: (t) => t.label(l10n),
                        cancel: l10n.imageWizardCancel,
                      );
                      if (chosen != null) {
                        cubit.setTechnique(chosen);
                      }
                    },
                  ),
                  if (settings.craft == Craft.crossStitch) ...<Widget>[
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('wizard-fabric'),
                      title: Text(l10n.imageWizardFabric),
                      additionalInfo: Text(_fabricLabel(l10n, settings.fabric)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        final Fabric? chosen = await _pick<Fabric>(
                          context,
                          title: l10n.imageWizardFabric,
                          values: _fabricChoices(settings.fabric),
                          label: (fabric) => _fabricLabel(l10n, fabric),
                          cancel: l10n.imageWizardCancel,
                        );
                        if (chosen != null) {
                          cubit.setFabric(chosen);
                        }
                      },
                    ),
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('wizard-floss-brand'),
                      title: Text(l10n.imageWizardFlossBrand),
                      additionalInfo: Text(state.flossBrand),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        final String? chosen = await _pick<String>(
                          context,
                          title: l10n.imageWizardFlossBrand,
                          values: flossBrandChoices,
                          label: (brand) => brand,
                          cancel: l10n.imageWizardCancel,
                        );
                        if (chosen != null) {
                          unawaited(cubit.setFlossBrand(chosen));
                        }
                      },
                    ),
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('wizard-fabric-color'),
                      title: Text(l10n.imageWizardFabricColor),
                      leading: _Swatch(settings.fabric.color),
                      additionalInfo: Text(_canvasName(l10n, settings.fabric.color)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        final Rgb? chosen = await _pick<Rgb>(
                          context,
                          title: l10n.imageWizardFabricColor,
                          values: _canvasColors,
                          label: (color) => _canvasName(l10n, color),
                          cancel: l10n.imageWizardCancel,
                        );
                        if (chosen != null) {
                          cubit.setFabricColor(chosen);
                        }
                      },
                    ),
                  ] else
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('wizard-bead-size'),
                      title: Text(l10n.imageWizardBeadSize),
                      additionalInfo: Text(_beadLabel(l10n, settings.beadSize)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        final BeadSize? chosen = await _pick<BeadSize>(
                          context,
                          title: l10n.imageWizardBeadSize,
                          values: BeadSize.values,
                          label: (size) => _beadLabel(l10n, size),
                          cancel: l10n.imageWizardCancel,
                        );
                        if (chosen != null) {
                          cubit.setBeadSize(chosen);
                        }
                      },
                    ),
                ],
              ),
              SizedBox(height: gap),
              if (settings.craft == Craft.crossStitch)
                _WidthCmRow(settings: settings, onChanged: cubit.setWidthCm)
              else
                _SliderRow(
                  title: l10n.imageWizardWidth,
                  value: settings.columns,
                  min: ImageToGridSettings.minColumns,
                  max: ImageToGridSettings.maxColumns,
                  onChanged: cubit.setColumns,
                ),
              _SizeAssist(state: state, cubit: cubit),
              _SliderRow(
                title: l10n.imageWizardColorCount,
                value: settings.maxColors,
                min: ImageToGridSettings.minColors,
                max: ImageToGridSettings.maxColorsLimit,
                onChanged: cubit.setMaxColors,
              ),
              _Section(
                title: l10n.imageWizardPreset,
                child: CupertinoSlidingSegmentedControl<_PresetChoice>(
                  key: const ValueKey<String>('wizard-preset'),
                  groupValue: switch (settings.preset) {
                    null => _PresetChoice.asIs,
                    GenerationPreset.simpler => _PresetChoice.simpler,
                    GenerationPreset.balanced => _PresetChoice.balanced,
                    GenerationPreset.detailed => _PresetChoice.detailed,
                  },
                  children: <_PresetChoice, Widget>{
                    _PresetChoice.asIs: _SegmentLabel(l10n.imageWizardPresetAsIs),
                    _PresetChoice.simpler: _SegmentLabel(l10n.imageWizardPresetSimpler),
                    _PresetChoice.balanced: _SegmentLabel(l10n.imageWizardPresetBalanced),
                    _PresetChoice.detailed: _SegmentLabel(l10n.imageWizardPresetDetailed),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      cubit.setPreset(switch (value) {
                        _PresetChoice.asIs => null,
                        _PresetChoice.simpler => GenerationPreset.simpler,
                        _PresetChoice.balanced => GenerationPreset.balanced,
                        _PresetChoice.detailed => GenerationPreset.detailed,
                      });
                    }
                  },
                ),
              ),
              if (state.hasSubject) ...<Widget>[
                _Section(
                  title: l10n.imageWizardBackground,
                  child: CupertinoSlidingSegmentedControl<BackgroundMode>(
                    key: const ValueKey<String>('wizard-background'),
                    groupValue: settings.background,
                    children: <BackgroundMode, Widget>{
                      BackgroundMode.keep: _SegmentLabel(l10n.imageWizardBackgroundKeep),
                      BackgroundMode.simplify: _SegmentLabel(l10n.imageWizardBackgroundSimplify),
                      BackgroundMode.remove: _SegmentLabel(l10n.imageWizardBackgroundRemove),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        cubit.setBackground(value);
                      }
                    },
                  ),
                ),
                if (settings.craft == Craft.beading)
                  MergeSemantics(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(l10n.imageWizardOutline),
                              Text(l10n.imageWizardOutlineHint, style: caption),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          key: const ValueKey<String>('wizard-outline'),
                          value: settings.outline,
                          onChanged: (value) => cubit.setOutline(value: value),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: gap),
              ],
              if (settings.craft == Craft.crossStitch) ...<Widget>[
                _SwitchRow(
                  switchKey: const ValueKey<String>('wizard-backstitch'),
                  title: l10n.imageWizardBackstitch,
                  hint: state.preview == null || !settings.backstitch || state.calculating
                      ? l10n.imageWizardBackstitchHint
                      : '${l10n.imageWizardBackstitchHint}\n${l10n.imageWizardBackstitchCount(state.preview!.lines.length)}',
                  value: settings.backstitch,
                  onChanged: (value) => cubit.setBackstitch(value: value),
                ),
                if ((state.preview?.blendSuggestions.isNotEmpty ?? false) || settings.blends)
                  _SwitchRow(
                    switchKey: const ValueKey<String>('wizard-blends'),
                    title: l10n.imageWizardBlends,
                    hint: l10n.imageWizardBlendsHint(state.preview?.blendSuggestions.length ?? 0),
                    value: settings.blends,
                    onChanged: (value) => cubit.setBlends(value: value),
                  ),
                SizedBox(height: gap),
              ],
              _Section(
                title: settings.craft == Craft.crossStitch ? l10n.imageWizardFlossPalette : l10n.imageWizardPalette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    CupertinoSlidingSegmentedControl<PaletteSource>(
                      groupValue: settings.paletteSource,
                      children: <PaletteSource, Widget>{
                        PaletteSource.catalog: _SegmentLabel(l10n.imageWizardPaletteCatalog),
                        PaletteSource.free: _SegmentLabel(l10n.imageWizardPaletteFree),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          cubit.setPaletteSource(value);
                        }
                      },
                    ),
                    if (settings.paletteSource == PaletteSource.catalog && settings.craft == Craft.beading) ...<Widget>[
                      SizedBox(height: tokens.spacing.s),
                      Text(l10n.imageWizardBeadSeries, style: caption),
                      SizedBox(height: tokens.spacing.xs),
                      CupertinoSlidingSegmentedControl<BeadSeries>(
                        key: const ValueKey<String>('wizard-bead-series'),
                        groupValue: cubit.beadSeries,
                        children: <BeadSeries, Widget>{
                          BeadSeries.delica: _SegmentLabel(l10n.imageWizardSeriesDelica),
                          BeadSeries.round: _SegmentLabel(l10n.imageWizardSeriesRound),
                        },
                        onValueChanged: (value) {
                          if (value != null) {
                            cubit.setBeadSeries(value);
                          }
                        },
                      ),
                      for (final BeadFinishGroup group in BeadFinishGroup.values)
                        MergeSemantics(
                          child: Row(
                            children: <Widget>[
                              Expanded(child: Text(_finishTitle(l10n, group))),
                              CupertinoSwitch(
                                key: ValueKey<String>('wizard-finish-${group.name}'),
                                value: settings.finishGroups.contains(group),
                                onChanged: (value) => cubit.setFinishGroup(group, value: value),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (state.catalogMissing)
                      Padding(
                        padding: EdgeInsets.only(top: tokens.spacing.s),
                        child: Text(
                          settings.craft == Craft.crossStitch
                              ? l10n.imageWizardFlossMissing
                              : l10n.imageWizardCatalogMissing,
                          style: caption,
                        ),
                      )
                    else if (state.catalogShort)
                      Padding(
                        padding: EdgeInsets.only(top: tokens.spacing.s),
                        child: Text(
                          l10n.imageWizardCatalogFew(state.catalogColors, settings.maxColors),
                          key: const ValueKey<String>('wizard-catalog-few'),
                          style: caption,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              AppListSection(
                margin: EdgeInsets.zero,
                children: <Widget>[
                  CupertinoListTile.notched(
                    key: const ValueKey<String>('wizard-brush'),
                    title: Text(l10n.imageWizardBrushTitle),
                    additionalInfo: state.brush.isEmpty ? null : Text(l10n.imageWizardBrushManual),
                    trailing: const CupertinoListTileChevron(),
                    onTap: cubit.startBrush,
                  ),
                  if (!state.brush.isEmpty)
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('wizard-brush-reset'),
                      title: Text(
                        l10n.imageWizardBrushReset,
                        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                      ),
                      onTap: cubit.resetBrush,
                    ),
                ],
              ),
              if (state.hasMasks) ...<Widget>[
                SizedBox(height: gap),
                MergeSemantics(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(l10n.imageWizardUseMasks),
                            Text(l10n.imageWizardUseMasksHint, style: caption),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        key: const ValueKey<String>('wizard-use-masks'),
                        value: settings.useMasks,
                        onChanged: (value) => cubit.setUseMasks(value: value),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.faceAdvice case final FaceSizeAdvice advice) ...<Widget>[
                SizedBox(height: gap),
                _FaceWarning(
                  advice: advice,
                  onCrop: advice.cropRect == null ? null : cubit.cropToFace,
                  onWiden: advice.neededColumns == null ? null : cubit.widenForFace,
                ),
              ],
              SizedBox(height: gap),
              CupertinoTextField(
                key: const ValueKey<String>('wizard-name'),
                controller: _name,
                placeholder: l10n.imageWizardName,
                onChanged: cubit.setName,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        // Ошибка стоит рядом с кнопкой: внизу прокручиваемого списка её не видно, и кнопка казалась сломанной.
        if (state.problem != null)
          Padding(
            padding: EdgeInsets.fromLTRB(gap, gap / 2, gap, 0),
            child: _Problem(state.problem),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(gap, gap / 2, gap, gap),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              key: const ValueKey<String>('wizard-save'),
              onPressed: state.canSave ? cubit.save : null,
              child: Text(l10n.imageWizardSave),
            ),
          ),
        ),
      ],
    );
  }
}

/// Системный выбор значения: нижний лист действий iOS.
Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T value) label,
  required String cancel,
}) => showCupertinoModalPopup<T>(
  context: context,
  builder: (sheet) => CupertinoActionSheet(
    title: Text(title),
    actions: <Widget>[
      for (final T value in values)
        CupertinoActionSheetAction(onPressed: () => Navigator.of(sheet).pop(value), child: Text(label(value))),
    ],
    cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(sheet).pop(), child: Text(cancel)),
  ),
);

String _beadLabel(AppLocalizations l10n, BeadSize size) {
  final String shape = switch (size.shape) {
    BeadShape.delica => l10n.beadShapeDelica,
    BeadShape.rocaille => l10n.beadShapeRocaille,
  };
  return '$shape ${size.sizeCode}';
}

/// Выбор детальности в мастере: «как на фото» (T24 без предустановки) и три предустановки.
enum _PresetChoice { asIs, simpler, balanced, detailed }

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: context.tokens.minTapTarget - 4),
    child: Center(child: Text(text)),
  );
}

String _finishTitle(AppLocalizations l10n, BeadFinishGroup group) => switch (group) {
  BeadFinishGroup.solid => l10n.imageWizardFinishSolid,
  BeadFinishGroup.luster => l10n.imageWizardFinishLuster,
  BeadFinishGroup.transparent => l10n.imageWizardFinishTransparent,
};

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.tokens.spacing.m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: context.tokens.spacing.s),
        child,
      ],
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.tokens.spacing.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text('$value', key: ValueKey<String>('slider-value-$title')),
          ],
        ),
        CupertinoSlider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    ),
  );
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.symmetric(horizontal: context.tokens.spacing.m),
    minimumSize: Size.square(context.tokens.minTapTarget),
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon),
        SizedBox(width: context.tokens.spacing.s),
        Text(label),
      ],
    ),
  );
}

/// Предпросмотр схемы. Пока палец на нём, вместо схемы показана исходная картинка («до/после»).
class _Preview extends StatelessWidget {
  const _Preview({required this.state, required this.height});

  final ImageWizardState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageWizardCubit cubit = context.read<ImageWizardCubit>();
    final AppTokensData tokens = context.tokens;
    final Grid? grid = state.preview?.grid;
    final ImageToGridSettings? shown = state.previewSettings;
    final Widget content;
    if (state.comparing && state.prepared != null) {
      content = Semantics(
        label: l10n.imageWizardOriginalLabel,
        image: true,
        child: Image.memory(state.prepared!, fit: BoxFit.contain, gaplessPlayback: true),
      );
    } else if (grid != null && shown != null && state.previewPalette != null) {
      content = Semantics(
        label: l10n.imageWizardPreviewLabel,
        image: true,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.s),
          child: GridPatternView(
            key: const ValueKey<String>('wizard-grid'),
            grid: grid,
            palette: state.previewPalette!,
            geometry: shown.geometry,
            metrics: shown.metrics,
            options: GridViewOptions(
              showGridLines: false,
              realistic: state.realistic,
              canvasColor: shown.craft == Craft.crossStitch
                  ? Color.fromARGB(255, shown.fabric.color.r, shown.fabric.color.g, shown.fabric.color.b)
                  : null,
            ),
            interactive: false,
          ),
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        GestureDetector(
          key: const ValueKey<String>('wizard-preview'),
          behavior: HitTestBehavior.opaque,
          onTap: grid == null ? null : () => showFullPreview(context),
          onLongPressStart: (_) => cubit.setComparing(value: true),
          onLongPressEnd: (_) => cubit.setComparing(value: false),
          onLongPressCancel: () => cubit.setComparing(value: false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.m),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: ColoredBox(
                color: CupertinoColors.secondarySystemFill.resolveFrom(context),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: Center(child: content)),
                    if (grid != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CupertinoButton(
                          key: const ValueKey<String>('wizard-preview-open'),
                          padding: EdgeInsets.all(tokens.spacing.s),
                          minimumSize: Size.square(tokens.minTapTarget),
                          onPressed: () => showFullPreview(context),
                          child: Semantics(
                            label: l10n.imageWizardFullPreviewOpen,
                            button: true,
                            child: const Icon(CupertinoIcons.arrow_up_left_arrow_down_right),
                          ),
                        ),
                      ),
                    if (state.calculating)
                      Positioned(
                        top: tokens.spacing.s,
                        right: tokens.spacing.s,
                        child: Semantics(
                          liveRegion: true,
                          label: l10n.imageWizardCalculating,
                          child: const CupertinoActivityIndicator(key: ValueKey<String>('wizard-calculating')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (grid != null)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.s),
            child: CupertinoSlidingSegmentedControl<bool>(
              key: const ValueKey<String>('wizard-look'),
              groupValue: state.realistic,
              onValueChanged: (value) => cubit.setRealistic(value: value ?? false),
              children: <bool, Widget>{
                false: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
                  child: Text(l10n.imageWizardLookChart),
                ),
                true: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
                  child: Text(l10n.imageWizardLookRealistic),
                ),
              },
            ),
          ),
        if (grid != null)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.s),
            child: Text(
              shown?.craft == Craft.crossStitch
                  ? l10n.imageWizardSizeStitch(
                      grid.width,
                      grid.height,
                      _cm(shown!.fabric.cmForCells(grid.width)),
                      _cm(shown.fabric.cmForCells(grid.height)),
                    )
                  : l10n.imageWizardSize(grid.width, grid.height),
              key: const ValueKey<String>('wizard-size'),
              style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ),
      ],
    );
  }
}

String _cm(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

/// Канвы на выбор: самые частые в наборах. Цвет канвы берётся у текущей.
List<Fabric> _fabricChoices(Fabric current) {
  Fabric make(FabricKind kind, int count) => Fabric.create(kind: kind, count: count, color: current.color).valueOrNull!;
  return <Fabric>[
    for (final int count in <int>[11, 14, 16, 18, 20]) make(FabricKind.aida, count),
    make(FabricKind.evenweave, 28),
    make(FabricKind.evenweave, 32),
    make(FabricKind.linen, 28),
    make(FabricKind.linen, 32),
  ];
}

String _fabricLabel(AppLocalizations l10n, Fabric fabric) => switch (fabric.kind) {
  FabricKind.aida => l10n.imageWizardFabricAida(fabric.count),
  FabricKind.evenweave => l10n.imageWizardFabricEvenweave(fabric.count, fabric.overCount),
  FabricKind.linen => l10n.imageWizardFabricLinen(fabric.count, fabric.overCount),
};

const List<Rgb> _canvasColors = <Rgb>[
  Rgb(255, 255, 255),
  Rgb(245, 239, 224),
  Rgb(227, 213, 184),
  Rgb(150, 150, 150),
  Rgb(20, 20, 20),
];

String _canvasName(AppLocalizations l10n, Rgb color) => switch (_canvasColors.indexOf(color)) {
  0 => l10n.imageWizardCanvasWhite,
  1 => l10n.imageWizardCanvasCream,
  2 => l10n.imageWizardCanvasLinen,
  3 => l10n.imageWizardCanvasGray,
  4 => l10n.imageWizardCanvasBlack,
  _ => color.hex,
};

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Rgb color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Color.fromARGB(255, color.r, color.g, color.b),
      shape: BoxShape.circle,
      border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
    ),
  );
}

/// Ширина вышивки в сантиметрах: клетки считаются по канве.
class _WidthCmRow extends StatelessWidget {
  const _WidthCmRow({required this.settings, required this.onChanged});

  final ImageToGridSettings settings;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Fabric fabric = settings.fabric;
    final double snapped = ImageToGridSettings.snapCm(settings.widthCm);
    // Клетки целые: 50 см — это 276 крестиков, 50,1 см. Если размер близок к шагу, показываем шаг.
    final double shownCm = (settings.widthCm - snapped).abs() < 0.3 ? snapped : settings.widthCm;
    const double min = ImageToGridSettings.minStitchWidthCm;
    const double max = ImageToGridSettings.maxStitchWidthCm;
    return Padding(
      padding: EdgeInsets.only(bottom: context.tokens.spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.imageWizardWidthCm, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(l10n.imageWizardCm(_cm(shownCm)), key: const ValueKey<String>('wizard-width-cm')),
            ],
          ),
          CupertinoSlider(
            key: const ValueKey<String>('wizard-width-cm-slider'),
            value: ImageToGridSettings.snapCm(settings.widthCm),
            min: min,
            max: max,
            divisions: ((max - min) / ImageToGridSettings.stitchCmStep).round(),
            onChanged: onChanged,
          ),
          Text(
            l10n.imageWizardWidthCrosses(
              settings.columns,
              _fabricLabel(l10n, fabric),
              fabric.stitchesPerCm.toStringAsFixed(1).replaceAll('.', ','),
            ),
            key: const ValueKey<String>('wizard-width-crosses'),
            style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title),
              Text(
                hint,
                style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ],
          ),
        ),
        CupertinoSwitch(key: switchKey, value: value, onChanged: onChanged),
      ],
    ),
  );
}
