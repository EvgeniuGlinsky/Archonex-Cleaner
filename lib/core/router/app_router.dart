import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/router/app_route.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/ui/language_selection_page.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/ui/quarantine_page.dart';
import 'package:archonex_cleaner/project_files/features/splash/ui/splash_page.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_page.dart';

/// Builds the application router.
///
/// A second tool — the space saver on the roadmap — is added by appending one
/// [GoRoute] beside [AppRoute.storageCleaner] and one entry to the enum.
class AppRouter {
  const AppRouter._();

  static GoRouter create() {
    return GoRouter(
      initialLocation: AppRoute.splash.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.splash.path,
          name: AppRoute.splash.routeName,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoute.languageSelection.path,
          name: AppRoute.languageSelection.routeName,
          builder: (context, state) => const LanguageSelectionPage(),
        ),
        GoRoute(
          path: AppRoute.storageCleaner.path,
          name: AppRoute.storageCleaner.routeName,
          builder: (context, state) => const StorageCleanerPage(),
          routes: <RouteBase>[
            GoRoute(
              path: AppRoute.quarantine.path,
              name: AppRoute.quarantine.routeName,
              builder: (context, state) => const QuarantinePage(),
            ),
          ],
        ),
      ],
    );
  }
}
