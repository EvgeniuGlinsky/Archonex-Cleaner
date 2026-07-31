import 'package:equatable/equatable.dart';

/// The directories a ruleset is written against, resolved once per scan.
///
/// The rulesets are pure tables — `WindowsJunkRules.of(roots)` returns a list
/// and touches no disk — and this is what makes that possible: every path that
/// depends on the machine is answered here, by `CleanerRootsResolver`, and
/// handed in. It is also what lets the Windows rules be tested from Linux CI.
///
/// Every field is nullable except the two the app can always answer for itself,
/// because an environment variable can be missing and a rule pointing at `null`
/// is dropped rather than guessed at.
final class CleanerRoots extends Equatable {
  const CleanerRoots({
    required this.appCache,
    required this.appSupport,
    this.externalAppCaches = const <String>[],
    this.home,
    this.systemTemp,
    this.localAppData,
    this.roamingAppData,
    this.windowsDirectory,
    this.externalStorage,
    this.grantedFolders = const <String>[],
  });

  /// `getTemporaryDirectory()`, and **only app-specific on Android and iOS**.
  ///
  /// On the three desktops it answers the shared system temp directory itself —
  /// `%TEMP%`, `/tmp`, `$TMPDIR` — rather than a subdirectory of it, which is
  /// why no desktop table has an `appCache` row: it would be the system temp
  /// wearing this app's name. See `WindowsJunkRules.of`.
  ///
  /// Present on every platform regardless, including web, where it is the only
  /// root that resolves at all.
  final String appCache;

  /// This app's own support directory, which is where the quarantine lives.
  /// Never scanned; named here so `ProtectedPaths` can refuse to delete it.
  final String appSupport;

  /// Android's per-volume external caches, which are ours to empty too.
  final List<String> externalAppCaches;

  /// The user's home directory. `null` on Android and iOS, where the concept
  /// does not apply to an app.
  final String? home;

  /// `%TEMP%`, `/tmp`, or whatever `TMPDIR` says.
  final String? systemTemp;

  /// Windows only.
  final String? localAppData;
  final String? roamingAppData;
  final String? windowsDirectory;

  /// Android's shared storage — `/storage/emulated/0`. Only readable with
  /// all-files access, which is why the ruleset takes the access level too.
  final String? externalStorage;

  /// Folders the user handed over one at a time through the picker.
  final List<String> grantedFolders;

  @override
  List<Object?> get props => <Object?>[
        appCache,
        appSupport,
        externalAppCaches,
        home,
        systemTemp,
        localAppData,
        roamingAppData,
        windowsDirectory,
        externalStorage,
        grantedFolders,
      ];
}
