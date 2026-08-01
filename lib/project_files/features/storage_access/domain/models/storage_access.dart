import 'package:equatable/equatable.dart';

/// How much of the device the app is currently allowed to look at.
enum StorageAccessLevel {
  /// Everything the rules for this platform name. Every desktop, and Android
  /// once all-files access has been granted.
  full,

  /// Only folders the user handed over one at a time through the system picker.
  scopedFolders,

  /// The app's own cache and temporary directory. iOS always; Android when
  /// all-files access was refused.
  appOnly,

  /// Nothing — there is no file system here at all. Web.
  none,
}

/// The answer to "where may I look", and what can still be done about it.
///
/// [canRequestMore], [canAddFolder] and [isPermanentlyDenied] are fields rather
/// than questions derived from [level], because the same level means different
/// things per platform: iOS is `appOnly` and there is nothing to ask for,
/// Android is `appOnly` and there is — or was, until the user closed the door.
final class StorageAccess extends Equatable {
  const StorageAccess({
    required this.level,
    this.grantedRoots = const <String>[],
    this.canRequestMore = false,
    this.canAddFolder = false,
    this.isPermanentlyDenied = false,
  });

  /// Every desktop: the rules name paths the process can already read.
  const StorageAccess.open()
      : level = StorageAccessLevel.full,
        grantedRoots = const <String>[],
        canRequestMore = false,
        canAddFolder = false,
        isPermanentlyDenied = false;

  /// Web: no file system, and no permission that would produce one.
  const StorageAccess.unavailable()
      : level = StorageAccessLevel.none,
        grantedRoots = const <String>[],
        canRequestMore = false,
        canAddFolder = false,
        isPermanentlyDenied = false;

  /// iOS, and a sandboxed macOS build: the container, permanently.
  ///
  /// Not [isPermanentlyDenied], which would be the wrong word for it: nothing
  /// was refused here and there is no setting to go and change. The platform is
  /// simply built this way, and those are two different sentences to read.
  const StorageAccess.sandboxed()
      : level = StorageAccessLevel.appOnly,
        grantedRoots = const <String>[],
        canRequestMore = false,
        canAddFolder = false,
        isPermanentlyDenied = false;

  final StorageAccessLevel level;

  /// Extra roots the user picked, on top of whatever [level] already covers.
  final List<String> grantedRoots;

  /// Whether a permission dialog exists that would widen [level].
  final bool canRequestMore;

  /// Whether the folder picker is a route to more coverage.
  final bool canAddFolder;

  /// Whether the system has stopped offering the permission sheet.
  ///
  /// The one state that used to be indistinguishable from iOS, and read as it:
  /// both are `appOnly` with nothing to request, but here the door is closed
  /// rather than absent, and Settings is the way back through it. Told apart so
  /// the screen can say which of the two it is and offer the route that exists.
  final bool isPermanentlyDenied;

  /// Whether a scan is worth starting at all.
  bool get canScan => level != StorageAccessLevel.none;

  /// Whether the app is seeing the whole device.
  bool get isComplete => level == StorageAccessLevel.full;

  /// Whether the screen should say the scan is going to be partial.
  ///
  /// True for a narrowed Android and for iOS alike — the reason differs, the
  /// consequence for the user does not, and the mapper tells the two apart.
  bool get isNarrowed =>
      level == StorageAccessLevel.appOnly ||
      level == StorageAccessLevel.scopedFolders;

  StorageAccess copyWith({
    StorageAccessLevel? level,
    List<String>? grantedRoots,
    bool? canRequestMore,
    bool? canAddFolder,
    bool? isPermanentlyDenied,
  }) {
    return StorageAccess(
      level: level ?? this.level,
      grantedRoots: grantedRoots ?? this.grantedRoots,
      canRequestMore: canRequestMore ?? this.canRequestMore,
      canAddFolder: canAddFolder ?? this.canAddFolder,
      isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        level,
        grantedRoots,
        canRequestMore,
        canAddFolder,
        isPermanentlyDenied,
      ];
}
