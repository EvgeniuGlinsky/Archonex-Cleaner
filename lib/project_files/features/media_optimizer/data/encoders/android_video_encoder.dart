import 'dart:async';

import 'package:flutter/services.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/media_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';

/// Re-encodes a video through Android's own media stack.
///
/// The first platform channel in this project, and the reason it exists is that
/// nothing on pub does this job. The packages that compress video all reduce
/// the *resolution* to get their savings, which is precisely the quality loss
/// this feature was asked to avoid, and none of them will write HEVC — which is
/// where the forty per cent actually comes from. FFmpegKit, which would have,
/// was retired in January 2025.
///
/// So the Kotlin side is a `MediaCodec` pipeline: extract, decode onto a
/// surface, encode as HEVC, mux. Same width, same height, same frame rate, and
/// the audio track copied through without being touched. It is
/// hardware-accelerated on every device made in about the last decade, which
/// matters more here than anywhere else in the app — a phone re-encoding an
/// hour of video in software would be warm to hold and flat by the end.
///
/// The Dart side is this file and nothing else: a channel, a progress stream
/// and a cancel. Everything that decides *whether* to encode is in
/// `SavingsEstimator`, and everything that decides what happens to the original
/// is in `IoMediaOptimizeRepo`. The native code is handed two paths and asked
/// for a file.
class AndroidVideoEncoder implements MediaEncoder {
  AndroidVideoEncoder({
    MethodChannel? channel,
    EventChannel? events,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _events = events ?? const EventChannel(_eventsName);

  static const String _channelName = 'com.archonex.cleaner/transcoder';
  static const String _eventsName = 'com.archonex.cleaner/transcoder/progress';

  final MethodChannel _channel;
  final EventChannel _events;

  Future<bool>? _availability;

  /// Whether this device's media stack offers an HEVC encoder.
  ///
  /// Asked rather than assumed from the API level. It is a property of the
  /// chip, and while every phone since roughly 2015 has one, "roughly" is not
  /// something to ship a delete-the-original feature on. Cached, because the
  /// answer cannot change while the app is open.
  @override
  Future<bool> get isAvailable => _availability ??= _probeAvailability();

  Future<bool> _probeAvailability() async {
    try {
      return await _channel.invokeMethod<bool>('hasHevcEncoder') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // The channel is not registered — a debug build of another platform, or a
      // widget test. Not an error, just no encoder.
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // The run had already finished. Nothing to stop.
    } on MissingPluginException {
      // The channel was never registered — another platform's build, or a
      // widget test. Caught here as well as in `_probeAvailability` because
      // this one is reached from `MediaOptimizerBloc.close()`: an exception
      // there is thrown while the screen is being torn down, where nothing is
      // left to catch it.
    }
  }

  @override
  Stream<double> encode({
    required MediaCandidate candidate,
    required String outputPath,
  }) async* {
    final StreamController<double> progress = StreamController<double>();

    final StreamSubscription<dynamic> events = _events.receiveBroadcastStream().listen(
      (Object? value) {
        if (value is double && !progress.isClosed) {
          progress.add(value.clamp(0.0, 1.0));
        }
      },
      onError: (Object _) {
        // Progress is decoration. Losing it must not fail a run that is
        // otherwise working, and the file's bar goes indeterminate instead.
      },
    );

    final Future<void> transcode = _channel.invokeMethod<void>(
      'transcode',
      <String, Object>{
        'input': candidate.path,
        'output': outputPath,
      },
    ).catchError((Object error, StackTrace stackTrace) {
      // Put onto the stream rather than left on the future, because the future
      // is only awaited below if the consumer drains the stream — and the one
      // consumer that does not is the user pressing Cancel, which is exactly
      // when a half-finished transcode is most likely to fail. Left on the
      // future it surfaced as an unhandled zone error with the screen already
      // gone; here it reaches whoever is still listening, and is dropped
      // quietly by whoever is not.
      if (!progress.isClosed) {
        progress.addError(error, stackTrace);
      }
    }).whenComplete(() async {
      await events.cancel();

      if (!progress.isClosed) {
        await progress.close();
      }
    });

    yield* progress.stream;

    // Still awaited, so a caller that drains the stream to its end does not
    // return before the platform side has finished with the file.
    await transcode;
  }
}
