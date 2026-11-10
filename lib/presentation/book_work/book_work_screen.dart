import 'dart:async';

import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_sheets.dart';
import 'package:beading/presentation/book_work/book_work_state.dart';
import 'package:beading/presentation/book_work/page_canvas.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Работа по схеме из книги: страница на весь экран с зумом до 8×, линейка текущего ряда и крупные кнопки под большой
/// палец. [BookWorkCubit] берётся из контекста; экран сам вызывает `load()` только если его создал маршрут.
class BookWorkScreen extends StatelessWidget {
  const BookWorkScreen({required this.files, super.key});

  static const String routePath = '/book/:projectId';

  static String locationFor(String projectId) => '/book/$projectId';

  /// Предел зума: на таком масштабе различима отдельная бусина на фото страницы.
  static const double maxZoom = 8;

  final FileStore files;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      // Клавиатура листа заметок не должна менять размер страницы под ним.
      resizeToAvoidBottomInset: false,
      child: BlocBuilder<BookWorkCubit, BookWorkState>(
        buildWhen: (previous, current) => previous.status != current.status,
        builder: (context, state) => switch (state.status) {
          BookWorkStatus.loading => const Center(child: CupertinoActivityIndicator()),
          BookWorkStatus.failed => const _LoadFailed(),
          BookWorkStatus.ready => _Workspace(files: files),
        },
      ),
    );
  }
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
            child: Text(l10n.bookWorkLoadFailed, textAlign: TextAlign.center),
          ),
          CupertinoButton.filled(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.bookWorkClose)),
        ],
      ),
    );
  }
}

/// Высоты панелей поверх страницы: по ним подстраивается вид, чтобы линейка не пряталась под ними.
const double _topBarHeight = 60;
const double _bottomPanelHeight = 160;

class _Workspace extends StatefulWidget {
  const _Workspace({required this.files});

