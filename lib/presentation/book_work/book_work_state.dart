import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:equatable/equatable.dart';

enum BookWorkStatus { loading, ready, failed }

/// Экран работы по схеме из книги: страницы, линейка и вид каждой страницы, заметки.
class BookWorkState extends Equatable {
  const BookWorkState({
    this.status = BookWorkStatus.loading,
    this.projectName = '',
    this.notes = '',
    this.pages = const <ImagePatternPage>[],
    this.pageIndex = 0,
    this.works = const <String, PageWork>{},
    this.saveFailed = false,
    this.panelCollapsed = false,
    this.undoRuler,
    this.zoneEditing = false,
    this.markerEditing = false,
    this.markerColor = 0,
    this.markerWidth = 1,
    this.markerEraser = false,
    this.showMarkup = true,
    this.markupUndo = const <PageMarkup>[],
    this.markupRedo = const <PageMarkup>[],
  });

  final BookWorkStatus status;
  final String projectName;
  final String notes;
  final List<ImagePatternPage> pages;
  final int pageIndex;

  /// Состояние линейки и вида по id страницы; есть у каждой страницы, когда [status] — ready.
  final Map<String, PageWork> works;

  /// Последняя запись на диск не удалась; пропадёт после следующей удачной.
  final bool saveFailed;

  /// Панель плетения свёрнута в капсулу. Не сохраняется: после открытия экрана панель снова полная.
  final bool panelCollapsed;

  /// Линейка до последнего сдвига: по ней работает «Отменить». `null`, когда отменять нечего.
  final RulerState? undoRuler;

  /// Идёт выбор границ схемы на фото: поверх страницы ручки зоны. Не сохраняется.
  final bool zoneEditing;

  /// Включён режим «Маркер» (T45): линейка притушена, палец рисует, два пальца двигают страницу.
  final bool markerEditing;

  /// Номера в [MarkerPalette.colors] и [MarkerPalette.widths].
  final int markerColor;
  final int markerWidth;

  /// Вместо рисования стирается мазок, которого коснулся палец.
  final bool markerEraser;

  /// «Показывать пометки» (глаз): выключенный прячет мазки на экране, данные остаются.
  final bool showMarkup;

  /// Прежние состояния пометок текущей страницы для «Отменить» и «Вернуть»; сбрасываются при смене страницы.
  final List<PageMarkup> markupUndo;
  final List<PageMarkup> markupRedo;

  bool get canUndoMarkup => markupUndo.isNotEmpty;
  bool get canRedoMarkup => markupRedo.isNotEmpty;

  bool get isReady => status == BookWorkStatus.ready;

  ImagePatternPage get page => pages[pageIndex];

  PageWork get work => works[page.id]!;

  double get _pageHeight => page.height.toDouble();

  bool get canAdvance => work.ruler.canAdvance(_pageHeight);

  bool get canRetreat => work.ruler.canRetreat(_pageHeight);

  /// Линейка на последнем ряду страницы.
  bool get isLastRow => work.ruler.isLastRow(_pageHeight);

  bool get hasNextPage => pageIndex < pages.length - 1;

  BookWorkState copyWith({
    BookWorkStatus? status,
    String? projectName,
    String? notes,
    List<ImagePatternPage>? pages,
    int? pageIndex,
    Map<String, PageWork>? works,
    bool? saveFailed,
    bool? panelCollapsed,
    RulerState? undoRuler,
    bool clearUndo = false,
    bool? zoneEditing,
    bool? markerEditing,
    int? markerColor,
    int? markerWidth,
    bool? markerEraser,
    bool? showMarkup,
    List<PageMarkup>? markupUndo,
    List<PageMarkup>? markupRedo,
  }) => BookWorkState(
    status: status ?? this.status,
    projectName: projectName ?? this.projectName,
    notes: notes ?? this.notes,
    pages: pages ?? this.pages,
    pageIndex: pageIndex ?? this.pageIndex,
    works: works ?? this.works,
    saveFailed: saveFailed ?? this.saveFailed,
    panelCollapsed: panelCollapsed ?? this.panelCollapsed,
    undoRuler: clearUndo ? null : undoRuler ?? this.undoRuler,
    zoneEditing: zoneEditing ?? this.zoneEditing,
    markerEditing: markerEditing ?? this.markerEditing,
    markerColor: markerColor ?? this.markerColor,
    markerWidth: markerWidth ?? this.markerWidth,
    markerEraser: markerEraser ?? this.markerEraser,
    showMarkup: showMarkup ?? this.showMarkup,
    markupUndo: markupUndo ?? this.markupUndo,
    markupRedo: markupRedo ?? this.markupRedo,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    projectName,
    notes,
    pages,
    pageIndex,
    works,
    saveFailed,
    panelCollapsed,
    undoRuler,
    zoneEditing,
    markerEditing,
    markerColor,
    markerWidth,
    markerEraser,
    showMarkup,
    markupUndo,
    markupRedo,
  ];
}
