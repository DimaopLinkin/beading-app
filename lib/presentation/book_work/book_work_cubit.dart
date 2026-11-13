import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/record_book_progress.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/domain/image_pattern/image_pattern_repository.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:beading/domain/projects/use_cases/update_notes.dart';
import 'package:beading/presentation/book_work/book_work_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Работа по схеме из книги: линейка, страницы, вид и заметки.
///
/// Изменения применяются сразу, а на диск пишутся с задержкой [saveDelay] (debounce) и обязательно при закрытии,
/// чтобы быстрые сдвиги не превращались в запись на каждый тап.
class BookWorkCubit extends Cubit<BookWorkState> {
  BookWorkCubit({
    required String projectId,
    required ProjectRepository projects,
    required ImagePatternRepository patterns,
    required BookWorkRepository work,
    required RecordBookProgress recordProgress,
    required UpdateNotes updateNotes,
    this.saveDelay = const Duration(milliseconds: 250),
  }) : _projectId = projectId,
       _projects = projects,
       _patterns = patterns,
       _work = work,
       _recordProgress = recordProgress,
       _updateNotes = updateNotes,
       super(const BookWorkState());

  /// Не больше 300 мс по плану: дольше пользовательница рискует потерять сдвиг при вылете.
  final Duration saveDelay;

  final String _projectId;
  final ProjectRepository _projects;
  final ImagePatternRepository _patterns;
  final BookWorkRepository _work;
  final RecordBookProgress _recordProgress;
  final UpdateNotes _updateNotes;

  String? _patternId;
  final Set<String> _dirtyPages = <String>{};
  bool _currentPageDirty = false;
  bool _progressDirty = false;
  String? _dirtyNotes;
  Timer? _timer;
  int _retries = 0;
  static const int _maxRetries = 4;
  Future<void> _flushing = Future<void>.value();

  Future<void> load() async {
    final Result<Project> project = await _projects.get(_projectId);
    final Result<ImagePattern> pattern = await _patterns.getByProject(_projectId);
    if (isClosed) {
      return;
    }
    if (project.isFailure || pattern.isFailure) {
      emit(state.copyWith(status: BookWorkStatus.failed));
      return;
    }
    final ImagePattern found = pattern.valueOrNull!;
    if (found.pages.isEmpty) {
      emit(state.copyWith(status: BookWorkStatus.failed));
      return;
    }
    final Result<BookWork> saved = await _work.load(found.id);
    if (isClosed) {
      return;
    }
    if (saved case Err<BookWork>()) {
      emit(state.copyWith(status: BookWorkStatus.failed));
      return;
    }
    final BookWork restored = saved.valueOrNull!;
    _patternId = found.id;
    final int index = found.pages.indexWhere((p) => p.id == restored.currentPageId);
    emit(
      BookWorkState(
        status: BookWorkStatus.ready,
        projectName: project.valueOrNull!.name,
        notes: project.valueOrNull!.notes,
        pages: found.pages,
        pageIndex: index < 0 ? 0 : index,
        works: <String, PageWork>{
          for (final ImagePatternPage page in found.pages) page.id: _restoredWork(page, restored.pages[page.id]),
        },
      ),
    );
  }

  PageWork _restoredWork(ImagePatternPage page, PageWork? saved) {
    final double height = page.height.toDouble();
    if (saved == null) {
      return PageWork(pageId: page.id, ruler: RulerState.initial(height));
    }
    return saved.copyWith(ruler: saved.ruler.fit(height, imageWidth: page.width.toDouble()));
  }

  /// Следующий ряд: линейка на шаг по направлению рядов. Если сдвинуться некуда, ничего не происходит.
  void nextRow() {
    if (!state.isReady) {
      return;
    }
    final RulerState before = state.work.ruler;
    _applyRuler(before.next(state.page.height.toDouble()), progress: true, undoTo: before);
  }

  /// Предыдущий ряд.
  void previousRow() {
    if (!state.isReady) {
      return;
    }
    final RulerState before = state.work.ruler;
    _applyRuler(before.previous(state.page.height.toDouble()), progress: true, undoTo: before);
  }

