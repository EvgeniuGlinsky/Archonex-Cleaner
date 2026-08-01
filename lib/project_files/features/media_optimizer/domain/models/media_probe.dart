import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// What reading the first few kilobytes of a file said about it.
///
/// Only what a header can answer, and nothing that needs decoding: dimensions,
/// container, and for a video the codec, the length and the frame rate. That
/// is exactly the set `SavingsEstimator` needs, which is not a coincidence —
/// anything requiring a decode would mean opening every file on the device
/// twice, once to decide and once to convert.
///
/// The video fields are null on a photo. A video that parsed but would not give
/// up its duration keeps [durationMs] null too, and the estimator refuses it
/// rather than guessing: without a length there is no bitrate, and without a
/// bitrate there is no question to answer.
final class MediaProbe extends Equatable {
  const MediaProbe({
    required this.container,
    required this.width,
    required this.height,
    this.codec,
    this.durationMs,
    this.frameRate,
  });

  final MediaContainer container;
  final int width;
  final int height;

  /// Video only.
  final VideoCodec? codec;
  final int? durationMs;
  final double? frameRate;

  MediaKind get kind => container.kind;

  int get pixelCount => width * height;

  /// Whether the header gave up enough to judge the file on.
  ///
  /// Dimensions are the floor for both kinds; a video additionally needs a
  /// length and a frame rate, because the whole judgement is bits per pixel per
  /// frame and two of those three come from here.
  bool get isComplete {
    if (width <= 0 || height <= 0) {
      return false;
    }

    if (kind == MediaKind.photo) {
      return true;
    }

    final int? duration = durationMs;
    final double? rate = frameRate;

    return duration != null && duration > 0 && rate != null && rate > 0;
  }

  @override
  List<Object?> get props =>
      <Object?>[container, width, height, codec, durationMs, frameRate];
}
