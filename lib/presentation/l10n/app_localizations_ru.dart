// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Канитель';

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
  String get settingsDefaultFlossBrand => 'Производитель мулине';

  @override
  String get settingsSectionData => 'Данные';

  @override
  String get settingsBackup => 'Резервная копия';

  @override
  String get settingsSync => 'Синхронизация с iCloud';

  @override
  String get settingsSoon => 'Скоро';

  @override
  String get settingsBackupCreate => 'Создать резервную копию';

  @override
  String get settingsRestore => 'Восстановить из файла';

  @override
  String get projectShareFile => 'Поделиться файлом';

  @override
  String get ok => 'Понятно';

  @override
  String importConfirmTitle(int count) {
    return 'В файле проектов: $count';
  }

  @override
  String importConflictsNote(int count) {
    return 'Уже есть в библиотеке: $count';
  }

  @override
  String get importAction => 'Добавить в библиотеку';

  @override
  String get importAsNew => 'Добавить как новые';

  @override
  String get importSkipExisting => 'Пропустить уже существующие';

  @override
  String get importDoneTitle => 'Готово';

  @override
  String importDoneBody(int added, int skipped) {
    return 'Добавлено проектов: $added. Пропущено: $skipped.';
  }

  @override
  String get transferFailedGeneric => 'Не получилось. Попробуйте ещё раз.';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsSaveFailed => 'Не удалось сохранить настройку. Попробуй ещё раз.';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String get aboutTagline => 'Каждая бусина и каждый крестик на своём месте.';

  @override
  String get aboutCredits =>
      'Цвета ниток DMC: craft-color-codes, MakeBead (makebead.com), лицензия CC BY 4.0. DMC — торговая марка DMC, приложение с ней не связано. Цвета ниток «Гамма» и Anchor: firma-gamma.ru и crosti.ru. «Гамма» и Anchor — торговые марки своих владельцев, приложение с ними не связано.';

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
  String get bookWorkZoneTitle => 'Схема на странице';

  @override
  String get bookWorkZoneEdit => 'Обвести схему на фото';

  @override
  String get bookWorkZoneReset => 'Вся страница';

  @override
  String get bookWorkZoneHint => 'Потяни за края рамки, чтобы она обвела только схему. Ряды не выйдут за рамку.';

  @override
  String get bookWorkZoneRowCount => 'Рядов в схеме';

  @override
  String get bookWorkZoneRowCountManual => 'Задавать вручную';

  @override
  String get bookWorkZoneRowCountAuto => 'Высота ряда считается сама';

  @override
  String get bookWorkZoneRowCountUnset => 'не задано';

  @override
  String get bookWorkZoneMore => 'Больше рядов';

  @override
  String get bookWorkZoneLess => 'Меньше рядов';

  @override
  String get bookWorkZoneHandle => 'Край схемы';

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
  String get bookWorkPageHasMarkup => 'Пометки';

  @override
  String get bookWorkMarker => 'Маркер';

  @override
  String get bookWorkMarkerBack => 'Линейка';

  @override
  String get bookWorkMarkerEraser => 'Ластик';

  @override
  String get bookWorkMarkerUndo => 'Отменить';

  @override
  String get bookWorkMarkerRedo => 'Вернуть';

  @override
  String get bookWorkMarkerShow => 'Пометки';

  @override
  String get bookWorkMarkerThin => 'Тонкий';

  @override
  String get bookWorkMarkerMedium => 'Средний';

  @override
  String get bookWorkMarkerWide => 'Широкий';

  @override
  String get bookWorkMarkerYellow => 'Жёлтый';

  @override
  String get bookWorkMarkerPink => 'Розовый';

  @override
  String get bookWorkMarkerBlue => 'Голубой';

  @override
  String get bookWorkMarkerGreen => 'Зелёный';

  @override
  String get bookWorkMarkerOrange => 'Оранжевый';

  @override
  String get bookWorkMarkerClear => 'Очистить страницу';

  @override
  String bookWorkMarkerClearMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пометок: $count. Это можно отменить.',
      many: 'Пометок: $count. Это можно отменить.',
      few: 'Пометки: $count. Это можно отменить.',
      one: 'Пометка: $count. Это можно отменить.',
    );
    return '$_temp0';
  }

  @override
  String get bookWorkMarkerHint => 'Один палец рисует, два пальца двигают и масштабируют страницу.';

  @override
  String get bookWorkMarkerEmpty => 'Пометок пока нет';

  @override
  String bookWorkPageItemMarked(int number) {
    return 'Страница $number, есть пометки';
  }

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
  String stitchLegendCrosses(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString крестика',
      many: '$countString крестиков',
      few: '$countString крестика',
      one: '$countString крестик',
    );
    return '$_temp0';
  }

  @override
  String stitchLegendPartials(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString неполных',
      many: '$countString неполных',
      few: '$countString неполных',
      one: '$countString неполный',
    );
    return '$_temp0';
  }

  @override
  String stitchLegendBackstitch(String length) {
    return 'бэкстич $length кл.';
  }

  @override
  String stitchLegendKnots(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString узелка',
      many: '$countString узелков',
      few: '$countString узелка',
      one: '$countString узелок',
    );
    return '$_temp0';
  }

  @override
  String stitchLegendCrossStrands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нитки',
      many: '$count ниток',
      few: '$count нитки',
      one: '$count нитку',
    );
    return 'крестик в $_temp0';
  }

  @override
  String stitchLegendBackStrands(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нитки',
      many: '$count ниток',
      few: '$count нитки',
      one: '$count нитку',
    );
    return 'бэкстич в $_temp0';
  }

  @override
  String get stitchLegendHighlighted => 'подсвечен';

  @override
  String get stitchLegendEmpty => 'В схеме пока нет ни одной нитки.';

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
  String libraryCardProgress(int percent) {
    return '$percent%';
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
  String get editorDone => 'Готово';

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
  String get catalogStockTitle => 'Мой запас';

  @override
  String catalogStockBadgeSemantic(String amount) {
    return 'в запасе $amount';
  }

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
  String get templateEntryTitle => 'Узор по шаблону';

  @override
  String get templateTitle => 'Узор по шаблону';

  @override
  String get templateCancel => 'Отмена';

  @override
  String get templateSave => 'Сохранить';

  @override
  String get templateSaving => 'Сохраняем…';

  @override
  String get templateSectionKind => 'Шаблон';

  @override
  String get templateSectionTechnique => 'Техника';

  @override
  String get templateSectionBead => 'Бисер';

  @override
  String get templateSectionSize => 'Размер';

  @override
  String get templateSectionColors => 'Цвета';

  @override
  String get templateSectionParams => 'Параметры';

  @override
  String get templateSectionSymmetry => 'Симметрия';

  @override
  String get templateSectionName => 'Название';

  @override
  String get templateKindStripes => 'Полосы';

  @override
  String get templateKindZigzag => 'Зигзаг';

  @override
  String get templateKindDiamonds => 'Ромбы';

  @override
  String get templateKindChecker => 'Шахматка';

  @override
  String get templateKindGradient => 'Градиент';

  @override
  String get templateKindBorder => 'Бордюр';

  @override
  String get templateWidth => 'Бусин в ряду';

  @override
  String get templateHeight => 'Рядов';

  @override
  String get templateStripeWidth => 'Ширина полосы';

  @override
  String get templateAmplitude => 'Размах зигзага';

  @override
  String get templateZigzagThickness => 'Толщина линии';

  @override
  String get templateGap => 'Просвет между линиями';

  @override
  String get templateDiamondSize => 'Размер ромба';

  @override
  String get templateCellSize => 'Сторона клетки';

  @override
  String get templateSteps => 'Ступеней градиента';

  @override
  String get templateBorderThickness => 'Толщина бордюра';

  @override
  String get templateAxis => 'Направление';

  @override
  String get templateAxisX => 'Слева направо';

  @override
  String get templateAxisY => 'Сверху вниз';

  @override
  String get templateSymmetryNone => 'Нет';

  @override
  String get templateSymmetryHorizontal => 'Лево и право';

  @override
  String get templateSymmetryVertical => 'Верх и низ';

  @override
  String get templateSymmetryBoth => 'Обе оси';

  @override
  String get templateSymmetryApproximate =>
      'В этой технике ряды сдвинуты на полбусины, поэтому отражение получится с небольшим сдвигом.';

  @override
  String get templateAddColor => 'Добавить цвет';

  @override
  String get templateRemoveColor => 'Убрать этот цвет';

  @override
  String get templatePickColorTitle => 'Выберите цвет';

  @override
  String get templateColorEmpty => 'Ничего не найдено';

  @override
  String get templateValueMinus => 'Меньше';

  @override
  String get templateValuePlus => 'Больше';

  @override
  String get templateProblemCatalog => 'Каталог цветов недоступен. Попробуйте ещё раз.';

  @override
  String get templateProblemParameters => 'Узор с такими параметрами не собрать. Попробуйте изменить размер или цвета.';

  @override
  String get templateProblemSave => 'Не удалось сохранить узор. Попробуйте ещё раз.';

  @override
  String get templateRetry => 'Повторить';

  @override
  String templateColorSlot(int number) {
    return 'Цвет $number';
  }

  @override
  String templateDefaultName(String kind, int width, int height) {
    return '$kind $width×$height';
  }

  @override
  String templatePreviewLabel(int width, int height) {
    return 'Предпросмотр узора: $width бусин в ряду, $height рядов';
  }

  @override
  String templateBeadSize(String shape, String size) {
    return '$shape $size';
  }

  @override
  String get templateDone => 'Готово';

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
  String get imageWizardLookChart => 'Схема';

  @override
  String get imageWizardLookRealistic => 'Как будет';

  @override
  String get imageWizardFullPreviewOpen => 'Во весь экран';

  @override
  String get imageWizardFullPreviewTitle => 'Предпросмотр';

  @override
  String get imageWizardFullPreviewBack => 'Параметры';

  @override
  String get imageWizardFullPreviewHint => 'Щипком меняйте масштаб, пальцем двигайте схему';

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
  String get imageWizardBeadSeries => 'Серия бисера';

  @override
  String get imageWizardSeriesDelica => 'Delica';

  @override
  String get imageWizardSeriesRound => 'Круглый Toho';

  @override
  String get imageWizardFinishSolid => 'Непрозрачный и матовый';

  @override
  String get imageWizardFinishLuster => 'Блестящий';

  @override
  String get imageWizardFinishTransparent => 'Прозрачный и с линией';

  @override
  String imageWizardCatalogFew(int available, int wanted) {
    return 'В выбранной серии и отделках всего $available цветов, а в схеме их до $wanted: попробуй другую серию или отделки, либо выбери «Любые».';
  }

  @override
  String imageWizardSizeHintBeads(int columns, int colors, String cm) {
    return 'Для этого фото лучше от $columns бусин по ширине и $colors цветов, около $cm см.';
  }

  @override
  String imageWizardSizeHintStitch(String fabric, String cm, int columns, int colors) {
    return 'Для этого фото на канве $fabric лучше от $cm см ($columns крестиков) и $colors цветов.';
  }

  @override
  String get imageWizardSizeHintLimit => 'Мелкие детали этого фото не получатся даже на самом большом размере.';

  @override
  String get imageWizardSizeHintApply => 'Применить';

  @override
  String get imageWizardSizeHintApplied => 'Размер подобран по фото';

  @override
  String get imageWizardPurpose => 'Размер по назначению';

  @override
  String get imageWizardPurposeBracelet => 'Браслет';

  @override
  String get imageWizardPurposePanel => 'Панно';

  @override
  String get imageWizardPurposePicture => 'Картина';

  @override
  String imageWizardPurposeBeads(int columns, String cm) {
    return '$columns бусин, около $cm см';
  }

  @override
  String imageWizardBeadsFewForFace(int columns) {
    return 'Бисера на такое лицо не хватает: на $columns столбцах глаза и губы не получатся. Возьми размер из подсказки или вышивку.';
  }

  @override
  String get imageWizardToStitch => 'Сделать вышивкой';

  @override
  String get imageWizardPreset => 'Детальность';

  @override
  String get imageWizardPresetSimpler => 'Проще';

  @override
  String get imageWizardPresetBalanced => 'Средне';

  @override
  String get imageWizardPresetAsIs => 'Как на фото';

  @override
  String get imageWizardPresetDetailed => 'Детально';

  @override
  String get imageWizardBrushTitle => 'Выделить важное';

  @override
  String get imageWizardBrushCropHint => 'Выделение сохранится при обрезке и повороте.';

  @override
  String get imageWizardBrushManual => 'Выделено вручную';

  @override
  String get imageWizardBrushReset => 'Сбросить выделение';

  @override
  String get imageWizardBrushDone => 'Готово';

  @override
  String get imageWizardBrushHint => 'Один палец рисует, два масштабируют.';

  @override
  String get imageWizardBrushShowAuto => 'Показать, что генератор считает важным';

  @override
  String get imageWizardBrushBrush => 'Кисть';

  @override
  String get imageWizardBrushEraser => 'Ластик';

  @override
  String get imageWizardBrushSmall => 'Малый';

  @override
  String get imageWizardBrushMedium => 'Средний';

  @override
  String get imageWizardBrushLarge => 'Крупный';

  @override
  String get imageWizardBrushClear => 'Очистить';

  @override
  String get imageWizardBrushClearMessage =>
      'Убрать все ваши мазки? Найденное генератором останется. Это можно отменить.';

  @override
  String get imageWizardBrushUndo => 'Отменить';

  @override
  String get imageWizardBrushEmpty => 'Генератор сам ничего не выделил. Проведите кистью по самому важному.';

  @override
  String get imageWizardBrushLegendFound => 'Нашёл генератор';

  @override
  String get imageWizardBrushLegendMine => 'Ваши мазки';

  @override
  String get imageWizardBrushCanvas => 'Картинка: проведите пальцем по важному';

  @override
  String imageWizardBrushSizeMenu(String name) {
    return 'Размер: $name';
  }

  @override
  String get imageWizardUseMasks => 'Выделять главное';

  @override
  String get imageWizardUseMasksHint => 'Лица и главный предмет получают больше цветов и деталей, фон — меньше.';

  @override
  String imageWizardFaceSmall(int cells, int min) {
    String _temp0 = intl.Intl.pluralLogic(
      cells,
      locale: localeName,
      other: 'Лицо шириной всего $cells бусин',
      many: 'Лицо шириной всего $cells бусин',
      few: 'Лицо шириной всего $cells бусины',
      one: 'Лицо шириной всего $cells бусина',
    );
    return '$_temp0: глаза и губы могут не получиться. Нужно хотя бы $min.';
  }

  @override
  String get imageWizardFaceCrop => 'Обрезать по лицу';

  @override
  String get imageWizardFaceWider => 'Схема шире';

  @override
  String get imageWizardBackground => 'Фон';

  @override
  String get imageWizardBackgroundKeep => 'Оставить';

  @override
  String get imageWizardBackgroundSimplify => 'Упростить';

  @override
  String get imageWizardBackgroundRemove => 'Убрать';

  @override
  String get imageWizardOutline => 'Обводка';

  @override
  String get imageWizardOutlineHint => 'Тёмная линия в одну бусину вокруг главного: силуэт виден сразу.';

  @override
  String get imageWizardCraft => 'Что делаем';

  @override
  String get imageWizardCraftBeading => 'Бисер';

  @override
  String get imageWizardCraftStitch => 'Вышивка';

  @override
  String get imageWizardFlossBrand => 'Производитель мулине';

  @override
  String get imageWizardFabric => 'Канва';

  @override
  String imageWizardFabricAida(int count) {
    return 'Аида $count';
  }

  @override
  String imageWizardFabricEvenweave(int count, int over) {
    return 'Равномерка $count, через $over';
  }

  @override
  String imageWizardFabricLinen(int count, int over) {
    return 'Лён $count, через $over';
  }

  @override
  String get imageWizardFabricColor => 'Цвет канвы';

  @override
  String get imageWizardCanvasWhite => 'Белая';

  @override
  String get imageWizardCanvasCream => 'Молочная';

  @override
  String get imageWizardCanvasLinen => 'Под лён';

  @override
  String get imageWizardCanvasGray => 'Серая';

  @override
  String get imageWizardCanvasBlack => 'Чёрная';

  @override
  String get imageWizardWidthCm => 'Ширина вышивки';

  @override
  String imageWizardCm(String cm) {
    return '$cm см';
  }

  @override
  String imageWizardSizeStitch(int columns, int rows, String width, String height) {
    return '$columns × $rows крестиков, $width × $height см';
  }

  @override
  String imageWizardWidthCrosses(int columns, String fabric, String perCm) {
    return '$columns крестиков в ширину. На канве $fabric их $perCm на сантиметр.';
  }

  @override
  String imageWizardStitchOnFabric(String fabric, String width, String height) {
    return 'На канве $fabric. Отрез берите с запасом по 5 см с каждой стороны: около $width × $height см.';
  }

  @override
  String get imageWizardFlossPalette => 'Цвета мулине';

  @override
  String get imageWizardFlossMissing => 'В каталоге нет мулине этого бренда, поэтому цвета подобраны свободно.';

  @override
  String get imageWizardBackstitch => 'Контуры';

  @override
  String get imageWizardBackstitchHint =>
      'Тёмная линия бэкстичем по краям предмета и резким границам: форма читается чётче.';

  @override
  String imageWizardBackstitchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стежков контура',
      many: '$count стежков контура',
      few: '$count стежка контура',
      one: '$count стежок контура',
    );
    return '$_temp0';
  }

  @override
  String get imageWizardBlends => 'Бленды из двух ниток';

  @override
  String imageWizardBlendsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      many: '$count мест',
      few: '$count места',
      one: 'Одно место',
    );
    return '$_temp0 лучше выходит, если взять две нитки в иголку. Включите, и они заменят одиночные цвета.';
  }

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

  @override
  String get startupFailedTitle => 'Не удалось открыть данные';

  @override
  String get startupFailedBody =>
      'Приложение не смогло открыть свои данные. Ничего не удалено: закройте приложение и откройте его снова. Если это повторяется, покажите разработчику текст ниже.';

  @override
  String get stitchLoadFailed => 'Не получилось открыть вышивку. Попробуй ещё раз.';

  @override
  String get stitchClose => 'Закрыть';

  @override
  String stitchPercent(int percent) {
    return '$percent%';
  }

  @override
  String get stitchToolTap => 'Касание';

  @override
  String get stitchToolStroke => 'Мазок';

  @override
  String get stitchToolArea => 'Область';

  @override
  String stitchCounter(int done, int total) {
    return 'Сделано $done из $total';
  }

  @override
  String stitchRemaining(int count) {
    return 'Осталось $count';
  }

  @override
  String get stitchColors => 'Цвета';

  @override
  String get stitchColorsTitle => 'Что осталось по цветам';

  @override
  String stitchColorProgress(int done, int total) {
    return '$done из $total';
  }

  @override
  String get stitchColorFinished => 'Цвет готов';

  @override
  String get stitchMarkColor => 'Отметить весь цвет';

  @override
  String get stitchUnmarkColor => 'Снять отметки с цвета';

  @override
  String get stitchHighlightColor => 'Подсветить на схеме';

  @override
  String get stitchResetHighlight => 'Сбросить выбор цвета';

  @override
  String get stitchGoToParked => 'К месту остановки';

  @override
  String get stitchClearParked => 'Снять метку';

  @override
  String get stitchParkHint =>
      'Долгое касание запоминает место, где остановилась. Ещё одно долгое касание по метке снимает её.';

  @override
  String get stitchBlocks => 'Блоки 10×10';

  @override
  String get stitchActionFloss => 'Нитки';

  @override
  String get stitchActionBlocks => 'Блоки';

  @override
  String get stitchActionSymbols => 'Символы';

  @override
  String get stitchActionParking => 'Парковка';

  @override
  String get stitchActionMore => 'Ещё';

  @override
  String get stitchActionUndo => 'Отменить';

  @override
  String stitchUndoMarked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count крестика',
      many: '$count крестиков',
      few: '$count крестика',
      one: '$count крестик',
    );
    return 'Отмечено $_temp0';
  }

  @override
  String stitchUndoUnmarked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count крестика',
      many: '$count крестиков',
      few: '$count крестика',
      one: '$count крестик',
    );
    return 'Снято $_temp0';
  }

  @override
  String get stitchZoomHint => 'Приблизьте, чтобы отметить касанием';

  @override
  String get stitchSymbols => 'Показать символы';

  @override
  String get stitchFinishTitle => 'Вся вышивка сделана. Отметить работу законченной?';

  @override
  String get stitchFinishYes => 'Готово';

  @override
  String get stitchFinishLater => 'Позже';

  @override
  String get stitchSaveFailed => 'Не получилось сохранить прогресс. Попробую ещё раз.';

  @override
  String get stitchParked => 'Место запомнено';

  @override
  String get flossTitle => 'Мулине';

  @override
  String flossFabricLine(String fabric) {
    return 'Канва: $fabric';
  }

  @override
  String flossFabricNeed(String width, String height, String stitchedWidth, String stitchedHeight, String margin) {
    return 'Кусок канвы: $width × $height см (вышивка $stitchedWidth × $stitchedHeight см и поля по $margin см)';
  }

  @override
  String get flossShoppingTitle => 'Что купить';

  @override
  String get flossBeadsTitle => 'Бисер на вышивке';

  @override
  String flossBeadPieces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count бусины',
      many: '$count бусин',
      few: '$count бусины',
      one: '$count бусина',
    );
    return '$_temp0';
  }

  @override
  String flossShareBeadLine(String bead, String pieces) {
    return '$bead — $pieces';
  }

  @override
  String get flossColorsTitle => 'По цветам схемы';

  @override
  String flossSkeins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мотка',
      many: '$count мотков',
      few: '$count мотка',
      one: '$count моток',
    );
    return '$_temp0';
  }

  @override
  String flossStitches(String count) {
    return '$count крестиков';
  }

  @override
  String flossPartials(String count) {
    return 'неполных: $count';
  }

  @override
  String flossBackstitch(String cells) {
    return 'бэкстич: $cells кл.';
  }

  @override
  String flossKnots(String count) {
    return 'узелков: $count';
  }

  @override
  String get flossBlendHint => 'Смешанная нить: в иголку идут обе нитки, мотки берут по каждой.';

  @override
  String flossTotal(String skeins) {
    return 'Итого: $skeins';
  }

  @override
  String get flossEstimateHint =>
      'Расход примерный, до мотка. Моток — 8 м из 6 сложений; одинаковые нитки разных цветов схемы складываются.';

  @override
  String get flossEmptyTitle => 'В схеме пока нет крестиков';

  @override
  String get flossEmptyMessage => 'Когда в схеме появятся цвета, здесь будет список ниток.';

  @override
  String get flossUnsupported => 'Расход мулине считается только для схемы на канве.';

  @override
  String flossShareHeader(String name) {
    return 'Мулине: $name';
  }

  @override
  String flossShareLine(int number, String thread, String skeins) {
    return '$number. $thread — $skeins';
  }

  @override
  String flossShareFabric(String fabric, String width, String height) {
    return 'Канва $fabric, кусок $width × $height см';
  }

  @override
  String flossShareReserve(int percent) {
    return 'Мотки указаны с запасом $percent%.';
  }

  @override
  String get flossScopeAll => 'Вся схема';

  @override
  String get flossScopeRemaining => 'Осталось вышить';

  @override
  String get flossScopeRemainingHint =>
      'Считаются невышитые крестики. Бэкстич, неполные крестики и узелки считаются целиком: их выполнение не отмечается.';

  @override
  String get flossRemainingDone => 'Все крестики вышиты';

  @override
  String get flossRemainingDoneMessage => 'На оставшуюся работу ниток больше не нужно.';

  @override
  String get flossStockCovered => 'Запаса ниток хватает на всю работу';

  @override
  String get flossStockCoveredRemaining => 'Запаса ниток хватает на оставшуюся работу';

  @override
  String flossStockShort(String skeins) {
    return 'Докупить: $skeins';
  }

  @override
  String flossStockShortThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'не хватает $count ниток',
      many: 'не хватает $count ниток',
      few: 'не хватает $count ниток',
      one: 'не хватает $count нитки',
    );
    return '$_temp0';
  }

  @override
  String flossStockNeedHave(String need, String have) {
    return 'Нужно $need · есть $have';
  }

  @override
  String flossStockAmount(String amount) {
    return '$amount мот.';
  }

  @override
  String get flossStockEnough => 'Хватает';

  @override
  String flossStockBuy(String skeins) {
    return 'Докупить: $skeins';
  }

  @override
  String get flossStockEdit => 'Изменить запас ниток';

  @override
  String flossStockSheetTitle(String thread) {
    return 'Запас: $thread';
  }

  @override
  String get flossStockSheetHint => 'Сколько мотков осталось. Начатый моток — доля: 0,5 — половина.';

  @override
  String get flossStockLess => 'Меньше';

  @override
  String get flossStockMore => 'Больше';

  @override
  String beadStockAmount(String amount) {
    return '$amount г';
  }

  @override
  String get beadStockWriteFailed => 'Не удалось сохранить запас бисера';

  @override
  String get flossStockClear => 'Нет в запасе';

  @override
  String get flossStockWriteFailed => 'Не удалось сохранить запас ниток';

  @override
  String get flossShareToBuy => 'Докупить:';

  @override
  String get flossShareAllCovered => 'Весь запас на месте: докупать ничего не нужно.';

  @override
  String get editorToolHalfStitch => 'Полукрестик';

  @override
  String get editorToolQuarterStitch => 'Четверть крестика';

  @override
  String get editorToolThreeQuarterStitch => '¾ крестика';

  @override
  String get editorToolPetit => 'Петит';

  @override
  String get editorToolBackstitch => 'Бэкстич';

  @override
  String get editorToolKnot => 'Французский узелок';

  @override
  String get editorHintPartial => 'Коснитесь клетки у нужного угла или диагонали. Повторное касание убирает стежок.';

  @override
  String get editorHintBackstitch =>
      'Коснитесь двух узлов подряд или проведите пальцем: между ними ляжет стежок. Узлы — углы, середины сторон и центры клеток.';

  @override
  String get editorHintBackstitchStart =>
      'Начало отмечено. Коснитесь следующего узла, повторное касание узла закончит линию.';

  @override
  String get editorHintKnot =>
      'Коснитесь узла: угла, середины стороны или центра клетки. Повторное касание убирает узелок.';

  @override
  String get editorHintEraserStitch =>
      'Коснитесь линии или узелка, чтобы убрать их; клетку очищает касание внутри неё, мазок стирает несколько клеток.';

  @override
  String get newStitchTitle => 'Новая вышивка';

  @override
  String get newStitchDefaultName => 'Новая вышивка';

  @override
  String get newStitchUnitCells => 'Крестики';

  @override
  String get newStitchUnitCm => 'Сантиметры';

  @override
  String get newStitchWidthCells => 'Ширина, крестиков';

  @override
  String get newStitchHeightCells => 'Высота, крестиков';

  @override
  String get newStitchWidthCm => 'Ширина, см';

  @override
  String get newStitchHeightCm => 'Высота, см';

  @override
  String newStitchSizeSummary(String width, String height, String widthCm, String heightCm) {
    return '$width × $height крестиков, на этой канве $widthCm × $heightCm см';
  }

  @override
  String newStitchSizeInvalid(int max) {
    return 'Размер: от 1 до $max крестиков по каждой стороне';
  }

  @override
  String get libraryDrawStitchPattern => 'Нарисовать схему вышивки';

  @override
  String get colorSheetAllBrands => 'Все';

  @override
  String get colorSheetBlend => 'Смесь двух ниток';

  @override
  String get colorSheetBlendHint =>
      'В иголку идут две нитки. Выберите каждую из каталога, цвет на схеме будет средним.';

  @override
  String colorSheetThread(int number, String code) {
    return 'Нитка $number: $code';
  }

  @override
  String get editorToolBead => 'Бусина';

  @override
  String get editorHintBead =>
      'Коснитесь узла, чтобы поставить бусину. Повторное касание значка инструмента выбирает другую бусину из каталога.';

  @override
  String get editorProblemNoBead => 'Сначала выберите бусину из каталога.';
}
