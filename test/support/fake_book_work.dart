import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/book_work/book_work_repository.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';

/// Запомненная работа по схемам в памяти. [failure] заставляет любую операцию вернуть ошибку.
class FakeBookWorkRepository implements BookWorkRepository {
  final Map<String, String> currentPages = <String, String>{};
  final Map<String, PageWork> pages = <String, PageWork>{};
  final Map<String, Set<String>> pageIdsByPattern = <String, Set<String>>{};
  Failure? failure;
  int saves = 0;
  bool throwOnSave = false;

  @override
  Future<Result<BookWork>> load(String patternId) async {
    if (failure != null) {
      return Err<BookWork>(failure!);
    }
    return Success<BookWork>(
      BookWork(
        currentPageId: currentPages[patternId],
        pages: <String, PageWork>{
          for (final MapEntry<String, PageWork> e in pages.entries)
            if (pageIdsByPattern[patternId]?.contains(e.key) ?? true) e.key: e.value,
        },
      ),
    );
  }

  @override
  Future<Result<void>> savePage(PageWork work) async {
    if (throwOnSave) {
      throw StateError('boom');
    }
    if (failure != null) {
      return Err<void>(failure!);
    }
    saves++;
    pages[work.pageId] = work;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> saveCurrentPage({required String patternId, required String pageId}) async {
    if (failure != null) {
      return Err<void>(failure!);
    }
    currentPages[patternId] = pageId;
    return const Success<void>(null);
  }
}
