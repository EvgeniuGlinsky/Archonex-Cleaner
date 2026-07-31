/// The rules that hold for every scan, whatever platform it runs on and
/// whatever the ruleset for that platform names.
///
/// These are the numbers a rule cannot override. A per-rule minimum age exists
/// as well — the browser caches want a longer one than `%TEMP%` does — but it
/// can only ever be *longer* than [minimumAge], never shorter, because the
/// reason for the floor is the same everywhere: the file might still be open.
class AppCleanPolicy {
  const AppCleanPolicy._();

  /// Nothing written more recently than this is ever offered for deletion.
  ///
  /// A temporary file created ninety seconds ago is not junk left behind, it is
  /// junk in use — an installer mid-run, a browser mid-download, the very
  /// application the user switched away from to open this one. An hour is long
  /// enough that a live process has finished with the file and short enough
  /// that today's leftovers are still found today.
  static const Duration minimumAge = Duration(hours: 1);

  /// How deep a single rule may descend from its root.
  ///
  /// Cache directories fan out by hashed prefix — `ab/cd/ef/…` — and a browser
  /// profile is already six levels down before the cache begins. Twelve reaches
  /// the bottom of everything the rulesets name; the limit exists for the
  /// directory that turns out to be a loop the symlink guard did not catch.
  static const int maxScanDepth = 12;

  /// Findings handed to the UI in one go.
  ///
  /// A scan of a Windows `%TEMP%` routinely turns up tens of thousands of
  /// files. One event per file means one bloc rebuild per file, which is a
  /// frozen screen; the count is chosen so the list still grows visibly.
  static const int foundBatchSize = 64;

  /// How long a partial batch waits before being flushed anyway.
  ///
  /// Without it the last few findings of a slow directory sit in the buffer
  /// until the next directory fills it, and the screen looks stalled.
  static const Duration foundFlushInterval = Duration(milliseconds: 250);

  /// Findings kept per rule before the walk moves on.
  ///
  /// Not a safety limit — everything past it is genuinely junk too. It bounds
  /// how much the app holds in memory while the user decides, and the scan
  /// reports that it stopped early rather than implying the directory is now
  /// accounted for. See `ScanTruncated`.
  static const int maxItemsPerRule = 5000;
}
