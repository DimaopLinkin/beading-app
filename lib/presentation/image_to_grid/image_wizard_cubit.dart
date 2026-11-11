import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_masks.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Мастер «Схема из картинки»: выбрать фото → обрезать → подобрать параметры при живом предпросмотре → сохранить.
///
/// Предпросмотр пересчитывается после паузы в правках ([debounce]). Расчёт идёт в изоляте и не отменяется, поэтому
/// устаревший результат просто отбрасывается: на экране всегда схема самых свежих параметров.
class ImageWizardCubit extends Cubit<ImageWizardState> {
  ImageWizardCubit({
    required BookImageSource source,
    required ImageProcessor processor,
    required ImageDecoder decoder,
    required ImageToGridRunner runner,
    required ImageMasks masks,
    required CatalogRepository catalog,
    required SettingsRepository settings,
    required CreatePatternFromImage createPattern,
    Duration debounce = const Duration(milliseconds: 300),
  }) : _source = source,
       _processor = processor,
       _decoder = decoder,
       _runner = runner,
       _masks = masks,
       _catalog = catalog,
       _settings = settings,
       _create = createPattern,
       _debounce = debounce,
       super(const ImageWizardState());

  final BookImageSource _source;
  final ImageProcessor _processor;
  final ImageDecoder _decoder;
  final ImageToGridRunner _runner;
  final ImageMasks _masks;
  final CatalogRepository _catalog;
  final SettingsRepository _settings;
  final CreatePatternFromImage _create;
  final Duration _debounce;

  List<CatalogColor> _catalogColors = const <CatalogColor>[];
  String _brand = '';

  /// Картинка после поворота и обрезки, в пикселях для конвейера.
  SourceImage? _image;

  /// Маска важности по пикселям [_image]: из масок Vision; `null` — масок нет и всё одинаково важно.
  Float32List? _importance;
  Timer? _timer;

  /// Номер последнего запрошенного расчёта: результаты с другим номером устарели.
  int _calculation = 0;

  /// Идёт черновой расчёт; пока он не закончен, следующий черновик ждёт ([_draftWaiting]), а не копится в очереди.
  bool _draftRunning = false;
  bool _draftWaiting = false;

  /// Номер расчёта, чья полная схема уже показана: опоздавший черновик её не затирает.
  int _fullShown = -1;

  /// То же для подготовки картинки (поворот, обрезка, декодирование).
  int _preparation = 0;

  /// Загружает каталог и бренд по умолчанию: от них зависит режим «цвета каталога».
  Future<void> start() async {
    final Result<List<CatalogColor>> colors = await _catalog.search(material: CatalogMaterial.bead);
    final Result<String> brand = await _settings.read(SettingKeys.defaultBeadBrand);
    if (isClosed) {
      return;
    }
    _catalogColors = colors.valueOrNull ?? const <CatalogColor>[];
    _brand = brand.valueOrNull ?? '';
    emit(state.copyWith(catalogColors: _countCatalog(state.settings)));
    if (_image != null) {
      _schedule(immediate: true);
    }
  }

  Future<void> takePhoto() => _pick(_source.takePhoto);

  Future<void> pickPhotos() => _pick(_source.pickPhotos);

  Future<void> pickFiles() => _pick(_source.pickFiles);

  Future<void> _pick(Future<Result<List<PickedBookFile>>> Function() pick) async {
    if (state.opening) {
      return;
    }
    emit(state.copyWith(opening: true, clearProblem: true));
    Result<List<PickedBookFile>> picked;
    try {
      picked = await pick();
    } on Object {
      // Файл недоступен (например, не скачан из iCloud): индикатор не должен остаться навсегда.
      picked = const Err<List<PickedBookFile>>(StorageFailure('picker'));
    }
    if (isClosed) {
      return;
    }
    if (picked case Err<List<PickedBookFile>>()) {
      emit(state.copyWith(opening: false, problem: ImageWizardProblem.sourceUnavailable));
      return;
    }
    final List<PickedBookFile> files = picked.valueOrNull!;
    if (files.isEmpty) {
      emit(state.copyWith(opening: false));
      return;
    }
    final PickedBookFile file = files.first;
    if (file.isPdf) {
      emit(state.copyWith(opening: false, problem: ImageWizardProblem.unreadable));
      return;
    }
    _timer?.cancel();
    final int preparation = ++_preparation;
    ++_calculation;
    final ({Uint8List png, SourceImage image})? prepared = await _prepareImage(file.bytes, 0, CropRect.full);
    if (isClosed || preparation != _preparation) {
      return;
    }
    if (prepared == null) {
      emit(state.copyWith(opening: false, problem: ImageWizardProblem.unreadable));
      return;
    }
    final ImageMaskSet? maskSet = await _findMasks(prepared.png, prepared.image);
    if (isClosed || preparation != _preparation) {
      return;
    }
    _importance = maskSet?.importance();
    emit(
      state.copyWith(
        step: ImageWizardStep.edit,
        opening: false,
        masks: maskSet,
        clearMasks: maskSet == null,
        source: file.bytes,
        prepared: prepared.png,
        quarterTurns: 0,
        crop: CropRect.full,
        name: state.name.isEmpty ? _nameFor(file.name) : state.name,
        clearPreview: true,
        clearProblem: true,
      ),
    );
    _image = prepared.image;
    _schedule(immediate: true);
  }

