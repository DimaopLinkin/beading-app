import 'package:beading/app/bootstrap.dart';
import 'package:beading/app/di.dart';
import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/fake_platform.dart';
import '../support/in_memory_database.dart';

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

void main() {
  setUp(() async {
    await GetIt.instance.reset();
  });

  testWidgets('приложение запускается и показывает «Мои работы»', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await tester.pumpAndSettle();

    expect(find.text('Мои работы'), findsOneWidget);
    expect(getIt, same(GetIt.instance));
  });

  testWidgets('в тёмной теме экран тоже строится', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await tester.pumpAndSettle();

    expect(find.text('Мои работы'), findsOneWidget);
    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Мои работы'))), Brightness.dark);
  });

  testWidgets('выбор режима темы переключает приложение', (tester) async {
    await tester.pumpWidget(await bootstrapWithFakes(tester));
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(find.text('Мои работы'));

    await context.read<ThemeModeCubit>().select(AppThemeMode.dark);
    await tester.pumpAndSettle();
    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Мои работы'))), Brightness.dark);

    await context.read<ThemeModeCubit>().select(AppThemeMode.light);
    await tester.pumpAndSettle();
    expect(CupertinoTheme.brightnessOf(tester.element(find.text('Мои работы'))), Brightness.light);
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
  });
}
