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
}
