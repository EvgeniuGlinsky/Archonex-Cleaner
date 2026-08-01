import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/constants/app_durations.dart';
import 'package:archonex_cleaner/core/router/app_route.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/home_page.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/ui/quarantine_page.dart';
import 'package:archonex_cleaner/project_files/features/splash/ui/splash_page.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_page.dart';

/// Builds the application router.
///
/// A second tool — the space saver behind `AppTool.optimizer` — is added by
/// appending one [GoRoute] beside [AppRoute.storageCleaner] and one entry to the
/// enum. The home screen already lists it.
class AppRouter {
  const AppRouter._();

  static GoRouter create() {
    return GoRouter(
      initialLocation: AppRoute.splash.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.splash.path,
          name: AppRoute.splash.routeName,
          pageBuilder: _fade(const SplashPage()),
        ),
        GoRoute(
          path: AppRoute.home.path,
          name: AppRoute.home.routeName,
          pageBuilder: _fade(const HomePage()),
        ),
        GoRoute(
          path: AppRoute.storageCleaner.path,
          name: AppRoute.storageCleaner.routeName,
          pageBuilder: _fade(const StorageCleanerPage()),
          routes: <RouteBase>[
            GoRoute(
              path: AppRoute.quarantine.path,
              name: AppRoute.quarantine.routeName,
              pageBuilder: _fade(const QuarantinePage()),
            ),
          ],
        ),
      ],
    );
  }

  /// One transition for the whole app, defined once.
  ///
  /// A crossfade rather than the platform's own slide: every route here is a
  /// step into a tool or back out of it, not a page in a stack the user is
  /// leafing through, and the storage ring reads as the same object growing
  /// across the cut instead of two rings sliding past each other.
  static Page<void> Function(BuildContext, GoRouterState) _fade(Widget child) {
    return (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: child,
          transitionDuration: AppDurations.routeTransition,
          reverseTransitionDuration: AppDurations.routeTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        );
  }
}
