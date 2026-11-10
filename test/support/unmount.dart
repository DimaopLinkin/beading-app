import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Снимает приложение с экрана и даёт drift закрыть потоки, пока тест ещё в fake-async.
/// Без этого `StreamQueryStore` оставляет отложенный таймер, и проверка инвариантов теста падает.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
