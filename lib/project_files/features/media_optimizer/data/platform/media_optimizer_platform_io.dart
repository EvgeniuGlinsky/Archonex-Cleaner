import 'package:flutter/foundation.dart';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/encoders/android_video_encoder.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/encoders/dart_image_encoder.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/encoders/ffmpeg_video_encoder.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/encoders/native_image_encoder.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/file_system/io_media_optimize_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/file_system/io_media_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/file_system/unsupported_media_optimize_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/file_system/unsupported_media_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';

/// Android and the three desktops. iOS compiles against `dart:io` too and gets
/// the refusals, because its file system holds nothing the user put there.
MediaScanRepo createMediaScanRepo() {
  return _reachesUserMedia
      ? IoMediaScanRepo()
      : const UnsupportedMediaScanRepo();
}

MediaOptimizeRepo createMediaOptimizeRepo() {
  if (!_reachesUserMedia) {
    return const UnsupportedMediaOptimizeRepo();
  }

  return IoMediaOptimizeRepo(
    photoEncoder: _photoEncoder(),
    videoEncoder: _videoEncoder(),
  );
}

/// Whether this platform's file system holds the user's own photographs.
///
/// iOS's does not, and no permission changes it. Fuchsia has no runner and the
/// conservative answer promises nothing.
bool get _reachesUserMedia =>
    defaultTargetPlatform != TargetPlatform.iOS &&
    defaultTargetPlatform != TargetPlatform.fuchsia;

/// The phones get the platform's codec; the desktops get pure Dart.
///
/// Not a preference. A pure-Dart pass over a phone's camera roll would take an
/// afternoon, and a native plugin on Windows and Linux does not exist. The two
/// produce the same file — a JPEG at the same quality and the same dimensions —
/// which is what makes the choice an implementation detail rather than a
/// product one.
MediaEncoder _photoEncoder() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => NativeImageEncoder(),
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS =>
      DartImageEncoder(),
    TargetPlatform.iOS || TargetPlatform.fuchsia => const UnavailableEncoder(),
  };
}

/// Android has a `MediaCodec` pipeline written for it; the desktops shell out
/// to whatever `ffmpeg` is on the path, and may find none.
MediaEncoder _videoEncoder() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidVideoEncoder(),
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS =>
      FfmpegVideoEncoder(),
    TargetPlatform.iOS || TargetPlatform.fuchsia => const UnavailableEncoder(),
  };
}
