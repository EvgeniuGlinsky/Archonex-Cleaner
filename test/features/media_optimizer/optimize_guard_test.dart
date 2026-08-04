import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/media_roots.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/off_limits_paths.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/rules/optimize_guard.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// The four questions, asked one at a time.
///
/// `deletion_guard_test.dart` is the same shape next door. The clock is
/// injected, so "written ninety seconds ago" is a literal rather than a wait.
void main() {
  final DateTime now = DateTime.utc(2026, 8, 1, 12);

  const MediaRoots roots = MediaRoots(
    appSupport: '/home/sam/.local/share/com.archonex.storagecleaner',
    home: '/home/sam',
    pictures: '/home/sam/Pictures',
    videos: '/home/sam/Videos',
  );

  final OptimizeGuard guard = OptimizeGuard(
    offLimitsPaths: OffLimitsPaths(
      context: p.Context(style: p.Style.posix),
      roots: OffLimitsPaths.of(TargetPlatform.linux, roots).roots,
      segments: OffLimitsPaths.of(TargetPlatform.linux, roots).segments,
    ),
    now: () => now,
  );

  bool allows({
    String path = '/home/sam/Pictures/holiday.jpg',
    MediaKind kind = MediaKind.photo,
    int? sizeInBytes,
    DateTime? modifiedAt,
    bool isLink = false,
  }) {
    return guard.allows(
      path: path,
      kind: kind,
      sizeInBytes: sizeInBytes ?? 8 * AppByteUnits.megabyte,
      modifiedAt: modifiedAt ?? now.subtract(const Duration(days: 30)),
      isLink: isLink,
    );
  }

  test('an ordinary large photo in a media folder passes', () {
    expect(allows(), isTrue);
  });

  test('a symlink is refused before it is resolved', () {
    // Following one out of a media folder is how a walk ends up somewhere it
    // was never sent.
    expect(allows(isLink: true), isFalse);
  });

  test('a file inside an off-limits directory is refused', () {
    expect(allows(path: '/home/sam/Dropbox/Photos/a.jpg'), isFalse);
    expect(allows(path: '/home/sam/.cache/thumbnails/a.jpg'), isFalse);
  });

  group('the size floor', () {
    test('a photo under the photo floor is refused', () {
      expect(
        allows(sizeInBytes: AppOptimizerPolicy.minimumPhotoBytes - 1),
        isFalse,
      );
    });

    test('exactly the floor passes', () {
      expect(
        allows(sizeInBytes: AppOptimizerPolicy.minimumPhotoBytes),
        isTrue,
      );
    });

    test('a video is held to a much higher floor than a photo', () {
      // A photo costs a second of CPU and a video costs minutes, so the two
      // floors are not the same number and cannot be.
      const int betweenTheFloors = 4 * AppByteUnits.megabyte;

      expect(
        allows(
          path: '/home/sam/Videos/clip.mp4',
          kind: MediaKind.video,
          sizeInBytes: betweenTheFloors,
        ),
        isFalse,
      );
      expect(allows(sizeInBytes: betweenTheFloors), isTrue);
    });

    test('the floors the walker skips on are the ones the guard enforces', () {
      // The walker checks the floor before it stats, to avoid opening
      // thousands of thumbnails. If the two ever disagree the cheap check is
      // wrong and nothing else would say so.
      expect(
        OptimizeGuard.minimumBytesFor(MediaKind.photo),
        AppOptimizerPolicy.minimumPhotoBytes,
      );
      expect(
        OptimizeGuard.minimumBytesFor(MediaKind.video),
        AppOptimizerPolicy.minimumVideoBytes,
      );
    });
  });

  group('the age floor', () {
    test('a file written ninety seconds ago is refused', () {
      // It may still be being written. Reading it half-formed and re-encoding
      // it produces something truncated, and the original is deleted after
      // that.
      expect(
        allows(modifiedAt: now.subtract(const Duration(seconds: 90))),
        isFalse,
      );
    });

    test('exactly the floor passes', () {
      expect(
        allows(modifiedAt: now.subtract(AppOptimizerPolicy.minimumAge)),
        isTrue,
      );
    });

    test('a file dated in the future is refused', () {
      // A wrong clock somewhere, and no reason to trust anything else about it.
      expect(allows(modifiedAt: now.add(const Duration(days: 1))), isFalse);
    });
  });

  test('all four are asked, not just the first that fails', () {
    expect(
      allows(
        path: '/home/sam/OneDrive/a.jpg',
        sizeInBytes: 1,
        modifiedAt: now,
        isLink: true,
      ),
      isFalse,
    );
  });
}
