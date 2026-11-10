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
  String get importProblemNoPages => 'Выберите хотя бы одну страницу.';

  @override
  String get importProblemEmptyName => 'Введите название.';
}
