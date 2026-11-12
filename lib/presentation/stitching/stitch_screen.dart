import 'dart:math' as math;

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/stitch_legend_view.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/stitching/stitch_canvas.dart';
import 'package:beading/presentation/stitching/stitch_cubit.dart';
import 'package:beading/presentation/stitching/stitch_state.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Режим вышивания: схема на весь экран, отметка клеток касанием, мазком или областью, остаток по цветам, процент
/// по блокам 10×10 и парковка. [StitchCubit] берётся из контекста.
class StitchScreen extends StatelessWidget {
  const StitchScreen({super.key});

  static const String routePath = '/stitch/:projectId';

  static String locationFor(String projectId) => '/stitch/$projectId';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground,
    child: BlocBuilder<StitchCubit, StitchState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) => switch (state.status) {
        StitchStatus.loading => const Center(child: CupertinoActivityIndicator()),
        StitchStatus.failed => const _LoadFailed(),
        StitchStatus.ready => const _Workspace(),
      },
    ),
  );
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(context.tokens.spacing.l),
            child: Text(l10n.stitchLoadFailed, textAlign: TextAlign.center),
          ),
          CupertinoButton.filled(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.stitchClose)),
        ],
      ),
    );
  }
}

const double _topBarHeight = 64;
const double _toolsHeight = 56;
const double _bottomPanelHeight = 132;

class _Workspace extends StatefulWidget {
  const _Workspace();

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> with WidgetsBindingObserver {
  final TransformationController _controller = TransformationController();
  StitchLayers? _layers;
  GridPattern? _layersFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Время вышивания не идёт, пока приложение не на виду.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final StitchCubit cubit = context.read<StitchCubit>();
    if (state == AppLifecycleState.resumed) {
      cubit.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      cubit.pause();
    }
  }

  StitchLayers? _layersOf(GridPattern pattern) {
    if (!identical(_layersFor, pattern)) {
      _layersFor = pattern;
      final blob = pattern.layers;
      _layers = blob == null ? null : StitchLayersCodec.fromBlob(blob).valueOrNull;
    }
    return _layers;
  }

  GridViewOptions _options(StitchState s) {
    final CellMetrics metrics = s.pattern!.metrics;
    final CellPosition? parked = s.parked;
    return GridViewOptions(
      showSymbols: s.showSymbols,
      boldEvery: 10,
      stitchStyle: StitchStyle.colorAndSymbol,
      showCenter: true,
      highlightColor: s.highlight,
      canvasColor: metrics is Fabric ? Color.fromARGB(255, metrics.color.r, metrics.color.g, metrics.color.b) : null,
      currentCell: parked == null ? null : (column: parked.column, row: parked.row),
      doneCells: s.progress.cells(height: s.pattern!.grid.height).toSet(),
    );
  }

