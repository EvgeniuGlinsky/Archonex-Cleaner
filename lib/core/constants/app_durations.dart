/// Timings used across the whole app.
class AppDurations {
  const AppDurations._();

  static const Duration splash = Duration(seconds: 1);
  static const Duration shortAnimation = Duration(milliseconds: 180);

  /// How long the storage ring takes to fill from empty to the figure the disk
  /// reported. Slower than [shortAnimation] on purpose: it is the one number the
  /// home screen exists to show, and it should be watched arriving rather than
  /// found already there.
  static const Duration ringSweep = Duration(milliseconds: 900);

  /// The splash mark fading and settling into place.
  static const Duration splashEntrance = Duration(milliseconds: 520);

  /// One screen crossfading into the next.
  static const Duration routeTransition = Duration(milliseconds: 220);
}
