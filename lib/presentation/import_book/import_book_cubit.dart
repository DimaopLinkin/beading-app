import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/import_book/import_book_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Поток «Схема из книги»: выбрать источник → (страницы PDF) → проверить, повернуть, обрезать → импортировать.
class ImportBookCubit extends Cubit<ImportBookState> {
  ImportBookCubit({
    required BookImageSource source,
    required PdfRasterizer rasterizer,
    required ImportBookPattern importBookPattern,
    Craft craft = Craft.beading,
  }) : _source = source,
       _rasterizer = rasterizer,
       _import = importBookPattern,
       super(ImportBookState(craft: craft));

  final BookImageSource _source;
  final PdfRasterizer _rasterizer;
  final ImportBookPattern _import;
  int _nextPageId = 0;

  Future<void> takePhoto() => _load(_source.takePhoto);

  Future<void> pickPhotos() => _load(_source.pickPhotos);

  Future<void> pickFiles() => _load(_source.pickFiles);

  Future<void> _load(Future<Result<List<PickedBookFile>>> Function() pick) async {
    final Result<List<PickedBookFile>> picked = await pick();
    if (isClosed) {
      return;
    }
    if (picked case Err<List<PickedBookFile>>()) {
      emit(state.copyWith(problem: ImportProblem.sourceUnavailable));
      return;
    }
    final List<PickedBookFile> files = picked.valueOrNull!;
    if (files.isEmpty) {
      return;
    }
    final PickedBookFile? pdf = files.where((f) => f.isPdf).firstOrNull;
    if (pdf != null) {
      final Result<int> count = await _rasterizer.pageCount(pdf.bytes);
      if (isClosed) {
        return;
      }
      if (count case Success<int>(:final int value) when value > 0) {
        emit(
          state.copyWith(
            step: ImportStep.choosePdfPages,
            pdf: pdf,
            pdfPageCount: value,
            selectedPdfPages: <int>{},
            name: _nameFor(pdf.name),
            clearProblem: true,
          ),
        );
      } else {
        emit(state.copyWith(problem: ImportProblem.pdfFailed));
      }
      return;
    }
    emit(
      state.copyWith(
        step: ImportStep.review,
        pages: <PageDraft>[
          ...state.pages,
          for (final PickedBookFile file in files) PageDraft(id: _nextPageId++, bytes: file.bytes),
        ],
        name: state.name.isEmpty ? _nameFor(files.first.name) : state.name,
        clearProblem: true,
      ),
    );
  }

  void togglePdfPage(int index) {
    final Set<int> selected = <int>{...state.selectedPdfPages};
    if (!selected.remove(index)) {
      selected.add(index);
    }
    emit(state.copyWith(selectedPdfPages: selected));
  }

  void selectAllPdfPages() =>
      emit(state.copyWith(selectedPdfPages: <int>{for (int i = 0; i < state.pdfPageCount; i++) i}));

  void clearPdfPages() => emit(state.copyWith(selectedPdfPages: <int>{}));

  /// Растеризует отмеченные страницы (по порядку в документе) и переходит к проверке.
  Future<void> confirmPdfPages() async {
    final PickedBookFile? pdf = state.pdf;
    if (pdf == null || state.selectedPdfPages.isEmpty) {
      emit(state.copyWith(problem: ImportProblem.noPages));
      return;
    }
    final List<int> indexes = state.selectedPdfPages.toList()..sort();
    final Result<List<ProcessedImage>> rendered = await _rasterizer.render(pdf.bytes, indexes);
    if (isClosed) {
      return;
    }
    if (rendered case Err<List<ProcessedImage>>()) {
      emit(state.copyWith(problem: ImportProblem.pdfFailed));
      return;
    }
    emit(
      state.copyWith(
        step: ImportStep.review,
        pages: <PageDraft>[
          ...state.pages,
          for (final ProcessedImage image in rendered.valueOrNull!) PageDraft(id: _nextPageId++, bytes: image.png),
        ],
        clearProblem: true,
      ),
    );
  }

  /// Вернуться к выбору источника, оставив уже добавленные страницы.
  void addMore() => emit(state.copyWith(step: ImportStep.pickSource, clearProblem: true));

  /// Рамка задана в повёрнутых осях, поэтому после поворота она сбрасывается.
  /// Вернуться к проверке, если уже есть добавленные страницы.
  void backToReview() {
    if (state.pages.isNotEmpty) {
      emit(state.copyWith(step: ImportStep.review, clearProblem: true));
    }
  }

  void rotate(int pageId) =>
      _update(pageId, (p) => p.copyWith(quarterTurns: (p.quarterTurns + 1) % 4, crop: CropRect.full));

  void setCrop(int pageId, CropRect crop) => _update(pageId, (p) => p.copyWith(crop: crop));

  void remove(int pageId) {
    final List<PageDraft> pages = state.pages.where((p) => p.id != pageId).toList();
    emit(state.copyWith(pages: pages, step: pages.isEmpty ? ImportStep.pickSource : state.step));
  }

  void move(int oldIndex, int newIndex) {
    final List<PageDraft> pages = <PageDraft>[...state.pages];
    final PageDraft moved = pages.removeAt(oldIndex);
    pages.insert(newIndex.clamp(0, pages.length), moved);
    emit(state.copyWith(pages: pages));
  }

  void setName(String name) => emit(state.copyWith(name: name));

  void setCraft(Craft craft) => emit(state.copyWith(craft: craft));

  Future<void> submit() async {
    if (state.pages.isEmpty) {
      emit(state.copyWith(problem: ImportProblem.noPages));
      return;
    }
    if (state.name.trim().isEmpty) {
      emit(state.copyWith(problem: ImportProblem.emptyName));
      return;
    }
    emit(state.copyWith(step: ImportStep.importing, clearProblem: true));
    final Result<Project> result = await _import(
      name: state.name,
      craft: state.craft,
      pages: <BookPageSource>[
        for (final PageDraft p in state.pages)
          BookPageSource(bytes: p.bytes, quarterTurns: p.quarterTurns, crop: p.crop),
      ],
    );
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<Project>(:final Project value):
        emit(state.copyWith(step: ImportStep.done, projectId: value.id));
      case Err<Project>(:final Failure failure):
        emit(
          state.copyWith(
            step: ImportStep.review,
            problem: failure is ValidationFailure ? ImportProblem.unreadable : ImportProblem.saveFailed,
          ),
        );
    }
  }

  void _update(int pageId, PageDraft Function(PageDraft page) change) => emit(
    state.copyWith(pages: <PageDraft>[for (final PageDraft p in state.pages) p.id == pageId ? change(p) : p]),
  );

  /// Название по умолчанию — имя файла без расширения.
  String _nameFor(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    final String base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.trim();
  }
}