  /// Поворот на 90° по часовой стрелке; рамка задана в повёрнутых осях, поэтому сбрасывается.
  Future<void> rotate() => _reshape(quarterTurns: (state.quarterTurns + 1) % 4, crop: CropRect.full);

  Future<void> setCrop(CropRect crop) => _reshape(quarterTurns: state.quarterTurns, crop: crop);

  Future<void> _reshape({required int quarterTurns, required CropRect crop}) async {
    final Uint8List? source = state.source;
    if (source == null) {
      return;
    }
    _timer?.cancel();
    final int preparation = ++_preparation;
    ++_calculation;
    emit(state.copyWith(quarterTurns: quarterTurns, crop: crop, calculating: true, clearProblem: true));
    final ({Uint8List png, SourceImage image})? prepared = await _prepareImage(source, quarterTurns, crop);
    if (isClosed || preparation != _preparation) {
      return;
    }
    if (prepared == null) {
      emit(state.copyWith(calculating: false, problem: ImageWizardProblem.unreadable));
      return;
    }
    final ImageMaskSet? maskSet = await _findMasks(prepared.png, prepared.image);
    if (isClosed || preparation != _preparation) {
      return;
    }
    _image = prepared.image;
    _importance = maskSet?.importance();
    emit(state.copyWith(prepared: prepared.png, masks: maskSet, clearMasks: maskSet == null));
    _schedule(immediate: true);
  }

  /// Ищет на картинке лица, объект и значимые области. Любая ошибка (нет Vision, симулятор, сбой) — `null`:
  /// мастер работает без масок, как раньше.
  Future<ImageMaskSet?> _findMasks(Uint8List png, SourceImage image) async {
    try {
      return (await _masks.analyze(png, width: image.width, height: image.height)).valueOrNull;
    } on Object {
      return null;
    }
  }

  /// Поворачивает и обрезает картинку, декодирует её для конвейера. Результат применяет вызывающий, если подготовка
  /// не устарела. `null` — картинку не удалось прочитать.
  Future<({Uint8List png, SourceImage image})?> _prepareImage(Uint8List bytes, int quarterTurns, CropRect crop) async {
    try {
      final Result<ProcessedImage> processed = await _processor.process(bytes, quarterTurns: quarterTurns, crop: crop);
      final ProcessedImage? png = processed.valueOrNull;
      if (png == null) {
        return null;
      }
      final SourceImage? image = (await _decoder.decode(png.png)).valueOrNull;
      return image == null ? null : (png: png.png, image: image);
    } on Object {
      return null;
    }
  }

  void setTechnique(Technique technique) => _change(state.settings.copyWith(technique: technique));

  void setBeadSize(BeadSize size) => _change(state.settings.copyWith(beadSize: size));

  void setColumns(int columns) => _change(state.settings.copyWith(columns: columns));

  void setMaxColors(int colors) => _change(state.settings.copyWith(maxColors: colors));

  void setPaletteSource(PaletteSource source) => _change(state.settings.copyWith(paletteSource: source));

  void setPreset(GenerationPreset preset) => _change(state.settings.copyWith(preset: preset));

  /// «Выделять главное»: учитывать ли лица и объект, найденные на фото.
  void setUseMasks({required bool value}) => _change(state.settings.copyWith(useMasks: value));

  /// «Обрезать по лицу»: рамка вокруг самого крупного лица из совета, в осях уже обрезанной картинки.
  Future<void> cropToFace() async {
    final NormalizedRect? face = state.faceAdvice?.cropRect;
    // Пока картинка пересчитывается, маски лежат в осях прежней обрезки: совет устарел.
    if (face == null || state.calculating) {
      return;
    }
    final CropRect now = state.crop;
    double clamp(double v) => v.clamp(0.0, 1.0);
    await setCrop(
      CropRect(
        left: clamp(now.left + face.left * now.width),
        top: clamp(now.top + face.top * now.height),
        right: clamp(now.left + face.right * now.width),
        bottom: clamp(now.top + face.bottom * now.height),
      ),
    );
  }

  /// «Схема шире»: ширина, при которой лицо занимает нужное число бусин.
  void widenForFace() {
    final int? columns = state.faceAdvice?.neededColumns;
    if (columns != null && !state.calculating) {
      setColumns(columns);
    }
  }

  void setDither({required bool value}) => _change(state.settings.copyWith(dither: value));

  void setName(String name) => emit(state.copyWith(name: name, clearProblem: true));