  final FileStore files;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  final TransformationController _controller = TransformationController();
  String? _shownPageId;
  Size? _shownSize;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_viewChanged);
  }

  /// Инерция жеста идёт и после `onInteractionEnd`: запоминаем вид, когда он успокоился.
  void _viewChanged() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        context.read<BookWorkCubit>().setViewport(_viewportNow);
      }
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    _controller.dispose();
    super.dispose();
  }

  PageViewport get _viewportNow {
    final List<double> m = _controller.value.storage;
    return PageViewport(scale: m[0], dx: m[12], dy: m[13]);
  }

  void _show(PageViewport viewport) {
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, viewport.scale)
      ..setEntry(1, 1, viewport.scale)
      ..setEntry(0, 3, viewport.dx)
      ..setEntry(1, 3, viewport.dy);
  }

  /// Вид, в котором линейка видна между панелями.
  PageViewport _revealed(BookWorkState state, PageViewport from, Size view, EdgeInsets safe) {
    final double k = view.width / state.page.width;
    final RulerState ruler = state.work.ruler;
    return from.revealing(
      rulerTop: ruler.top * k,
      rulerBottom: ruler.bottom * k,
      viewHeight: view.height,
      contentHeight: state.page.height * k,
      topInset: safe.top + _topBarHeight,
      bottomInset: safe.bottom + _bottomPanelHeight,
    );
  }

  /// Открывает страницу: запомненный вид (или вид по умолчанию под верхней панелью) и линейка в поле зрения.
  void _syncPage(BookWorkState state, Size view, EdgeInsets safe) {
    if (_shownPageId == state.page.id && _shownSize == view) {
      return;
    }
    final Size? previous = _shownSize;
    final bool resizedOnly = _shownPageId == state.page.id && previous != null && previous.width > 0;
    _shownPageId = state.page.id;
    _shownSize = view;
    if (resizedOnly) {
      // Окно изменили: страница вписана по ширине, поэтому сдвиг масштабируется вместе с ней.
      // Запись отложена до следующего жеста, а не на каждый кадр ресайза.
      final double ratio = view.width / previous.width;
      final PageViewport now = _viewportNow;
      final PageViewport scaled = _revealed(
        state,
        PageViewport(scale: now.scale, dx: now.dx * ratio, dy: now.dy * ratio),
        view,
        safe,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _show(scaled);
        }
      });
      return;
    }
    final PageViewport stored = state.work.viewport;
    final PageViewport start = stored == PageViewport.identity
        ? PageViewport(scale: 1, dx: 0, dy: safe.top + _topBarHeight)
        : stored;
    final PageViewport fitted = _revealed(state, start, view, safe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _show(fitted);
      context.read<BookWorkCubit>().setViewport(fitted);
    });
  }

  void _followRuler(BookWorkState state, Size view, EdgeInsets safe) {
    final PageViewport now = _viewportNow;
    final PageViewport next = _revealed(state, now, view, safe);
    if (next != now) {
      _show(next);
    }
    context.read<BookWorkCubit>().setViewport(next);
  }

  @override
  Widget build(BuildContext context) {
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): cubit.nextRow,
        const SingleActivator(LogicalKeyboardKey.arrowUp): cubit.previousRow,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size view = constraints.biggest;
            return BlocListener<BookWorkCubit, BookWorkState>(
              // Линейка ушла со своего места на той же странице: ведём за ней вид.
              listenWhen: (previous, current) =>
                  previous.isReady &&
                  previous.page.id == current.page.id &&
                  (previous.work.ruler.top != current.work.ruler.top ||
                      previous.work.ruler.height != current.work.ruler.height),
              listener: (context, state) => _followRuler(state, view, safe),
              child: BlocBuilder<BookWorkCubit, BookWorkState>(
                builder: (context, state) {
                  _syncPage(state, view, safe);
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _controller,
                          constrained: false,
                          alignment: Alignment.topLeft,
                          minScale: 1,
                          maxScale: BookWorkScreen.maxZoom,
                          boundaryMargin: EdgeInsets.fromLTRB(
                            0,
                            safe.top + _topBarHeight,
                            0,
                            safe.bottom + _bottomPanelHeight,
                          ),
                          onInteractionEnd: (_) => cubit.setViewport(_viewportNow),
                          child: PageCanvas(
                            key: ValueKey<String>('canvas-${state.page.id}'),
                            files: widget.files,
                            page: state.page,
                            ruler: state.work.ruler,
                            width: view.width,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: _PanelFrame(child: _TopBar(state: state)),
                      ),
                      if (state.saveFailed)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: safe.top + _topBarHeight,
                          child: const _SaveFailedNotice(),
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
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final BookWorkState state;

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
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs),
          child: Row(
            children: <Widget>[
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: () => Navigator.of(context).maybePop(),
                child: Semantics(label: l10n.bookWorkClose, child: const Icon(AppIcons.back)),
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
              if (state.pages.length > 1)
                CupertinoButton(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                  minimumSize: Size.square(tokens.minTapTarget),
                  onPressed: () => showPagesSheet(context, context.read<BookWorkCubit>()),
                  child: Text(l10n.bookWorkPageLabel(state.pageIndex + 1, state.pages.length)),
                )
              else
                SizedBox.square(dimension: tokens.minTapTarget),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
      child: GlassPanel(
        density: GlassDensity.dense,
        padding: EdgeInsets.all(tokens.spacing.m),
        child: Text(
          AppLocalizations.of(context).bookWorkSaveFailed,
          textAlign: TextAlign.center,
          style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.state});

  final BookWorkState state;

  /// Быстрее этого движения пальца по номеру ряда — свайп, px/с.
  static const double _swipeVelocity = 200;

  /// Высота больших кнопок ряда: заметно выше минимальных 44 pt, под большой палец.
  static const double _rowButtonHeight = 56;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
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
                    // Свайп вверх по номеру — следующий ряд, вниз — назад (как прокрутка).
                    child: GestureDetector(
                      key: const ValueKey<String>('row-swipe-area'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (details) {
                        final double velocity = details.primaryVelocity ?? 0;
                        if (velocity <= -_swipeVelocity) {
                          cubit.nextRow();
                        } else if (velocity >= _swipeVelocity) {
                          cubit.previousRow();
                        }
                      },
                      child: Semantics(
                        liveRegion: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: tokens.minTapTarget),
                          child: Center(
                            child: Text(
                              l10n.bookWorkRow(state.work.ruler.row),
                              style: CupertinoTheme.of(
                                context,
                              ).textTheme.navLargeTitleTextStyle.merge(tokens.counterTextStyle).copyWith(fontSize: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _IconAction(
                    icon: AppIcons.rulerSettings,
                    label: l10n.bookWorkRulerSettings,
                    onPressed: () => showRulerSettingsSheet(context, cubit),
                  ),
                  _IconAction(
                    icon: AppIcons.notes,
                    label: l10n.bookWorkNotes,
                    onPressed: () => showNotesSheet(context, cubit),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.s),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CupertinoButton.tinted(
                      key: const ValueKey<String>('previous-row'),
                      minimumSize: const Size.fromHeight(_rowButtonHeight),
                      onPressed: state.canMoveUp ? cubit.previousRow : null,
                      child: _ButtonLabel(icon: AppIcons.rowUp, text: l10n.bookWorkPrevRow),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s),
                  Expanded(
                    child: CupertinoButton.filled(
                      key: const ValueKey<String>('next-row'),
                      minimumSize: const Size.fromHeight(_rowButtonHeight),
                      onPressed: state.canMoveDown ? cubit.nextRow : null,
                      child: _ButtonLabel(icon: AppIcons.rowDown, text: l10n.bookWorkNextRow),
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

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 20),
      SizedBox(width: context.tokens.spacing.xs),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
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

/// Панели управления: крупный шрифт системы ограничен 1,4×, чтобы панель не вырастала выше отведённых под неё
/// [_topBarHeight] и [_bottomPanelHeight], а на широком окне macOS панель не шире 520 pt.
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
