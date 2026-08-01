import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:storage_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';

/// Re-encodes a photograph through the platform's own codec, on the two
/// platforms where a pure-Dart pass would take an afternoon.
///
/// Android and iOS. The same work `DartImageEncoder` does, handed to
/// `Bitmap.compress` and `UIImage`, both of which are hardware-assisted and
/// roughly an order of magnitude faster. A phone is where the camera rolls are
/// and where the CPU is slowest, so this is the platform pair that most needs
/// it.
///
/// `keepExif` is not a preference. The date a picture was taken and the
/// orientation it should be shown at live there, and a gallery without them
/// reorders itself and turns half the photographs on their side. On a phone it
/// is also the only record of where a picture was taken.
class NativeImageEncoder implements MediaEncoder {
  NativeImageEncoder();

  bool _isCancelling = false;

  /// Always. The codec is part of the operating system.
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<void> cancel() async {
    _isCancelling = true;
  }

  @override
  Stream<double> encode({
    required MediaCandidate candidate,
    required String outputPath,
  }) async* {
    _isCancelling = false;

    // The plugin reports nothing while it works, so the file's own bar is
    // indeterminate. It is fast enough on these two platforms that the run's
    // bar stepping per file is the progress that matters.
    final Uint8List encoded = await FlutterImageCompress.compressWithFile(
          candidate.path,
          quality: candidate.plan.quality ?? AppOptimizerPolicy.photoQuality,
          format: CompressFormat.jpeg,
          keepExif: true,
          // The dimensions are never touched. Shrinking a photograph by making
          // it smaller is not what was asked for and cannot be undone; the size
          // comes out of the quality scale alone. The plugin's defaults would
          // cap the longest edge, so both are pinned above anything a camera
          // produces.
          minWidth: _noLimit,
          minHeight: _noLimit,
        ) ??
        Uint8List(0);

    if (encoded.isEmpty) {
      throw const FileSystemException('The image could not be decoded.');
    }

    if (_isCancelling) {
      return;
    }

    await File(outputPath).writeAsBytes(encoded, flush: true);

    yield 1;
  }

  /// Larger than any camera sensor in existence, which is how this plugin is
  /// told not to resize. It has no other way of being told.
  static const int _noLimit = 100000;
}
