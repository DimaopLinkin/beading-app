import 'dart:typed_data';

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/face_size_advisor.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';

enum ImageWizardStep { pickSource, edit, saving, done }

/// Что пошло не так, в терминах для текста на экране.
enum ImageWizardProblem { sourceUnavailable, unreadable, calculationFailed, saveFailed, invalidName }

class ImageWizardState extends Equatable {
  const ImageWizardState({
    this.step = ImageWizardStep.pickSource,
    this.opening = false,
    this.source,
    this.prepared,
    this.quarterTurns = 0,
    this.crop = CropRect.full,
    this.settings = const ImageToGridSettings(),
    this.name = '',
    this.preview,
    this.previewPalette,
    this.previewSettings,
    this.calculating = false,
    this.catalogColors = 0,
    this.flossBrand = '',
    this.comparing = false,
    this.realistic = false,
    this.masks,
    this.brush = ImportanceBrush.empty,
    this.brushing = false,
    this.brushEraser = false,
    this.brushSize = 1,
    this.brushShowAuto = false,
    this.brushUndoDepth = 0,
    this.preparedWidth = 0,
    this.preparedHeight = 0,
    this.sizeHint,
    this.problem,
    this.projectId,
  });

  final ImageWizardStep step;

  /// Идёт открытие выбранного файла.
  final bool opening;

  /// Выбранная картинка как есть: поворот и рамка накладываются на неё при показе и расчёте.
  final Uint8List? source;

  /// Она же после поворота и обрезки (PNG): её показываем при сравнении «до/после».
  final Uint8List? prepared;
  final int quarterTurns;
  final CropRect crop;
  final ImageToGridSettings settings;
  final String name;

  /// Последняя посчитанная схема; пока идёт новый расчёт, остаётся прежняя.
  final GeneratedPattern? preview;

  /// Палитра показанной схемы и параметры, с которыми она посчитана: рисуем именно по ним, а не по текущим.
  final PaletteSnapshot? previewPalette;
  final ImageToGridSettings? previewSettings;

  /// Идёт расчёт: показанная схема может не совпадать с текущими параметрами.
  final bool calculating;

  /// Сколько цветов каталога подходит под размер бусины и бренд.
  final int catalogColors;

  /// Производитель мулине для схемы вышивки (из настроек, можно сменить в мастере).
  final String flossBrand;

  /// Пользовательница держит палец на предпросмотре: показываем исходную картинку.
  final bool comparing;

  /// Предпросмотр «как будет выглядеть» (бусины с бликом) вместо плоской схемы.
  final bool realistic;
  final ImageWizardProblem? problem;

  /// Маски и лица, найденные на подготовленной картинке (T48); `null` — Vision недоступен или ничего не нашёл.
  final ImageMaskSet? masks;

  /// Мазки кисти «важное» (T60) в долях исходной картинки; переживают поворот и обрезку.
  final ImportanceBrush brush;

  /// Открыт режим «Выделить важное»; ластик, размер (номер в [brushSizes]), показ найденного генератором, глубина «Отменить».
  final bool brushing;
  final bool brushEraser;
  final int brushSize;
  final bool brushShowAuto;
  final int brushUndoDepth;

  /// Размер подготовленной картинки в пикселях (0, пока её нет).
  final int preparedWidth;
  final int preparedHeight;

  /// Толщина кисти в коротких сторонах картинки: малая, средняя, крупная.
  static const List<double> brushSizes = <double>[0.02, 0.04, 0.08];

  bool get canUndoBrush => brushUndoDepth > 0;

  /// Подсказка размера по черновикам (T61); `null` — ещё не посчитана, устарела или фото без разброса светлоты.
  final SizeSuggestion? sizeHint;

  /// Подсказка уже применена: ширина и число цветов совпадают с ней.
  bool get sizeHintApplied =>
      sizeHint != null && settings.columns == sizeHint!.columns && settings.maxColors == sizeHint!.colors;

  /// На фото есть лицо, а схема из бисера уже порога, с которого лица читаются (60 столбцов, T61).
  bool get beadsTooSmallForFace =>
      settings.craft == Craft.beading && masks != null && masks!.faces.isNotEmpty && settings.columns < beadFaceColumns;

  static const int beadFaceColumns = 60;

