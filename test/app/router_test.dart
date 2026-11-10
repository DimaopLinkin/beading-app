import 'package:beading/app/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Iterable<String> paths({required bool devTools}) {
    final GoRouter router = createRouter(showDeveloperTools: devTools);
    addTearDown(router.dispose);
    return router.configuration.routes.whereType<GoRoute>().map((route) => route.path);
  }

  test('в отладочной и профильной сборке есть маршрут проверки стекла', () {
    expect(paths(devTools: true), contains(AppRoutes.glassCheck));
  });

  test('в релизной сборке маршрута проверки стекла нет', () {
    expect(paths(devTools: false), isNot(contains(AppRoutes.glassCheck)));
    expect(paths(devTools: false), contains(AppRoutes.settings));
  });
}
