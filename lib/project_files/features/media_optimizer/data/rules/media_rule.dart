import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';

/// One folder to walk, and what counts once the walk is inside it.
///
/// Far simpler than `JunkRule`, and the simplicity is the point. The cleaner
/// needs four matching modes because junk hides in directory *shapes* — an
/// empty folder, a whole cache tree, a file whose name starts with `~$`. Media
/// is a file with a recognisable header inside a folder the user filled, so
/// there is one mode and the rule only has to say where to start.
///
/// A row is a location. Adding a *kind* of file is an entry in
/// `MediaContainer`, and adding a reason to refuse one is `OffLimitsPaths`.
class MediaRule {
  const MediaRule({
    required this.root,
    required this.label,
    this.maxDepth = AppOptimizerPolicy.maxScanDepth,
  });

  /// Absolute path to start from. Resolved by `MediaRootsResolver` and never
  /// composed here.
  final String root;

  /// What the progress line calls this folder while it is being walked.
  ///
  /// The folder's own name rather than a translated one: it is a place on the
  /// user's disk, and a user looking for where 8 GB went is better served by
  /// the string they would type than by a description of it.
  final String label;

  /// How deep to descend. People nest photo folders by year and by event, which
  /// is two or three, and the default leaves room.
  final int maxDepth;

  /// Whether a file name is one this tool would even open.
  ///
  /// The extension is a first filter and not the verdict — what a file actually
  /// is comes from its magic bytes, in `MediaProbeReader`. It exists so a walk
  /// of a folder full of documents does not open every one of them.
  bool matchesFile(String fileName) {
    // A working file from a run that crashed part way. Never a candidate: it is
    // half an encode, and the next run sweeps it away rather than measuring it.
    //
    // The name the app wrote under its working title is refused as well, and
    // that is the load-bearing half of these four checks:
    // `.archonex-working-holiday.jpg` ends in `.jpg` and would sail through the
    // extension filter below, where a superseded original never does. The older
    // suffix is named anyway, so the pair reads as a pair.
    if (fileName.startsWith(AppOptimizerPolicy.workingPrefix) ||
        fileName.startsWith(AppOptimizerPolicy.legacyWorkingPrefix)) {
      return false;
    }

    if (fileName.endsWith(AppOptimizerPolicy.supersededSuffix) ||
        fileName.endsWith(AppOptimizerPolicy.legacySupersededSuffix)) {
      return false;
    }

    final int dot = fileName.lastIndexOf('.');

    if (dot < 0) {
      return false;
    }

    return MediaContainer.allExtensions.contains(
      fileName.substring(dot).toLowerCase(),
    );
  }
}