  /// Совет, если лицо на схеме слишком мелкое (T54); пока маски не учитываются, лицо не важно и совета нет.
  FaceSizeAdvice? get faceAdvice {
    final ImageMaskSet? found = masks;
    if (found == null || !settings.useMasks) {
      return null;
    }
    return const FaceSizeAdvisor().advise(found, columns: settings.columns);
  }

  /// Есть что выделять: показываем переключатель «Выделять главное».
  bool get hasMasks => masks != null && !masks!.isEmpty;

  /// Найден главный предмет или человек: показываем настройки фона и обводки (T55).
  bool get hasSubject => masks?.subjectOrPerson != null;

  /// Созданный проект, когда [step] — [ImageWizardStep.done].
  final String? projectId;

  /// Сохранять можно только то, что видно: схема посчитана для текущих параметров.
  bool get canSave => step == ImageWizardStep.edit && preview != null && !calculating && previewSettings == settings;

  /// В режиме каталога нечего подбирать: под размер или бренд нет цветов, схема подбирается свободно.
  bool get catalogMissing => settings.paletteSource == PaletteSource.catalog && catalogColors == 0;

  /// Каталог после отбора по серии и отделкам беднее числа цветов в схеме (T62): мастер предупреждает.
  bool get catalogShort =>
      settings.craft == Craft.beading &&
      settings.paletteSource == PaletteSource.catalog &&
      catalogColors > 0 &&
      catalogColors < settings.maxColors;

  ImageWizardState copyWith({
    ImageWizardStep? step,
    bool? opening,
    Uint8List? source,
    Uint8List? prepared,
    int? quarterTurns,
    CropRect? crop,
    ImageToGridSettings? settings,
    String? name,
    GeneratedPattern? preview,
    PaletteSnapshot? previewPalette,
    ImageToGridSettings? previewSettings,
    bool? calculating,
    int? catalogColors,
    String? flossBrand,
    bool? comparing,
    bool? realistic,
    ImageMaskSet? masks,
    ImportanceBrush? brush,
    bool? brushing,
    bool? brushEraser,
    int? brushSize,
    bool? brushShowAuto,
    int? brushUndoDepth,
    int? preparedWidth,
    int? preparedHeight,
    SizeSuggestion? sizeHint,
    ImageWizardProblem? problem,
    String? projectId,
    bool clearProblem = false,
    bool clearPreview = false,
    bool clearMasks = false,
    bool clearSizeHint = false,
  }) => ImageWizardState(
    step: step ?? this.step,
    opening: opening ?? this.opening,
    source: source ?? this.source,
    prepared: prepared ?? this.prepared,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    crop: crop ?? this.crop,
    settings: settings ?? this.settings,
    name: name ?? this.name,
    preview: clearPreview ? null : (preview ?? this.preview),
    previewPalette: clearPreview ? null : (previewPalette ?? this.previewPalette),
    previewSettings: clearPreview ? null : (previewSettings ?? this.previewSettings),
    calculating: calculating ?? this.calculating,
    catalogColors: catalogColors ?? this.catalogColors,
    flossBrand: flossBrand ?? this.flossBrand,
    comparing: comparing ?? this.comparing,
    realistic: realistic ?? this.realistic,
    masks: clearMasks ? null : (masks ?? this.masks),
    brush: brush ?? this.brush,
    brushing: brushing ?? this.brushing,
    brushEraser: brushEraser ?? this.brushEraser,
    brushSize: brushSize ?? this.brushSize,
    brushShowAuto: brushShowAuto ?? this.brushShowAuto,
    brushUndoDepth: brushUndoDepth ?? this.brushUndoDepth,
    preparedWidth: preparedWidth ?? this.preparedWidth,
    preparedHeight: preparedHeight ?? this.preparedHeight,
    sizeHint: clearSizeHint ? null : (sizeHint ?? this.sizeHint),
    problem: clearProblem ? null : (problem ?? this.problem),
    projectId: projectId ?? this.projectId,
  );

  @override
  List<Object?> get props => <Object?>[
    step,
    opening,
    source,
    prepared,
    quarterTurns,
    crop,
    settings,
    name,
    preview,
    previewPalette,
    previewSettings,
    calculating,
    catalogColors,
    flossBrand,
    comparing,
    realistic,
    masks,
    brush,
    brushing,
    brushEraser,
    brushSize,
    brushShowAuto,
    brushUndoDepth,
    preparedWidth,
    preparedHeight,
    sizeHint,
    problem,
    projectId,
  ];
}
