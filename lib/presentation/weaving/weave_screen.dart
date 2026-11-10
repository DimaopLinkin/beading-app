import 'dart:math' as math;

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/grid/word_chart.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/weaving/weave_cubit.dart';
import 'package:beading/presentation/weaving/weave_state.dart';
import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Плетение по своей схеме: схема на весь экран, подсвеченный ряд, word chart под ней и крупные кнопки под большой
/// палец. [WeaveCubit] берётся из контекста.
class WeaveScreen extends StatelessWidget {
  const WeaveScreen({this.onOpenEditor, super.key});

  /// Переход в редактор этой схемы; без него кнопки правки нет.
  final VoidCallback? onOpenEditor;

  static const String routePath = '/weave/:projectId';

  static String locationFor(String projectId) => '/weave/$projectId';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground,
    child: BlocBuilder<WeaveCubit, WeaveState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) => switch (state.status) {
        WeaveStatus.loading => const Center(child: CupertinoActivityIndicator()),
        WeaveStatus.failed => const _LoadFailed(),
        WeaveStatus.ready => _Workspace(onOpenEditor: onOpenEditor),
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
            child: Text(l10n.weaveLoadFailed, textAlign: TextAlign.center),
          ),
          CupertinoButton.filled(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.weaveClose)),
        ],
      ),
    );
  }
}

/// Высоты панелей поверх схемы: по ним схема отступает от краёв.
const double _topBarHeight = 96;
const double _togglesHeight = 56;
const double _bottomPanelHeight = 160;

class _Workspace extends StatefulWidget {
  const _Workspace({this.onOpenEditor});

  final VoidCallback? onOpenEditor;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> with WidgetsBindingObserver {
  final TransformationController _controller = TransformationController();
  Size? _fitted;

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

  /// Время плетения не идёт, пока приложение не на виду.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final WeaveCubit cubit = context.read<WeaveCubit>();
    if (state == AppLifecycleState.resumed) {
      cubit.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      cubit.pause();
    }
  }

