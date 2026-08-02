/// Whatever keeps a long run alive while the app is not on screen.
///
/// On Android that is a foreground service with an ongoing notification and a
/// wake lock; everywhere else it is nothing at all, and `SilentRunNotice`
/// answers every call benignly rather than throwing. The seam exists so that
/// the difference is one factory call instead of a `Platform.isAndroid` in a
/// widget — see the Platform boundaries section of the skill.
///
/// It is a platform service and not a domain rule, so nothing here decides
/// anything. Every string it shows is handed in by the caller, already
/// translated: the alternative was a message field on a domain object, which is
/// exactly the thing `CleanFailure` exists to avoid.
abstract interface class RunNotice {
  /// Raises the notice, or updates the one already up.
  ///
  /// Called again for every step of a run. [progress] is `null` while there is
  /// nothing honest to say about how far along it is — before the first frame
  /// of an encode, and throughout a photograph, which finishes in one step.
  Future<void> show({
    required String channelName,
    required String title,
    required String text,
    required String stopLabel,
    double? progress,
  });

  /// Takes it down. Safe to call when nothing is up.
  Future<void> hide();

  /// The user pressed Stop on the notification itself.
  ///
  /// A stream rather than a callback because the notice outlives any one
  /// listener, and broadcast because the run and the screen may both be
  /// watching.
  Stream<void> get stopRequests;

  /// Releases whatever the implementation holds. The notice does not survive
  /// the app, and neither should its subscription.
  Future<void> dispose();
}
