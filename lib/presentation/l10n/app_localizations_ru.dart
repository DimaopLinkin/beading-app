// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Бисер';

  @override
  String get libraryTitle => 'Мои работы';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionAppearance => 'Оформление';

  @override
  String get settingsThemeLabel => 'Тема';

  @override
  String get settingsThemeSystem => 'Как в системе';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsSectionWork => 'Работа';

  @override
  String get settingsKeepScreenAwake => 'Не гасить экран';

  @override
  String get settingsSymbolMode => 'Символы на схеме';

  @override
  String get settingsDefaultBrand => 'Производитель бисера';

  @override
  String get settingsSectionData => 'Данные';

  @override
  String get settingsBackup => 'Резервная копия';

  @override
  String get settingsSync => 'Синхронизация с iCloud';

  @override
  String get settingsSoon => 'Скоро';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsSaveFailed => 'Не удалось сохранить настройку. Попробуй ещё раз.';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String get aboutTagline => 'Каждая бусинка на своём месте. Плети с удовольствием!';

  @override
  String aboutVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get hiddenTitle => 'Секретный раздел';

  @override
  String get hiddenSectionName => 'Как к тебе обращаться';

  @override
  String get hiddenNameHint => 'Имя';

  @override
  String get hiddenSectionDates => 'Особые даты';

  @override
  String get hiddenDatesFooter => 'В эти дни приложение скажет что-нибудь особенное.';

  @override
  String get hiddenAddDate => 'Добавить дату';

  @override
  String get hiddenDateLabelHint => 'Название, например «День рождения»';

  @override
  String get hiddenDateDefaultLabel => 'Особый день';

  @override
  String get hiddenDateSave => 'Добавить';

  @override
  String get hiddenDateCancel => 'Отмена';

  @override
  String get hiddenDateRemove => 'Удалить дату';

  @override
  String get cancel => 'Отмена';

  @override
  String get settingsSectionDev => 'Для разработки';

  @override
  String get settingsGlassCheck => 'Проверка стекла';

  @override
  String get glassCheckTitle => 'Проверка стекла';

  @override
  String glassCheckReduceTransparency(String state) {
    return 'Уменьшить прозрачность: $state';
  }

  @override
  String glassCheckHighContrast(String state) {
    return 'Повышенная контрастность: $state';
  }

  @override
  String get glassCheckOn => 'вкл';

  @override
  String get glassCheckOff => 'выкл';

  @override
  String glassCheckSurface(String mode) {
    return 'Стекло: $mode';
  }

  @override
  String get glassCheckSurfaceGlass => 'прозрачное';

  @override
  String get glassCheckSurfaceOpaque => 'сплошное';

  @override
  String glassCheckFrames(int count) {
    return 'Кадров: $count';
  }

  @override
  String glassCheckAverage(String ms, String p95, String worst) {
    return 'Среднее $ms мс, 95% кадров до $p95 мс, худший $worst мс';
  }

  @override
  String glassCheckOverBudget(int slow, int jank) {
    return 'Дольше 8,3 мс: $slow, дольше 16,7 мс: $jank';
  }

  @override
  String get glassCheckProfileHint => 'Цифры верны только в профильной сборке: flutter run --profile.';

  @override
  String get glassCheckPause => 'Пауза';

  @override
  String get glassCheckResume => 'Продолжить';

  @override
  String get glassCheckReset => 'Сбросить цифры';

  @override
  String get libraryImportBook => 'Схема из книги';

  @override
  String get importBookTitle => 'Схема из книги';

  @override
  String get importBookCancel => 'Отмена';

  @override
  String get importPickHint => 'Сфотографируйте страницу книги или выберите готовые фото и PDF.';

  @override
  String get importSourceCamera => 'Снять на камеру';

  @override
  String get importSourcePhotos => 'Выбрать из Фото';

  @override
  String get importSourceFiles => 'Выбрать из Файлов (фото или PDF)';

  @override
  String get importPdfTitle => 'Страницы PDF';

  @override
  String importPdfSelected(int count, int total) {
    return 'Выбрано: $count из $total';
  }

  @override
  String get importPdfSelectAll => 'Все';

  @override
  String get importPdfClear => 'Снять';

  @override
  String get importPdfContinue => 'Продолжить';

  @override
  String importPdfPageLabel(int page) {
    return 'Страница $page';
  }

  @override
  String get importReviewTitle => 'Страницы схемы';

  @override
  String get importNameLabel => 'Название';

  @override
  String get importCraftBeading => 'Бисер';

  @override
  String get importCraftCrossStitch => 'Вышивка';

  @override
  String get importAddMore => 'Добавить ещё';

  @override
  String get importSubmit => 'Импортировать';

  @override
  String get importRotate => 'Повернуть';

  @override
  String get importCrop => 'Обрезать';

  @override
  String get importRemove => 'Убрать';

  @override
  String get importCropped => 'Обрезана';

  @override
  String importPageNumber(int number) {
    return 'Страница $number';
  }

  @override
  String get importCropTitle => 'Обрезка';

  @override
  String get importCropReset => 'Сбросить';

  @override
  String get importCropDone => 'Готово';

  @override
  String get importSaving => 'Сохраняем страницы…';

  @override
  String get importProblemSourceUnavailable => 'Нет доступа к камере или Фото. Разрешите его в настройках.';

  @override
  String get importProblemUnreadable => 'Не удалось прочитать картинку. Попробуйте другой файл.';

  @override
  String get importProblemPdfFailed => 'Не удалось открыть PDF.';

  @override
  String get importProblemSaveFailed => 'Не удалось сохранить схему. Проверьте свободное место.';

  @override
  String importStep(int number, int total) {
    return 'Шаг $number из $total';
  }

  @override
  String get importOpening => 'Открываем файл…';

  @override
  String get importRendering => 'Готовим страницы…';

  @override
  String get importProblemPdfEmpty => 'В этом PDF нет страниц. Выберите другой файл.';

  @override
  String get importPickAnother => 'Выбрать другой файл';

  @override
  String get importProblemNoPages => 'Выберите хотя бы одну страницу.';

  @override
  String get importProblemEmptyName => 'Введите название.';

  @override
  String bookWorkRow(int row) {
    return 'Ряд $row';
  }

  @override
  String get bookWorkPrevRow => 'Ряд назад';

  @override
  String get bookWorkNextRow => 'Следующий ряд';

  @override
  String bookWorkPageLabel(int current, int total) {
    return 'Страница $current из $total';
  }

  @override
  String get bookWorkPagesTitle => 'Страницы';

  @override
  String bookWorkPageItem(int number) {
    return 'Страница $number';
  }

  @override
  String get bookWorkDirection => 'Направление рядов';

  @override
  String get bookWorkDirectionDown => 'Сверху вниз';

  @override
  String get bookWorkDirectionUp => 'Снизу вверх';

  @override
  String get bookWorkResizeHandle => 'Высота линейки: потяни вверх или вниз';

  @override
  String get bookWorkPageEnd => 'Страница закончена';

  @override
  String get bookWorkNextPage => 'Следующая страница';

  @override
  String get bookWorkUndo => 'Отменить';

  @override
  String get bookWorkFitWidth => 'По ширине';

  @override
  String bookWorkZoomLevel(String scale) {
    return 'Масштаб ×$scale';
  }

  @override
  String get bookWorkCollapsePanel => 'Свернуть панель';

  @override
  String get bookWorkExpandPanel => 'Развернуть панель';

  @override
  String get bookWorkClose => 'Закрыть';

  @override
  String get bookWorkRulerSettings => 'Настройка линейки';

  @override
  String get bookWorkRulerHeight => 'Высота линейки';

  @override
  String get bookWorkRulerStep => 'Шаг сдвига';

  @override
  String get bookWorkRulerColor => 'Цвет подсветки';

  @override
  String get bookWorkColorYellow => 'Жёлтый';

  @override
  String get bookWorkColorGreen => 'Зелёный';

  @override
  String get bookWorkColorBlue => 'Синий';

  @override
  String get bookWorkColorPink => 'Розовый';

  @override
  String get bookWorkNotes => 'Заметки';

  @override
  String get bookWorkNotesHint => 'Что важно не забыть: цвета, где остановилась, что поменять';

  @override
  String get bookWorkDone => 'Готово';

  @override
  String get bookWorkLoadFailed => 'Схема не открылась. Закрой экран и попробуй ещё раз.';

  @override
  String get bookWorkSaveFailed =>
      'Не получилось сохранить, где ты остановилась. Проверь, есть ли место на устройстве.';

  @override
  String gridRowMarker(int row) {
    return 'Ряд $row';
  }

  @override
  String get bookWorkImageFailed => 'Не получилось показать эту страницу. Попробуй открыть её ещё раз.';

  @override
  String get librarySearchPlaceholder => 'Поиск';

  @override
  String get libraryNewProject => 'Новый проект';

  @override
  String get libraryEmptyTitle => 'Пока нет работ';

  @override
  String get libraryEmptyMessage => 'Нажмите «+», чтобы добавить первую схему.';

  @override
  String get libraryNoMatchesTitle => 'Ничего не найдено';

  @override
  String get libraryNoMatchesMessage => 'Попробуйте изменить запрос или сбросить фильтры.';

  @override
  String get libraryResetFilters => 'Сбросить фильтры';

  @override
  String get libraryLoadFailedTitle => 'Не удалось загрузить работы';

  @override
  String get libraryRetry => 'Повторить';

  @override
  String get craftBeading => 'Бисер';

  @override
  String get craftCrossStitch => 'Вышивка';

  @override
  String get statusIdea => 'Идея';

  @override
  String get statusInProgress => 'В работе';

  @override
  String get statusDone => 'Готово';

  @override
  String get techniqueLoom => 'Станок';

  @override
  String get techniquePeyote => 'Мозаика';

  @override
  String get techniqueBrick => 'Кирпичик';

  @override
  String get techniqueSquare => 'Квадратное';

  @override
  String get techniqueOffLoom => 'Без станка';

  @override
  String get techniqueCrossStitch => 'Крестик';

  @override
  String get techniqueTent => 'Полукрест';

  @override
  String libraryCardSubtitle(String craft, String technique) {
    return '$craft · $technique';
  }

  @override
  String libraryCardLastWorked(String status, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$status · $dateString';
  }

  @override
  String get projectRename => 'Переименовать';

  @override
  String get projectDuplicate => 'Дублировать';

  @override
  String get projectDelete => 'Удалить';

  @override
  String projectDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get projectDeleteMessage => 'Работа исчезнет из списка.';

  @override
  String get projectRenameTitle => 'Новое название';

  @override
  String get projectNamePlaceholder => 'Название';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonOk => 'Понятно';

  @override
  String get actionFailedTitle => 'Не получилось';

  @override
  String get actionFailedValidation => 'Проверьте название: оно не должно быть пустым или слишком длинным.';

  @override
  String get actionFailedNotFound => 'Этой работы уже нет.';

  @override
  String get actionFailedGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get newProjectCraftQuestion => 'Что будем делать?';

  @override
  String get newProjectNoEntries => 'Способы создания появятся в следующих версиях.';

  @override
  String get libraryAddSemantic => 'Добавить проект';

  @override
  String get weaveLoadFailed => 'Не получилось открыть схему. Попробуй ещё раз.';

  @override
  String get weaveClose => 'Закрыть';

  @override
  String weaveRowCounter(int row, int total) {
    return 'Ряд $row из $total';
  }

  @override
  String get weaveModeByRow => 'По ряду';

  @override
  String get weaveModeByBead => 'По бусине';

  @override
  String get weaveSymbols => 'Показать символы на бусинах';

  @override
  String get weaveBack => 'Назад';

  @override
  String get weaveNextBead => 'Следующая бусина';

  @override
  String get weaveRowDone => 'Ряд готов';

  @override
  String weaveRowCompleted(int row) {
    return 'Ряд $row готов';
  }

  @override
  String get weaveUndo => 'Отменить';

  @override
  String get weaveFinishTitle => 'Последний ряд готов. Отметить работу законченной?';

  @override
  String get weaveFinishYes => 'Готово';

  @override
  String get weaveFinishLater => 'Позже';

  @override
  String get weaveSaveFailed => 'Не получилось сохранить прогресс. Попробую ещё раз.';

  @override
  String weaveBeadProgress(int laid, int total) {
    return 'Бусина $laid из $total';
  }

  @override
  String get weaveDirRight => 'Нить идёт вправо';

  @override
  String get weaveDirLeft => 'Нить идёт влево';

  @override
  String get weaveDirDown => 'Нить идёт вниз';

  @override
  String get weaveDirUp => 'Нить идёт вверх';

  @override
  String get weaveWordChart => 'Бусины ряда';

  @override
  String get weaveEdit => 'Править схему';

  @override
  String get libraryDrawPattern => 'Нарисовать схему';

  @override
  String get newGridTitle => 'Новая схема';

  @override
  String get newGridCancel => 'Отмена';

  @override
  String get newGridCreate => 'Создать';

  @override
  String get newGridName => 'Название';

  @override
  String get newGridDefaultName => 'Новая схема';

  @override
  String get newGridTechnique => 'Техника';

  @override
  String get newGridWidth => 'Ширина, бусин';

  @override
  String get newGridHeight => 'Высота, бусин';

  @override
  String get newGridBead => 'Бисер';

  @override
  String newGridSizeCm(String width, String height) {
    return 'Получится примерно $width × $height см';
  }

  @override
  String get newGridSizeInvalid => 'Размер: от 1 до 500 бусин по каждой стороне';

  @override
  String get newGridFailed => 'Не удалось создать схему. Попробуй ещё раз.';

  @override
  String get editorToolBrush => 'Кисть';

  @override
  String get editorToolEraser => 'Ластик';

  @override
  String get editorToolFill => 'Заливка';

  @override
  String get editorToolPipette => 'Пипетка';

  @override
  String get editorToolReplace => 'Заменить цвет';

  @override
  String get editorToolSelection => 'Выделение';

  @override
  String get editorMirrorHorizontal => 'Зеркало по горизонтали';

  @override
  String get editorMirrorVertical => 'Зеркало по вертикали';

  @override
  String get editorMirrorNote =>
      'Для мозаики и кирпичика зеркало меняет местами ячейки, а не физическое расположение бусин.';

  @override
  String get editorRowsColumns => 'Ряды и столбцы';

  @override
  String get editorInsertRowAbove => 'Вставить ряд выше';

  @override
  String get editorInsertRowBelow => 'Вставить ряд ниже';

  @override
  String editorDeleteRow(int row) {
    return 'Удалить ряд $row';
  }

  @override
  String get editorInsertColumnLeft => 'Вставить столбец слева';

  @override
  String get editorInsertColumnRight => 'Вставить столбец справа';

  @override
  String editorDeleteColumn(int column) {
    return 'Удалить столбец $column';
  }

  @override
  String get editorTouchFirst => 'Сначала коснись схемы, чтобы выбрать место.';

  @override
  String get editorUndo => 'Отменить';

  @override
  String get editorRedo => 'Повторить';

  @override
  String get editorSymbols => 'Символы';

  @override
  String get editorPalette => 'Палитра';

  @override
  String get editorAddColor => 'Добавить цвет';

  @override
  String editorColorSwatch(String name) {
    return 'Цвет $name';
  }

  @override
  String get editorSaving => 'Сохраняется…';

  @override
  String get editorSaved => 'Сохранено';

  @override
  String get editorSaveFailed => 'Не удалось сохранить. Нажми, чтобы повторить.';

  @override
  String get editorLoadFailed => 'Не удалось открыть схему.';

  @override
  String get editorProblemNoColor => 'Сначала добавь цвет в палитру.';

  @override
  String get editorProblemPaletteFull => 'В палитре больше нет места.';

  @override
  String get editorProblemLimit => 'Схема уже самая большая.';

  @override
  String get editorProblemLast => 'Последний ряд или столбец удалить нельзя.';

  @override
  String get colorSheetTitle => 'Цвет';

  @override
  String get colorSheetDone => 'Готово';

  @override
  String get colorSheetName => 'Название';

  @override
  String get colorSheetRed => 'Красный';

  @override
  String get colorSheetGreen => 'Зелёный';

  @override
  String get colorSheetBlue => 'Синий';

  @override
  String get colorSheetCatalog => 'Из каталога';

  @override
  String get colorSheetSearch => 'Артикул или название';

  @override
  String get colorSheetNearest => 'Ближайшие';

  @override
  String get colorSheetNothing => 'Ничего не нашлось';

  @override
  String get colorSheetDelete => 'Удалить цвет из палитры';

  @override
  String get colorSheetDeleteHint => 'Бусины этого цвета на схеме станут пустыми.';

  @override
  String get newGridBeadDelica => 'Delica';

  @override
  String get newGridBeadRocaille => 'Рокайль';

  @override
  String get libraryCatalogSemantic => 'Каталог цветов';

  @override
  String get projectMaterials => 'Материалы';

  @override
  String get catalogTitleBead => 'Каталог бисера';

  @override
  String get catalogTitleFloss => 'Каталог ниток';

  @override
  String get catalogSearchPlaceholder => 'Артикул или название';

  @override
  String get catalogAllBrands => 'Все';

  @override
  String get catalogEmptyTitle => 'Ничего не найдено';

  @override
  String get catalogEmptyMessage => 'Попробуйте другой артикул или название.';

  @override
  String get catalogLoadFailedTitle => 'Не удалось открыть каталог';

  @override
  String catalogItemSemantic(String code, String name) {
    return '$code, $name';
  }

  @override
  String catalogSeriesAndSize(String brand, String series, String size) {
    return '$brand $series $size';
  }

  @override
  String get catalogSimilarTitle => 'Похожие цвета';

  @override
  String get catalogSimilarNone => 'Похожих цветов не нашлось';

  @override
  String get catalogSimilarFailed => 'Не удалось подобрать похожие цвета';

  @override
  String catalogSimilarityPercent(int percent) {
    return '$percent%';
  }

  @override
  String catalogSimilaritySemantic(String code, String name, int percent, String level) {
    return '$code, $name, похожесть $percent процентов, $level';
  }

  @override
  String get similarityNearlyIdentical => 'почти не отличить';

  @override
  String get similarityVeryClose => 'очень похож';

  @override
  String get similarityClose => 'похож';

  @override
  String get similarityNoticeable => 'заметно отличается';

  @override
  String get catalogColorApproximate => 'Цвет на экране может чуть отличаться от настоящего бисера.';

  @override
  String get catalogClose => 'Закрыть';

  @override
  String get materialsTitle => 'Материалы';

  @override
  String get materialsReserveNone => 'По схеме';

  @override
  String materialsReserveWith(int percent) {
    return 'С запасом $percent%';
  }

  @override
  String materialsPieces(String count) {
    return '$count шт';
  }

  @override
  String materialsGramsLess(String grams) {
    return '< $grams г';
  }

  @override
  String materialsGrams(String grams) {
    return '$grams г';
  }

  @override
  String get materialsTotal => 'Итого';

  @override
  String materialsBeadSize(String size) {
    return 'Размер бисера: $size';
  }

  @override
  String get materialsWeightHint => 'Вес примерный: у разных отделок бисер весит по-разному.';

  @override
  String get materialsShare => 'Поделиться списком';

  @override
  String get materialsEmptyTitle => 'В схеме пока нет бусин';

  @override
  String get materialsEmptyMessage => 'Когда в схеме появятся цвета, здесь будет список.';

  @override
  String get materialsUnsupported => 'Для этой схемы размер бусины не задан, поэтому материалы посчитать нельзя.';

  @override
  String get materialsLoadFailedTitle => 'Не удалось посчитать материалы';

  @override
  String materialsShareSubject(String name) {
    return 'Материалы: $name';
  }

  @override
  String materialsShareHeader(String name) {
    return 'Материалы: $name';
  }

  @override
  String materialsShareBeads(String size) {
    return 'Бисер $size';
  }

  @override
  String materialsShareLine(int number, String color, String pieces, String grams) {
    return '$number. $color — $pieces, $grams';
  }

  @override
  String materialsShareTotal(String pieces, String grams) {
    return 'Итого: $pieces, $grams';
  }

  @override
  String materialsShareReserve(int percent) {
    return 'Количество указано с запасом $percent%.';
  }

  @override
  String get materialsShareApprox => 'Вес приблизительный.';

  @override
  String get shareFailed => 'Не удалось поделиться. Попробуйте ещё раз.';

  @override
  String get beadShapeDelica => 'Delica';

  @override
  String get beadShapeRocaille => 'рокайль';

  @override
  String get libraryImageToGrid => 'Схема из картинки';

  @override
  String get imageWizardTitle => 'Схема из картинки';

  @override
  String get imageWizardCancel => 'Отмена';

  @override
  String get imageWizardPickHint => 'Выберите картинку: по ней получится схема для плетения.';

  @override
  String get imageWizardSourceCamera => 'Сделать снимок';

  @override
  String get imageWizardSourcePhotos => 'Выбрать из Фото';

  @override
  String get imageWizardSourceFiles => 'Выбрать из Файлов';

  @override
  String get imageWizardOpening => 'Открываю картинку…';

  @override
  String get imageWizardRotate => 'Повернуть';

  @override
  String get imageWizardCrop => 'Обрезать';

  @override
  String get imageWizardPreviewLabel => 'Предпросмотр схемы';

  @override
  String get imageWizardOriginalLabel => 'Исходная картинка';

  @override
  String get imageWizardCompareHint => 'Удерживайте схему, чтобы увидеть исходную картинку';

  @override
  String get imageWizardCalculating => 'Считаю схему…';

  @override
  String imageWizardSize(int columns, int rows) {
    return '$columns × $rows бусин';
  }

  @override
  String get imageWizardTechnique => 'Техника';

  @override
  String get imageWizardBeadSize => 'Бисер';

  @override
  String get imageWizardWidth => 'Ширина схемы';

  @override
  String get imageWizardColorCount => 'Цветов в схеме';

  @override
  String get imageWizardPalette => 'Цвета бисера';

  @override
  String get imageWizardPaletteCatalog => 'Из каталога';

  @override
  String get imageWizardPaletteFree => 'Любые';

  @override
  String get imageWizardCatalogMissing => 'В каталоге нет бисера такого размера, поэтому цвета подобраны свободно.';

  @override
  String get imageWizardDither => 'Плавные переходы';

  @override
  String get imageWizardDitherHint => 'Лучше передаёт оттенки, но схема становится пестрее.';

  @override
  String get imageWizardName => 'Название';

  @override
  String get imageWizardSave => 'Сохранить схему';

  @override
  String get imageWizardSaving => 'Сохраняю…';

  @override
  String get imageWizardProblemSourceUnavailable =>
      'Не удалось открыть выбранный источник. Проверьте доступ к Фото или камере.';

  @override
  String get imageWizardProblemUnreadable => 'Не получилось прочитать картинку. Выберите другую.';

  @override
  String get imageWizardProblemCalculation =>
      'Не удалось посчитать схему. Измените параметры или выберите другую картинку.';

  @override
  String get imageWizardProblemSave => 'Не удалось сохранить схему. Попробуйте ещё раз.';

  @override
  String get imageWizardProblemName => 'Дайте схеме название (до 120 символов).';
}
