/// Picks the data layer that fits the platform the app was compiled for.
///
/// Two factories, and the second is where this boundary earns more than the
/// cleaner's does. `createMediaScanRepo()` is a compile-time question — is
/// there a `dart:io` here — but the encoders behind
/// `createMediaOptimizeRepo()` are four completely different things: a
/// pure-Dart codec, a platform plugin, a Kotlin `MediaCodec` pipeline and an
/// `ffmpeg` process. Which of them is right is a runtime question, and it is
/// answered inside the io side by `defaultTargetPlatform`.
///
/// Whether the chosen one *works* is a third question again, and neither of
/// these answers it. `MediaOptimizeRepo.support()` does, by asking the machine
/// — see `FfmpegVideoEncoder.isAvailable`.
library;

export 'media_optimizer_platform_web.dart'
    if (dart.library.io) 'media_optimizer_platform_io.dart';
