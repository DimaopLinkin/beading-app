import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';

/// Запомненная работа по схеме из книги: линейка и вид каждой страницы, открытая страница.
abstract interface class BookWorkRepository {
  /// Для схемы, над которой ещё не работали, возвращает пустой [BookWork].
  Future<Result<BookWork>> load(String patternId);

  /// Записывает состояние страницы (создаёт или заменяет).
  Future<Result<void>> savePage(PageWork work);

  Future<Result<void>> saveCurrentPage({required String patternId, required String pageId});
}
