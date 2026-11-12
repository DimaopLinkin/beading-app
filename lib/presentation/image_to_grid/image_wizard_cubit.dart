import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_masks.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/size_purpose.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/rgb.dart';
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
    bool sizeHints = false,
  }) : _source = source,
       _processor = processor,
       _decoder = decoder,
       _runner = runner,
       _masks = masks,
       _catalog = catalog,
       _settings = settings,
       _create = createPattern,
       _debounce = debounce,
       _sizeHints = sizeHints,
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

  /// Считать ли подсказку размера в фоне (T61); тесты с управляемым запуском конвейера её отключают.
  final bool _sizeHints;

  List<CatalogColor> _catalogColors = const <CatalogColor>[];
  String _brand = '';
  String _flossBrand = '';

  /// Картинка после поворота и обрезки, в пикселях для конвейера.
  SourceImage? _image;

  /// Маска важности по пикселям [_image]: из масок Vision; `null` — масок нет и всё одинаково важно.
  Float32List? _importance;

  /// Маска важности только из масок Vision, без мазков: [_importance] строится из неё и мазков заново.
  Float32List? _autoImportance;
  final List<ImportanceBrush> _brushUndo = <ImportanceBrush>[];
  ImportanceBrush? _brushAtStart;
  Uint8List? _subjectMask;
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

  /// Для какой картинки и ремесла подсказка размера уже посчитана или считается (T61); `null` — нужна новая.
  (int, Craft)? _hintKey;
  bool _hintRunning = false;

  /// Пользовательница сама меняла размер или число цветов для этой фотографии: подсказка сама ничего не применяет (T66).
  bool _sizeTouched = false;

  /// Загружает каталог и бренд по умолчанию: от них зависит режим «цвета каталога». [craft] — ремесло, с которого
  /// открывается мастер (из вкладки «Вышивка» листа «Новый проект» — вышивка).
  Future<void> start({Craft craft = Craft.beading}) async {
    final Result<List<CatalogColor>> colors = await _catalog.search(material: CatalogMaterial.bead);
    final Result<List<CatalogColor>> floss = await _catalog.search(material: CatalogMaterial.floss);
    final Result<String> brand = await _settings.read(SettingKeys.defaultBeadBrand);
    final Result<String> flossBrand = await _settings.read(SettingKeys.defaultFlossBrand);
    if (isClosed) {
      return;
    }
    _catalogColors = <CatalogColor>[
      ...?colors.valueOrNull,
      ...?floss.valueOrNull,
    ];
    _brand = brand.valueOrNull ?? '';
    _flossBrand = flossBrand.valueOrNull ?? '';
    emit(state.copyWith(catalogColors: _countCatalog(state.settings), flossBrand: _flossBrand));
    setCraft(craft);
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
    _autoImportance = maskSet?.importance();
    _subjectMask = maskSet?.subjectOrPerson;
    _brushUndo.clear();
    emit(
      state.copyWith(
        brush: ImportanceBrush.empty,
        brushing: false,
        brushUndoDepth: 0,
        preparedWidth: prepared.image.width,
        preparedHeight: prepared.image.height,
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
        clearSizeHint: true,
      ),
    );
    _hintKey = null;
    _sizeTouched = false;
    _image = prepared.image;
    _rebuildImportance();
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
    _hintKey = null;
    emit(
      state.copyWith(
        quarterTurns: quarterTurns,
        crop: crop,
        calculating: true,
        clearProblem: true,
        clearSizeHint: true,
      ),
    );
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
    _autoImportance = maskSet?.importance();
    _subjectMask = maskSet?.subjectOrPerson;
    emit(
      state.copyWith(
        prepared: prepared.png,
        masks: maskSet,
        clearMasks: maskSet == null,
        preparedWidth: prepared.image.width,
        preparedHeight: prepared.image.height,
      ),
    );
    _rebuildImportance();
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
      final SourceImage? image = (await _decoder.decode(png.png, maxSide: wizardImageMaxSide)).valueOrNull;
      return image == null ? null : (png: png.png, image: image);
    } on Object {
      return null;
    }
  }

  void setTechnique(Technique technique) => _change(state.settings.copyWith(technique: technique));

  /// Бисер или вышивка. Ширина, число цветов и контуры возвращаются к значениям по умолчанию ремесла: вышивка крупнее
  /// бисера (ориентир A09 — около 150 крестиков и 30 цветов), и контуры-бэкстич для неё хорошо работают с самого начала.
  void setCraft(Craft craft) {
    final ImageToGridSettings now = state.settings;
    if (now.craft == craft) {
      return;
    }
    _change(
      craft == Craft.crossStitch
          ? now.copyWith(
              technique: Technique.defaultFor(craft),
              columns: ImageToGridSettings.defaultStitchColumns,
              maxColors: ImageToGridSettings.defaultStitchColors,
              backstitch: true,
            )
          : now.copyWith(
              technique: Technique.defaultFor(craft),
              columns: ImageToGridSettings.defaultColumns,
              maxColors: ImageToGridSettings.defaultMaxColors,
            ),
    );
  }

  /// Другая канва: ширина работы в сантиметрах остаётся прежней, клетки пересчитываются.
  void setFabric(Fabric fabric) {
    final ImageToGridSettings now = state.settings;
    _change(now.copyWith(fabric: fabric, columns: fabric.cellsForCm(ImageToGridSettings.snapCm(now.widthCm))));
  }

  /// Цвет канвы: фон схемы (невышитые места).
  void setFabricColor(Rgb color) => _change(state.settings.copyWith(fabric: state.settings.fabric.withColor(color)));

  /// Производитель мулине для схемы: запоминается как бренд по умолчанию.
  Future<void> setFlossBrand(String brand) async {
    if (brand == _flossBrand) {
      return;
    }
    _flossBrand = brand;
    emit(state.copyWith(flossBrand: brand, catalogColors: _countCatalog(state.settings)));
    if (_image != null) {
      _schedule();
    }
    await _settings.write(SettingKeys.defaultFlossBrand, brand);
  }

  /// Ширина готовой вышивки в сантиметрах: клетки считаются по канве.
  void setWidthCm(double cm) {
    _sizeTouched = true;
    _change(state.settings.copyWith(columns: state.settings.fabric.cellsForCm(ImageToGridSettings.snapCm(cm))));
  }

  /// Контуры-бэкстич из картинки (T49).
  void setBackstitch({required bool value}) => _change(state.settings.copyWith(backstitch: value));

  /// Заменить области «посередине» двух ниток блендом (T57).
  void setBlends({required bool value}) => _change(state.settings.copyWith(blends: value));

  void setBeadSize(BeadSize size) => _change(state.settings.copyWith(beadSize: size));

  void setColumns(int columns) {
    _sizeTouched = true;
    _change(state.settings.copyWith(columns: columns));
  }

  void setMaxColors(int colors) {
    _sizeTouched = true;
    _change(state.settings.copyWith(maxColors: colors));
  }

  void setPaletteSource(PaletteSource source) => _change(state.settings.copyWith(paletteSource: source));

  /// Серия бисера в палитре (T62).
  void setBeadSeries(BeadSeries series) => _change(state.settings.copyWith(beadSeries: series));

  /// Серия, из которой сейчас берутся цвета: выбранная или по бренду из настроек.
  BeadSeries get beadSeries => state.settings.seriesFor(_brand);

  /// Включает или выключает группу отделок; последнюю включённую выключить нельзя.
  void setFinishGroup(BeadFinishGroup group, {required bool value}) {
    final Set<BeadFinishGroup> groups = <BeadFinishGroup>{...state.settings.finishGroups};
    if (value) {
      groups.add(group);
    } else {
      groups.remove(group);
    }
    if (groups.isEmpty) return;
    _change(state.settings.copyWith(finishGroups: groups));
  }

  /// Предустановка; `null` — «как на фото»: простой путь T24 без сглаживания и очистки, больше исходных деталей.
  void setPreset(GenerationPreset? preset) =>
      _change(preset == null ? state.settings.copyWith(clearPreset: true) : state.settings.copyWith(preset: preset));

  /// «Выделять главное»: учитывать ли лица и объект, найденные на фото.
  void setUseMasks({required bool value}) {
    _rebuildImportance(useMasks: value);
    _change(state.settings.copyWith(useMasks: value));
  }

  PreparedFrame? get _frame {
    final SourceImage? image = _image;
    return image == null
        ? null
        : PreparedFrame(width: image.width, height: image.height, quarterTurns: state.quarterTurns, crop: state.crop);
  }

  /// Итоговая маска важности: найденное Vision (если включено) и поверх него мазки пользователя.
  void _rebuildImportance({bool? useMasks}) {
    final PreparedFrame? frame = _frame;
    final Float32List? auto = (useMasks ?? state.settings.useMasks) ? _autoImportance : null;
    _importance = frame == null ? auto : state.brush.applyTo(auto, frame);
  }

  /// «Выделить важное»: открывает режим кисти; «Отмена» вернёт мазки, какими они были.
  void startBrush() {
    if (state.brushing || state.prepared == null) {
      return;
    }
    _brushAtStart = state.brush;
    _brushUndo.clear();
    emit(state.copyWith(brushing: true, brushEraser: false, brushShowAuto: false, brushUndoDepth: 0));
  }

  /// «Готово»: мазки применяются, схема пересчитывается.
  void finishBrush() {
    if (!state.brushing) {
      return;
    }
    final bool changed = state.brush != _brushAtStart;
    _brushAtStart = null;
    _brushUndo.clear();
    emit(state.copyWith(brushing: false, brushUndoDepth: 0));
    if (changed) {
      _rebuildImportance();
      _schedule(immediate: true);
    }
  }

  void cancelBrush() {
    if (!state.brushing) {
      return;
    }
    final ImportanceBrush before = _brushAtStart ?? state.brush;
    _brushAtStart = null;
    _brushUndo.clear();
    emit(state.copyWith(brushing: false, brush: before, brushUndoDepth: 0));
  }

  void setBrushEraser({required bool eraser}) =>
      emit(state.copyWith(brushEraser: eraser, brushShowAuto: !eraser && state.brushShowAuto));

  void setBrushSize(int index) {
    if (index >= 0 && index < ImageWizardState.brushSizes.length) {
      emit(state.copyWith(brushSize: index));
    }
  }

  void setBrushShowAuto({required bool value}) => emit(state.copyWith(brushShowAuto: value));

  /// Мазок закончен: [points] — пары `x, y` в долях подготовленной картинки.
  void addBrushStroke(List<double> points) {
    final PreparedFrame? frame = _frame;
    if (frame == null || points.length < 2) {
      return;
    }
    final List<double> source = <double>[];
    for (int i = 0; i + 1 < points.length; i += 2) {
      final (double, double) p = frame.toSource(points[i], points[i + 1]);
      source
        ..add(p.$1)
        ..add(p.$2);
    }
    _changeBrush(
      state.brush.withStroke(BrushStroke(points: source, radius: ImageWizardState.brushSizes[state.brushSize])),
    );
  }

  /// Ластик прошёл по [points] (доли подготовленной картинки): задетые мазки стёрты.
  void eraseBrush(List<double> points) {
    final PreparedFrame? frame = _frame;
    if (frame == null) {
      return;
    }
    final ImportanceBrush next = state.brush.erasing(points, ImageWizardState.brushSizes[state.brushSize], frame);
    if (!identical(next, state.brush)) {
      _changeBrush(next);
    }
  }

  void clearBrush() {
    if (!state.brush.isEmpty) {
      _changeBrush(ImportanceBrush.empty);
    }
  }

  void undoBrush() {
    if (_brushUndo.isNotEmpty) {
      final ImportanceBrush previous = _brushUndo.removeLast();
      emit(state.copyWith(brush: previous, brushUndoDepth: _brushUndo.length));
    }
  }

  /// «Сбросить выделение» в параметрах: все мазки убраны, схема пересчитана.
  void resetBrush() {
    if (state.brush.isEmpty) {
      return;
    }
    emit(state.copyWith(brush: ImportanceBrush.empty, brushUndoDepth: 0));
    _brushUndo.clear();
    _rebuildImportance();
    _schedule(immediate: true);
  }

  void _changeBrush(ImportanceBrush next) {
    _brushUndo.add(state.brush);
    if (_brushUndo.length > 50) {
      _brushUndo.removeAt(0);
    }
    emit(state.copyWith(brush: next, brushUndoDepth: _brushUndo.length));
  }

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
    if (columns == null || state.calculating) return;
    // Предупреждение ссылается на ту же подсказку, если она не уже нужной для лица ширины (T61).
    final SizeSuggestion? hint = state.sizeHint;
    if (hint != null && hint.columns >= columns) {
      applySizeHint();
    } else {
      setColumns(columns);
    }
  }

  /// Фон: оставить, упростить или убрать (нужна маска объекта).
  void setBackground(BackgroundMode mode) => _change(state.settings.copyWith(background: mode));

  /// Обводка объекта одной тёмной бусиной (нужна маска объекта).
  void setOutline({required bool value}) => _change(state.settings.copyWith(outline: value));

  void setDither({required bool value}) => _change(state.settings.copyWith(dither: value));

  void setName(String name) => emit(state.copyWith(name: name, clearProblem: true));

  /// Пока палец на предпросмотре, показывается исходная картинка.
  void setComparing({required bool value}) {
    if (state.comparing != value) {
      emit(state.copyWith(comparing: value));
    }
  }

  /// Переключает предпросмотр между плоской схемой и видом «как будет выглядеть».
  void setRealistic({required bool value}) {
    if (state.realistic != value) emit(state.copyWith(realistic: value));
  }

  void _change(ImageToGridSettings settings) {
    if (settings == state.settings) {
      return;
    }
    final bool craftChanged = settings.craft != state.settings.craft;
    if (craftChanged) _hintKey = null;
    emit(state.copyWith(settings: settings, catalogColors: _countCatalog(settings), clearSizeHint: craftChanged));
    if (_image != null) {
      _schedule();
    }
  }

  /// Применяет подсказку размера одним касанием: ширина и число цветов (T61).
  void applySizeHint() {
    final SizeSuggestion? hint = state.sizeHint;
    if (hint == null) return;
    _sizeTouched = true;
    _change(
      state.settings.copyWith(
        columns: hint.columns,
        maxColors: hint.colors.clamp(ImageToGridSettings.minColors, ImageToGridSettings.maxColorsLimit),
      ),
    );
  }

  /// Размер по назначению: «браслет», «панно», «картина» (бисер) или сантиметры (вышивка).
  void setPurpose(SizePurpose purpose) {
    _sizeTouched = true;
    _change(state.settings.copyWith(columns: purpose.columnsFor(state.settings)));
  }

  /// Считает подсказку размера в фоне по черновикам на нескольких ширинах (T61); стартует после полного расчёта, поэтому
  /// первый предпросмотр не задерживает, и прерывается, как только параметры снова меняются.
  Future<void> _computeHint() async {
    final SourceImage? image = _image;
    final ImageToGridSettings base = state.settings;
    final (int, Craft) key = (_preparation, base.craft);
    if (!_sizeHints || image == null || _hintRunning || _hintKey == key) return;
    _hintRunning = true;
    final int calculation = _calculation;
    try {
      final List<SizeProbe> probes = <SizeProbe>[];
      for (final ({int columns, int colors}) c in SizeSuggester.candidates(
        base.craft,
        maxColumns: ImageToGridSettings.maxColumnsOf(base.craft),
      )) {
        if (isClosed || calculation != _calculation) return;
        final GeneratedPattern pattern = await _runner.run(
          base
              .copyWith(columns: c.columns, maxColors: c.colors, paletteSource: PaletteSource.free)
              .toRequest(image: image, draft: true, measure: true),
        );
        probes.add(SizeProbe(columns: c.columns, colors: c.colors, correlation: pattern.stats?.lightnessCorrelation));
      }
      if (isClosed || calculation != _calculation) return;
      final ImageMaskSet? found = state.masks;
      final bool subject = found != null && (found.faces.isNotEmpty || found.subjectOrPerson != null);
      // С лицом и предметом бисера на картину меньше 80 столбцов мало (отзыв Дмитрия: портреты в бисере не читаются).
      final SizeSuggestion? hint = const SizeSuggester().choose(
        probes,
        minColumns: base.craft == Craft.beading && subject ? beadSubjectColumns : 0,
      );
      _hintKey = key;
      emit(state.copyWith(sizeHint: hint, clearSizeHint: hint == null));
      // Размер по умолчанию берётся из подсказки, пока его никто не менял (T66).
      if (hint != null && !_sizeTouched) {
        _change(
          state.settings.copyWith(
            columns: hint.columns,
            maxColors: hint.colors.clamp(ImageToGridSettings.minColors, ImageToGridSettings.maxColorsLimit),
          ),
        );
      }
    } on Object {
      // Подсказка не обязательна: без неё мастер работает как раньше.
    } finally {
      _hintRunning = false;
    }
  }

  /// Самая узкая схема из бисера для фото с лицом или предметом (станок, A09).
  static const int beadSubjectColumns = 80;

  String _brandFor(ImageToGridSettings settings) => settings.craft == Craft.crossStitch ? _flossBrand : _brand;

  int _countCatalog(ImageToGridSettings settings) =>
      settings.catalogFor(_catalogColors, brand: _brandFor(settings)).length;

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

  /// Черновик есть только у пиксельного пути конвейера: путь T24 (без предустановки) его не знает.
  bool get _hasDraft => state.settings.preset != null;

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
          brand: _brandFor(settings),
          importance: _importance,
          masks: settings.useMasks ? state.masks : null,
          subjectMask: _subjectMask,
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
    if (palette != null) unawaited(_computeHint());
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
      metrics: state.settings.metrics,
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
