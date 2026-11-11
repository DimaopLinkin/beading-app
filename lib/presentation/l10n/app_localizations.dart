import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// Название приложения
  ///
  /// In ru, this message translates to:
  /// **'Бисер'**
  String get appTitle;

  /// Заголовок главного экрана со списком проектов
  ///
  /// In ru, this message translates to:
  /// **'Мои работы'**
  String get libraryTitle;

  /// Заголовок экрана настроек и подпись кнопки открытия настроек
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsThemeLabel;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsSectionWork.
  ///
  /// In ru, this message translates to:
  /// **'Работа'**
  String get settingsSectionWork;

  /// No description provided for @settingsKeepScreenAwake.
  ///
  /// In ru, this message translates to:
  /// **'Не гасить экран'**
  String get settingsKeepScreenAwake;

  /// No description provided for @settingsSymbolMode.
  ///
  /// In ru, this message translates to:
  /// **'Символы на схеме'**
  String get settingsSymbolMode;

  /// No description provided for @settingsDefaultBrand.
  ///
  /// In ru, this message translates to:
  /// **'Производитель бисера'**
  String get settingsDefaultBrand;

  /// No description provided for @settingsSectionData.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get settingsSectionData;

  /// No description provided for @settingsBackup.
  ///
  /// In ru, this message translates to:
  /// **'Резервная копия'**
  String get settingsBackup;

  /// No description provided for @settingsSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация с iCloud'**
  String get settingsSync;

  /// No description provided for @settingsSoon.
  ///
  /// In ru, this message translates to:
  /// **'Скоро'**
  String get settingsSoon;

  /// Пункт настроек: отдать все проекты одним файлом
  ///
  /// In ru, this message translates to:
  /// **'Создать резервную копию'**
  String get settingsBackupCreate;

  /// Пункт настроек: импорт файла .biser
  ///
  /// In ru, this message translates to:
  /// **'Восстановить из файла'**
  String get settingsRestore;

  /// Действие над проектом: отправить файл .biser
  ///
  /// In ru, this message translates to:
  /// **'Поделиться файлом'**
  String get projectShareFile;

  /// No description provided for @ok.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get ok;

  /// No description provided for @importConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'В файле проектов: {count}'**
  String importConfirmTitle(int count);

  /// No description provided for @importConflictsNote.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть в библиотеке: {count}'**
  String importConflictsNote(int count);

  /// No description provided for @importAction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в библиотеку'**
  String get importAction;

  /// No description provided for @importAsNew.
  ///
  /// In ru, this message translates to:
  /// **'Добавить как новые'**
  String get importAsNew;

  /// No description provided for @importSkipExisting.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить уже существующие'**
  String get importSkipExisting;

  /// No description provided for @importDoneTitle.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get importDoneTitle;

  /// No description provided for @importDoneBody.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено проектов: {added}. Пропущено: {skipped}.'**
  String importDoneBody(int added, int skipped);

  /// No description provided for @transferFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось. Попробуйте ещё раз.'**
  String get transferFailedGeneric;

  /// No description provided for @settingsAbout.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get settingsAbout;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройку. Попробуй ещё раз.'**
  String get settingsSaveFailed;

  /// No description provided for @aboutTitle.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In ru, this message translates to:
  /// **'Каждая бусинка на своём месте. Плети с удовольствием!'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String aboutVersion(String version);

  /// No description provided for @hiddenTitle.
  ///
  /// In ru, this message translates to:
  /// **'Секретный раздел'**
  String get hiddenTitle;

  /// No description provided for @hiddenSectionName.
  ///
  /// In ru, this message translates to:
  /// **'Как к тебе обращаться'**
  String get hiddenSectionName;

  /// No description provided for @hiddenNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get hiddenNameHint;

  /// No description provided for @hiddenSectionDates.
  ///
  /// In ru, this message translates to:
  /// **'Особые даты'**
  String get hiddenSectionDates;

  /// No description provided for @hiddenDatesFooter.
  ///
  /// In ru, this message translates to:
  /// **'В эти дни приложение скажет что-нибудь особенное.'**
  String get hiddenDatesFooter;

  /// No description provided for @hiddenAddDate.
  ///
  /// In ru, this message translates to:
  /// **'Добавить дату'**
  String get hiddenAddDate;

  /// No description provided for @hiddenDateLabelHint.
  ///
  /// In ru, this message translates to:
  /// **'Название, например «День рождения»'**
  String get hiddenDateLabelHint;

  /// No description provided for @hiddenDateDefaultLabel.
  ///
  /// In ru, this message translates to:
  /// **'Особый день'**
  String get hiddenDateDefaultLabel;

  /// No description provided for @hiddenDateSave.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get hiddenDateSave;

  /// No description provided for @hiddenDateCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get hiddenDateCancel;

  /// No description provided for @hiddenDateRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить дату'**
  String get hiddenDateRemove;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// Раздел только в отладочных и профильных сборках
  ///
  /// In ru, this message translates to:
  /// **'Для разработки'**
  String get settingsSectionDev;

  /// No description provided for @settingsGlassCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверка стекла'**
  String get settingsGlassCheck;

  /// No description provided for @glassCheckTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка стекла'**
  String get glassCheckTitle;

  /// No description provided for @glassCheckReduceTransparency.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить прозрачность: {state}'**
  String glassCheckReduceTransparency(String state);

  /// No description provided for @glassCheckHighContrast.
  ///
  /// In ru, this message translates to:
  /// **'Повышенная контрастность: {state}'**
  String glassCheckHighContrast(String state);

  /// No description provided for @glassCheckOn.
  ///
  /// In ru, this message translates to:
  /// **'вкл'**
  String get glassCheckOn;

  /// No description provided for @glassCheckOff.
  ///
  /// In ru, this message translates to:
  /// **'выкл'**
  String get glassCheckOff;

  /// No description provided for @glassCheckSurface.
  ///
  /// In ru, this message translates to:
  /// **'Стекло: {mode}'**
  String glassCheckSurface(String mode);

  /// No description provided for @glassCheckSurfaceGlass.
  ///
  /// In ru, this message translates to:
  /// **'прозрачное'**
  String get glassCheckSurfaceGlass;

  /// No description provided for @glassCheckSurfaceOpaque.
  ///
  /// In ru, this message translates to:
  /// **'сплошное'**
  String get glassCheckSurfaceOpaque;

  /// No description provided for @glassCheckFrames.
  ///
  /// In ru, this message translates to:
  /// **'Кадров: {count}'**
  String glassCheckFrames(int count);

  /// No description provided for @glassCheckAverage.
  ///
  /// In ru, this message translates to:
  /// **'Среднее {ms} мс, 95% кадров до {p95} мс, худший {worst} мс'**
  String glassCheckAverage(String ms, String p95, String worst);

  /// No description provided for @glassCheckOverBudget.
  ///
  /// In ru, this message translates to:
  /// **'Дольше 8,3 мс: {slow}, дольше 16,7 мс: {jank}'**
  String glassCheckOverBudget(int slow, int jank);

  /// No description provided for @glassCheckProfileHint.
  ///
  /// In ru, this message translates to:
  /// **'Цифры верны только в профильной сборке: flutter run --profile.'**
  String get glassCheckProfileHint;

  /// No description provided for @glassCheckPause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get glassCheckPause;

  /// No description provided for @glassCheckResume.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get glassCheckResume;

  /// No description provided for @glassCheckReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить цифры'**
  String get glassCheckReset;

  /// Кнопка в библиотеке: импорт схемы из книги
  ///
  /// In ru, this message translates to:
  /// **'Схема из книги'**
  String get libraryImportBook;

  /// Заголовок экрана импорта
  ///
  /// In ru, this message translates to:
  /// **'Схема из книги'**
  String get importBookTitle;

  /// Закрыть экран импорта
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get importBookCancel;

  /// Подсказка при выборе источника
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте страницу книги или выберите готовые фото и PDF.'**
  String get importPickHint;

  /// Источник: камера
  ///
  /// In ru, this message translates to:
  /// **'Снять на камеру'**
  String get importSourceCamera;

  /// Источник: фотопленка
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из Фото'**
  String get importSourcePhotos;

  /// Источник: файлы
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из Файлов (фото или PDF)'**
  String get importSourceFiles;

  /// Заголовок выбора страниц PDF
  ///
  /// In ru, this message translates to:
  /// **'Страницы PDF'**
  String get importPdfTitle;

  /// Счётчик выбранных страниц PDF
  ///
  /// In ru, this message translates to:
  /// **'Выбрано: {count} из {total}'**
  String importPdfSelected(int count, int total);

  /// Выбрать все страницы PDF
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get importPdfSelectAll;

  /// Снять выбор страниц PDF
  ///
  /// In ru, this message translates to:
  /// **'Снять'**
  String get importPdfClear;

  /// Перейти к проверке страниц
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get importPdfContinue;

  /// Подпись страницы PDF в сетке
  ///
  /// In ru, this message translates to:
  /// **'Страница {page}'**
  String importPdfPageLabel(int page);

  /// Заголовок проверки страниц
  ///
  /// In ru, this message translates to:
  /// **'Страницы схемы'**
  String get importReviewTitle;

  /// Подпись поля названия проекта
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get importNameLabel;

  /// Ремесло: бисер
  ///
  /// In ru, this message translates to:
  /// **'Бисер'**
  String get importCraftBeading;

  /// Ремесло: вышивка
  ///
  /// In ru, this message translates to:
  /// **'Вышивка'**
  String get importCraftCrossStitch;

  /// Добавить страницы
  ///
  /// In ru, this message translates to:
  /// **'Добавить ещё'**
  String get importAddMore;

  /// Создать проект из страниц
  ///
  /// In ru, this message translates to:
  /// **'Импортировать'**
  String get importSubmit;

  /// Повернуть страницу
  ///
  /// In ru, this message translates to:
  /// **'Повернуть'**
  String get importRotate;

  /// Обрезать страницу
  ///
  /// In ru, this message translates to:
  /// **'Обрезать'**
  String get importCrop;

  /// Убрать страницу
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get importRemove;

  /// Пометка у обрезанной страницы
  ///
  /// In ru, this message translates to:
  /// **'Обрезана'**
  String get importCropped;

  /// Подпись страницы в списке
  ///
  /// In ru, this message translates to:
  /// **'Страница {number}'**
  String importPageNumber(int number);

  /// Заголовок обрезки
  ///
  /// In ru, this message translates to:
  /// **'Обрезка'**
  String get importCropTitle;

  /// Сбросить рамку обрезки
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get importCropReset;

  /// Применить обрезку
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get importCropDone;

  /// Идёт импорт
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем страницы…'**
  String get importSaving;

  /// Ошибка источника
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к камере или Фото. Разрешите его в настройках.'**
  String get importProblemSourceUnavailable;

  /// Ошибка чтения картинки
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать картинку. Попробуйте другой файл.'**
  String get importProblemUnreadable;

  /// Ошибка PDF
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть PDF.'**
  String get importProblemPdfFailed;

  /// Ошибка сохранения
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить схему. Проверьте свободное место.'**
  String get importProblemSaveFailed;

  /// Подпись шага потока импорта
  ///
  /// In ru, this message translates to:
  /// **'Шаг {number} из {total}'**
  String importStep(int number, int total);

  /// Ожидание: открывается выбранный файл или фото
  ///
  /// In ru, this message translates to:
  /// **'Открываем файл…'**
  String get importOpening;

  /// Ожидание: отрисовываются страницы PDF
  ///
  /// In ru, this message translates to:
  /// **'Готовим страницы…'**
  String get importRendering;

  /// Ошибка: PDF открылся, но пустой
  ///
  /// In ru, this message translates to:
  /// **'В этом PDF нет страниц. Выберите другой файл.'**
  String get importProblemPdfEmpty;

  /// Кнопка в сообщении об ошибке файла
  ///
  /// In ru, this message translates to:
  /// **'Выбрать другой файл'**
  String get importPickAnother;

  /// Нет страниц
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы одну страницу.'**
  String get importProblemNoPages;

  /// Пустое название
  ///
  /// In ru, this message translates to:
  /// **'Введите название.'**
  String get importProblemEmptyName;

  /// Номер текущего ряда на экране работы по схеме
  ///
  /// In ru, this message translates to:
  /// **'Ряд {row}'**
  String bookWorkRow(int row);

  /// Кнопка: линейка на ряд назад
  ///
  /// In ru, this message translates to:
  /// **'Ряд назад'**
  String get bookWorkPrevRow;

  /// Кнопка: линейка на следующий ряд
  ///
  /// In ru, this message translates to:
  /// **'Следующий ряд'**
  String get bookWorkNextRow;

  /// Кнопка выбора страницы многостраничной схемы
  ///
  /// In ru, this message translates to:
  /// **'Страница {current} из {total}'**
  String bookWorkPageLabel(int current, int total);

  /// Заголовок списка страниц схемы
  ///
  /// In ru, this message translates to:
  /// **'Страницы'**
  String get bookWorkPagesTitle;

  /// Пункт списка страниц схемы
  ///
  /// In ru, this message translates to:
  /// **'Страница {number}'**
  String bookWorkPageItem(int number);

  /// Заголовок переключателя направления рядов
  ///
  /// In ru, this message translates to:
  /// **'Направление рядов'**
  String get bookWorkDirection;

  /// Ряды идут сверху вниз
  ///
  /// In ru, this message translates to:
  /// **'Сверху вниз'**
  String get bookWorkDirectionDown;

  /// Ряды идут снизу вверх
  ///
  /// In ru, this message translates to:
  /// **'Снизу вверх'**
  String get bookWorkDirectionUp;

  /// Подпись ручки высоты линейки для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'Высота линейки: потяни вверх или вниз'**
  String get bookWorkResizeHandle;

  /// Баннер на последнем ряду страницы
  ///
  /// In ru, this message translates to:
  /// **'Страница закончена'**
  String get bookWorkPageEnd;

  /// Кнопка на последнем ряду страницы
  ///
  /// In ru, this message translates to:
  /// **'Следующая страница'**
  String get bookWorkNextPage;

  /// Кнопка тоста: вернуть линейку на прошлый ряд
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get bookWorkUndo;

  /// Кнопка: вписать страницу по ширине
  ///
  /// In ru, this message translates to:
  /// **'По ширине'**
  String get bookWorkFitWidth;

  /// Индикатор масштаба страницы
  ///
  /// In ru, this message translates to:
  /// **'Масштаб ×{scale}'**
  String bookWorkZoomLevel(String scale);

  /// Кнопка: свернуть панель плетения
  ///
  /// In ru, this message translates to:
  /// **'Свернуть панель'**
  String get bookWorkCollapsePanel;

  /// Кнопка: развернуть панель плетения
  ///
  /// In ru, this message translates to:
  /// **'Развернуть панель'**
  String get bookWorkExpandPanel;

  /// Кнопка выхода с экрана работы по схеме
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get bookWorkClose;

  /// Кнопка и заголовок листа настройки линейки
  ///
  /// In ru, this message translates to:
  /// **'Настройка линейки'**
  String get bookWorkRulerSettings;

  /// No description provided for @bookWorkRulerHeight.
  ///
  /// In ru, this message translates to:
  /// **'Высота линейки'**
  String get bookWorkRulerHeight;

  /// No description provided for @bookWorkRulerStep.
  ///
  /// In ru, this message translates to:
  /// **'Шаг сдвига'**
  String get bookWorkRulerStep;

  /// No description provided for @bookWorkRulerColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет подсветки'**
  String get bookWorkRulerColor;

  /// Заголовок раздела настройки границ схемы на фото страницы
  ///
  /// In ru, this message translates to:
  /// **'Схема на странице'**
  String get bookWorkZoneTitle;

  /// Кнопка: начать выбор границ схемы на странице
  ///
  /// In ru, this message translates to:
  /// **'Обвести схему на фото'**
  String get bookWorkZoneEdit;

  /// Кнопка: схема занимает всю страницу, границы снимаются
  ///
  /// In ru, this message translates to:
  /// **'Вся страница'**
  String get bookWorkZoneReset;

  /// No description provided for @bookWorkZoneHint.
  ///
  /// In ru, this message translates to:
  /// **'Потяни за края рамки, чтобы она обвела только схему. Ряды не выйдут за рамку.'**
  String get bookWorkZoneHint;

  /// Подпись счётчика числа рядов в зоне схемы
  ///
  /// In ru, this message translates to:
  /// **'Рядов в схеме'**
  String get bookWorkZoneRowCount;

  /// Кнопка: не считать высоту ряда по числу рядов
  ///
  /// In ru, this message translates to:
  /// **'Задавать вручную'**
  String get bookWorkZoneRowCountManual;

  /// No description provided for @bookWorkZoneRowCountAuto.
  ///
  /// In ru, this message translates to:
  /// **'Высота ряда считается сама'**
  String get bookWorkZoneRowCountAuto;

  /// No description provided for @bookWorkZoneRowCountUnset.
  ///
  /// In ru, this message translates to:
  /// **'не задано'**
  String get bookWorkZoneRowCountUnset;

  /// No description provided for @bookWorkZoneMore.
  ///
  /// In ru, this message translates to:
  /// **'Больше рядов'**
  String get bookWorkZoneMore;

  /// No description provided for @bookWorkZoneLess.
  ///
  /// In ru, this message translates to:
  /// **'Меньше рядов'**
  String get bookWorkZoneLess;

  /// Подпись ручки, которой двигают границу схемы
  ///
  /// In ru, this message translates to:
  /// **'Край схемы'**
  String get bookWorkZoneHandle;

  /// No description provided for @bookWorkColorYellow.
  ///
  /// In ru, this message translates to:
  /// **'Жёлтый'**
  String get bookWorkColorYellow;

  /// No description provided for @bookWorkColorGreen.
  ///
  /// In ru, this message translates to:
  /// **'Зелёный'**
  String get bookWorkColorGreen;

  /// No description provided for @bookWorkColorBlue.
  ///
  /// In ru, this message translates to:
  /// **'Синий'**
  String get bookWorkColorBlue;

  /// No description provided for @bookWorkColorPink.
  ///
  /// In ru, this message translates to:
  /// **'Розовый'**
  String get bookWorkColorPink;

  /// Кнопка и заголовок листа заметок проекта
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get bookWorkNotes;

  /// No description provided for @bookWorkNotesHint.
  ///
  /// In ru, this message translates to:
  /// **'Что важно не забыть: цвета, где остановилась, что поменять'**
  String get bookWorkNotesHint;

  /// Кнопка закрытия листа
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get bookWorkDone;

  /// No description provided for @bookWorkLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Схема не открылась. Закрой экран и попробуй ещё раз.'**
  String get bookWorkLoadFailed;

  /// No description provided for @bookWorkSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось сохранить, где ты остановилась. Проверь, есть ли место на устройстве.'**
  String get bookWorkSaveFailed;

  /// Маркер текущего ряда сеточной схемы у левого края (номер с единицы)
  ///
  /// In ru, this message translates to:
  /// **'Ряд {row}'**
  String gridRowMarker(int row);

  /// No description provided for @bookWorkImageFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось показать эту страницу. Попробуй открыть её ещё раз.'**
  String get bookWorkImageFailed;

  /// Подсказка в поле поиска по проектам
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get librarySearchPlaceholder;

  /// Кнопка и заголовок листа создания проекта
  ///
  /// In ru, this message translates to:
  /// **'Новый проект'**
  String get libraryNewProject;

  /// Заголовок пустой библиотеки
  ///
  /// In ru, this message translates to:
  /// **'Пока нет работ'**
  String get libraryEmptyTitle;

  /// Подсказка в пустой библиотеке
  ///
  /// In ru, this message translates to:
  /// **'Нажмите «+», чтобы добавить первую схему.'**
  String get libraryEmptyMessage;

  /// Заголовок, когда поиск и фильтры ничего не оставили
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get libraryNoMatchesTitle;

  /// Подсказка, когда ничего не найдено
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте изменить запрос или сбросить фильтры.'**
  String get libraryNoMatchesMessage;

  /// Кнопка сброса поиска и фильтров
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get libraryResetFilters;

  /// Заголовок ошибки загрузки списка
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить работы'**
  String get libraryLoadFailedTitle;

  /// Кнопка повторной попытки
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get libraryRetry;

  /// Ремесло: бисероплетение
  ///
  /// In ru, this message translates to:
  /// **'Бисер'**
  String get craftBeading;

  /// Ремесло: вышивка крестом
  ///
  /// In ru, this message translates to:
  /// **'Вышивка'**
  String get craftCrossStitch;

  /// Статус проекта: ещё не начат
  ///
  /// In ru, this message translates to:
  /// **'Идея'**
  String get statusIdea;

  /// Статус проекта: в процессе
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get statusInProgress;

  /// Статус проекта: закончен
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get statusDone;

  /// Техника бисероплетения: на станке
  ///
  /// In ru, this message translates to:
  /// **'Станок'**
  String get techniqueLoom;

  /// Техника бисероплетения: мозаичное плетение
  ///
  /// In ru, this message translates to:
  /// **'Мозаика'**
  String get techniquePeyote;

  /// Техника бисероплетения: кирпичный стежок
  ///
  /// In ru, this message translates to:
  /// **'Кирпичик'**
  String get techniqueBrick;

  /// Техника бисероплетения: квадратное плетение
  ///
  /// In ru, this message translates to:
  /// **'Квадратное'**
  String get techniqueSquare;

  /// Техника бисероплетения: свободное плетение
  ///
  /// In ru, this message translates to:
  /// **'Без станка'**
  String get techniqueOffLoom;

  /// Техника вышивки: счётный крест
  ///
  /// In ru, this message translates to:
  /// **'Крестик'**
  String get techniqueCrossStitch;

  /// Техника вышивки: полукрест (гобеленовый стежок)
  ///
  /// In ru, this message translates to:
  /// **'Полукрест'**
  String get techniqueTent;

  /// Подпись карточки проекта: ремесло и техника
  ///
  /// In ru, this message translates to:
  /// **'{craft} · {technique}'**
  String libraryCardSubtitle(String craft, String technique);

  /// Статус проекта и дата последней работы
  ///
  /// In ru, this message translates to:
  /// **'{status} · {date}'**
  String libraryCardLastWorked(String status, DateTime date);

  /// Действие над проектом
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get projectRename;

  /// Действие над проектом
  ///
  /// In ru, this message translates to:
  /// **'Дублировать'**
  String get projectDuplicate;

  /// Действие над проектом
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get projectDelete;

  /// Заголовок подтверждения удаления
  ///
  /// In ru, this message translates to:
  /// **'Удалить «{name}»?'**
  String projectDeleteTitle(String name);

  /// Пояснение в подтверждении удаления
  ///
  /// In ru, this message translates to:
  /// **'Работа исчезнет из списка.'**
  String get projectDeleteMessage;

  /// Заголовок диалога переименования
  ///
  /// In ru, this message translates to:
  /// **'Новое название'**
  String get projectRenameTitle;

  /// Подсказка в поле названия проекта
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get projectNamePlaceholder;

  /// Подтверждение в диалоге
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// Закрыть сообщение
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get commonOk;

  /// Заголовок сообщения об ошибке действия
  ///
  /// In ru, this message translates to:
  /// **'Не получилось'**
  String get actionFailedTitle;

  /// Ошибка проверки названия
  ///
  /// In ru, this message translates to:
  /// **'Проверьте название: оно не должно быть пустым или слишком длинным.'**
  String get actionFailedValidation;

  /// Проект не найден
  ///
  /// In ru, this message translates to:
  /// **'Этой работы уже нет.'**
  String get actionFailedNotFound;

  /// Прочая ошибка действия
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так. Попробуйте ещё раз.'**
  String get actionFailedGeneric;

  /// Подсказка над выбором ремесла в листе создания
  ///
  /// In ru, this message translates to:
  /// **'Что будем делать?'**
  String get newProjectCraftQuestion;

  /// Лист создания пуст: ни одна фича не добавила пункты
  ///
  /// In ru, this message translates to:
  /// **'Способы создания появятся в следующих версиях.'**
  String get newProjectNoEntries;

  /// Подпись для VoiceOver у кнопки «+»
  ///
  /// In ru, this message translates to:
  /// **'Добавить проект'**
  String get libraryAddSemantic;

  /// Экран плетения: схема не открылась
  ///
  /// In ru, this message translates to:
  /// **'Не получилось открыть схему. Попробуй ещё раз.'**
  String get weaveLoadFailed;

  /// Закрыть экран плетения
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get weaveClose;

  /// Крупный счётчик: номер текущего ряда и всего рядов
  ///
  /// In ru, this message translates to:
  /// **'Ряд {row} из {total}'**
  String weaveRowCounter(int row, int total);

  /// Переключатель: отмечать ряд целиком
  ///
  /// In ru, this message translates to:
  /// **'По ряду'**
  String get weaveModeByRow;

  /// Переключатель: отмечать бусины по одной
  ///
  /// In ru, this message translates to:
  /// **'По бусине'**
  String get weaveModeByBead;

  /// Подпись переключателя символов (VoiceOver)
  ///
  /// In ru, this message translates to:
  /// **'Показать символы на бусинах'**
  String get weaveSymbols;

  /// Кнопка: шаг назад
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get weaveBack;

  /// Кнопка: выложена следующая бусина
  ///
  /// In ru, this message translates to:
  /// **'Следующая бусина'**
  String get weaveNextBead;

  /// Кнопка: ряд готов
  ///
  /// In ru, this message translates to:
  /// **'Ряд готов'**
  String get weaveRowDone;

  /// Тост после отметки ряда
  ///
  /// In ru, this message translates to:
  /// **'Ряд {row} готов'**
  String weaveRowCompleted(int row);

  /// Кнопка тоста: отменить отметку
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get weaveUndo;

  /// Вопрос после последнего ряда
  ///
  /// In ru, this message translates to:
  /// **'Последний ряд готов. Отметить работу законченной?'**
  String get weaveFinishTitle;

  /// Кнопка: отметить проект готовым
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get weaveFinishYes;

  /// Кнопка: не отмечать сейчас
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get weaveFinishLater;

  /// Предупреждение: прогресс не записался
  ///
  /// In ru, this message translates to:
  /// **'Не получилось сохранить прогресс. Попробую ещё раз.'**
  String get weaveSaveFailed;

  /// Подпись для VoiceOver: сколько бусин выложено
  ///
  /// In ru, this message translates to:
  /// **'Бусина {laid} из {total}'**
  String weaveBeadProgress(int laid, int total);

  /// Направление ряда
  ///
  /// In ru, this message translates to:
  /// **'Нить идёт вправо'**
  String get weaveDirRight;

  /// Направление ряда
  ///
  /// In ru, this message translates to:
  /// **'Нить идёт влево'**
  String get weaveDirLeft;

  /// Направление ряда
  ///
  /// In ru, this message translates to:
  /// **'Нить идёт вниз'**
  String get weaveDirDown;

  /// Направление ряда
  ///
  /// In ru, this message translates to:
  /// **'Нить идёт вверх'**
  String get weaveDirUp;

  /// Подпись word chart (VoiceOver)
  ///
  /// In ru, this message translates to:
  /// **'Бусины ряда'**
  String get weaveWordChart;

  /// Подпись кнопки перехода из плетения в редактор схемы (VoiceOver)
  ///
  /// In ru, this message translates to:
  /// **'Править схему'**
  String get weaveEdit;

  /// Пункт листа «Новый проект»: создать схему в редакторе
  ///
  /// In ru, this message translates to:
  /// **'Нарисовать схему'**
  String get libraryDrawPattern;

  /// Заголовок листа создания схемы
  ///
  /// In ru, this message translates to:
  /// **'Новая схема'**
  String get newGridTitle;

  /// Кнопка закрытия листа создания схемы
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get newGridCancel;

  /// Кнопка создания схемы
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get newGridCreate;

  /// Подпись поля названия схемы
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get newGridName;

  /// Название схемы, если ничего не введено
  ///
  /// In ru, this message translates to:
  /// **'Новая схема'**
  String get newGridDefaultName;

  /// Подпись выбора техники
  ///
  /// In ru, this message translates to:
  /// **'Техника'**
  String get newGridTechnique;

  /// Подпись ширины схемы
  ///
  /// In ru, this message translates to:
  /// **'Ширина, бусин'**
  String get newGridWidth;

  /// Подпись высоты схемы
  ///
  /// In ru, this message translates to:
  /// **'Высота, бусин'**
  String get newGridHeight;

  /// Подпись выбора размера бисера
  ///
  /// In ru, this message translates to:
  /// **'Бисер'**
  String get newGridBead;

  /// Предпросмотр размера изделия в сантиметрах
  ///
  /// In ru, this message translates to:
  /// **'Получится примерно {width} × {height} см'**
  String newGridSizeCm(String width, String height);

  /// Подсказка о допустимом размере схемы
  ///
  /// In ru, this message translates to:
  /// **'Размер: от 1 до 500 бусин по каждой стороне'**
  String get newGridSizeInvalid;

  /// Ошибка создания схемы
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать схему. Попробуй ещё раз.'**
  String get newGridFailed;

  /// Инструмент редактора
  ///
  /// In ru, this message translates to:
  /// **'Кисть'**
  String get editorToolBrush;

  /// Инструмент редактора
  ///
  /// In ru, this message translates to:
  /// **'Ластик'**
  String get editorToolEraser;

  /// Инструмент редактора
  ///
  /// In ru, this message translates to:
  /// **'Заливка'**
  String get editorToolFill;

  /// Инструмент редактора
  ///
  /// In ru, this message translates to:
  /// **'Пипетка'**
  String get editorToolPipette;

  /// Инструмент редактора: заменить цвет бусины во всей схеме
  ///
  /// In ru, this message translates to:
  /// **'Заменить цвет'**
  String get editorToolReplace;

  /// Инструмент редактора
  ///
  /// In ru, this message translates to:
  /// **'Выделение'**
  String get editorToolSelection;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Зеркало по горизонтали'**
  String get editorMirrorHorizontal;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Зеркало по вертикали'**
  String get editorMirrorVertical;

  /// Пояснение к зеркалу в схемах со сдвигом
  ///
  /// In ru, this message translates to:
  /// **'Для мозаики и кирпичика зеркало меняет местами ячейки, а не физическое расположение бусин.'**
  String get editorMirrorNote;

  /// Кнопка меню вставки и удаления рядов и столбцов
  ///
  /// In ru, this message translates to:
  /// **'Ряды и столбцы'**
  String get editorRowsColumns;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Вставить ряд выше'**
  String get editorInsertRowAbove;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Вставить ряд ниже'**
  String get editorInsertRowBelow;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Удалить ряд {row}'**
  String editorDeleteRow(int row);

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Вставить столбец слева'**
  String get editorInsertColumnLeft;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Вставить столбец справа'**
  String get editorInsertColumnRight;

  /// Действие редактора
  ///
  /// In ru, this message translates to:
  /// **'Удалить столбец {column}'**
  String editorDeleteColumn(int column);

  /// Подсказка, когда не выбрана ячейка для вставки или удаления
  ///
  /// In ru, this message translates to:
  /// **'Сначала коснись схемы, чтобы выбрать место.'**
  String get editorTouchFirst;

  /// Кнопка редактора
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get editorUndo;

  /// Кнопка редактора
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get editorRedo;

  /// Переключатель показа символов на схеме
  ///
  /// In ru, this message translates to:
  /// **'Символы'**
  String get editorSymbols;

  /// Подпись палитры схемы
  ///
  /// In ru, this message translates to:
  /// **'Палитра'**
  String get editorPalette;

  /// Кнопка добавления цвета в палитру
  ///
  /// In ru, this message translates to:
  /// **'Добавить цвет'**
  String get editorAddColor;

  /// Подпись цвета в палитре для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'Цвет {name}'**
  String editorColorSwatch(String name);

  /// Статус автосохранения
  ///
  /// In ru, this message translates to:
  /// **'Сохраняется…'**
  String get editorSaving;

  /// Статус автосохранения
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get editorSaved;

  /// Статус автосохранения: ошибка
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить. Нажми, чтобы повторить.'**
  String get editorSaveFailed;

  /// Ошибка загрузки схемы в редакторе
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть схему.'**
  String get editorLoadFailed;

  /// Подсказка редактора
  ///
  /// In ru, this message translates to:
  /// **'Сначала добавь цвет в палитру.'**
  String get editorProblemNoColor;

  /// Подсказка редактора
  ///
  /// In ru, this message translates to:
  /// **'В палитре больше нет места.'**
  String get editorProblemPaletteFull;

  /// Подсказка редактора
  ///
  /// In ru, this message translates to:
  /// **'Схема уже самая большая.'**
  String get editorProblemLimit;

  /// Подсказка редактора
  ///
  /// In ru, this message translates to:
  /// **'Последний ряд или столбец удалить нельзя.'**
  String get editorProblemLast;

  /// Заголовок листа цвета
  ///
  /// In ru, this message translates to:
  /// **'Цвет'**
  String get colorSheetTitle;

  /// Кнопка листа цвета
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get colorSheetDone;

  /// Поле названия цвета
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get colorSheetName;

  /// Ползунок цвета
  ///
  /// In ru, this message translates to:
  /// **'Красный'**
  String get colorSheetRed;

  /// Ползунок цвета
  ///
  /// In ru, this message translates to:
  /// **'Зелёный'**
  String get colorSheetGreen;

  /// Ползунок цвета
  ///
  /// In ru, this message translates to:
  /// **'Синий'**
  String get colorSheetBlue;

  /// Заголовок поиска по каталогу
  ///
  /// In ru, this message translates to:
  /// **'Из каталога'**
  String get colorSheetCatalog;

  /// Подсказка поля поиска по каталогу
  ///
  /// In ru, this message translates to:
  /// **'Артикул или название'**
  String get colorSheetSearch;

  /// Заголовок списка ближайших цветов каталога
  ///
  /// In ru, this message translates to:
  /// **'Ближайшие'**
  String get colorSheetNearest;

  /// Пустой результат поиска по каталогу
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашлось'**
  String get colorSheetNothing;

  /// Кнопка удаления цвета
  ///
  /// In ru, this message translates to:
  /// **'Удалить цвет из палитры'**
  String get colorSheetDelete;

  /// Пояснение к удалению цвета
  ///
  /// In ru, this message translates to:
  /// **'Бусины этого цвета на схеме станут пустыми.'**
  String get colorSheetDeleteHint;

  /// Название типа бисера: цилиндрический Miyuki Delica
  ///
  /// In ru, this message translates to:
  /// **'Delica'**
  String get newGridBeadDelica;

  /// Название типа бисера: круглый рокайль
  ///
  /// In ru, this message translates to:
  /// **'Рокайль'**
  String get newGridBeadRocaille;

  /// Подпись для VoiceOver у кнопки открытия каталога в шапке библиотеки
  ///
  /// In ru, this message translates to:
  /// **'Каталог цветов'**
  String get libraryCatalogSemantic;

  /// Действие над проектом: список бисера для схемы
  ///
  /// In ru, this message translates to:
  /// **'Материалы'**
  String get projectMaterials;

  /// Заголовок экрана каталога бисера
  ///
  /// In ru, this message translates to:
  /// **'Каталог бисера'**
  String get catalogTitleBead;

  /// Заголовок экрана каталога ниток
  ///
  /// In ru, this message translates to:
  /// **'Каталог ниток'**
  String get catalogTitleFloss;

  /// Подсказка в поле поиска по каталогу
  ///
  /// In ru, this message translates to:
  /// **'Артикул или название'**
  String get catalogSearchPlaceholder;

  /// Вкладка каталога без фильтра по бренду
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get catalogAllBrands;

  /// Заголовок пустого результата поиска по каталогу
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get catalogEmptyTitle;

  /// Подсказка при пустом результате поиска по каталогу
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте другой артикул или название.'**
  String get catalogEmptyMessage;

  /// Заголовок ошибки загрузки каталога
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть каталог'**
  String get catalogLoadFailedTitle;

  /// Подпись образца цвета в каталоге для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'{code}, {name}'**
  String catalogItemSemantic(String code, String name);

  /// Строка «бренд, серия, размер» под названием цвета
  ///
  /// In ru, this message translates to:
  /// **'{brand} {series} {size}'**
  String catalogSeriesAndSize(String brand, String series, String size);

  /// Заголовок списка похожих цветов в листе цвета
  ///
  /// In ru, this message translates to:
  /// **'Похожие цвета'**
  String get catalogSimilarTitle;

  /// Список похожих цветов пуст
  ///
  /// In ru, this message translates to:
  /// **'Похожих цветов не нашлось'**
  String get catalogSimilarNone;

  /// Ошибка подбора похожих цветов
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подобрать похожие цвета'**
  String get catalogSimilarFailed;

  /// Мера похожести цвета в процентах
  ///
  /// In ru, this message translates to:
  /// **'{percent}%'**
  String catalogSimilarityPercent(int percent);

  /// Подпись похожего цвета для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'{code}, {name}, похожесть {percent} процентов, {level}'**
  String catalogSimilaritySemantic(String code, String name, int percent, String level);

  /// Уровень похожести цветов: ΔE меньше 1
  ///
  /// In ru, this message translates to:
  /// **'почти не отличить'**
  String get similarityNearlyIdentical;

  /// Уровень похожести цветов: ΔE меньше 3
  ///
  /// In ru, this message translates to:
  /// **'очень похож'**
  String get similarityVeryClose;

  /// Уровень похожести цветов: ΔE меньше 6
  ///
  /// In ru, this message translates to:
  /// **'похож'**
  String get similarityClose;

  /// Уровень похожести цветов: ΔE от 6
  ///
  /// In ru, this message translates to:
  /// **'заметно отличается'**
  String get similarityNoticeable;

  /// Пометка в листе цвета каталога
  ///
  /// In ru, this message translates to:
  /// **'Цвет на экране может чуть отличаться от настоящего бисера.'**
  String get catalogColorApproximate;

  /// Закрыть лист цвета
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get catalogClose;

  /// Заголовок экрана материалов проекта
  ///
  /// In ru, this message translates to:
  /// **'Материалы'**
  String get materialsTitle;

  /// Переключатель расчёта без запаса
  ///
  /// In ru, this message translates to:
  /// **'По схеме'**
  String get materialsReserveNone;

  /// Переключатель расчёта с запасом
  ///
  /// In ru, this message translates to:
  /// **'С запасом {percent}%'**
  String materialsReserveWith(int percent);

  /// Количество бусин в таблице материалов
  ///
  /// In ru, this message translates to:
  /// **'{count} шт'**
  String materialsPieces(String count);

  /// Вес меньше точности показа в таблице материалов
  ///
  /// In ru, this message translates to:
  /// **'< {grams} г'**
  String materialsGramsLess(String grams);

  /// Вес бусин в таблице материалов
  ///
  /// In ru, this message translates to:
  /// **'{grams} г'**
  String materialsGrams(String grams);

  /// Подпись строки итогов в таблице материалов
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get materialsTotal;

  /// Строка под заголовком материалов
  ///
  /// In ru, this message translates to:
  /// **'Размер бисера: {size}'**
  String materialsBeadSize(String size);

  /// Пояснение под итогом материалов
  ///
  /// In ru, this message translates to:
  /// **'Вес примерный: у разных отделок бисер весит по-разному.'**
  String get materialsWeightHint;

  /// Кнопка «Поделиться» на экране материалов
  ///
  /// In ru, this message translates to:
  /// **'Поделиться списком'**
  String get materialsShare;

  /// Заголовок пустого экрана материалов
  ///
  /// In ru, this message translates to:
  /// **'В схеме пока нет бусин'**
  String get materialsEmptyTitle;

  /// Подсказка пустого экрана материалов
  ///
  /// In ru, this message translates to:
  /// **'Когда в схеме появятся цвета, здесь будет список.'**
  String get materialsEmptyMessage;

  /// Ошибка экрана материалов: нет размера бусины
  ///
  /// In ru, this message translates to:
  /// **'Для этой схемы размер бусины не задан, поэтому материалы посчитать нельзя.'**
  String get materialsUnsupported;

  /// Заголовок ошибки экрана материалов
  ///
  /// In ru, this message translates to:
  /// **'Не удалось посчитать материалы'**
  String get materialsLoadFailedTitle;

  /// Тема сообщения при «Поделиться» списком материалов
  ///
  /// In ru, this message translates to:
  /// **'Материалы: {name}'**
  String materialsShareSubject(String name);

  /// Первая строка текста списка материалов
  ///
  /// In ru, this message translates to:
  /// **'Материалы: {name}'**
  String materialsShareHeader(String name);

  /// Строка о размере бисера в тексте списка
  ///
  /// In ru, this message translates to:
  /// **'Бисер {size}'**
  String materialsShareBeads(String size);

  /// Строка цвета в тексте списка
  ///
  /// In ru, this message translates to:
  /// **'{number}. {color} — {pieces}, {grams}'**
  String materialsShareLine(int number, String color, String pieces, String grams);

  /// Строка итога в тексте списка
  ///
  /// In ru, this message translates to:
  /// **'Итого: {pieces}, {grams}'**
  String materialsShareTotal(String pieces, String grams);

  /// Пояснение в тексте списка, если выбран запас
  ///
  /// In ru, this message translates to:
  /// **'Количество указано с запасом {percent}%.'**
  String materialsShareReserve(int percent);

  /// Пояснение в тексте списка
  ///
  /// In ru, this message translates to:
  /// **'Вес приблизительный.'**
  String get materialsShareApprox;

  /// Ошибка системного листа «Поделиться»
  ///
  /// In ru, this message translates to:
  /// **'Не удалось поделиться. Попробуйте ещё раз.'**
  String get shareFailed;

  /// Форма бусины: цилиндрическая, в названии размера бисера
  ///
  /// In ru, this message translates to:
  /// **'Delica'**
  String get beadShapeDelica;

  /// Форма бусины: круглая, в названии размера бисера
  ///
  /// In ru, this message translates to:
  /// **'рокайль'**
  String get beadShapeRocaille;

  /// Пункт листа «Новый проект»: генерация узора по шаблону
  ///
  /// In ru, this message translates to:
  /// **'Узор по шаблону'**
  String get templateEntryTitle;

  /// Заголовок экрана генерации по шаблону
  ///
  /// In ru, this message translates to:
  /// **'Узор по шаблону'**
  String get templateTitle;

  /// Закрыть экран генерации без сохранения
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get templateCancel;

  /// Сохранить узор новым проектом
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get templateSave;

  /// Подпись во время сохранения узора
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем…'**
  String get templateSaving;

  /// Раздел экрана: галерея шаблонов
  ///
  /// In ru, this message translates to:
  /// **'Шаблон'**
  String get templateSectionKind;

  /// Раздел экрана: техника плетения
  ///
  /// In ru, this message translates to:
  /// **'Техника'**
  String get templateSectionTechnique;

  /// Раздел экрана: размер бисера
  ///
  /// In ru, this message translates to:
  /// **'Бисер'**
  String get templateSectionBead;

  /// Раздел экрана: размер узора
  ///
  /// In ru, this message translates to:
  /// **'Размер'**
  String get templateSectionSize;

  /// Раздел экрана: цвета узора
  ///
  /// In ru, this message translates to:
  /// **'Цвета'**
  String get templateSectionColors;

  /// Раздел экрана: числа выбранного шаблона
  ///
  /// In ru, this message translates to:
  /// **'Параметры'**
  String get templateSectionParams;

  /// Раздел экрана: зеркальное отражение
  ///
  /// In ru, this message translates to:
  /// **'Симметрия'**
  String get templateSectionSymmetry;

  /// Раздел экрана: название проекта
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get templateSectionName;

  /// Шаблон узора
  ///
  /// In ru, this message translates to:
  /// **'Полосы'**
  String get templateKindStripes;

  /// Шаблон узора
  ///
  /// In ru, this message translates to:
  /// **'Зигзаг'**
  String get templateKindZigzag;

  /// Шаблон узора
  ///
  /// In ru, this message translates to:
  /// **'Ромбы'**
  String get templateKindDiamonds;

  /// Шаблон узора
  ///
  /// In ru, this message translates to:
  /// **'Шахматка'**
  String get templateKindChecker;

  /// Шаблон узора
  ///
  /// In ru, this message translates to:
  /// **'Градиент'**
  String get templateKindGradient;

  /// Шаблон узора
  ///
  /// In ru, this message translates to:
  /// **'Бордюр'**
  String get templateKindBorder;

  /// Параметр: число бусин в ряду
  ///
  /// In ru, this message translates to:
  /// **'Бусин в ряду'**
  String get templateWidth;

  /// Параметр: число рядов
  ///
  /// In ru, this message translates to:
  /// **'Рядов'**
  String get templateHeight;

  /// Параметр полос
  ///
  /// In ru, this message translates to:
  /// **'Ширина полосы'**
  String get templateStripeWidth;

  /// Параметр зигзага
  ///
  /// In ru, this message translates to:
  /// **'Размах зигзага'**
  String get templateAmplitude;

  /// Параметр зигзага
  ///
  /// In ru, this message translates to:
  /// **'Толщина линии'**
  String get templateZigzagThickness;

  /// Параметр зигзага
  ///
  /// In ru, this message translates to:
  /// **'Просвет между линиями'**
  String get templateGap;

  /// Параметр ромбов
  ///
  /// In ru, this message translates to:
  /// **'Размер ромба'**
  String get templateDiamondSize;

  /// Параметр шахматки
  ///
  /// In ru, this message translates to:
  /// **'Сторона клетки'**
  String get templateCellSize;

  /// Параметр градиента
  ///
  /// In ru, this message translates to:
  /// **'Ступеней градиента'**
  String get templateSteps;

  /// Параметр бордюра
  ///
  /// In ru, this message translates to:
  /// **'Толщина бордюра'**
  String get templateBorderThickness;

  /// Параметр: ось полос и градиента
  ///
  /// In ru, this message translates to:
  /// **'Направление'**
  String get templateAxis;

  /// Направление изменения цвета
  ///
  /// In ru, this message translates to:
  /// **'Слева направо'**
  String get templateAxisX;

  /// Направление изменения цвета
  ///
  /// In ru, this message translates to:
  /// **'Сверху вниз'**
  String get templateAxisY;

  /// Без симметрии
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get templateSymmetryNone;

  /// Зеркало по горизонтали
  ///
  /// In ru, this message translates to:
  /// **'Лево и право'**
  String get templateSymmetryHorizontal;

  /// Зеркало по вертикали
  ///
  /// In ru, this message translates to:
  /// **'Верх и низ'**
  String get templateSymmetryVertical;

  /// Зеркало по обеим осям
  ///
  /// In ru, this message translates to:
  /// **'Обе оси'**
  String get templateSymmetryBoth;

  /// Пояснение под выбором симметрии
  ///
  /// In ru, this message translates to:
  /// **'В этой технике ряды сдвинуты на полбусины, поэтому отражение получится с небольшим сдвигом.'**
  String get templateSymmetryApproximate;

  /// Кнопка добавления цвета в полосы
  ///
  /// In ru, this message translates to:
  /// **'Добавить цвет'**
  String get templateAddColor;

  /// Кнопка в листе выбора цвета
  ///
  /// In ru, this message translates to:
  /// **'Убрать этот цвет'**
  String get templateRemoveColor;

  /// Заголовок листа выбора цвета
  ///
  /// In ru, this message translates to:
  /// **'Выберите цвет'**
  String get templatePickColorTitle;

  /// Пустой результат поиска цвета
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get templateColorEmpty;

  /// Подпись кнопки «−» у числового поля
  ///
  /// In ru, this message translates to:
  /// **'Меньше'**
  String get templateValueMinus;

  /// Подпись кнопки «+» у числового поля
  ///
  /// In ru, this message translates to:
  /// **'Больше'**
  String get templateValuePlus;

  /// Ошибка загрузки каталога
  ///
  /// In ru, this message translates to:
  /// **'Каталог цветов недоступен. Попробуйте ещё раз.'**
  String get templateProblemCatalog;

  /// Ошибка параметров
  ///
  /// In ru, this message translates to:
  /// **'Узор с такими параметрами не собрать. Попробуйте изменить размер или цвета.'**
  String get templateProblemParameters;

  /// Ошибка сохранения
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить узор. Попробуйте ещё раз.'**
  String get templateProblemSave;

  /// Кнопка повторной загрузки каталога
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get templateRetry;

  /// Подпись образца цвета в узоре
  ///
  /// In ru, this message translates to:
  /// **'Цвет {number}'**
  String templateColorSlot(int number);

  /// Название проекта по умолчанию
  ///
  /// In ru, this message translates to:
  /// **'{kind} {width}×{height}'**
  String templateDefaultName(String kind, int width, int height);

  /// Подпись предпросмотра для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр узора: {width} бусин в ряду, {height} рядов'**
  String templatePreviewLabel(int width, int height);

  /// Размер бисера в выборе
  ///
  /// In ru, this message translates to:
  /// **'{shape} {size}'**
  String templateBeadSize(String shape, String size);

  /// Закрыть колесо выбора значения
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get templateDone;

  /// Пункт листа «Новый проект»: схема по фотографии
  ///
  /// In ru, this message translates to:
  /// **'Схема из картинки'**
  String get libraryImageToGrid;

  /// Заголовок мастера схемы по картинке
  ///
  /// In ru, this message translates to:
  /// **'Схема из картинки'**
  String get imageWizardTitle;

  /// Кнопка выхода из мастера
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get imageWizardCancel;

  /// Подсказка на первом экране мастера
  ///
  /// In ru, this message translates to:
  /// **'Выберите картинку: по ней получится схема для плетения.'**
  String get imageWizardPickHint;

  /// Источник картинки: камера
  ///
  /// In ru, this message translates to:
  /// **'Сделать снимок'**
  String get imageWizardSourceCamera;

  /// Источник картинки: библиотека Фото
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из Фото'**
  String get imageWizardSourcePhotos;

  /// Источник картинки: Файлы
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из Файлов'**
  String get imageWizardSourceFiles;

  /// Индикатор открытия файла
  ///
  /// In ru, this message translates to:
  /// **'Открываю картинку…'**
  String get imageWizardOpening;

  /// Кнопка поворота картинки
  ///
  /// In ru, this message translates to:
  /// **'Повернуть'**
  String get imageWizardRotate;

  /// Кнопка обрезки картинки
  ///
  /// In ru, this message translates to:
  /// **'Обрезать'**
  String get imageWizardCrop;

  /// Подпись предпросмотра для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр схемы'**
  String get imageWizardPreviewLabel;

  /// Подпись исходной картинки для VoiceOver
  ///
  /// In ru, this message translates to:
  /// **'Исходная картинка'**
  String get imageWizardOriginalLabel;

  /// Подсказка про сравнение до/после
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте схему, чтобы увидеть исходную картинку'**
  String get imageWizardCompareHint;

  /// Индикатор расчёта предпросмотра
  ///
  /// In ru, this message translates to:
  /// **'Считаю схему…'**
  String get imageWizardCalculating;

  /// Размер получившейся схемы: ширина × высота
  ///
  /// In ru, this message translates to:
  /// **'{columns} × {rows} бусин'**
  String imageWizardSize(int columns, int rows);

  /// Заголовок выбора техники
  ///
  /// In ru, this message translates to:
  /// **'Техника'**
  String get imageWizardTechnique;

  /// Заголовок выбора размера бисера
  ///
  /// In ru, this message translates to:
  /// **'Бисер'**
  String get imageWizardBeadSize;

  /// Заголовок ползунка ширины
  ///
  /// In ru, this message translates to:
  /// **'Ширина схемы'**
  String get imageWizardWidth;

  /// Заголовок ползунка числа цветов
  ///
  /// In ru, this message translates to:
  /// **'Цветов в схеме'**
  String get imageWizardColorCount;

  /// Заголовок выбора источника цветов
  ///
  /// In ru, this message translates to:
  /// **'Цвета бисера'**
  String get imageWizardPalette;

  /// Цвета берутся из каталога бисера
  ///
  /// In ru, this message translates to:
  /// **'Из каталога'**
  String get imageWizardPaletteCatalog;

  /// Цвета подбираются по картинке свободно
  ///
  /// In ru, this message translates to:
  /// **'Любые'**
  String get imageWizardPaletteFree;

  /// Пояснение, когда каталог пуст под выбранный размер
  ///
  /// In ru, this message translates to:
  /// **'В каталоге нет бисера такого размера, поэтому цвета подобраны свободно.'**
  String get imageWizardCatalogMissing;

  /// Заголовок выбора предустановки генератора
  ///
  /// In ru, this message translates to:
  /// **'Детальность'**
  String get imageWizardPreset;

  /// Предустановка: крупные чистые области
  ///
  /// In ru, this message translates to:
  /// **'Проще'**
  String get imageWizardPresetSimpler;

  /// Предустановка по умолчанию
  ///
  /// In ru, this message translates to:
  /// **'Средне'**
  String get imageWizardPresetBalanced;

  /// Предустановка: больше мелких деталей
  ///
  /// In ru, this message translates to:
  /// **'Детально'**
  String get imageWizardPresetDetailed;

  /// Переключатель дизеринга
  ///
  /// In ru, this message translates to:
  /// **'Плавные переходы'**
  String get imageWizardDither;

  /// Пояснение к плавным переходам
  ///
  /// In ru, this message translates to:
  /// **'Плавные переходы цвета (небо, тени) выкладываются узором из соседних цветов. Остальное в схеме не меняется.'**
  String get imageWizardDitherHint;

  /// Переключатель: учитывать найденные на фото лица и объект
  ///
  /// In ru, this message translates to:
  /// **'Выделять главное'**
  String get imageWizardUseMasks;

  /// Пояснение к выделению главного
  ///
  /// In ru, this message translates to:
  /// **'Лица и главный предмет получают больше цветов и деталей, фон — меньше.'**
  String get imageWizardUseMasksHint;

  /// Заголовок выбора, что делать с фоном фото
  ///
  /// In ru, this message translates to:
  /// **'Фон'**
  String get imageWizardBackground;

  /// Фон как на фото
  ///
  /// In ru, this message translates to:
  /// **'Оставить'**
  String get imageWizardBackgroundKeep;

  /// Фон в несколько спокойных цветов
  ///
  /// In ru, this message translates to:
  /// **'Упростить'**
  String get imageWizardBackgroundSimplify;

  /// Фон без бусин
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get imageWizardBackgroundRemove;

  /// Переключатель обводки главного предмета
  ///
  /// In ru, this message translates to:
  /// **'Обводка'**
  String get imageWizardOutline;

  /// Пояснение к обводке
  ///
  /// In ru, this message translates to:
  /// **'Тёмная линия в одну бусину вокруг главного: силуэт виден сразу.'**
  String get imageWizardOutlineHint;

  /// Подсказка в поле названия схемы
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get imageWizardName;

  /// Главная кнопка мастера
  ///
  /// In ru, this message translates to:
  /// **'Сохранить схему'**
  String get imageWizardSave;

  /// Индикатор сохранения
  ///
  /// In ru, this message translates to:
  /// **'Сохраняю…'**
  String get imageWizardSaving;

  /// Ошибка источника картинки
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть выбранный источник. Проверьте доступ к Фото или камере.'**
  String get imageWizardProblemSourceUnavailable;

  /// Ошибка чтения картинки
  ///
  /// In ru, this message translates to:
  /// **'Не получилось прочитать картинку. Выберите другую.'**
  String get imageWizardProblemUnreadable;

  /// Ошибка расчёта схемы
  ///
  /// In ru, this message translates to:
  /// **'Не удалось посчитать схему. Измените параметры или выберите другую картинку.'**
  String get imageWizardProblemCalculation;

  /// Ошибка сохранения
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить схему. Попробуйте ещё раз.'**
  String get imageWizardProblemSave;

  /// Ошибка названия
  ///
  /// In ru, this message translates to:
  /// **'Дайте схеме название (до 120 символов).'**
  String get imageWizardProblemName;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
