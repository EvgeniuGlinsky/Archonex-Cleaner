/// Picks the access repository that fits the platform the app was compiled for.
///
/// A barrel of its own rather than a fourth factory on the cleaner's, because
/// two tools now ask the same question: the cleaner wants to know where it may
/// look, and the optimiser wants to know where it may rewrite. Leaving the
/// factory on `storage_cleaner_platform.dart` would have made the optimiser
/// import the cleaner to find out whether it is allowed to run.
///
/// Callers only ever see `createStorageAccessRepo()`. `Platform.is*` and
/// `kIsWeb` appear nowhere above this file; inside the io side
/// `defaultTargetPlatform` still does, because Android, iOS and the three
/// desktops all compile against `dart:io` and give different answers, and that
/// is a runtime question rather than the compile-time one this export answers.
library;

export 'storage_access_platform_web.dart'
    if (dart.library.io) 'storage_access_platform_io.dart';