  /// Показывает клетку остановки в середине окна.
  void _goTo(StitchState s, CellPosition cell, Size viewport) {
    final GridScene scene = GridScene(
      geometry: s.pattern!.geometry,
      metrics: s.pattern!.metrics,
      columns: s.pattern!.grid.width,
      rows: s.pattern!.grid.height,
    );
    final double scale = math.max(_controller.value.getMaxScaleOnAxis(), 2.5);
    final Offset center = scene.cellRect(cell).center;
    _controller.value = Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - center.dx * scale, viewport.height / 2 - center.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final StitchCubit cubit = context.read<StitchCubit>();
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double topInset = safe.top + _topBarHeight + _toolsHeight;
    final double bottomInset = safe.bottom + _bottomPanelHeight;
    return BlocListener<StitchCubit, StitchState>(
      listenWhen: (previous, current) => previous.marks != current.marks,
      listener: (context, state) => HapticFeedback.selectionClick(),
      child: BlocBuilder<StitchCubit, StitchState>(
        builder: (context, state) {
          final GridPattern pattern = state.pattern!;
          return Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: topInset,
                bottom: bottomInset,
                child: StitchCanvas(
                  pattern: pattern,
                  state: state,
                  options: _options(state),
                  layers: _layersOf(pattern),
                  controller: _controller,
                  onTap: cubit.tapCell,
                  onLongPress: cubit.park,
                  onStrokeStart: cubit.strokeStart,
                  onStrokeCell: cubit.strokeCell,
                  onStrokeEnd: cubit.strokeEnd,
                  onArea: cubit.areaDrag,
                  onAreaEnd: cubit.areaEnd,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _Frame(child: _TopBar(state: state)),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: safe.top + _topBarHeight,
                child: _Frame(child: _Tools(state: state)),
              ),
              if (state.offerFinish)
                Positioned(left: 0, right: 0, top: topInset, child: const _FinishOffer())
              else if (state.saveFailed)
                Positioned(left: 0, right: 0, top: topInset, child: const _SaveFailedNotice()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Frame(
                  child: _BottomPanel(
                    state: state,
                    onGoToParked: state.parked == null
                        ? null
                        : () {
                            final Size size = MediaQuery.sizeOf(context);
                            _goTo(state, state.parked!, Size(size.width, size.height - topInset - bottomInset));
                          },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4, child: child),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final StitchState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s),
        child: GlassBar(
          density: GlassDensity.dense,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs, vertical: tokens.spacing.xs),
          child: Row(
            children: <Widget>[
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: () => Navigator.of(context).maybePop(),
                child: Semantics(label: l10n.stitchClose, child: const Icon(AppIcons.back)),
              ),
              Expanded(
                child: Text(
                  state.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                child: Text(
                  key: const ValueKey<String>('stitch-percent'),
                  l10n.stitchPercent((state.fraction * 100).floor()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
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

class _Tools extends StatelessWidget {
  const _Tools({required this.state});

  final StitchState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StitchCubit cubit = context.read<StitchCubit>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
      child: Row(
        children: <Widget>[
          Expanded(
            child: CupertinoSlidingSegmentedControl<StitchTool>(
              key: const ValueKey<String>('stitch-tools'),
              groupValue: state.tool,
              onValueChanged: (tool) {
                if (tool != null) {
                  cubit.setTool(tool);
                }
              },
              children: <StitchTool, Widget>{
                StitchTool.tap: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(l10n.stitchToolTap),
                ),
                StitchTool.stroke: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(l10n.stitchToolStroke),
                ),
                StitchTool.area: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(l10n.stitchToolArea),
                ),
              },
            ),
          ),
          SizedBox(width: tokens.spacing.s),
          CupertinoButton(
            key: const ValueKey<String>('stitch-symbols'),
            padding: EdgeInsets.zero,
            minimumSize: Size.square(tokens.minTapTarget),
            onPressed: cubit.toggleSymbols,
            child: Semantics(
              label: l10n.stitchSymbols,
              toggled: state.showSymbols,
              child: Icon(
                CupertinoIcons.textformat_abc,
                color: state.showSymbols ? null : CupertinoColors.inactiveGray,
              ),
            ),
          ),
          CupertinoButton(
            key: const ValueKey<String>('stitch-blocks'),
            padding: EdgeInsets.zero,
            minimumSize: Size.square(tokens.minTapTarget),
            onPressed: cubit.toggleBlocks,
            child: Semantics(
              label: l10n.stitchBlocks,
              toggled: state.showBlocks,
              child: Icon(
                CupertinoIcons.square_grid_2x2,
                color: state.showBlocks ? null : CupertinoColors.inactiveGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state, required this.onGoToParked});

  final StitchState state;
  final VoidCallback? onGoToParked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s),
        child: GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      key: const ValueKey<String>('stitch-counter'),
                      l10n.stitchCounter(state.done, state.total),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    key: const ValueKey<String>('stitch-remaining'),
                    l10n.stitchRemaining(state.remaining),
                    style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressBar(fraction: state.fraction),
                ),
              ),
              SizedBox(height: tokens.spacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoButton.filled(
                      key: const ValueKey<String>('stitch-colors'),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.fromHeight(44),
                      onPressed: () => showCupertinoModalPopup<void>(
                        context: context,
                        builder: (_) => BlocProvider<StitchCubit>.value(
                          value: context.read<StitchCubit>(),
                          child: const _ColorsSheet(),
                        ),
                      ),
                      child: Text(l10n.stitchColors),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Expanded(
                    child: CupertinoButton.tinted(
                      key: const ValueKey<String>('stitch-go-parked'),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.fromHeight(44),
                      onPressed: onGoToParked,
                      child: Text(
                        onGoToParked == null ? l10n.stitchParkHint : l10n.stitchGoToParked,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Полоска прогресса.
class LinearProgressBar extends StatelessWidget {
  const LinearProgressBar({required this.fraction, super.key});

  final double fraction;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(child: ColoredBox(color: CupertinoColors.systemFill.resolveFrom(context))),
      FractionallySizedBox(
        widthFactor: fraction.clamp(0, 1),
        child: ColoredBox(color: context.tokens.accent.resolveFrom(context)),
      ),
    ],
  );
}

/// Лист «Что осталось по цветам»: образец, нитка, сколько осталось; касание подсвечивает цвет, а действия — отмечают или
/// снимают цвет целиком.
class _ColorsSheet extends StatelessWidget {
  const _ColorsSheet();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: BlocBuilder<StitchCubit, StitchState>(
            builder: (context, state) {
              final List<PatternColor> palette = state.pattern!.palette.colors;
              return Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(tokens.spacing.m),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            l10n.stitchColorsTitle,
                            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.square(tokens.minTapTarget),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.stitchClose),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.byColor.length,
                      itemBuilder: (context, i) {
                        final ColorCount count = state.byColor[i];
                        if (count.total == 0) {
                          return const SizedBox.shrink();
                        }
                        return _ColorRow(
                          key: ValueKey<String>('stitch-color-$i'),
                          color: palette[i],
                          count: count,
                          highlighted: state.highlight == i + 1,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.color, required this.count, required this.highlighted, super.key});

  final PatternColor color;
  final ColorCount count;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StitchCubit cubit = context.read<StitchCubit>();
    final bool finished = count.remaining == 0;
    return CupertinoListTile(
      backgroundColor: highlighted ? CupertinoColors.systemFill.resolveFrom(context) : null,
      leading: ColorSwatchView(rgb: color.rgb, radius: 6),
      title: Text('${color.symbol == null ? '' : '${color.symbol}  '}${StitchLegendView.threadLabel(color)}'),
      subtitle: Text(color.name),
      additionalInfo: Text(finished ? l10n.stitchColorFinished : l10n.stitchRemaining(count.remaining)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.stitchColorProgress(count.done, count.total)),
          CupertinoButton(
            key: ValueKey<String>('stitch-mark-color-${count.color}'),
            padding: EdgeInsets.zero,
            minimumSize: Size.square(context.tokens.minTapTarget),
            onPressed: () => cubit.markColor(count.color),
            child: Semantics(
              label: finished ? l10n.stitchUnmarkColor : l10n.stitchMarkColor,
              child: Icon(finished ? CupertinoIcons.arrow_counterclockwise : CupertinoIcons.checkmark_circle),
            ),
          ),
        ],
      ),
      onTap: () {
        cubit.highlight(count.color + 1);
        Navigator.of(context).pop();
      },
    );
  }
}

class _FinishOffer extends StatelessWidget {
  const _FinishOffer();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StitchCubit cubit = context.read<StitchCubit>();
    return _Frame(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
        child: GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.stitchFinishTitle, textAlign: TextAlign.center),
              SizedBox(height: tokens.spacing.s),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoButton.tinted(
                      key: const ValueKey<String>('stitch-finish-later'),
                      onPressed: cubit.dismissFinish,
                      child: Text(l10n.stitchFinishLater),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s),
                  Expanded(
                    child: CupertinoButton.filled(
                      key: const ValueKey<String>('stitch-finish-yes'),
                      onPressed: cubit.finishProject,
                      child: Text(l10n.stitchFinishYes),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveFailedNotice extends StatelessWidget {
  const _SaveFailedNotice();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return _Frame(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
        child: GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.s),
          child: Text(
            key: const ValueKey<String>('stitch-save-failed'),
            l10n.stitchSaveFailed,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
