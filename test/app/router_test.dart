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

  test('есть маршруты каталога и материалов проекта (в том числе в релизной сборке)', () {
    for (final bool devTools in <bool>[true, false]) {
      expect(paths(devTools: devTools), containsAll(<String>[AppRoutes.catalog, '/projects/:projectId/materials']));
    }
    expect(AppRoutes.materials('p-1'), '/projects/p-1/materials');
  });

  test('в релизной сборке маршрута проверки стекла нет', () {
    expect(paths(devTools: false), isNot(contains(AppRoutes.glassCheck)));
    expect(paths(devTools: false), contains(AppRoutes.settings));
  });
}
