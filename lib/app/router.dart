import 'package:beading/presentation/library/library_screen.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const String library = '/';
}

GoRouter createRouter() => GoRouter(
  routes: <RouteBase>[
    GoRoute(path: AppRoutes.library, builder: (_, _) => const LibraryScreen()),
  ],
);
