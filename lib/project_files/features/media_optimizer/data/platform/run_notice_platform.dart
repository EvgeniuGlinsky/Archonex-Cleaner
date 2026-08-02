/// Picks the thing that keeps a run alive when the app is not on screen.
///
/// Its own boundary rather than a third factory on `media_optimizer_platform`,
/// because it answers a different question. That one asks which encoder can do
/// the work; this asks what the operating system does to a process that is not
/// in front of the user, and only one operating system here does anything at
/// all. Everywhere else `SilentRunNotice` is not a refusal — it is the correct
/// answer.
library;

export 'run_notice_platform_web.dart'
    if (dart.library.io) 'run_notice_platform_io.dart';
