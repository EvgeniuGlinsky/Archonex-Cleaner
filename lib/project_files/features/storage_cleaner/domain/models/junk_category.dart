/// The kinds of junk the app knows how to find.
///
/// A closed set, and deliberately small: every entry has to be explainable in
/// one line to someone about to delete it. A rule that cannot be filed under
/// one of these is a rule that has not been thought through yet, not a reason
/// to add a tenth category.
///
/// Declaration order is display order — safest and largest first, the two
/// categories that want a second look last.
enum JunkCategory {
  /// This app's own cache. Always offered, on every platform, because it is the
  /// one directory that is ours to empty whatever the OS thinks.
  appCache(selectedByDefault: true),

  /// The platform's temporary directory and whatever installers left in it.
  systemTemp(selectedByDefault: true),

  /// Generated previews. Regenerated on demand, so deleting them costs the
  /// user a slower first scroll and nothing else.
  thumbnails(selectedByDefault: true),

  /// Application and system logs old enough that nobody is going to read them.
  logs(selectedByDefault: true),

  /// Memory dumps written when something crashed. Large, and useful only to
  /// whoever was debugging that crash on the day.
  crashDumps(selectedByDefault: true),

  /// Directories with nothing in them, left behind by uninstallers.
  emptyFolders(selectedByDefault: true),

  /// Browser caches. Not ticked by default: emptying one costs the user a
  /// noticeably slower web for a day, which is a trade they should make rather
  /// than discover.
  browserCache(selectedByDefault: false, needsSecondLook: true),

  /// Downloaded installers and unpacked archives. Junk by every technical
  /// measure and occasionally the only copy of something paid for.
  installerLeftovers(selectedByDefault: false, needsSecondLook: true),

  /// The recycle bin. Everything in it was already deleted once, deliberately,
  /// and emptying it is the one action here the user could have taken without
  /// this app.
  trash(selectedByDefault: false, needsSecondLook: true);

  const JunkCategory({
    required this.selectedByDefault,
    this.needsSecondLook = false,
  });

  /// Whether a fresh scan arrives with this category ticked.
  ///
  /// The product decision lives here rather than in the bloc, so the screen and
  /// the "select all" action cannot answer it differently.
  final bool selectedByDefault;

  /// Whether the screen marks the category as worth a look before agreeing.
  ///
  /// The inverse of [selectedByDefault] today, and kept separate on purpose:
  /// the two answer different questions, and a category that is off by default
  /// merely because it is usually empty would want one and not the other.
  final bool needsSecondLook;
}
