/// Every destination of the app.
///
/// The enum entry name doubles as the GoRouter route name, so there is exactly
/// one source of truth per destination.
enum AppRoute {
  splash(path: '/'),
  languageSelection(path: '/language'),
  storageCleaner(path: '/cleaner'),

  /// Child of [storageCleaner] — a relative path, nested under it, because it
  /// only ever holds what a cleanup put there and going back means going back
  /// to the cleaner.
  quarantine(path: 'quarantine');

  const AppRoute({required this.path});

  final String path;

  /// GoRouter route name, e.g. `languageSelection`.
  String get routeName => name;
}
