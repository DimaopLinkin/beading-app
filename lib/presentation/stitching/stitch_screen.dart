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
const double _bottomPanelHeight = 236;
const double _bottomPanelHeightLarge = 372;

/// Ширина, с которой экран раскладывается как на Mac: слева остаток по цветам, сверху панель режимов.
const double _wideBreakpoint = 700;
const double _sidebarWidth = 340;

/// Масштаб шрифта, с которого режимы лежат сеткой 2 × 2 (AX3 в макете 10).
const double _largeTextScale = 1.7;

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

  final GlobalKey _canvasKey = GlobalKey();

  /// Показывает клетку остановки в середине полотна.
  void _goToParked(StitchState s) {
    final CellPosition? cell = s.parked;
    final Size? viewport = (_canvasKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    if (cell == null || viewport == null) {
      return;
    }
    final GridScene scene = GridScene(
      geometry: s.pattern!.geometry,
      metrics: s.pattern!.metrics,
      columns: s.pattern!.grid.width,
      rows: s.pattern!.grid.height,
    );
    final double scale = math.max(_controller.value.storage[0], 2.5);
    final Offset center = scene.cellRect(cell).center;
    _controller.value = Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - center.dx * scale, viewport.height / 2 - center.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Widget _canvas(StitchState state, StitchCubit cubit) {
    final GridPattern pattern = state.pattern!;
    return KeyedSubtree(
      key: _canvasKey,
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
    );
  }

  Widget? _notice(StitchState state) {
    if (state.offerFinish) {
      return const _FinishOffer();
    }
    return state.saveFailed ? const _SaveFailedNotice() : null;
  }

  @override
  Widget build(BuildContext context) {
    final StitchCubit cubit = context.read<StitchCubit>();
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool large = MediaQuery.textScalerOf(context).scale(14) / 14 >= _largeTextScale;
    final double topInset = safe.top + _topBarHeight;
    final double bottomInset = safe.bottom + (large ? _bottomPanelHeightLarge : _bottomPanelHeight);
    return BlocListener<StitchCubit, StitchState>(
      listenWhen: (previous, current) => previous.marks != current.marks,
      listener: (context, state) => HapticFeedback.selectionClick(),
      child: LayoutBuilder(
        builder: (context, box) => BlocBuilder<StitchCubit, StitchState>(
          builder: (context, state) {
            final Widget? notice = _notice(state);
            if (box.maxWidth >= _wideBreakpoint) {
              return _wideLayout(state, cubit, topInset, notice);
            }
            return Stack(
              children: <Widget>[
                Positioned(left: 0, right: 0, top: topInset, bottom: bottomInset, child: _canvas(state, cubit)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _Frame(child: _TopBar(state: state)),
                ),
                if (notice != null) Positioned(left: 0, right: 0, top: topInset, child: notice),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Frame(
                    child: _BottomPanel(state: state, large: large, onGoToParked: () => _goToParked(state)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Широкий экран (Mac, планшет): слева остаток по цветам, сверху панель режимов, снизу сводка работы.
  Widget _wideLayout(StitchState state, StitchCubit cubit, double topInset, Widget? notice) {
    final AppTokensData tokens = context.tokens;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: topInset,
          bottom: 0,
          width: _sidebarWidth + safe.left,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.s + safe.left,
              tokens.spacing.s,
              0,
              tokens.spacing.s + safe.bottom,
            ),
            child: GlassPanel(
              key: const ValueKey<String>('stitch-sidebar'),
              density: GlassDensity.dense,
              padding: EdgeInsets.zero,
              child: _ColorsList(state: state, closeOnTap: false),
            ),
          ),
        ),
        Positioned(
          left: _sidebarWidth + safe.left + tokens.spacing.s,
          right: safe.right,
          top: topInset,
          bottom: 0,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(tokens.spacing.s),
                child: GlassBar(
                  density: GlassDensity.dense,
                  padding: EdgeInsets.all(tokens.spacing.xs),
                  child: _ActionRow(
                    actions: <_Action>[
                      ..._modes(context, state, withColors: false),
                      ..._extras(context, state, () => _goToParked(state)),
                    ],
                    compact: true,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: _canvas(state, cubit)),
                    if (notice != null) Positioned(left: 0, right: 0, top: 0, child: notice),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.s,
                  tokens.spacing.s,
                  tokens.spacing.s,
                  tokens.spacing.s + safe.bottom,
                ),
                child: GlassPanel(
                  density: GlassDensity.dense,
                  padding: EdgeInsets.all(tokens.spacing.s),
                  child: _Summary(state: state),
                ),
              ),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, top: 0, child: _TopBar(state: state)),
      ],
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

/// Кнопка нижней панели: значок и подпись у каждой (урок 06-editor).
class _Action {
  const _Action({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
}

/// Режимы отметки и лист цветов.
List<_Action> _modes(BuildContext context, StitchState state, {bool withColors = true}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final StitchCubit cubit = context.read<StitchCubit>();
  return <_Action>[
    _Action(
      id: 'stitch-tool-tap',
      icon: CupertinoIcons.hand_point_right,
      label: l10n.stitchToolTap,
      selected: state.tool == StitchTool.tap,
      onPressed: () => cubit.setTool(StitchTool.tap),
    ),
    _Action(
      id: 'stitch-tool-stroke',
      icon: AppIcons.brush,
      label: l10n.stitchToolStroke,
      selected: state.tool == StitchTool.stroke,
      onPressed: () => cubit.setTool(StitchTool.stroke),
    ),
    _Action(
      id: 'stitch-tool-area',
      icon: AppIcons.zoneFrame,
      label: l10n.stitchToolArea,
      selected: state.tool == StitchTool.area,
      onPressed: () => cubit.setTool(StitchTool.area),
    ),
    if (withColors)
      _Action(
        id: 'stitch-colors',
        icon: AppIcons.catalog,
        label: l10n.stitchColors,
        onPressed: () => _openColors(context),
      ),
  ];
}

/// Слои и закладка: блоки, символы, место остановки.
List<_Action> _extras(BuildContext context, StitchState state, VoidCallback goToParked) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final StitchCubit cubit = context.read<StitchCubit>();
  final bool parked = state.parked != null;
  return <_Action>[
    _Action(
      id: 'stitch-blocks',
      icon: CupertinoIcons.square_grid_2x2,
      label: l10n.stitchActionBlocks,
      selected: state.showBlocks,
      onPressed: cubit.toggleBlocks,
    ),
    _Action(
      id: 'stitch-symbols',
      icon: CupertinoIcons.textformat_abc,
      label: l10n.stitchActionSymbols,
      selected: state.showSymbols,
      onPressed: cubit.toggleSymbols,
    ),
    _Action(
      id: 'stitch-go-parked',
      icon: CupertinoIcons.flag,
      label: parked ? l10n.stitchGoToParked : l10n.stitchActionParking,
      onPressed: parked ? goToParked : () => _showParkHint(context),
    ),
  ];
}

void _openColors(BuildContext context) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) => BlocProvider<StitchCubit>.value(value: context.read<StitchCubit>(), child: const _ColorsSheet()),
);

void _showParkHint(BuildContext context) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  showCupertinoDialog<void>(
    context: context,
    builder: (dialog) => CupertinoAlertDialog(
      content: Text(l10n.stitchParkHint),
      actions: <Widget>[
        CupertinoDialogAction(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.stitchClose)),
      ],
    ),
  );
}

/// Одна кнопка панели: значок над подписью, выбранная подсвечена. [size] — высота (62 обычная, 84 для AX3).
class _LabelButton extends StatelessWidget {
  const _LabelButton({required this.action, required this.size});

  final _Action action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color accent = tokens.accent.resolveFrom(context);
    final Color color = action.selected ? accent : CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      key: ValueKey<String>(action.id),
      padding: EdgeInsets.zero,
      minimumSize: Size(tokens.minTapTarget, size),
      onPressed: action.onPressed,
      child: Semantics(
        selected: action.selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: action.selected ? accent.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: size,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(action.icon, color: color, size: size > 70 ? 30 : 22),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: size > 70 ? 17 : 12, fontWeight: FontWeight.w600),
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

/// Ряд кнопок одинаковой ширины.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions, this.size = 62, this.compact = false});

  final List<_Action> actions;
  final double size;

  /// Компактный ряд (панель Mac): кнопки по размеру подписи, а не растянуты.
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    children: <Widget>[
      for (final _Action a in actions)
        compact
            ? SizedBox(width: 92, child: _LabelButton(action: a, size: 52))
            : Expanded(
                child: _LabelButton(action: a, size: size),
              ),
    ],
  );
}

/// Счётчик и полоса прогресса.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final StitchState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return Column(
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
          child: SizedBox(height: 6, child: LinearProgressBar(fraction: state.fraction)),
        ),
      ],
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state, required this.large, required this.onGoToParked});

  final StitchState state;

  /// AX3: режимы сеткой 2 × 2, остальное под кнопкой «Ещё».
  final bool large;
  final VoidCallback onGoToParked;

  void _more(BuildContext context) {
    final List<_Action> extras = _extras(context, state, onGoToParked);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        actions: <Widget>[
          for (final _Action a in extras)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheet).pop();
                a.onPressed?.call();
              },
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: Text(AppLocalizations.of(context).stitchClose),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final List<_Action> modes = _modes(context, state);
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
              _Summary(state: state),
              SizedBox(height: tokens.spacing.xs),
              if (large) ...<Widget>[
                _ActionRow(actions: modes.sublist(0, 2), size: 84),
                _ActionRow(actions: modes.sublist(2), size: 84),
                CupertinoButton.tinted(
                  key: const ValueKey<String>('stitch-more'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.fromHeight(48),
                  onPressed: () => _more(context),
                  child: Text(l10n.stitchActionMore),
                ),
              ] else ...<Widget>[
                _ActionRow(actions: modes),
                _ActionRow(actions: _extras(context, state, onGoToParked), size: 48),
              ],
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
                  Expanded(child: _ColorsList(state: state, closeOnTap: true)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Строки цветов: лист и боковая панель широкого экрана.
class _ColorsList extends StatelessWidget {
  const _ColorsList({required this.state, required this.closeOnTap});

  final StitchState state;

  /// В листе касание строки закрывает его; в боковой панели лист остаётся на месте.
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) {
    final List<PatternColor> palette = state.pattern!.palette.colors;
    return ListView.builder(
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
          closeOnTap: closeOnTap,
        );
      },
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.color,
    required this.count,
    required this.highlighted,
    required this.closeOnTap,
    super.key,
  });

  final bool closeOnTap;

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
          if (closeOnTap) Text(l10n.stitchColorProgress(count.done, count.total)),
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
        if (closeOnTap) {
          Navigator.of(context).pop();
        }
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
