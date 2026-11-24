import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/bead_stock/bead_stock_entry.dart';
import 'package:beading/domain/bead_stock/bead_stock_repository.dart';
import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_pattern_repository.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/frame_planner.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/generation_stamp.dart';
import 'package:beading/domain/image_to_grid/image_decoder.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_masks.dart';
import 'package:beading/domain/image_to_grid/image_recipe.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/pattern_floss.dart';
import 'package:beading/domain/image_to_grid/printable_generated.dart';
import 'package:beading/domain/image_to_grid/size_purpose.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/create_pattern_from_image.dart';
import 'package:beading/domain/image_to_grid/use_cases/replace_pattern_from_image.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/printing/pattern_printer.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/printing/print_options_store.dart';
import 'package:beading/domain/printing/use_cases/export_pattern_pdf.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
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
    FlossStockRepository? flossStock,
    BeadStockRepository? beadStock,
    ImageRecipeStore? recipes,
    GenerationBuildProvider? generationBuild,
    ReplacePatternFromImage? replacePattern,
    ProjectRepository? projects,
    GridPatternRepository? patterns,
    PatternPrinter? printer,
    Duration debounce = const Duration(milliseconds: 500),
    bool sizeHints = false,
  }) : _source = source,
       _processor = processor,
       _decoder = decoder,
       _runner = runner,
       _masks = masks,
       _catalog = catalog,
       _settings = settings,
       _create = createPattern,
       _flossStock = flossStock,
       _beadStock = beadStock,
       _recipes = recipes,
       _generationBuild = generationBuild,
       _replace = replacePattern,
       _projects = projects,
       _patterns = patterns,
       _printer = printer,
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

  /// Запасы мулине и бисера для режима «только из запаса» (T34); без них запас пуст.
  final FlossStockRepository? _flossStock;
  final BeadStockRepository? _beadStock;

  /// Нужны для правки готовой схемы (T79); без них мастер только создаёт новые.
  final ImageRecipeStore? _recipes;

  /// Сборка для отпечатка генерации в рецепте (T104); без неё рецепт пишется без отпечатка.
  final GenerationBuildProvider? _generationBuild;
  final ReplacePatternFromImage? _replace;
  final ProjectRepository? _projects;
  final GridPatternRepository? _patterns;

  /// Печать схемы до сохранения (T80); без принтера кнопки печати в мастере нет.
  final PatternPrinter? _printer;
  final Duration _debounce;

  /// Считать ли подсказку размера в фоне (T61); тесты с управляемым запуском конвейера её отключают.
  final bool _sizeHints;

  List<CatalogColor> _catalogColors = const <CatalogColor>[];
  String _brand = '';
  String _flossBrand = '';

  /// Что есть в запасе (T34): читается один раз при открытии мастера.
  Set<CatalogRef> _stash = const <CatalogRef>{};

  /// Картинка после поворота и обрезки, в пикселях для конвейера.
  SourceImage? _image;

  /// Рамка, по которой сделана [_image] (T88c): рамка пользовательницы или подогнанная под высоту. Это только ключ кеша
  /// подготовленной картинки; подогнанную рамку считает [ImageWizardState.effectiveCropOf] по настройкам.
  CropRect _appliedCrop = CropRect.full;

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
    final Result<List<FlossStockEntry>>? flossStock = await _flossStock?.all();
    final Result<List<BeadStockEntry>>? beadStock = await _beadStock?.all();
    if (isClosed) {
      return;
    }
    _stash = <CatalogRef>{
      for (final FlossStockEntry entry in flossStock?.valueOrNull ?? const <FlossStockEntry>[]) entry.ref,
      for (final BeadStockEntry entry in beadStock?.valueOrNull ?? const <BeadStockEntry>[]) entry.ref,
    };
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

  /// Открывает на правку схему проекта [projectId] (T79): параметры и фото берутся из сохранённого рецепта. Схемы,
  /// созданные раньше, рецепта не имеют: размер, канва и техника берутся из самой схемы, фото выбирают заново.
  Future<void> startEditing(String projectId) async {
    final Project? project = (await _projects?.get(projectId))?.valueOrNull;
    final GridPattern? pattern = (await _patterns?.getByProject(projectId))?.valueOrNull;
    if (project == null || pattern == null) {
      emit(state.copyWith(problem: ImageWizardProblem.sourceUnavailable));
      return;
    }
    emit(state.copyWith(editingProjectId: projectId, name: project.name));
    await start(craft: project.craft);
    if (isClosed) return;
    final ImageRecipe? recipe = await _recipes?.load(projectId);
    if (isClosed) return;
    if (recipe == null) {
      final CellMetrics metrics = pattern.metrics;
      _change(
        state.settings.copyWith(
          technique: project.technique,
          columns: pattern.grid.width,
          beadSize: metrics is BeadSize ? metrics : null,
          fabric: metrics is Fabric ? metrics : null,
        ),
      );
      return;
    }
    // Производитель берётся из рецепта, а не из последнего выбора в других схемах (T101); у старых рецептов его нет.
    if (recipe.flossBrand.isNotEmpty) _flossBrand = recipe.flossBrand;
    emit(
      state.copyWith(
        settings: recipe.settings,
        flossBrand: _flossBrand,
        catalogColors: _countCatalog(recipe.settings),
      ),
    );
    await _loadSource(
      recipe.source,
      project.name,
      quarterTurns: recipe.quarterTurns,
      crop: recipe.crop,
      brush: recipe.brush,
    );
  }

  /// Есть ли у открытой на правку схемы отметки прогресса: замена их сотрёт, и стоит предложить копию.
  Future<bool> editingHasProgress() async {
    final String? id = state.editingProjectId;
    return id != null && (await _replace?.hasProgress(id)) == true;
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
    await _loadSource(file.bytes, _nameFor(file.name));
  }

  /// Открывает фото в мастере: [quarterTurns], [crop] и [brush] приходят из сохранённого рецепта (T79).
  Future<void> _loadSource(
    Uint8List bytes,
    String fileName, {
    int quarterTurns = 0,
    CropRect crop = CropRect.full,
    ImportanceBrush brush = ImportanceBrush.empty,
  }) async {
    _timer?.cancel();
    final int preparation = ++_preparation;
    ++_calculation;
    final _Framed? prepared = await _prepareFramed(bytes, quarterTurns, crop, state.settings);
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
        brush: brush,
        brushing: false,
        brushUndoDepth: 0,
        preparedWidth: prepared.image.width,
        preparedHeight: prepared.image.height,
        sourceAspect: prepared.aspect,
        step: ImageWizardStep.edit,
        opening: false,
        masks: maskSet,
        clearMasks: maskSet == null,
        source: bytes,
        prepared: prepared.png,
        quarterTurns: quarterTurns,
        crop: crop,
        name: state.name.isEmpty ? fileName : state.name,
        clearPreview: true,
        clearProblem: true,
        clearSizeHint: true,
      ),
    );
    _hintKey = null;
    _sizeTouched = state.editing;
    _image = prepared.image;
    _appliedCrop = prepared.applied;
    _rebuildImportance();
    _schedule(immediate: true);
  }

  /// Поворот на 90° (по умолчанию по часовой); рамка задана в повёрнутых осях, поэтому сбрасывается.
  ///
  /// Высота ([ImageToGridSettings.rows]) остаётся: рамка по ней подгоняется заново в новых осях (T88c).
  Future<void> rotate({bool clockwise = true}) => _reshape(
    quarterTurns: (state.quarterTurns + (clockwise ? 1 : 3)) % 4,
    crop: CropRect.full,
    aspect: state.sourceAspect > 0 ? 1 / state.sourceAspect : null,
  );

  Future<void> setCrop(CropRect crop) => _reshape(quarterTurns: state.quarterTurns, crop: crop);

  /// Результат редактора обрезки (T88c): с чипом пропорций высота подстраивается под рамку (при текущей ширине), со
  /// свободной рамкой высота снова считается по фото. Последнее действие главнее.
  Future<void> setCropResult(CropRect crop, {double? aspect}) {
    final ImageToGridSettings now = state.settings;
    _sizeTouched = true;
    final ImageToGridSettings next = aspect == null
        ? now.copyWith(clearRows: true)
        : now.copyWith(
            rows: GridSizing.rowsForAspect(
              aspect: aspect,
              geometry: now.geometry,
              metrics: now.metrics,
              columns: now.columns,
            ),
          );
    return _reshape(quarterTurns: state.quarterTurns, crop: crop, settings: next);
  }

  Future<void> _reshape({
    required int quarterTurns,
    required CropRect crop,
    ImageToGridSettings? settings,
    double? aspect,
  }) async {
    final Uint8List? source = state.source;
    if (source == null) {
      return;
    }
    final ImageToGridSettings next = settings ?? state.settings;
    final double? known = aspect ?? (state.sourceAspect > 0 ? state.sourceAspect : null);
    _timer?.cancel();
    final int preparation = ++_preparation;
    ++_calculation;
    _hintKey = null;
    emit(
      state.copyWith(
        quarterTurns: quarterTurns,
        crop: crop,
        settings: next,
        catalogColors: _countCatalog(next),
        calculating: true,
        clearProblem: true,
        clearSizeHint: true,
      ),
    );
    final _Framed? prepared = await _prepareFramed(source, quarterTurns, crop, next, knownAspect: known);
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
    _appliedCrop = prepared.applied;
    _autoImportance = maskSet?.importance();
    _subjectMask = maskSet?.subjectOrPerson;
    emit(
      state.copyWith(
        prepared: prepared.png,
        masks: maskSet,
        clearMasks: maskSet == null,
        preparedWidth: prepared.image.width,
        preparedHeight: prepared.image.height,
        sourceAspect: prepared.aspect,
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

  /// Готовит картинку под рамку, нужную настройкам (T88c): с заданной высотой рамка пользовательницы подгоняется
  /// ([FramePlanner]), иначе берётся как есть. Пропорции всей картинки [knownAspect] неизвестны только при открытии
  /// файла: тогда они узнаются по первой подготовке, и при необходимости картинка готовится ещё раз.
  Future<_Framed?> _prepareFramed(
    Uint8List bytes,
    int quarterTurns,
    CropRect crop,
    ImageToGridSettings settings, {
    double? knownAspect,
  }) async {
    CropRect applied = knownAspect == null ? crop : ImageWizardState.effectiveCropOf(knownAspect, crop, settings);
    ({Uint8List png, SourceImage image})? prepared = await _prepareImage(bytes, quarterTurns, applied);
    if (prepared == null) {
      return null;
    }
    final double aspect = knownAspect ?? prepared.image.width / prepared.image.height * crop.height / crop.width;
    if (knownAspect == null) {
      final CropRect wanted = ImageWizardState.effectiveCropOf(aspect, crop, settings);
      if (wanted != crop) {
        prepared = await _prepareImage(bytes, quarterTurns, wanted);
        if (prepared == null) {
          return null;
        }
        applied = wanted;
      }
    }
    return (png: prepared.png, image: prepared.image, aspect: aspect, applied: applied);
  }

  /// Подгоняет подготовленную картинку под рамку, которой требуют текущие настройки (высота, вписывание и ширина её
  /// меняют). `false` — пока готовили, расчёт устарел или картинку не удалось прочитать.
  Future<bool> _syncImage(int calculation, ImageToGridSettings settings) async {
    final Uint8List? source = state.source;
    if (source == null || _image == null || _frameFits(settings)) {
      return true;
    }
    final CropRect wanted = ImageWizardState.effectiveCropOf(state.sourceAspect, state.crop, settings);
    final ({Uint8List png, SourceImage image})? prepared = await _prepareImage(source, state.quarterTurns, wanted);
    if (isClosed || calculation != _calculation) {
      return false;
    }
    if (prepared == null) {
      emit(state.copyWith(calculating: false, problem: ImageWizardProblem.unreadable));
      return false;
    }
    final ImageMaskSet? maskSet = await _findMasks(prepared.png, prepared.image);
    if (isClosed || calculation != _calculation) {
      return false;
    }
    _image = prepared.image;
    _appliedCrop = wanted;
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
    return true;
  }

  /// Подготовленная картинка уже взята по рамке, которой требуют [settings].
  bool _frameFits(ImageToGridSettings settings) =>
      ImageWizardState.effectiveCropOf(state.sourceAspect, state.crop, settings) == _appliedCrop;

  /// Станок и квадратное плетение не оставляют полей: вписывание принудительно «обрезать» (T88c).
  ImageToGridSettings _fitAllowed(ImageToGridSettings settings) =>
      settings.supportsMargins || settings.fit == FrameFit.crop ? settings : settings.copyWith(fit: FrameFit.crop);

  void setTechnique(Technique technique) => _change(_fitAllowed(state.settings.copyWith(technique: technique)));

  /// Высота вышивки в сантиметрах (шаг 5 см): клетки считаются по канве. Применяется как любая правка размера, то есть
  /// после паузы, а не на каждый тик ползунка.
  void setHeightCm(double cm) {
    _sizeTouched = true;
    _change(state.settings.copyWith(rows: state.settings.fabric.cellsForCm(ImageToGridSettings.snapCm(cm))));
  }

  /// Высота схемы из бисера в рядах.
  void setRows(int rows) {
    _sizeTouched = true;
    _change(state.settings.copyWith(rows: rows));
  }

  /// «По фото»: высота снова считается по пропорциям фото, рамка обрезки пользовательницы остаётся.
  void clearHeight() {
    _sizeTouched = true;
    _change(state.settings.copyWith(clearRows: true));
  }

  /// «Обрезать» или «Оставить поля»; там, где поля невозможны (станок, квадрат), всегда «Обрезать».
  void setFit(FrameFit fit) => _change(_fitAllowed(state.settings.copyWith(fit: fit)));

  /// Бисер или вышивка. Ширина и число цветов возвращаются к значениям по умолчанию ремесла: вышивка крупнее
  /// бисера (60 см и 50 цветов, T71). Контуры-бэкстич по умолчанию выключены.
  void setCraft(Craft craft) {
    final ImageToGridSettings now = state.settings;
    if (now.craft == craft) {
      return;
    }
    _change(
      craft == Craft.crossStitch
          ? now.copyWith(
              technique: Technique.defaultFor(craft),
              columns: now.fabric.cellsForCm(ImageToGridSettings.defaultStitchWidthCm),
              maxColors: ImageToGridSettings.defaultStitchColors,
              backstitch: false,
              clearRows: true,
              fit: FrameFit.crop,
            )
          : now.copyWith(
              technique: Technique.defaultFor(craft),
              columns: ImageToGridSettings.defaultColumns,
              maxColors: ImageToGridSettings.defaultMaxColors,
              clearRows: true,
              fit: FrameFit.crop,
            ),
    );
  }

  /// Другая канва: ширина работы в сантиметрах остаётся прежней, клетки пересчитываются.
  void setFabric(Fabric fabric) {
    _change(state.settings.withFabric(fabric));
  }

  /// Цвет канвы: фон схемы (невышитые места).
  void setFabricColor(Rgb color) => _change(state.settings.copyWith(fabric: state.settings.fabric.withColor(color)));

  /// Производитель мулине для схемы: в новой схеме запоминается как бренд по умолчанию.
  Future<void> setFlossBrand(String brand) async {
    if (brand == _flossBrand) {
      return;
    }
    _flossBrand = brand;
    emit(state.copyWith(flossBrand: brand, catalogColors: _countCatalog(state.settings)));
    if (_image != null) {
      _schedule();
    }
    // При правке готовой схемы выбор остаётся за этой схемой и не меняет бренд для новых (T101).
    if (!state.editing) await _settings.write(SettingKeys.defaultFlossBrand, brand);
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

  /// Добирать нитки других производителей мулине (T86). Число подходящих позиций каталога меняется, пересчитываем.
  void setOtherBrands({required bool value}) => _change(state.settings.copyWith(otherBrands: value));

  /// «Авто» в выборе брендов добора (T90): берётся любой бренд каталога.
  void setOtherBrandsAuto() => _change(state.settings.copyWith(otherBrandsOnly: const <String>{}));

  /// Отметить или снять бренд [brand] в выборе брендов добора (T90); если не осталось ни одного, снова «Авто».
  void toggleOtherBrand(String brand) {
    final Set<String> next = <String>{...state.settings.otherBrandsOnly};
    if (!next.remove(brand)) next.add(brand);
    _change(state.settings.copyWith(otherBrandsOnly: next));
  }

  /// Сила подъёма глубоких теней фото, 0..100 %; `null` — «Авто» (T87). Действует у вышивки с палитрой из каталога.
  void setShadows(int? value) =>
      _change(value == null ? state.settings.copyWith(clearShadows: true) : state.settings.copyWith(shadows: value));

  /// Смешанная техника: полукресты поверх крестов (T72).
  void setMixedStitches({required bool value}) => _change(state.settings.copyWith(mixedStitches: value));

  /// Брать цвета только из запаса (T34).
  void setOnlyStash({required bool value}) => _change(state.settings.copyWith(onlyStash: value));

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
        : PreparedFrame(width: image.width, height: image.height, quarterTurns: state.quarterTurns, crop: _appliedCrop);
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
    // Лицо найдено на картинке, взятой по подогнанной рамке: переводим его в доли всей картинки (T88c).
    final CropRect now = state.effectiveCrop;
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

  /// Применяет подсказку размера одним касанием: ширина и число цветов (T61). Заданная высота остаётся (T88c).
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
              .copyWith(columns: c.columns, maxColors: c.colors, paletteSource: PaletteSource.free, clearRows: true)
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
      // Размер по умолчанию берётся из подсказки, пока его никто не менял (T66). У вышивки по умолчанию 60 см и
      // 50 цветов (T71): подсказка только предлагается кнопкой «Применить».
      if (hint != null && !_sizeTouched && base.craft == Craft.beading) {
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
      settings.catalogFor(_catalogColors, brand: _brandFor(settings), stash: _stash).length;

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
    // Картинка ещё не подогнана под новую высоту: черновик по ней вышел бы с искажёнными пропорциями.
    if (!_frameFits(state.settings)) {
      return;
    }
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
    if (state.stashEmpty) {
      // В запасе нет ни одного подходящего цвета: показываем подсказку, а не рисуем схему из чужих цветов (T34).
      if (!draft && calculation == _calculation && !isClosed) {
        emit(state.copyWith(calculating: false));
      }
      return;
    }
    // Без подгонки под высоту расчёт стартует сразу, без лишнего ожидания.
    if (!draft && !_frameFits(settings) && !await _syncImage(calculation, settings)) {
      return;
    }
    if (draft) {
      _draftRunning = true;
    }
    GeneratedPattern? pattern;
    try {
      pattern = await _runner.run(
        settings.toRequest(
          image: _image ?? image,
          frame: settings.rows == null ? null : ImageWizardState.planOf(state.sourceAspect, state.crop, settings),
          catalog: _catalogColors,
          brand: _brandFor(settings),
          stash: _stash,
          importance: _importance,
          masks: settings.useMasks ? state.masks : null,
          subjectMask: _subjectMask,
          draft: draft,
          draftMaxCells: draft ? ImageToGridSettings.draftMaxCells : null,
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
              flossEstimate: pattern == null ? null : estimateFlossForGenerated(pattern, palette, settings.metrics),
              calculating: false,
              clearProblem: true,
            ),
    );
    if (palette != null) unawaited(_computeHint());
  }

  bool get canPrint =>
      _printer != null && state.flossEstimate != null && state.previewSettings?.craft == Craft.crossStitch;

  /// Размер показанной схемы для окна настроек печати.
  PrintSummary? get printSummary {
    final GeneratedPattern? pattern = state.preview;
    final PaletteSnapshot? palette = state.previewPalette;
    if (pattern == null || palette == null) return null;
    return PrintSummary(columns: pattern.grid.width, rows: pattern.grid.height, colors: palette.length);
  }

  Future<PrintOptions> loadPrintOptions() => PrintOptionsStore(_settings).load();

  /// PDF показанной схемы (T80): настройки запоминаются, схема не сохраняется.
  Future<Result<PatternPdf>> exportPdf(PrintOptions options) async {
    final PatternPrinter? printer = _printer;
    final GeneratedPattern? pattern = state.preview;
    final PaletteSnapshot? palette = state.previewPalette;
    final ImageToGridSettings? settings = state.previewSettings;
    final GridPattern? printable = pattern == null || palette == null || settings == null
        ? null
        : printablePatternOf(pattern, palette, settings.metrics);
    if (printer == null || printable == null) {
      return const Err<PatternPdf>(ValidationFailure('Схема ещё не посчитана'));
    }
    await PrintOptionsStore(_settings).save(options);
    final String title = state.name.trim().isEmpty ? 'Схема' : state.name.trim();
    final Result<Uint8List> pdf = await printer.renderPdf(title: title, pattern: printable, options: options);
    return pdf.map((bytes) => PatternPdf(fileName: '${ExportPatternPdf.fileNameOf(title)}.pdf', bytes: bytes));
  }

  /// Сохраняет посчитанную схему проектом. Кнопка доступна, только когда [ImageWizardState.canSave].
  ///
  /// При правке готовой схемы (T79) заменяет её сетку; [asCopy] сохраняет новым проектом, а прежний не трогает.
  Future<void> save({bool asCopy = false}) async {
    final GeneratedPattern? pattern = state.preview;
    if (!state.canSave || pattern == null) {
      return;
    }
    if (state.name.trim().isEmpty) {
      emit(state.copyWith(problem: ImageWizardProblem.invalidName));
      return;
    }
    emit(state.copyWith(step: ImageWizardStep.saving, clearProblem: true));
    Result<Project> created;
    final String? editing = state.editingProjectId;
    try {
      created = editing != null && !asCopy && _replace != null
          ? await _replace(
              projectId: editing,
              name: state.name,
              metrics: state.settings.metrics,
              generated: pattern,
            )
          : await _create(
              name: state.name,
              technique: state.settings.technique,
              metrics: state.settings.metrics,
              pattern: pattern,
            );
    } on Object {
      // Сбой драйвера или нехватка памяти на огромной схеме: без этого мастер навсегда остался бы в «Сохраняю…».
      created = const Err<Project>(StorageFailure('Не удалось записать схему'));
    }
    if (isClosed) {
      return;
    }
    switch (created) {
      case Success<Project>(:final Project value):
        await _saveRecipe(value.id);
        // Места на стойке, выбранные при печати из мастера, закрепляются за новой вышивкой.
        final PrintOptionsStore store = PrintOptionsStore(_settings);
        await store.save(await store.load(), projectId: value.id);
        if (isClosed) return;
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

  /// Запоминает, из чего собрана схема, чтобы её можно было открыть в мастере. Сбой записи схему не отменяет.
  Future<void> _saveRecipe(String projectId) async {
    final Uint8List? source = state.source;
    if (_recipes == null || source == null) return;
    try {
      final ImageRecipe recipe = ImageRecipe(
        source: source,
        quarterTurns: state.quarterTurns,
        crop: state.crop,
        brush: state.brush,
        settings: state.settings,
        flossBrand: _flossBrand,
      );
      final GenerationBuild? build = await _generationBuild?.load();
      await _recipes.save(projectId, build == null ? recipe : recipe.stamped(build));
    } on Object {
      // Без рецепта схема просто не откроется на правку.
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

/// Подготовленная картинка: PNG, пиксели для конвейера, пропорции всей повёрнутой картинки и рамка, по которой взято.
typedef _Framed = ({Uint8List png, SourceImage image, double aspect, CropRect applied});