  void _setView(double scale, Offset offset) {
    _controller.value = Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Вписывает схему по ширине (не крупнее 3×) один раз на размер окна и доводит вид до текущего ряда.
  void _fit(WeaveState state, Size viewport) {
    if (_fitted == viewport) {
      return;
    }
    _fitted = viewport;
    final GridScene scene = _scene(state.pattern!);
    final double scale = math.min(3, viewport.width / scene.size.width);
    _setView(scale, Offset.zero);
    _reveal(state, viewport, force: true);
  }

  GridScene _scene(GridPattern pattern) => GridScene(
    geometry: pattern.geometry,
    metrics: pattern.metrics,
    columns: pattern.grid.width,
    rows: pattern.grid.height,
  );

  /// Двигает вид так, чтобы текущий ряд был целиком в окне; если он уже виден, вид не трогаем.
  void _reveal(WeaveState state, Size viewport, {bool force = false}) {
    if (state.cells.isEmpty) {
      return;
    }
    const double margin = 24;
    final GridScene scene = _scene(state.pattern!);
    final double scale = _controller.value.storage[0];
    final Offset shift = Offset(_controller.value.storage[12], _controller.value.storage[13]);
    final Rect rowRect = scene.cellsBounds(state.cells);
    final Rect onScreen = Rect.fromLTWH(
      rowRect.left * scale + shift.dx,
      rowRect.top * scale + shift.dy,
      rowRect.width * scale,
      rowRect.height * scale,
    );
    final Rect window = Rect.fromLTWH(0, 0, viewport.width, viewport.height).deflate(margin);
    if (!force && window.contains(onScreen.topLeft) && window.contains(onScreen.bottomRight)) {
      return;
    }
    // Ряд, который не помещается, центрируем по короткой стороне и прижимаем началом к краю по длинной.
    double dx = shift.dx;
    double dy = shift.dy;
    if (onScreen.width <= window.width) {
      dx = viewport.width / 2 - rowRect.center.dx * scale;
    } else {
      dx = margin - rowRect.left * scale;
    }
    if (onScreen.height <= window.height) {
      dy = viewport.height / 2 - rowRect.center.dy * scale;
    } else {
      dy = margin - rowRect.top * scale;
    }
    _setView(scale, Offset(dx, dy));
  }

  GridViewOptions _options(WeaveState s) {
    final CellPosition? next = s.nextBead;
    return GridViewOptions(
      showSymbols: s.showSymbols,
      showGridLines: false,
      currentRow: s.row,
      currentCell: next == null ? null : (column: next.column, row: next.row),
      doneRows: s.completedRows,
      markCurrentRowBeads: false,
      order: s.order,
      pendingCells: s.pendingBeads,
    );
  }

  @override
  Widget build(BuildContext context) {
    final WeaveCubit cubit = context.read<WeaveCubit>();
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double topInset = safe.top + _topBarHeight + _togglesHeight;
    final double bottomInset = safe.bottom + _bottomPanelHeight;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): cubit.stepForward,
        const SingleActivator(LogicalKeyboardKey.arrowRight): cubit.stepForward,
        const SingleActivator(LogicalKeyboardKey.space): cubit.stepForward,
        const SingleActivator(LogicalKeyboardKey.arrowUp): cubit.back,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): cubit.back,
      },
      child: Focus(
        autofocus: true,
        child: BlocListener<WeaveCubit, WeaveState>(
          listenWhen: (previous, current) => previous.completions != current.completions,
          listener: (context, state) => HapticFeedback.lightImpact(),
          child: BlocBuilder<WeaveCubit, WeaveState>(
            builder: (context, state) {
              final GridPattern pattern = state.pattern!;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: topInset,
                    bottom: bottomInset,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final Size viewport = Size(
                          math.max(1, constraints.maxWidth - gridRowGutter),
                          constraints.maxHeight,
                        );
                        _fit(state, viewport);
                        return BlocListener<WeaveCubit, WeaveState>(
                          listenWhen: (previous, current) => previous.row != current.row,
                          listener: (context, state) => _reveal(state, viewport),
                          child: GridPatternView(
                            grid: pattern.grid,
                            palette: pattern.palette,
                            geometry: pattern.geometry,
                            metrics: pattern.metrics,
                            options: _options(state),
                            controller: _controller,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _PanelFrame(
                      child: _TopBar(state: state, onOpenEditor: widget.onOpenEditor),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: safe.top + _topBarHeight,
                    child: _PanelFrame(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.tokens.spacing.l),
                        child: _Toggles(state: state),
                      ),
                    ),
                  ),
                  if (state.offerFinish)
                    Positioned(left: 0, right: 0, top: topInset, child: const _FinishOffer())
                  else if (state.saveFailed)
                    Positioned(left: 0, right: 0, top: topInset, child: const _SaveFailedNotice()),
                  if (state.toastRow != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottomInset + 8,
                      child: _PanelFrame(child: _Toast(row: state.toastRow! + 1)),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _PanelFrame(child: _BottomPanel(state: state)),
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

/// Верхняя панель: название, крупный счётчик «Ряд 42 из 180» (читается с расстояния) и переключатели.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, this.onOpenEditor});

  final WeaveState state;
  final VoidCallback? onOpenEditor;

  /// Быстрее этого движения пальца по счётчику — свайп, px/с.
  static const double _swipeVelocity = 200;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final WeaveCubit cubit = context.read<WeaveCubit>();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GlassBar(
              density: GlassDensity.dense,
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs, vertical: tokens.spacing.xs),
              child: Row(
                children: <Widget>[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.square(tokens.minTapTarget),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Semantics(label: l10n.weaveClose, child: const Icon(AppIcons.back)),
                  ),
                  Expanded(
                    // Свайп вверх по счётчику — дальше, вниз — назад (как прокрутка).
                    child: GestureDetector(
                      key: const ValueKey<String>('weave-swipe-area'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (details) {
                        final double velocity = details.primaryVelocity ?? 0;
                        if (velocity <= -_swipeVelocity) {
                          cubit.stepForward();
                        } else if (velocity >= _swipeVelocity) {
                          cubit.back();
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            state.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                CupertinoTheme.of(
                                  context,
                                ).textTheme.textStyle.copyWith(
                                  fontSize: 14,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.weaveRowCounter(state.rowNumber, state.rowCount),
                                key: const ValueKey<String>('weave-counter'),
                                style: tokens.counterTextStyle,
                                textScaler: tokens.counterTextScaler(MediaQuery.textScalerOf(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onOpenEditor == null)
                    SizedBox.square(dimension: tokens.minTapTarget)
                  else
                    CupertinoButton(
                      key: const ValueKey<String>('weave-edit'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.square(tokens.minTapTarget),
                      onPressed: onOpenEditor,
                      child: Semantics(label: l10n.weaveEdit, child: const Icon(AppIcons.brush)),
                    ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.xs),
            _ProgressLine(value: state.progress),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent.resolveFrom(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: CupertinoColors.systemFill.resolveFrom(context))),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0, 1),
                child: ColoredBox(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Переключатели «по ряду / по бусине» и «Aa» — над схемой, под шапкой.
class _Toggles extends StatelessWidget {
  const _Toggles({required this.state});

  final WeaveState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final WeaveCubit cubit = context.read<WeaveCubit>();
    return Row(
      children: <Widget>[
        Expanded(
          child: CupertinoSlidingSegmentedControl<WeaveMode>(
            key: const ValueKey<String>('weave-mode'),
            groupValue: state.mode,
            onValueChanged: (mode) {
              if (mode != null) {
                cubit.setMode(mode);
              }
            },
            children: <WeaveMode, Widget>{
              WeaveMode.byRow: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                child: Text(l10n.weaveModeByRow),
              ),
              WeaveMode.byBead: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                child: Text(l10n.weaveModeByBead),
              ),
            },
          ),
        ),
        SizedBox(width: tokens.spacing.s),
        CupertinoButton(
          key: const ValueKey<String>('weave-symbols'),
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: cubit.toggleSymbols,
          child: Semantics(
            label: l10n.weaveSymbols,
            toggled: state.showSymbols,
            child: Text(
              'Aa',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: state.showSymbols
                    ? tokens.accent.resolveFrom(context)
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinishOffer extends StatelessWidget {
  const _FinishOffer();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final WeaveCubit cubit = context.read<WeaveCubit>();
    return _PanelFrame(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
        child: GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.weaveFinishTitle, textAlign: TextAlign.center),
              SizedBox(height: tokens.spacing.s),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoButton.tinted(
                      key: const ValueKey<String>('weave-finish-later'),
                      onPressed: cubit.dismissFinish,
                      child: Text(l10n.weaveFinishLater),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s),
                  Expanded(
                    child: CupertinoButton.filled(
                      key: const ValueKey<String>('weave-finish-yes'),
                      onPressed: cubit.finishProject,
                      child: Text(l10n.weaveFinishYes),
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
    final AppTokensData tokens = context.tokens;
    return _PanelFrame(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
        child: GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.m),
          child: Text(
            AppLocalizations.of(context).weaveSaveFailed,
            textAlign: TextAlign.center,
            style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
          ),
        ),
      ),
    );
  }
}

/// Тост «Ряд 41 готов · Отменить» над нижней панелью.
class _Toast extends StatelessWidget {
  const _Toast({required this.row});

  final int row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
      child: GlassBar(
        key: const ValueKey<String>('weave-toast'),
        density: GlassDensity.dense,
        padding: EdgeInsets.only(left: tokens.spacing.l, right: tokens.spacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(l10n.weaveRowCompleted(row), maxLines: 1, overflow: TextOverflow.ellipsis)),
            CupertinoButton(
              key: const ValueKey<String>('weave-undo'),
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
              minimumSize: Size.square(tokens.minTapTarget),
              onPressed: context.read<WeaveCubit>().undoCompletion,
              child: Text(l10n.weaveUndo),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state});

  final WeaveState state;

  /// Высота больших кнопок: заметно выше минимальных 44 pt, под большой палец.
  static const double _buttonHeight = 64;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final WeaveCubit cubit = context.read<WeaveCubit>();
    final bool byBead = state.mode == WeaveMode.byBead;
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
              _WordChartBar(state: state),
              SizedBox(height: tokens.spacing.xs),
              Row(
                children: <Widget>[
                  CupertinoButton.tinted(
                    key: const ValueKey<String>('weave-back'),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, _buttonHeight),
                    onPressed: state.canGoBack ? cubit.back : null,
                    child: Semantics(label: l10n.weaveBack, child: const Icon(AppIcons.undo)),
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Expanded(
                    child: CupertinoButton.filled(
                      key: const ValueKey<String>('weave-next'),
                      minimumSize: const Size.fromHeight(_buttonHeight),
                      onPressed: state.allDone ? null : cubit.stepForward,
                      child: Text(byBead ? l10n.weaveNextBead : l10n.weaveRowDone, maxLines: 1),
                    ),
                  ),
                  if (byBead) ...<Widget>[
                    SizedBox(width: tokens.spacing.xs),
                    CupertinoButton.tinted(
                      key: const ValueKey<String>('weave-row-done'),
                      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                      minimumSize: const Size(112, _buttonHeight),
                      onPressed: state.allDone ? null : cubit.completeRow,
                      child: Text(l10n.weaveRowDone, maxLines: 1),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Word chart текущего ряда со стрелкой направления: «← 3 × A, 2 × B, 1 × A».
class _WordChartBar extends StatelessWidget {
  const _WordChartBar({required this.state});

  final WeaveState state;

  static const double _height = 52;

  IconData get _arrow => switch (state.direction) {
    RowDirection.right => CupertinoIcons.arrow_right,
    RowDirection.left => CupertinoIcons.arrow_left,
    RowDirection.down => CupertinoIcons.arrow_down,
    RowDirection.up => CupertinoIcons.arrow_up,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final GridPattern pattern = state.pattern!;
    final String direction = switch (state.direction) {
      RowDirection.right => l10n.weaveDirRight,
      RowDirection.left => l10n.weaveDirLeft,
      RowDirection.down => l10n.weaveDirDown,
      RowDirection.up => l10n.weaveDirUp,
    };
    return Semantics(
      label: '${l10n.weaveWordChart}: $direction',
      child: Container(
        key: const ValueKey<String>('weave-word-chart'),
        height: _height,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Row(
          children: <Widget>[
            Icon(_arrow, size: 20, color: tokens.accent.resolveFrom(context)),
            SizedBox(width: tokens.spacing.s),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final WordRun run in state.runs) ...<Widget>[
                      _RunChip(run: run, color: pattern.palette.colorAt(run.colorIndex), showSymbol: state.showSymbols),
                      SizedBox(width: tokens.spacing.s),
                    ],
                  ],
                ),
              ),
            ),
            if (state.mode == WeaveMode.byBead)
              Semantics(
                label: l10n.weaveBeadProgress(state.laid, state.beadCount),
                child: ExcludeSemantics(
                  child: Text(
                    '${state.laid}/${state.beadCount}',
                    style: tokens.counterTextStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunChip extends StatelessWidget {
  const _RunChip({required this.run, required this.color, required this.showSymbol});

  final WordRun run;
  final PatternColor? color;
  final bool showSymbol;

  @override
  Widget build(BuildContext context) {
    final PatternColor? c = color;
    final Color fill = c == null ? CupertinoColors.systemGrey : Color.fromARGB(255, c.rgb.r, c.rgb.g, c.rgb.b);
    final Color ink = fill.computeLuminance() > 0.5 ? const Color(0xFF151316) : const Color(0xFFFFFFFF);
    final String? symbol = c?.symbol;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${run.count} ×', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x40000000)),
          ),
          child: showSymbol && symbol != null
              ? Text(
                  symbol,
                  style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700),
                )
              : null,
        ),
      ],
    );
  }
}

/// Панели управления: крупный шрифт системы ограничен 1,4×, а на широком окне macOS панель не шире 520 pt.
class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});

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
