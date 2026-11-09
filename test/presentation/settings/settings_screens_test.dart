import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/secret_tap_detector.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/settings/about_screen.dart';
import 'package:beading/presentation/settings/hidden_settings_screen.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/settings/settings_screen.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_settings_repository.dart';

class _RecordingHandler implements SecretTapHandler {
  int calls = 0;

  @override
  void onSecretTapped() => calls++;
}

void main() {
  late FakeSettingsRepository repo;
  late SettingsCubit settings;
  late ThemeModeCubit theme;

  setUp(() async {
    // Достаточно высокое окно, чтобы ленивый список построил все пункты.
    final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..devicePixelRatio = 1
      ..physicalSize = const Size(600, 1600);
    addTearDown(
      () => binding.platformDispatcher.views.first
        ..resetDevicePixelRatio()
        ..resetPhysicalSize(),
    );
    repo = FakeSettingsRepository();
    settings = SettingsCubit(repo);
    theme = ThemeModeCubit(repo);
    await settings.load();
  });

  tearDown(() async {
    await settings.close();
    await theme.close();
  });

  Widget wrap(Widget home, {CupertinoThemeData themeData = AppTheme.light}) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<SettingsCubit>.value(value: settings),
      BlocProvider<ThemeModeCubit>.value(value: theme),
    ],
    child: CupertinoApp(
      theme: themeData,
      builder: AppTheme.builder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  group('SettingsScreen', () {
    for (final CupertinoThemeData themeData in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
      testWidgets('показывает все пункты в теме ${themeData.brightness}', (tester) async {
        await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () {}), themeData: themeData));

        expect(find.text('Тема'), findsOneWidget);
        expect(find.text('Не гасить экран'), findsOneWidget);
        expect(find.text('Символы на схеме'), findsOneWidget);
        expect(find.text('Производитель бисера'), findsOneWidget);
        expect(find.text('Miyuki'), findsOneWidget);
        expect(find.text('Резервная копия'), findsOneWidget);
        expect(find.text('Синхронизация с iCloud'), findsOneWidget);
        expect(find.text('Скоро'), findsNWidgets(2));
        expect(find.text('О приложении'), findsOneWidget);
      });
    }

    testWidgets('переключатель «Не гасить экран» сразу пишет настройку', (tester) async {
      await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () {})));
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey<String>('keep-screen-awake'))).value, isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('keep-screen-awake')));
      await tester.pump();

      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey<String>('keep-screen-awake'))).value, isFalse);
      expect(repo.values[SettingKeys.keepScreenAwake.name], false);
    });

    testWidgets('переключатель символов пишет настройку', (tester) async {
      await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () {})));

      await tester.tap(find.byKey(const ValueKey<String>('symbol-mode')));
      await tester.pump();

      expect(repo.values[SettingKeys.symbolMode.name], true);
    });

    testWidgets('выбор темы меняет ThemeModeCubit', (tester) async {
      await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () {})));

      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();

      expect(theme.state, AppThemeMode.dark);
      expect(repo.themeMode, AppThemeMode.dark);
    });

    testWidgets('бренд выбирается из списка', (tester) async {
      await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () {})));

      await tester.tap(find.byKey(const ValueKey<String>('default-brand')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toho'));
      await tester.pumpAndSettle();

      expect(settings.state.defaultBeadBrand, 'Toho');
      expect(find.text('Toho'), findsOneWidget);
    });

    testWidgets('ошибка записи показывает предупреждение', (tester) async {
      repo.failWrites = true;
      await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () {})));

      await tester.tap(find.byKey(const ValueKey<String>('symbol-mode')));
      await tester.pump();

      expect(find.text('Не удалось сохранить настройку. Попробуй ещё раз.'), findsOneWidget);
    });

    testWidgets('«О приложении» вызывает переход', (tester) async {
      var opened = 0;
      await tester.pumpWidget(wrap(SettingsScreen(onOpenAbout: () => opened++)));

      await tester.tap(find.byKey(const ValueKey<String>('settings-about')));

      expect(opened, 1);
    });
  });

  group('AboutScreen', () {
    late FakeClock clock;
    late _RecordingHandler handler;
    late int hiddenOpened;

    Widget about({CupertinoThemeData themeData = AppTheme.light}) => wrap(
      AboutScreen(
        appInfo: Future<AppInfo>.value(const AppInfo(version: '0.1.0', build: '3')),
        detector: SecretTapDetector(clock: clock),
        secretTapHandler: handler,
        onOpenHidden: () => hiddenOpened++,
      ),
      themeData: themeData,
    );

    setUp(() {
      clock = FakeClock(DateTime(2026, 11, 9));
      handler = _RecordingHandler();
      hiddenOpened = 0;
    });

    for (final CupertinoThemeData themeData in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
      testWidgets('показывает название, версию и подпись в теме ${themeData.brightness}', (tester) async {
        await tester.pumpWidget(about(themeData: themeData));
        await tester.pump();

        expect(find.text('Бисер'), findsOneWidget);
        expect(find.text('Версия 0.1.0 (3)'), findsOneWidget);
        expect(find.text('Каждая бусинка на своём месте. Плети с удовольствием!'), findsOneWidget);
      });
    }

    testWidgets('семь нажатий по логотипу сообщают о секрете', (tester) async {
      await tester.pumpWidget(about());

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('about-logo')));
        clock.advance(const Duration(milliseconds: 200));
      }
      expect(handler.calls, 0);

      await tester.tap(find.byKey(const ValueKey<String>('about-logo')));
      expect(handler.calls, 1);
    });

    testWidgets('долгое нажатие на версию открывает скрытый раздел', (tester) async {
      await tester.pumpWidget(about());
      await tester.pump();

      await tester.longPress(find.byKey(const ValueKey<String>('about-version')));

      expect(hiddenOpened, 1);
    });
  });

  group('HiddenSettingsScreen', () {
    testWidgets('показывает имя по умолчанию и пустой список дат', (tester) async {
      await tester.pumpWidget(wrap(const HiddenSettingsScreen()));

      expect(find.widgetWithText(CupertinoTextFormFieldRow, 'Настя'), findsOneWidget);
      expect(find.text('Добавить дату'), findsOneWidget);
    });

    testWidgets('сохраняет имя после ввода', (tester) async {
      await tester.pumpWidget(wrap(const HiddenSettingsScreen()));

      await tester.enterText(find.byKey(const ValueKey<String>('hidden-name')), 'Оля');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(settings.state.userName, 'Оля');
      expect(repo.values[SettingKeys.userName.name], 'Оля');
    });

    testWidgets('добавляет дату через лист и удаляет её', (tester) async {
      await tester.pumpWidget(wrap(const HiddenSettingsScreen()));

      await tester.tap(find.byKey(const ValueKey<String>('hidden-add-date')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('date-label')), 'День рождения');
      await tester.tap(find.byKey(const ValueKey<String>('date-save')));
      await tester.pumpAndSettle();

      expect(settings.state.specialDates, hasLength(1));
      expect(settings.state.specialDates.single.label, 'День рождения');
      expect(find.text('День рождения'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Удалить дату'));
      await tester.pumpAndSettle();

      expect(settings.state.specialDates, isEmpty);
    });

    testWidgets('дата без названия получает название по умолчанию', (tester) async {
      await tester.pumpWidget(wrap(const HiddenSettingsScreen()));

      await tester.tap(find.byKey(const ValueKey<String>('hidden-add-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('date-save')));
      await tester.pumpAndSettle();

      expect(settings.state.specialDates.single.label, 'Особый день');
    });

    testWidgets('показывает сохранённые даты', (tester) async {
      repo.values[SettingKeys.specialDates.name] = <SpecialDate>[
        const SpecialDate(label: '8 марта', month: 3, day: 8),
      ];
      await settings.load();
      await tester.pumpWidget(wrap(const HiddenSettingsScreen()));

      expect(find.text('8 марта'), findsOneWidget);
      expect(find.text('08.03'), findsOneWidget);
    });
  });
}
