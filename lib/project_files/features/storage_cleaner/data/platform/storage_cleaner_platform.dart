/// Picks the data layer that fits the platform the app was compiled for.
///
/// `dart:io` is the whole reason this boundary exists: importing it from code
/// that also compiles to web breaks the web build outright, and every one of
/// the four implementations below is built on it. Callers only ever see the
/// factories:
///
/// * `createJunkScanRepo()`
/// * `createJunkCleanRepo(quarantine)`
/// * `createQuarantineRepo()`
/// * `createStorageAccessRepo()`
///
/// `Platform.is*` and `kIsWeb` appear nowhere above this file. Inside it, the
/// io side still asks `defaultTargetPlatform` — Android, iOS and the desktops
/// need different access repositories and they all compile against `dart:io` —
/// and that question is a runtime one, unlike the compile-time one this
/// conditional export answers.
library;

export 'storage_cleaner_platform_web.dart'
    if (dart.library.io) 'storage_cleaner_platform_io.dart';
