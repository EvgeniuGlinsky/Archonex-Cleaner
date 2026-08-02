import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:storage_cleaner/core/constants/app_durations.dart';
import 'package:storage_cleaner/core/router/app_route.dart';
import 'package:storage_cleaner/project_files/features/home/ui/home_page.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/media_optimizer_view.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/quarantine_page.dart';
import 'package:storage_cleaner/project_files/features/splash/ui/splash_page.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/ui/storage_cleaner_view.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/storage_insights_page.dart';

/// Builds the application router.
///
/// Six routes and no shell. Both tools are pushed from the home screen and
/// sit beside each other rather than nesting, because they are two ways into
/// the same storage and neither is inside the other; the quarantine is the one
/// child, under the cleaner that fills it.
///
/// The two tools go straight to their views. Their blocs are provided above the
/// `Navigator` by `MediaOptimizerScope` and `StorageCleanerScope`, so that a
/// transcode survives the user pressing Back — see either scope for the whole
/// of that argument. The home, splash and quarantine screens still build theirs
/// in a page beside them, because nothing they start outlives a tap.
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
          path: AppRoute.storageInsights.path,
          name: AppRoute.storageInsights.routeName,
          pageBuilder: _fade(const StorageInsightsPage()),
        ),
        GoRoute(
          path: AppRoute.storageCleaner.path,
          name: AppRoute.storageCleaner.routeName,
          pageBuilder: _fade(const StorageCleanerView()),
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
          pageBuilder: _fade(const MediaOptimizerView()),
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
