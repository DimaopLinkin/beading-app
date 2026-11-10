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
