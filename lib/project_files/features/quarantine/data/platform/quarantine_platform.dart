/// Picks the quarantine that fits the platform the app was compiled for.
///
/// Its own barrel rather than a fifth factory on the cleaner's, because the
/// quarantine is a feature of its own and the cleaner depends on it: the
/// dependency has to be able to point one way, and a shared barrel would make
/// both sides import both features.
///
/// Callers see one factory: `createQuarantineRepo()`.
library;

export 'quarantine_platform_web.dart'
    if (dart.library.io) 'quarantine_platform_io.dart';