  /// Возвращает линейку на место до последнего сдвига.
  void undoRow() {
    final RulerState? back = state.undoRuler;
    if (!state.isReady || back == null) {
      return;
    }
    _applyRuler(back, progress: false);
    emit(state.copyWith(clearUndo: true));
  }

  /// Убирает подсказку «Отменить» (например, по таймеру).
  void dismissUndo() {
    if (state.undoRuler != null) {
      emit(state.copyWith(clearUndo: true));
    }
  }

  /// Страница закончена: открыть следующую страницу схемы, если она есть.
  void nextPage() => selectPage(state.pageIndex + 1);

  void setPanelCollapsed({required bool collapsed}) {
    if (collapsed != state.panelCollapsed) {
      emit(state.copyWith(panelCollapsed: collapsed));
    }
  }

  /// Направление рядов: у текущей страницы и у тех, где ещё не начали работу.
  void setDirection(RowDirection value) {
    if (!state.isReady) {
      return;
    }
    final Map<String, PageWork> next = <String, PageWork>{};
    for (final ImagePatternPage page in state.pages) {
      final PageWork work = state.works[page.id]!;
      final bool apply = page.id == state.page.id || work.ruler.row == 1;
      next[page.id] = apply ? work.copyWith(ruler: work.ruler.withDirection(value, page.height.toDouble())) : work;
      if (next[page.id] != work) {
        _dirtyPages.add(page.id);
      }
    }
    emit(state.copyWith(works: next, clearUndo: true));
    _schedule();
  }

  /// Начинает выбор границ схемы: зона по умолчанию — вся страница, ручки двигают её края.
  // --- Маркер (T45) ---

  /// Сколько шагов «Отменить» помним: пометки живут в памяти целиком, поэтому предел небольшой.
  static const int _maxMarkupHistory = 30;

  /// Точки ближе этого (доля ширины страницы) в мазок не попадают: файл меньше, линия та же.
  static const double _minPointGap = 0.0008;

  PageMarkup? _eraseSnapshot;

  void startMarker() {
    if (!state.isReady || state.markerEditing) {
      return;
    }
    emit(
      state.copyWith(
        markerEditing: true,
        zoneEditing: false,
        showMarkup: true,
        markerEraser: false,
        markupUndo: const <PageMarkup>[],
        markupRedo: const <PageMarkup>[],
        clearUndo: true,
      ),
    );
  }

  void finishMarker() {
    if (state.markerEditing) {
      emit(state.copyWith(markerEditing: false));
    }
  }

  void setMarkerColor(int index) {
    if (index >= 0 && index < MarkerPalette.colors.length) {
      emit(state.copyWith(markerColor: index, markerEraser: false));
    }
  }

  void setMarkerWidth(int index) {
    if (index >= 0 && index < MarkerPalette.widths.length) {
      emit(state.copyWith(markerWidth: index));
    }
  }

  void setMarkerEraser({required bool eraser}) {
    if (eraser != state.markerEraser) {
      emit(state.copyWith(markerEraser: eraser));
    }
  }

  void toggleShowMarkup() => emit(state.copyWith(showMarkup: !state.showMarkup));

  /// Мазок закончен: [points] — пары `x, y` в долях ширины страницы.
  void addStroke(List<double> points) {
    if (!state.isReady || points.length < 2) {
      return;
    }
    final List<double> kept = <double>[points[0], points[1]];
    for (int i = 2; i + 1 < points.length; i += 2) {
      final double dx = points[i] - kept[kept.length - 2];
      final double dy = points[i + 1] - kept[kept.length - 1];
      final bool last = i + 3 >= points.length;
      if (last || dx * dx + dy * dy >= _minPointGap * _minPointGap) {
        kept
          ..add(points[i])
          ..add(points[i + 1]);
      }
    }
    _changeMarkup(
      state.work.markup.withStroke(
        MarkerStroke(
          rgb: MarkerPalette.colors[state.markerColor],
          width: MarkerPalette.widths[state.markerWidth],
          points: kept,
        ),
      ),
    );
  }

