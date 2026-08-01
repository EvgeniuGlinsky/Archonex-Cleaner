/// The things this app does to a device's storage.
///
/// Two, and they are the two halves of the same problem: the cleaner deletes
/// what should not be there, and the optimiser shrinks what should. A third
/// entry is a `GoRoute`, a card and an ARB key, and nothing else — see
/// `AppRouter`.
///
/// [isAvailable] stays on the enum now that both are built. It carried the
/// "Soon" badge while the optimiser was a promise, and it is what the next
/// unfinished tool will use for the same beat.
enum AppTool {
  cleaner(isAvailable: true),

  /// Walks the device for photographs and videos and rewrites them smaller,
  /// keeping the resolution and replacing the originals.
  optimizer(isAvailable: true);

  const AppTool({required this.isAvailable});

  /// Whether tapping the card does anything. A field rather than a check at the
  /// call site, so the badge and the disabled tap cannot disagree.
  final bool isAvailable;
}
