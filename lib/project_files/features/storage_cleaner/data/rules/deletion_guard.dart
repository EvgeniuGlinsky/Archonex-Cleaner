import 'package:path/path.dart' as p;

import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';

/// The four questions asked about every single finding, in order, before it is
/// allowed onto the list the user sees.
///
/// Pure and clock-injected on purpose: this is the class whose being wrong is
/// expensive, and it is unit-tested against every platform's `ProtectedPaths`
/// without a file system anywhere near it.
class DeletionGuard {
  const DeletionGuard({
    required ProtectedPaths protectedPaths,
    required DateTime Function() now,
    required p.Context context,
  })  : _protectedPaths = protectedPaths,
        _now = now,
        _context = context;

  final ProtectedPaths _protectedPaths;
  final DateTime Function() _now;
  final p.Context _context;

  /// Whether this finding may be offered for deletion.
  bool allows({
    required String path,
    required String ruleRoot,
    required DateTime modifiedAt,
    required Duration minimumAge,
    required bool isLink,
  }) {
    // 1. A symlink is a name pointing at something else, and deleting what it
    //    points at is never what the rule meant. Refused before anything is
    //    resolved, so a link into `System32` is not even measured.
    if (isLink) {
      return false;
    }

    // 2. Emptying a directory must not delete the directory. `%TEMP%` that no
    //    longer exists breaks the next installer to run.
    if (_context.equals(_context.normalize(path), _context.normalize(ruleRoot))) {
      return false;
    }

    // 3. The guard, which the rule does not get to overrule.
    if (_protectedPaths.contains(path)) {
      return false;
    }

    // 4. Age. A file written minutes ago is junk in use, not junk left behind.
    return _now().difference(modifiedAt) >= minimumAge;
  }
}
