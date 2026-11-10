import 'package:beading/app/bootstrap.dart';
import 'package:beading/app/di.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:beading/presentation/easter_eggs/compliment_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/fake_platform.dart';
import '../support/unmount.dart';
import '../support/in_memory_database.dart';

Future<Widget> _bootstrap(WidgetTester tester, AppDatabase database) async => (await tester.runAsync(
  () => bootstrap(
    database: database,
    orientationLock: FakeOrientationLock(),
    desktopWindow: FakeDesktopWindow(),
    wakelockController: fakeWakelockController(),
  ),
))!;

/// База и ассеты отвечают на настоящих часах, поэтому ждём в `runAsync`, пока баннер не появится (до 5 с).
Future<void> _waitForBanner(WidgetTester tester) async {
  for (int i = 0; i < 50 && find.byType(ComplimentBanner).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    rootBundle.clear();
  });

  testWidgets('в особую дату при запуске показывается баннер, который сам исчезает через 5 секунд', (tester) async {
    final AppDatabase database = createInMemoryDatabase();
    final DateTime today = DateTime.now();
    final Widget app = await _bootstrap(tester, database);
    await tester.runAsync(
      () => getIt<SettingsRepository>().write(SettingKeys.specialDates, <SpecialDate>[
        SpecialDate(label: 'тест', month: today.month, day: today.day),
      ]),
    );

    await tester.pumpWidget(app);
    await _waitForBanner(tester);

    expect(find.byType(ComplimentBanner), findsOneWidget);
    expect(find.text('Мои работы'), findsWidgets);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(ComplimentBanner), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('секрет показывает комплимент по событию из шины', (tester) async {
    await tester.pumpWidget(await _bootstrap(tester, createInMemoryDatabase()));
    await tester.pump();

    getIt<AppEvents>().publish(const SecretTapped());
    await _waitForBanner(tester);

    expect(find.byType(ComplimentBanner), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('без событий баннера нет', (tester) async {
    await tester.pumpWidget(await _bootstrap(tester, createInMemoryDatabase()));
    await tester.pumpAndSettle();

    expect(find.byType(ComplimentBanner), findsNothing);
    await unmountApp(tester);
  });
}
