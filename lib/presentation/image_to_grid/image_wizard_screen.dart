import 'dart:io' show Platform;

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_state.dart';
import 'package:beading/presentation/import_book/crop_editor.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
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
                _Edit(state: state),
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
              SizedBox(height: gap),
              CupertinoListSection.insetGrouped(
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
                        values: ImageToGridSettings.techniques,
                        label: (t) => t.label(l10n),
                        cancel: l10n.imageWizardCancel,
                      );
                      if (chosen != null) {
                        cubit.setTechnique(chosen);
                      }
                    },
                  ),
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
              _SliderRow(
                title: l10n.imageWizardWidth,
                value: settings.columns,
                min: ImageToGridSettings.minColumns,
                max: ImageToGridSettings.maxColumns,
                onChanged: cubit.setColumns,
              ),
              _SliderRow(
                title: l10n.imageWizardColorCount,
                value: settings.maxColors,
                min: ImageToGridSettings.minColors,
                max: ImageToGridSettings.maxColorsLimit,
                onChanged: cubit.setMaxColors,
              ),
              _Section(
                title: l10n.imageWizardPalette,
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
                    if (state.catalogMissing)
                      Padding(
                        padding: EdgeInsets.only(top: tokens.spacing.s),
                        child: Text(l10n.imageWizardCatalogMissing, style: caption),
                      ),
                  ],
                ),
              ),
              MergeSemantics(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.imageWizardDither),
                          Text(l10n.imageWizardDitherHint, style: caption),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: settings.dither,
                      onChanged: (value) => cubit.setDither(value: value),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              CupertinoTextField(
                key: const ValueKey<String>('wizard-name'),
                controller: _name,
                placeholder: l10n.imageWizardName,
                onChanged: cubit.setName,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: gap),
              _Problem(state.problem),
            ],
          ),
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

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: context.tokens.minTapTarget - 4),
    child: Center(child: Text(text)),
  );
}

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
            metrics: shown.beadSize,
            options: const GridViewOptions(showGridLines: false),
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
            child: Text(
              l10n.imageWizardSize(grid.width, grid.height),
              key: const ValueKey<String>('wizard-size'),
              style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ),
      ],
    );
  }
}
