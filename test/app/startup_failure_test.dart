import 'package:beading/app/bootstrap.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:beading/app/startup_failure_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import '../support/fake_platform.dart';
import '../support/in_memory_database.dart';

final class _BrokenOrientationLock implements OrientationLock {
  @override
  Future<void> lockPortrait() async => throw StateError('база не открылась');
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
  });

  testWidgets('экран ошибки запуска объясняет, что случилось, и показывает текст ошибки', (tester) async {
    await tester.pumpWidget(StartupFailureApp(error: StateError('миграция упала')));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть данные'), findsOneWidget);
    expect(find.textContaining('Ничего не удалено'), findsOneWidget);
    expect(find.textContaining('миграция упала'), findsOneWidget);
  });

  testWidgets('bootstrapSafely при сбое запуска возвращает экран ошибки, а не бросает', (tester) async {
    final Widget app = (await tester.runAsync(
      () => bootstrapSafely(
        database: createInMemoryDatabase(),
        orientationLock: _BrokenOrientationLock(),
        desktopWindow: FakeDesktopWindow(),
        wakelockController: fakeWakelockController(),
      ),
    ))!;
    expect(app, isA<StartupFailureApp>());
  });
}
