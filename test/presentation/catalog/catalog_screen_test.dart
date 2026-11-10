import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_settings_repository.dart';

void main() {
  final CatalogColor red = catalogColor('DB0010', 'Red', '#cc0000');
  final CatalogColor darkRed = catalogColor('DB0011', 'Dark Red', '#bb0000');
  final CatalogColor tohoRed = catalogColor('5', 'Opaque Red', '#cd0101', brand: 'Toho', series: 'Round');
  final CatalogColor tohoBlue = catalogColor('8', 'Blue', '#0000cc', brand: 'Toho', series: 'Round');

  late FakeCatalogRepository catalog;
  late FakeSettingsRepository settings;

  setUp(() {
    catalog = FakeCatalogRepository(<CatalogColor>[red, darkRed, tohoRed, tohoBlue]);
    settings = FakeSettingsRepository();
  });

  Future<CatalogCubit> pumpScreen(
    WidgetTester tester, {
    CupertinoThemeData theme = AppTheme.light,
    Size size = const Size(430, 932),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final CatalogCubit cubit = CatalogCubit(
      catalog: catalog,
      findSimilar: FindSimilarColors(catalog),
      settings: settings,
      brandSetting: SettingKeys.defaultBeadBrand,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<CatalogCubit>.value(value: cubit, child: const CatalogScreen()),
      ),
    );
    await cubit.start();
    await tester.pump();
    return cubit;
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('сетка образцов и вкладки брендов, тема ${theme.brightness}', (tester) async {
      await pumpScreen(tester, theme: theme);

      expect(find.text('Каталог бисера'), findsWidgets);
      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Miyuki'), findsOneWidget);
      expect(find.text('Toho'), findsOneWidget);
      // Открывается бренд по умолчанию — Miyuki.
      expect(find.text('DB0010'), findsOneWidget);
      expect(find.text('Dark Red'), findsOneWidget);
      expect(find.text('Blue'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('вкладка бренда и «Все» меняют сетку', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Toho'));
    await tester.pump();
    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('DB0010'), findsNothing);

    await tester.tap(find.text('Все'));
    await tester.pump();
    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('DB0010'), findsOneWidget);
  });

  testWidgets('поиск по артикулу или названию', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'dark');
    await tester.pump();

    expect(find.text('Dark Red'), findsOneWidget);
    expect(find.text('DB0010'), findsNothing);
  });

  testWidgets('поиск без совпадений показывает подсказку', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
    await tester.pump();

    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('одна вкладка бренда не показывается', (tester) async {
    catalog = FakeCatalogRepository(<CatalogColor>[red, darkRed]);
    await pumpScreen(tester);

    expect(find.text('Все'), findsNothing);
    expect(find.text('DB0010'), findsOneWidget);
  });

  testWidgets('ошибка загрузки: сообщение и «Повторить»', (tester) async {
    catalog.fail = true;
    await pumpScreen(tester);
    expect(find.text('Не удалось открыть каталог'), findsOneWidget);

    catalog.fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump();

    expect(find.text('DB0010'), findsOneWidget);
  });

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('нажатие на образец открывает лист с пятью похожими и мерой похожести, тема ${theme.brightness}', (
      tester,
    ) async {
      await pumpScreen(tester, theme: theme);

      await tester.tap(find.text('DB0010'));
      await tester.pumpAndSettle();

      expect(find.text('Miyuki Delica 11/0'), findsOneWidget);
      expect(find.text('#CC0000'), findsOneWidget);
      expect(find.text('Похожие цвета'), findsOneWidget);
      // Из каталога из 4 цветов к «Red» подходят 3 остальных: сначала Toho 5 (почти неотличим), затем Dark Red и Blue.
      expect(find.text('Toho 5'), findsOneWidget);
      expect(find.text('Miyuki DB0011'), findsOneWidget);
      expect(find.text('Toho 8'), findsOneWidget);
      expect(find.text('почти не отличить'), findsOneWidget);
      expect(find.textContaining('%'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('в листе нажатие на похожий цвет открывает его, «Закрыть» убирает лист', (tester) async {
    final CatalogCubit cubit = await pumpScreen(tester);
    await tester.tap(find.text('DB0010'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toho 5'));
    await tester.pumpAndSettle();
    expect(cubit.state.selection!.source, tohoRed);
    expect(find.text('Toho Round 11/0'), findsOneWidget);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Похожие цвета'), findsNothing);
    expect(cubit.state.selection, isNull);
  });

  testWidgets('в листе, если подбор не удался, есть сообщение', (tester) async {
    await pumpScreen(tester);
    catalog.fail = true;

    await tester.tap(find.text('DB0010'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось подобрать похожие цвета'), findsOneWidget);
  });

  testWidgets('образцы читаются VoiceOver: артикул и название', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpScreen(tester);

    expect(find.bySemanticsLabel('DB0010, Red'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('широкое окно Mac: сетка не шире колонки контента и не переполняется', (tester) async {
    await pumpScreen(tester, size: const Size(1400, 900));

    expect(find.text('DB0010'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(ValueKey<String>('color-${red.id}'))).dx, greaterThan(200));
    expect(tester.takeException(), isNull);
  });
}
