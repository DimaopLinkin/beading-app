import 'package:beading/app/bootstrap.dart';
import 'package:beading/app/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
  });

  testWidgets('приложение запускается и показывает «Мои работы»', (tester) async {
    await tester.pumpWidget(await bootstrap());
    await tester.pumpAndSettle();

    expect(find.text('Мои работы'), findsOneWidget);
    expect(getIt, same(GetIt.instance));
  });

  testWidgets('в тёмной теме экран тоже строится', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(await bootstrap());
    await tester.pumpAndSettle();

    expect(find.text('Мои работы'), findsOneWidget);
    final ThemeData theme = Theme.of(tester.element(find.text('Мои работы')));
    expect(theme.brightness, Brightness.dark);
  });
}
