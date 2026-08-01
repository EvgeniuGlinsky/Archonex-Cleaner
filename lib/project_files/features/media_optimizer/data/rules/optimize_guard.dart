import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/off_limits_paths.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// The three questions asked about every file the walk turns up, in order,
/// before it is opened at all.
///
/// `DeletionGuard` next door is the same idea for the same reason: this is the
/// class whose being wrong is expensive, so it is pure, clock-injected, and
/// unit-tested against every platform's `OffLimitsPaths` with no file system
/// anywhere near it.
///
/// Everything it refuses is dropped silently rather than listed with a reason.
/// That is the opposite of what happens downstream — `SavingsEstimator` reports
/// why it left a file alone — and the difference is a matter of volume: a
/// camera roll holds thousands of files under the size floor and a handful of
/// files worth explaining.
///
/// It runs *before* the header is read, which is the point of the ordering. A
/// probe costs an open and a read on every file, and there is no reason to
/// spend one on a thumbnail, a symlink, or a photograph inside somebody's
/// OneDrive.
class OptimizeGuard {
  const OptimizeGuard({
    required OffLimitsPaths offLimitsPaths,
    required DateTime Function() now,
  })  : _offLimitsPaths = offLimitsPaths,
        _now = now;

  final OffLimitsPaths _offLimitsPaths;
  final DateTime Function() _now;

  /// Whether this file may be measured and offered.
  bool allows({
    required String path,
    required MediaKind kind,
    required int sizeInBytes,
    required DateTime modifiedAt,
    required bool isLink,
  }) {
    // 1. A symlink is a name pointing at something else. Rewriting what it
    //    points at is never what the rule meant, and following one out of a
    //    media folder is how a walk ends up inside a system directory. Refused
    //    before it is resolved, so the target is not even opened.
    if (isLink) {
      return false;
    }

    // 2. The list of places nothing is rewritten, which no rule overrules.
    if (_offLimitsPaths.contains(path)) {
      return false;
    }

    // 3. Big enough to be worth the CPU. Different floors per kind, because a
    //    photo costs a second and a video costs minutes.
    if (sizeInBytes < minimumBytesFor(kind)) {
      return false;
    }

    // 4. Old enough to have finished being written. A recording still being
    //    captured would be read half-formed and re-encoded into something
    //    truncated, and the original is deleted at the end of that.
    return _now().difference(modifiedAt) >= AppOptimizerPolicy.minimumAge;
  }

  /// The size floor for a kind. Public because the walker uses it to skip files
  /// before it stats them, and a test asserts the two agree.
  static int minimumBytesFor(MediaKind kind) => switch (kind) {
        MediaKind.photo => AppOptimizerPolicy.minimumPhotoBytes,
        MediaKind.video => AppOptimizerPolicy.minimumVideoBytes,
      };
}
