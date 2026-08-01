/// Every destination of the app.
///
/// The enum entry name doubles as the GoRouter route name, so there is exactly
/// one source of truth per destination.
enum AppRoute {
  splash(path: '/'),

  /// Where the app lands and comes back to. The tools are pushed from here.
  home(path: '/home'),

  storageCleaner(path: '/cleaner'),

  /// The second tool. A sibling of [storageCleaner] rather than a child: they
  /// are two ways into storage from the home screen, not one inside the other.
  mediaOptimizer(path: '/optimizer'),

  /// Child of [storageCleaner] — a relative path, nested under it, because it
  /// only ever holds what a cleanup put there and going back means going back
  /// to the cleaner.
  quarantine(path: 'quarantine');

  const AppRoute({required this.path});

  final String path;

  /// GoRouter route name, e.g. `storageCleaner`.
  String get routeName => name;
}
