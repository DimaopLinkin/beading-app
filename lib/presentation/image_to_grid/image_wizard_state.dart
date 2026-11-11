import 'dart:typed_data';

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/face_size_advisor.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
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
    this.comparing = false,
    this.masks,
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

  /// Пользовательница держит палец на предпросмотре: показываем исходную картинку.
  final bool comparing;
  final ImageWizardProblem? problem;

  /// Маски и лица, найденные на подготовленной картинке (T48); `null` — Vision недоступен или ничего не нашёл.
  final ImageMaskSet? masks;

  /// Есть что выделять: показываем переключатель «Выделять главное».
  /// Совет, если лицо на схеме слишком мелкое (T54); пока маски не учитываются, лицо не важно и совета нет.
  FaceSizeAdvice? get faceAdvice {
    final ImageMaskSet? found = masks;
    if (found == null || !settings.useMasks) {
      return null;
    }
    return const FaceSizeAdvisor().advise(found, columns: settings.columns);
  }

  bool get hasMasks => masks != null && !masks!.isEmpty;

  /// Созданный проект, когда [step] — [ImageWizardStep.done].
  final String? projectId;

  /// Сохранять можно только то, что видно: схема посчитана для текущих параметров.
  bool get canSave => step == ImageWizardStep.edit && preview != null && !calculating && previewSettings == settings;

  /// В режиме каталога нечего подбирать: под размер или бренд нет цветов, схема подбирается свободно.
  bool get catalogMissing => settings.paletteSource == PaletteSource.catalog && catalogColors == 0;

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
    bool? comparing,
    ImageMaskSet? masks,
    ImageWizardProblem? problem,
    String? projectId,
    bool clearProblem = false,
    bool clearPreview = false,
    bool clearMasks = false,
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
    comparing: comparing ?? this.comparing,
    masks: clearMasks ? null : (masks ?? this.masks),
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
    comparing,
    masks,
    problem,
    projectId,
  ];
}
