import 'package:storage_cleaner/core/constants/app_clean_policy.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// What a rule is looking for once it has a root.
enum JunkRuleMode {
  /// Everything directly inside the root, one finding per entry, a
  /// subdirectory counted whole and not descended into. The root itself
  /// survives — emptying `%TEMP%` must not delete `%TEMP%`.
  ///
  /// The mode for a directory that is disposable in its entirety, which is most
  /// of them. It is also what keeps the list readable: a Windows `%TEMP%` holds
  /// tens of thousands of files in a couple of hundred folders, and the user
  /// wants to scan two hundred rows, not walk twenty thousand.
  contents,

  /// Files at any depth under the root that pass the filters.
  ///
  /// For a root that is *not* disposable in its entirety — `Downloads`, or
  /// Local AppData — where only the files matching an extension or a prefix are
  /// junk and everything around them is the user's.
  files,

  /// Directories named in `JunkRule.directoryNames`, taken whole and not
  /// descended into. A `.thumbnails` folder is one finding, not four thousand.
  directories,

  /// Directories with nothing in them, at any depth.
  emptyDirectories,
}

/// One place to look, and what counts as junk once you are there.
///
/// A data row, not code: rules are declared in the four `*_junk_rules.dart`
/// tables and read by one walker. Adding a location is a row; adding a *kind*
/// of matching is a mode, and there are three, which has been enough.
class JunkRule {
  const JunkRule({
    required this.root,
    required this.category,
    required this.label,
    this.mode = JunkRuleMode.contents,
    this.extensions = const <String>{},
    this.namePrefixes = const <String>{},
    this.directoryNames = const <String>{},
    this.minimumAge = AppCleanPolicy.minimumAge,
    this.maxDepth = AppCleanPolicy.maxScanDepth,
    this.needsElevation = false,
  });

  /// Absolute path, already resolved from `CleanerRoots`.
  final String root;

  final JunkCategory category;

  /// Shown while the walk is inside this rule. A path the user recognises —
  /// `%TEMP%` rather than `C:\Users\…\AppData\Local\Temp`.
  final String label;

  final JunkRuleMode mode;

  /// Extensions without the dot, lower case. Empty means every extension.
  final Set<String> extensions;

  /// Name prefixes, lower case. Matches `~$`, `.trashed-`, `chrome_`.
  final Set<String> namePrefixes;

  /// Exact directory names, lower case. Only read in [JunkRuleMode.directories].
  final Set<String> directoryNames;

  /// How old a finding has to be, at least. Never shorter than
  /// `AppCleanPolicy.minimumAge`, and longer where a directory is written to
  /// constantly — a browser cache wants a day, not an hour.
  final Duration minimumAge;

  final int maxDepth;

  /// Whether the OS will refuse this root without elevated rights.
  ///
  /// Declared rather than discovered: the walk finds out by being refused, and
  /// a rule that is *expected* to be refused should not make the run look
  /// broken. Nothing marked with it is scanned today; it is here so the rows
  /// exist in the table with the reason attached.
  final bool needsElevation;

  /// Whether a file called [name] is what this rule is after.
  ///
  /// The name only — the age, the guard and the directory questions are the
  /// walker's, so this stays a pure string test with a unit test to match.
  ///
  /// A rule with no filters matches everything, which is only reachable in
  /// [JunkRuleMode.contents]: an unfiltered [JunkRuleMode.files] rule would
  /// walk a whole tree and take every file in it, and no root in the four
  /// tables is disposable that far down. `JunkRulesetTest` asserts none exists.
  bool matchesFile(String name) {
    if (extensions.isEmpty && namePrefixes.isEmpty) {
      return true;
    }

    final String lower = name.toLowerCase();

    for (final String prefix in namePrefixes) {
      if (lower.startsWith(prefix)) {
        return true;
      }
    }

    for (final String extension in extensions) {
      if (lower.endsWith('.$extension')) {
        return true;
      }
    }

    return false;
  }

  /// Whether a directory called [name] is one this rule takes whole.
  bool matchesDirectory(String name) =>
      mode == JunkRuleMode.directories &&
      directoryNames.contains(name.toLowerCase());
}
