import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/constants/app_durations.dart';
import 'package:archonex_cleaner/core/router/app_route.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/home_page.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/ui/media_optimizer_page.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/ui/quarantine_page.dart';
import 'package:archonex_cleaner/project_files/features/splash/ui/splash_page.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_page.dart';

/// Builds the application router.
///
/// Five routes and no shell. Both tools are pushed from the home screen and
/// sit beside each other rather than nesting, because they are two ways into
/// the same storage and neither is inside the other; the quarantine is the one
/// child, under the cleaner that fills it.
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
        GoRoute(
          path: AppRoute.mediaOptimizer.path,
          name: AppRoute.mediaOptimizer.routeName,
          pageBuilder: _fade(const MediaOptimizerPage()),
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
