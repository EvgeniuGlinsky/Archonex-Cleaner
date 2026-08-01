/// Picks the disk reader that fits the platform the app was compiled for.
///
/// Its own barrel rather than a factory on the cleaner's, because both the home
/// screen and the cleaner draw the ring and neither owns it — see
/// `quarantine_platform.dart`, which is separate for the same reason.
///
/// Callers see one factory: `createDeviceStorageRepo()`.
library;

export 'device_storage_platform_web.dart'
    if (dart.library.io) 'device_storage_platform_io.dart';
