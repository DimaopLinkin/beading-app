import 'dart:typed_data';

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';

enum ImportStep { pickSource, choosePdfPages, review, importing, done }

/// Что пошло не так, в терминах для текста на экране.
enum ImportProblem { sourceUnavailable, unreadable, pdfFailed, pdfEmpty, saveFailed, noPages, emptyName }

/// Чем занят поток, пока пользовательница ждёт.
enum ImportBusy { opening, rendering }

/// Страница в списке перед импортом: исходные байты и правки.
class PageDraft extends Equatable {
  const PageDraft({required this.id, required this.bytes, this.quarterTurns = 0, this.crop = CropRect.full});

  final int id;
  final Uint8List bytes;
  final int quarterTurns;
  final CropRect crop;

  PageDraft copyWith({int? quarterTurns, CropRect? crop}) =>
      PageDraft(id: id, bytes: bytes, quarterTurns: quarterTurns ?? this.quarterTurns, crop: crop ?? this.crop);

  @override
  List<Object?> get props => <Object?>[id, bytes, quarterTurns, crop];
}

class ImportBookState extends Equatable {
  const ImportBookState({
    this.step = ImportStep.pickSource,
    this.craft = Craft.beading,
    this.name = '',
    this.pages = const <PageDraft>[],
    this.pdf,
    this.pdfPageCount = 0,
    this.selectedPdfPages = const <int>{},
    this.problem,
    this.projectId,
    this.busy,
  });

  final ImportStep step;
  final Craft craft;
  final String name;
  final List<PageDraft> pages;

  /// PDF, из которого сейчас выбираем страницы.
  final PickedBookFile? pdf;
  final int pdfPageCount;
  final Set<int> selectedPdfPages;
  final ImportProblem? problem;

  /// Созданный проект, когда [step] — [ImportStep.done].
  final String? projectId;

  /// Идёт открытие файла или отрисовка страниц PDF: на экране индикатор, кнопки не нажимаются.
  final ImportBusy? busy;

  /// Сколько экранов в этом потоке: для PDF добавляется выбор страниц. Считается здесь, а не в строке экрана.
  int get stepCount => pdf != null ? 3 : 2;

  /// Номер текущего экрана потока, с 1; `null`, когда шаг не нумеруется (сохранение, конец).
  int? get stepNumber => switch (step) {
    ImportStep.pickSource => 1,
    ImportStep.choosePdfPages => 2,
    ImportStep.review => stepCount,
    ImportStep.importing || ImportStep.done => null,
  };

  ImportBookState copyWith({
    ImportStep? step,
    Craft? craft,
    String? name,
    List<PageDraft>? pages,
    PickedBookFile? pdf,
    int? pdfPageCount,
    Set<int>? selectedPdfPages,
    ImportProblem? problem,
    String? projectId,
    ImportBusy? busy,
    bool clearProblem = false,
    bool clearBusy = false,
    bool clearPdf = false,
  }) => ImportBookState(
    step: step ?? this.step,
    craft: craft ?? this.craft,
    name: name ?? this.name,
    pages: pages ?? this.pages,
    pdf: clearPdf ? null : (pdf ?? this.pdf),
    pdfPageCount: pdfPageCount ?? this.pdfPageCount,
    selectedPdfPages: selectedPdfPages ?? this.selectedPdfPages,
    problem: clearProblem ? null : (problem ?? this.problem),
    projectId: projectId ?? this.projectId,
    busy: clearBusy ? null : (busy ?? this.busy),
  );

  @override
  List<Object?> get props => <Object?>[
    step,
    craft,
    name,
    pages,
    pdf,
    pdfPageCount,
    selectedPdfPages,
    problem,
    projectId,
    busy,
  ];
}
