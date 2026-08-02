/// Picks the data layer that fits the platform the app was compiled for.
///
/// One factory and one compile-time question — is there a `dart:io` here — with
/// the runtime part of the answer left to `IoStorageInsightsRepo.isSupported`,
/// which reads `defaultTargetPlatform`. That split is the same one
/// `storage_cleaner_platform` makes and for the same reason: iOS compiles
/// against `dart:io` and still has nothing to walk.
library;

export 'storage_insights_platform_web.dart'
    if (dart.library.io) 'storage_insights_platform_io.dart';