  /// Начало жеста ластика: до его конца всё стёртое считается одним шагом «Отменить».
  void beginErase() => _eraseSnapshot = state.isReady ? state.work.markup : null;

  /// Стирает мазки, которых касаются [points] кругом ластика (радиус от толщины маркера).
  void eraseAlong(List<double> points) {
    if (!state.isReady) {
      return;
    }
    final PageMarkup before = state.work.markup;
    final PageMarkup after = before.erasing(
      points,
      MarkerPalette.widths[state.markerWidth] * MarkerPalette.eraserScale,
    );
    if (!identical(after, before)) {
      _replaceWork(state.work.copyWith(markup: after));
    }
  }

  void endErase() {
    final PageMarkup? snapshot = _eraseSnapshot;
    _eraseSnapshot = null;
    if (snapshot != null && state.isReady && !identical(snapshot, state.work.markup)) {
      emit(state.copyWith(markupUndo: _pushed(state.markupUndo, snapshot), markupRedo: const <PageMarkup>[]));
    }
  }

  void undoMarkup() {
    if (!state.isReady || !state.canUndoMarkup) {
      return;
    }
    final PageMarkup previous = state.markupUndo.last;
    final PageMarkup current = state.work.markup;
    _replaceWork(state.work.copyWith(markup: previous));
    emit(
      state.copyWith(
        markupUndo: state.markupUndo.sublist(0, state.markupUndo.length - 1),
        markupRedo: _pushed(state.markupRedo, current),
      ),
    );
  }

  void redoMarkup() {
    if (!state.isReady || !state.canRedoMarkup) {
      return;
    }
    final PageMarkup next = state.markupRedo.last;
    final PageMarkup current = state.work.markup;
    _replaceWork(state.work.copyWith(markup: next));
    emit(
      state.copyWith(
        markupRedo: state.markupRedo.sublist(0, state.markupRedo.length - 1),
        markupUndo: _pushed(state.markupUndo, current),
      ),
    );
  }

  /// «Очистить страницу»: пометки уходят, но «Отменить» их возвращает.
  void clearMarkup() {
    if (state.isReady && !state.work.markup.isEmpty) {
      _changeMarkup(const PageMarkup.empty());
    }
  }

  void _changeMarkup(PageMarkup next) {
    final PageMarkup before = state.work.markup;
    _replaceWork(state.work.copyWith(markup: next));
    emit(state.copyWith(markupUndo: _pushed(state.markupUndo, before), markupRedo: const <PageMarkup>[]));
  }

  static List<PageMarkup> _pushed(List<PageMarkup> stack, PageMarkup entry) {
    final List<PageMarkup> next = <PageMarkup>[...stack, entry];
    return next.length > _maxMarkupHistory ? next.sublist(next.length - _maxMarkupHistory) : next;
  }

  void startZoneEditing() {
    if (!state.isReady || state.zoneEditing) {
      return;
    }
    if (state.work.ruler.zone == null) {
      setZone(PatternZone.full(state.page.width.toDouble(), state.page.height.toDouble()));
    }
    emit(state.copyWith(zoneEditing: true, markerEditing: false, clearUndo: true));
  }

  void finishZoneEditing() {
    if (state.zoneEditing) {
      emit(state.copyWith(zoneEditing: false));
    }
  }

  /// Границы схемы на текущей странице. На первом ряду линейка встаёт к началу зоны.
  void setZone(PatternZone zone) => _applyRuler(
    state.work.ruler.withZone(zone, state.page.height.toDouble(), imageWidth: state.page.width.toDouble()),
    progress: false,
  );

  /// Схема на всю страницу: зона и число рядов снимаются.
  void resetZone() {
    _applyRuler(state.work.ruler.withoutZone(state.page.height.toDouble()), progress: false);
    finishZoneEditing();
  }

  /// Сколько рядов в зоне: высота и шаг считаются сами. `null` — задавать вручную.
  void setRowCount(int? count) =>
      _applyRuler(state.work.ruler.withRowCount(count, state.page.height.toDouble()), progress: false);

  void setRulerHeight(double value) =>
      _applyRuler(state.work.ruler.withHeight(value, state.page.height.toDouble()), progress: false);

