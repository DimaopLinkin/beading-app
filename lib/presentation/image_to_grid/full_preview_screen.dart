import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Открывает полноэкранный предпросмотр схемы мастера. Параметры живут в [ImageWizardCubit] мастера, поэтому возврат
/// ничего не сбрасывает.
Future<void> showFullPreview(BuildContext context) {
  final ImageWizardCubit cubit = context.read<ImageWizardCubit>();
  return Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => BlocProvider<ImageWizardCubit>.value(value: cubit, child: const FullPreviewScreen()),
    ),
  );
}

/// Схема из мастера на весь экран: тот же вид и тот же рисовальщик, что на экране вышивки (зум до клетки, сдвиг,
/// каждая десятая линия жирная, знаки), и переключатель «Схема / Как будет».
class FullPreviewScreen extends StatelessWidget {
  const FullPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageWizardCubit cubit = context.read<ImageWizardCubit>();
    final AppTokensData tokens = context.tokens;
    return BlocBuilder<ImageWizardCubit, ImageWizardState>(
      builder: (context, state) {
        final Grid? grid = state.preview?.grid;
        final ImageToGridSettings? shown = state.previewSettings;
        final bool ready = grid != null && shown != null && state.previewPalette != null;
        return CupertinoPageScaffold(
          key: const ValueKey<String>('full-preview'),
          navigationBar: CupertinoNavigationBar(
            middle: Text(l10n.imageWizardFullPreviewTitle),
            leading: CupertinoButton(
              key: const ValueKey<String>('full-preview-back'),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.imageWizardFullPreviewBack),
            ),
            trailing: state.calculating ? const CupertinoActivityIndicator() : null,
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRect(
                    child: ready
                        ? Semantics(
                            label: l10n.imageWizardPreviewLabel,
                            image: true,
                            child: GridPatternView(
                              key: ValueKey<String>('full-preview-grid-${state.realistic}'),
                              grid: grid,
                              palette: state.previewPalette!,
                              geometry: shown.geometry,
                              metrics: shown.metrics,
                              layers: _layers(state, grid),
                              maxScale: 16,
                              options: GridViewOptions(
                                showSymbols: !state.realistic,
                                boldEvery: shown.craft == Craft.crossStitch ? 10 : 0,
                                stitchStyle: shown.craft == Craft.crossStitch ? StitchStyle.colorAndSymbol : null,
                                showCenter: shown.craft == Craft.crossStitch,
                                realistic: state.realistic,
                                canvasColor: shown.craft == Craft.crossStitch
                                    ? Color.fromARGB(
                                        255,
                                        shown.fabric.color.r,
                                        shown.fabric.color.g,
                                        shown.fabric.color.b,
                                      )
                                    : null,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.m),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CupertinoSlidingSegmentedControl<bool>(
                        key: const ValueKey<String>('full-preview-look'),
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
                      SizedBox(height: tokens.spacing.s),
                      Text(
                        l10n.imageWizardFullPreviewHint,
                        style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Контуры-бэкстич схемы вышивки, как они лягут в проект.
  static StitchLayers? _layers(ImageWizardState state, Grid grid) {
    if (state.previewSettings?.craft != Craft.crossStitch || state.preview!.lines.isEmpty) {
      return null;
    }
    return StitchLayers(columns: grid.width, rows: grid.height, lines: state.preview!.lines);
  }
}
