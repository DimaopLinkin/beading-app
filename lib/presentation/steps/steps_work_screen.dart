import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/steps/step_widgets.dart';
import 'package:beading/presentation/steps/steps_list_sheet.dart';
import 'package:beading/presentation/steps/steps_work_cubit.dart';
import 'package:beading/presentation/steps/steps_work_state.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:beading/presentation/widgets/measured_size.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Инструкция в работе: крупный шаг (фото, текст, бусины), «Готово, дальше» под большим пальцем.
/// [StepsWorkCubit] берётся из контекста.
class StepsWorkScreen extends StatelessWidget {
  const StepsWorkScreen({required this.files, this.onOpenStats, super.key});

  final FileStore files;
  final VoidCallback? onOpenStats;

  static const String routePath = '/steps/:projectId';

  static String locationFor(String projectId) => '/steps/$projectId';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground,
    child: BlocBuilder<StepsWorkCubit, StepsWorkState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) => switch (state.status) {
        StepsWorkStatus.loading => const Center(child: CupertinoActivityIndicator()),
        StepsWorkStatus.failed => const _LoadFailed(),
        StepsWorkStatus.ready => _Workspace(files: files, onOpenStats: onOpenStats),
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
            child: Text(l10n.stepsLoadFailed, textAlign: TextAlign.center),
          ),
          CupertinoButton.filled(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.stepsClose)),
        ],
      ),
    );
  }
}

class _Workspace extends StatefulWidget {
  const _Workspace({required this.files, this.onOpenStats});