  void setRulerStep(double value) =>
      _applyRuler(state.work.ruler.withStep(value, state.page.height.toDouble()), progress: false);

  void setHighlight(RulerHighlight value) => _applyRuler(state.work.ruler.withHighlight(value), progress: false);

  /// Запоминает зум и сдвиг текущей страницы.
  void setViewport(PageViewport viewport) {
    if (!state.isReady || viewport == state.work.viewport) {
      return;
    }
    _replaceWork(state.work.copyWith(viewport: viewport));
  }

  /// Открывает страницу по номеру с нуля; номер запоминается.
  void selectPage(int index) {
    if (!state.isReady || index < 0 || index >= state.pages.length || index == state.pageIndex) {
      return;
    }
    _currentPageDirty = true;
    emit(
      state.copyWith(
        pageIndex: index,
        clearUndo: true,
        markupUndo: const <PageMarkup>[],
        markupRedo: const <PageMarkup>[],
      ),
    );
    _schedule();
  }

  void updateNotes(String text) {
    if (!state.isReady || text == state.notes) {
      return;
    }
    _dirtyNotes = text;
    emit(state.copyWith(notes: text));
    _schedule();
  }

  void _applyRuler(RulerState ruler, {required bool progress, RulerState? undoTo}) {
    if (!state.isReady || ruler == state.work.ruler) {
      return;
    }
    _progressDirty = _progressDirty || progress;
    _replaceWork(state.work.copyWith(ruler: ruler), undoTo: undoTo);
  }

  void _replaceWork(PageWork work, {RulerState? undoTo}) {
    _dirtyPages.add(work.pageId);
    emit(
      state.copyWith(
        works: <String, PageWork>{...state.works, work.pageId: work},
        undoRuler: undoTo,
        clearUndo: undoTo == null && state.undoRuler != null && work.ruler != state.work.ruler,
      ),
    );
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(saveDelay, () => unawaited(flush()));
  }

  /// Записывает всё, что ещё не записано. Записи идут по очереди.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _flushing = _flushing.then((_) => _writePending()).catchError((Object _) => _markFailed());
  }

  /// Непредвиденное исключение не должно ломать очередь записей: показываем сбой, повторим позже.
  void _markFailed() {
    if (!isClosed && !state.saveFailed) {
      emit(state.copyWith(saveFailed: true));
    }
  }

  Future<void> _writePending() async {
    final Set<String> pages = <String>{..._dirtyPages};
    final bool currentPage = _currentPageDirty;
    final bool progress = _progressDirty;
    final String? notes = _dirtyNotes;
    _dirtyPages.clear();
    _currentPageDirty = false;
    _progressDirty = false;
    _dirtyNotes = null;
    final String? patternId = _patternId;
    if (patternId == null || (pages.isEmpty && !currentPage && !progress && notes == null)) {
      return;
    }
    bool failed = false;
    // Не записанное возвращаем в очередь: оно уйдёт со следующей записью.
    for (final String id in pages) {
      if ((await _work.savePage(state.works[id]!)).isFailure) {
        failed = true;
        _dirtyPages.add(id);
      }
    }
    if (currentPage && (await _work.saveCurrentPage(patternId: patternId, pageId: state.page.id)).isFailure) {
      failed = true;
      _currentPageDirty = true;
    }
    if (progress && (await _recordProgress(_projectId)).isFailure) {
      failed = true;
      _progressDirty = true;
    }
    if (notes != null && (await _updateNotes(_projectId, notes)).isFailure) {
      failed = true;
      _dirtyNotes ??= notes;
    }
    if (!isClosed && failed != state.saveFailed) {
      emit(state.copyWith(saveFailed: failed));
    }
    if (failed && !isClosed && _retries < _maxRetries) {
      // Диск мог быть занят временно: пробуем ещё, пока она не закрыла экран.
      _retries++;
      _timer = Timer(saveDelay * (1 << _retries), () => unawaited(flush()));
    } else if (!failed) {
      _retries = 0;
    }
  }

  @override
  Future<void> close() async {
    try {
      await flush();
    } finally {
      await super.close();
    }
  }
}
