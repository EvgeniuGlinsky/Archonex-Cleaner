import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:archonex_cleaner/core/constants/app_optimizer_policy.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';

/// Re-encodes a photograph in pure Dart, on the three platforms with no native
/// encoder wired up.
///
/// Windows, Linux and macOS. It needs nothing installed, which is the whole
/// reason it exists: the desktop story for video is already "you may not have
/// `ffmpeg`", and having the photo half depend on something too would leave a
/// tool that usually cannot do anything.
///
/// The cost is speed. Decoding a 12 MP JPEG and writing it back takes about a
/// second on a laptop, which is why every call goes through [Isolate.run] — a
/// second of blocked event loop per file is a frozen screen for the length of
/// a camera roll. Android and iOS use `NativeImageEncoder` instead, where the
/// same work is hardware-assisted and a pure-Dart pass over a phone's photos
/// would take an afternoon.
class DartImageEncoder implements MediaEncoder {
  DartImageEncoder();

  bool _isCancelling = false;

  /// Always. There is nothing to install and nothing to detect.
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

    // Nothing between reading the file and writing it reports anything, so the
    // only honest progress is none. The bar for the file is indeterminate and
    // the run's own bar still steps once per file.
    final Uint8List source = await File(candidate.path).readAsBytes();

    if (_isCancelling) {
      return;
    }

    final Uint8List? encoded = await Isolate.run(
      () => _reencode(source, candidate.plan.quality ?? AppOptimizerPolicy.photoQuality),
    );

    if (encoded == null) {
      throw const FileSystemException('The image could not be decoded.');
    }

    if (_isCancelling) {
      return;
    }

    await File(outputPath).writeAsBytes(encoded, flush: true);

    yield 1;
  }

  /// Runs on the isolate. Top-level work only — nothing here may touch `this`.
  ///
  /// The EXIF block is carried across deliberately. It holds the date the
  /// picture was taken and the orientation it should be shown at, and a gallery
  /// without them reorders itself and turns half the photographs on their side.
  /// It is also, on a phone, the only record of where a picture was taken.
  ///
  /// The dimensions are never touched. Shrinking a photograph by making it
  /// smaller is not what was asked for and is not reversible; the size comes
  /// out of the quality scale alone, at the end where the bytes are and the
  /// detail is not.
  static Uint8List? _reencode(Uint8List source, int quality) {
    final img.Image? decoded = img.decodeImage(source);

    if (decoded == null) {
      return null;
    }

    return img.encodeJpg(decoded, quality: quality);
  }
}
