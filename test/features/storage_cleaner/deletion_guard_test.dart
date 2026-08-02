import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_clean_policy.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/cleaner_roots.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/deletion_guard.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/rules/protected_paths.dart';

/// The four questions, one at a time.
///
/// Clock-injected, so "a file written a minute ago" is a literal rather than
/// something the test has to wait for.
void main() {
  final DateTime now = DateTime.utc(2026, 7, 31, 12);

  const CleanerRoots roots = CleanerRoots(
    appCache: '/home/tester/.cache/storage_cleaner',
    appSupport: '/home/tester/.local/share/storage_cleaner',
    home: '/home/tester',
    systemTemp: '/tmp',
  );

  DeletionGuard guard() => DeletionGuard(
        protectedPaths: ProtectedPaths.of(TargetPlatform.linux, roots),
        now: () => now,
        context: p.Context(style: p.Style.posix),
      );

  bool allows({
    required String path,
    String ruleRoot = '/tmp',
    Duration age = const Duration(days: 1),
    Duration minimumAge = AppCleanPolicy.minimumAge,
    bool isLink = false,
  }) {
    return guard().allows(
      path: path,
      ruleRoot: ruleRoot,
      modifiedAt: now.subtract(age),
      minimumAge: minimumAge,
      isLink: isLink,
    );
  }

  test('an ordinary old file inside the rule root is allowed', () {
    expect(allows(path: '/tmp/build-1234/output.o'), isTrue);
  });

  test('a symlink is refused before anything about it is resolved', () {
    expect(allows(path: '/tmp/shortcut', isLink: true), isFalse);
  });

  test('the rule root itself is never deleted, only emptied', () {
    expect(allows(path: '/tmp'), isFalse);
    expect(allows(path: '/tmp/'), isFalse);
    expect(allows(path: '/tmp/./'), isFalse);
  });

  test('a protected path is refused even when the rule points at it', () {
    expect(allows(path: '/etc/passwd', ruleRoot: '/etc'), isFalse);
  });

  test('a file younger than the floor is refused', () {
    expect(
      allows(path: '/tmp/in-progress.part', age: const Duration(minutes: 1)),
      isFalse,
    );
  });

  test('a file exactly at the floor is allowed', () {
    expect(
      allows(path: '/tmp/done.tmp', age: AppCleanPolicy.minimumAge),
      isTrue,
    );
  });

  test("a rule's longer floor wins over the global one", () {
    // The browser-cache rules ask for a day, and the guard has to honour the
    // longer of the two rather than the global hour.
    expect(
      allows(
        path: '/tmp/cache-entry',
        age: const Duration(hours: 4),
        minimumAge: const Duration(days: 1),
      ),
      isFalse,
    );
  });

  test('a file dated in the future is refused', () {
    // A clock skew or a bad archive extraction. The difference is negative, so
    // it cannot reach the floor — which is the safe way to be wrong.
    expect(
      allows(path: '/tmp/tomorrow.tmp', age: const Duration(days: -1)),
      isFalse,
    );
  });

  test('every question is asked, so one pass does not excuse another', () {
    // Old enough, inside the root, not a link — and still protected.
    expect(
      allows(
        path: '/home/tester/.ssh/id_ed25519',
        ruleRoot: '/home/tester',
        age: const Duration(days: 400),
      ),
      isFalse,
    );
  });
}
