import 'package:beading/app/bootstrap.dart';
import 'package:beading/app/di.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/fake_platform.dart';
import '../support/in_memory_database.dart';
import '../support/unmount.dart';

Future<Widget> bootstrapWithFakes(
  WidgetTester tester, {
  FakeOrientationLock? orientation,
  FakeDesktopWindow? window,
}) async => (await tester.runAsync(
  () => bootstrap(
    database: createInMemoryDatabase(),
    orientationLock: orientation ?? FakeOrientationLock(),
    desktopWindow: window ?? FakeDesktopWindow(),
    wakelockController: fakeWakelockController(),
  ),
))!;

/// Реальная БД отвечает вне fake-async, поэтому даём ей ответить и только потом рисуем кадр.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Бисер',
      packageName: 'app.beading',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await GetIt.instance.reset();
  });

  testWidgets('приложение запускается и показывает «Мои работы»', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await settle(tester);

    expect(find.text('Мои работы'), findsWidgets);
    expect(getIt, same(GetIt.instance));
    await unmountApp(tester);
  });

  testWidgets('в тёмной теме экран тоже строится', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await settle(tester);

    expect(find.text('Мои работы'), findsWidgets);
    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Мои работы').first)), Brightness.dark);
    await unmountApp(tester);
  });

  testWidgets('выбор режима темы переключает приложение', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await settle(tester);
    final BuildContext context = tester.element(find.text('Мои работы').first);

    await context.read<ThemeModeCubit>().select(AppThemeMode.dark);
    await settle(tester);
    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Мои работы').first)), Brightness.dark);

    await context.read<ThemeModeCubit>().select(AppThemeMode.light);
    await settle(tester);
    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Мои работы').first)), Brightness.light);
    await unmountApp(tester);
  });

  testWidgets('bootstrap фиксирует портрет, настраивает окно и включает wakelock', (tester) async {
    final FakeOrientationLock orientation = FakeOrientationLock();
    final FakeDesktopWindow window = FakeDesktopWindow();
    final FakeScreenWakeLock lock = FakeScreenWakeLock();
    final Widget app = (await tester.runAsync(
      () => bootstrap(
        database: createInMemoryDatabase(),
        orientationLock: orientation,
        desktopWindow: window,
        wakelockController: fakeWakelockController(lock),
      ),
    ))!;
    await tester.pumpWidget(app);

    expect(orientation.portraitCalls, 1);
    expect(window.configs.single.size, const Size(480, 900));
    expect(lock.calls, <String>['enable']);
    await unmountApp(tester);
  });

  testWidgets('из «Моих работ» открываются настройки и «О приложении»', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Не гасить экран'), findsOneWidget);

    await tester.dragUntilVisible(find.text('О приложении'), find.byType(ListView), const Offset(0, -200));
    await tester.tap(find.text('О приложении'));
    await tester.pumpAndSettle();
    expect(find.text('Каждая бусинка на своём месте. Плети с удовольствием!'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('выбор тёмной темы в настройках сразу применяется', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Настройки'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();

    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Не гасить экран'))), Brightness.dark);
    await unmountApp(tester);
  });

  testWidgets('«Уменьшить прозрачность» из системы доходит до стекла', (tester) async {
    final Widget app = await bootstrapWithFakes(tester);
    getIt
      ..unregister<ReduceTransparencySource>()
      ..registerSingleton<ReduceTransparencySource>(FakeReduceTransparencySource(initial: true));

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('Мои работы'));
    expect(GlassPolicy.isOpaque(context), isTrue);
    await unmountApp(tester);
  });

  testWidgets('в отладочной сборке из настроек открывается «Проверка стекла»', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Настройки'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(find.text('Проверка стекла'), find.byType(ListView), const Offset(0, -200));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверка стекла'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Кадров: 0'), findsOneWidget);
    await unmountApp(tester);
  });
}
