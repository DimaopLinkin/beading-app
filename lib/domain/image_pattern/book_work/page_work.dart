import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:equatable/equatable.dart';

/// Состояние работы на одной странице схемы: линейка и вид.
class PageWork extends Equatable {
  const PageWork({
    required this.pageId,
    required this.ruler,
    this.viewport = PageViewport.identity,
    this.markup = const PageMarkup.empty(),
  });

  final String pageId;
  final RulerState ruler;
  final PageViewport viewport;

  /// Пометки маркером (T45).
  final PageMarkup markup;

  PageWork copyWith({RulerState? ruler, PageViewport? viewport, PageMarkup? markup}) => PageWork(
    pageId: pageId,
    ruler: ruler ?? this.ruler,
    viewport: viewport ?? this.viewport,
    markup: markup ?? this.markup,
  );

  @override
  List<Object?> get props => <Object?>[pageId, ruler, viewport, markup];
}

/// Всё, что запомнено о работе над схемой: открытая страница и состояние страниц, на которых уже работали.
class BookWork extends Equatable {
  const BookWork({this.currentPageId, this.pages = const <String, PageWork>{}});

  final String? currentPageId;

  /// По id страницы. Страниц, которых здесь нет, ещё не касались.
  final Map<String, PageWork> pages;

  @override
  List<Object?> get props => <Object?>[currentPageId, pages];
}