  final FileStore files;
  final VoidCallback? onOpenStats;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> with WidgetsBindingObserver {
  static const double _topBarHeight = 96;
  static const double _bottomPanelHeight = 150;

  double? _panelHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Время работы не идёт, пока приложение не на виду.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final StepsWorkCubit cubit = context.read<StepsWorkCubit>();
    if (state == AppLifecycleState.resumed) {
      cubit.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      cubit.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final StepsWorkCubit cubit = context.read<StepsWorkCubit>();
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): cubit.next,
        const SingleActivator(LogicalKeyboardKey.space): cubit.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): cubit.back,
      },
      child: Focus(
        autofocus: true,
        child: BlocConsumer<StepsWorkCubit, StepsWorkState>(
          listenWhen: (previous, current) => previous.progress != current.progress,
          listener: (context, state) => HapticFeedback.lightImpact(),
          builder: (context, state) => Stack(
            children: <Widget>[
              Positioned.fill(
                child: _StepBody(
                  state: state,
                  files: widget.files,
                  topInset: safe.top + _topBarHeight,
                  bottomInset: _panelHeight ?? safe.bottom + _bottomPanelHeight,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _PanelFrame(
                  child: _TopBar(state: state, onOpenStats: widget.onOpenStats),
                ),
              ),
              if (state.saveFailed)
                Positioned(
                  left: 0,
                  right: 0,
                  top: safe.top + _topBarHeight,
                  child: const _PanelFrame(child: _SaveFailedNotice()),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MeasuredHeight(
                  onChange: (height) {
                    if (mounted && _panelHeight != height) {
                      setState(() => _panelHeight = height);
                    }
                  },
                  child: _PanelFrame(child: _BottomPanel(state: state)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Панели на стекле не шире 520 pt (iPad, Mac) и не растут с крупным шрифтом дальше 1.4×.
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, this.onOpenStats});

  final StepsWorkState state;
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsWorkCubit cubit = context.read<StepsWorkCubit>();
    final StepSection? section = state.section;
    String? subtitle;
    if (state.isReady && section != null) {
      final (int n, int total) = state.sectionNumber;
      subtitle = section.title.isEmpty
          ? l10n.stepsSectionOf(n, total)
          : l10n.stepsSectionTitled(n, total, section.title);
    }
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
                    child: Semantics(label: l10n.stepsClose, child: const Icon(AppIcons.back)),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          state.projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.headline,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            key: const ValueKey<String>('steps-section'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.caption.copyWith(
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onOpenStats != null)
                    CupertinoButton(
                      key: const ValueKey<String>('steps-stats'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.square(tokens.minTapTarget),
                      onPressed: onOpenStats,
                      child: Semantics(label: l10n.stepsStatsSemantic, child: const Icon(AppIcons.timer)),
                    ),
                  CupertinoButton(
                    key: const ValueKey<String>('steps-list'),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.square(tokens.minTapTarget),
                    onPressed: state.isEmpty ? null : () => showStepsListSheet(context, cubit),
                    child: Semantics(label: l10n.stepsList, child: const Icon(CupertinoIcons.list_bullet)),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.xs),
            _ProgressLine(value: state.fraction),
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
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: <Widget>[
            ColoredBox(color: CupertinoColors.systemFill.resolveFrom(context), child: const SizedBox.expand()),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: ColoredBox(color: context.tokens.accent.resolveFrom(context), child: const SizedBox.expand()),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SaveFailedNotice extends StatelessWidget {
  const _SaveFailedNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.tokens.spacing.l),
    child: Text(
      AppLocalizations.of(context).stepsSaveFailed,
      key: const ValueKey<String>('steps-save-failed'),
      style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context), fontSize: 14),
    ),
  );
}

/// Прокручиваемая область шага. Свайп по ней — вперёд и назад, как кнопки внизу.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.state, required this.files, required this.topInset, required this.bottomInset});

  final StepsWorkState state;
  final FileStore files;
  final double topInset;
  final double bottomInset;

  /// Быстрее этого движения пальца по горизонтали — свайп, px/с.
  static const double _swipeVelocity = 300;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsWorkCubit cubit = context.read<StepsWorkCubit>();
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      tokens.spacing.l,
      topInset + tokens.spacing.m,
      tokens.spacing.l,
      bottomInset + tokens.spacing.m,
    );
    if (state.isEmpty || state.step == null) {
      return Padding(
        padding: padding,
        child: Center(
          child: Text(l10n.stepsEmpty, textAlign: TextAlign.center, style: tokens.typography.body),
        ),
      );
    }
    final StepPattern pattern = state.pattern!;
    final InstructionStep step = state.step!;
    final StepSection section = state.section!;
    final List<StepImage> images = <StepImage>[
      for (final String id in step.imageIds)
        for (final StepImage image in pattern.images)
          if (image.id == id) image,
    ];
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final double v = details.primaryVelocity ?? 0;
        if (v <= -_swipeVelocity) {
          cubit.next();
        } else if (v >= _swipeVelocity) {
          cubit.back();
        }
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.stepsStepOf(state.stepNumber, state.totalSteps),
                    key: const ValueKey<String>('steps-counter'),
                    style: tokens.counterTextStyle,
                    textScaler: tokens.counterTextScaler(MediaQuery.textScalerOf(context)),
                  ),
                ),
                if (!section.repeat.isUntilDone && section.repeat.passes > 1 || section.repeat.isUntilDone)
                  _RepeatLine(repeat: section.repeat, pass: state.progress!.sectionPass),
                if (step.repeat.isUntilDone || step.repeat.passes > 1)
                  _RepeatLine(repeat: step.repeat, pass: state.progress!.stepPass),
                SizedBox(height: tokens.spacing.m),
                if (images.isNotEmpty) ...<Widget>[
                  StepImagesPager(files: files, images: images),
                  SizedBox(height: tokens.spacing.m),
                ],
                if (step.text.isNotEmpty)
                  Text(step.text, key: const ValueKey<String>('steps-text'), style: tokens.typography.title2)
                else if (images.isEmpty && step.beads.isEmpty)
                  Text(l10n.stepsNoText, style: tokens.typography.body),
                if (step.beads.isNotEmpty) ...<Widget>[
                  SizedBox(height: tokens.spacing.m),
                  Wrap(
                    spacing: tokens.spacing.s,
                    runSpacing: tokens.spacing.s,
                    children: <Widget>[
                      for (final StepBead b in step.beads) BeadChip(bead: b, palette: pattern.palette),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «повтор 4 из 10» с сегментами; у «до нужной длины» — «4-й повтор» без общего числа.
class _RepeatLine extends StatelessWidget {
  const _RepeatLine({required this.repeat, required this.pass});

  final Repeat repeat;
  final int pass;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            repeat.isUntilDone ? l10n.stepsRepeatOpen(pass) : l10n.stepsRepeatOf(pass, repeat.passes),
            key: const ValueKey<String>('steps-repeat'),
            style: tokens.typography.callout.copyWith(color: tokens.colors.accentText.resolveFrom(context)),
          ),
          if (!repeat.isUntilDone) ...<Widget>[
            SizedBox(height: tokens.spacing.xs),
            RepeatSegments(pass: pass, total: repeat.passes),
          ],
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state});

  final StepsWorkState state;

  /// Кнопки заметно выше минимальных 44 pt: работа идёт мокрыми от бусин пальцами.
  static const double _buttonHeight = 64;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StepsWorkCubit cubit = context.read<StepsWorkCubit>();
    final bool last = state.isLastStep;
    final Widget back = CupertinoButton.tinted(
      key: const ValueKey<String>('steps-back'),
      minimumSize: const Size(112, _buttonHeight),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
      onPressed: state.isEmpty || state.isAtStart ? null : cubit.back,
      child: Text(l10n.stepsBack, maxLines: 1),
    );
    final Widget enough = CupertinoButton.tinted(
      key: const ValueKey<String>('steps-enough'),
      minimumSize: const Size(112, _buttonHeight),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
      onPressed: cubit.skipRepeat,
      child: Text(l10n.stepsEnough, maxLines: 1),
    );
    Widget main;
    if (state.finished) {
      main = Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
          child: Text(
            l10n.stepsWorkDone,
            key: const ValueKey<String>('steps-work-done'),
            style: tokens.typography.headline,
          ),
        ),
      );
    } else if (last) {
      main = CupertinoButton.filled(
        key: const ValueKey<String>('steps-finish'),
        minimumSize: const Size.fromHeight(_buttonHeight),
        onPressed: cubit.finishWork,
        child: Text(l10n.stepsFinishWork, maxLines: 2, textAlign: TextAlign.center),
      );
    } else {
      main = CupertinoButton.filled(
        key: const ValueKey<String>('steps-next'),
        minimumSize: const Size.fromHeight(_buttonHeight),
        onPressed: state.isEmpty ? null : cubit.next,
        child: Text(l10n.stepsNext, maxLines: 1),
      );
    }
    final bool twoRows = last || state.finished;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s),
        child: GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.s),
          child: twoRows
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    main,
                    SizedBox(height: tokens.spacing.xs),
                    Row(
                      children: <Widget>[
                        Expanded(child: back),
                        if (state.canSkipRepeat) ...<Widget>[
                          SizedBox(width: tokens.spacing.xs),
                          Expanded(child: enough),
                        ],
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (state.canSkipRepeat) ...<Widget>[enough, SizedBox(height: tokens.spacing.xs)],
                    Row(
                      children: <Widget>[
                        back,
                        SizedBox(width: tokens.spacing.xs),
                        Expanded(child: main),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