  /// Пока палец на предпросмотре, показывается исходная картинка.
  void setComparing({required bool value}) {
    if (state.comparing != value) {
      emit(state.copyWith(comparing: value));
    }
  }

  void _change(ImageToGridSettings settings) {
    if (settings == state.settings) {
      return;
    }
    emit(state.copyWith(settings: settings, catalogColors: _countCatalog(settings)));
    if (_image != null) {
      _schedule();
    }
  }

  int _countCatalog(ImageToGridSettings settings) => settings.catalogFor(_catalogColors, brand: _brand).length;

  /// Запрашивает расчёт; быстрые правки подряд сливаются в один полный расчёт после паузы.
  ///
  /// Пока параметры меняются (ползунок в движении), между правками считается быстрый черновик (T58): предпросмотр
  /// отзывается сразу, а полная схема появляется после паузы. Черновик показывают, но сохранить нельзя: кнопка
  /// доступна только для полного расчёта.
  void _schedule({bool immediate = false}) {
    final int calculation = ++_calculation;
    _timer?.cancel();
    emit(state.copyWith(calculating: true, clearProblem: true));
    if (immediate || _debounce == Duration.zero) {
      unawaited(_calculate(calculation));
    } else {
      if (_hasDraft) {
        _requestDraft();
      }
      _timer = Timer(_debounce, () => unawaited(_calculate(calculation)));
    }
  }

  /// Черновик есть только у пиксельного пути конвейера: путь T24 (без предустановки или с дизерингом) его не знает.
  bool get _hasDraft => state.settings.preset != null && !state.settings.dither;

  void _requestDraft() {
    if (_draftRunning) {
      _draftWaiting = true;
      return;
    }
    unawaited(_calculate(_calculation, draft: true));
  }

  Future<void> _calculate(int calculation, {bool draft = false}) async {
    final SourceImage? image = _image;
    if (image == null) {
      return;
    }
    final ImageToGridSettings settings = state.settings;
    if (draft) {
      _draftRunning = true;
    }
    GeneratedPattern? pattern;
    try {
      pattern = await _runner.run(
        settings.toRequest(
          image: image,
          catalog: _catalogColors,
          brand: _brand,
          importance: settings.useMasks ? _importance : null,
          masks: settings.useMasks ? state.masks : null,
          draft: draft,
        ),
      );
    } on Object {
      pattern = null;
    }
    if (draft) {
      _draftRunning = false;
      if (_draftWaiting && !isClosed) {
        // Пока считался черновик, параметры менялись: считаем свежий, если полный расчёт ещё не начался.
        _draftWaiting = false;
        if (calculation != _calculation && (_timer?.isActive ?? false)) {
          _requestDraft();
        }
      }
    }
    if (isClosed || calculation != _calculation) {
      // Параметры успели измениться: этот результат уже никому не нужен.
      return;
    }
    if (draft) {
      if (_fullShown == calculation) {
        return;
      }
      final PaletteSnapshot? draftPalette = pattern == null ? null : paletteFromGenerated(pattern).valueOrNull;
      if (draftPalette != null && pattern != null) {
        // Расчёт ещё идёт: полная схема придёт после паузы.
        emit(state.copyWith(preview: pattern, previewPalette: draftPalette, previewSettings: settings));
      }
      return;
    }
    final PaletteSnapshot? palette = pattern == null ? null : paletteFromGenerated(pattern).valueOrNull;
    _fullShown = calculation;
    emit(
      palette == null
          ? state.copyWith(calculating: false, problem: ImageWizardProblem.calculationFailed)
          : state.copyWith(
              preview: pattern,
              previewPalette: palette,
              previewSettings: settings,
              calculating: false,
              clearProblem: true,
            ),
    );
  }

  /// Сохраняет посчитанную схему проектом. Кнопка доступна, только когда [ImageWizardState.canSave].
  Future<void> save() async {
    final GeneratedPattern? pattern = state.preview;
    if (!state.canSave || pattern == null) {
      return;
    }
    if (state.name.trim().isEmpty) {
      emit(state.copyWith(problem: ImageWizardProblem.invalidName));
      return;
    }
    emit(state.copyWith(step: ImageWizardStep.saving, clearProblem: true));
    final Result<Project> created = await _create(
      name: state.name,
      technique: state.settings.technique,
      metrics: state.settings.beadSize,
      pattern: pattern,
    );
    if (isClosed) {
      return;
    }
    switch (created) {
      case Success<Project>(:final Project value):
        emit(state.copyWith(step: ImageWizardStep.done, projectId: value.id));
      case Err<Project>(:final Failure failure):
        emit(
          state.copyWith(
            step: ImageWizardStep.edit,
            problem: failure is ValidationFailure ? ImageWizardProblem.invalidName : ImageWizardProblem.saveFailed,
          ),
        );
    }
  }

  String _nameFor(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    return (dot > 0 ? fileName.substring(0, dot) : fileName).trim();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    unawaited(_runner.release());
    return super.close();
  }
}
