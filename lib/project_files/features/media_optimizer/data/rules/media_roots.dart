import 'package:equatable/equatable.dart';

/// The directories the media rules are written against, resolved once per scan.
///
/// The same arrangement as `CleanerRoots` and for the same reason: the rule
/// tables are pure — `WindowsMediaRules.of(roots)` returns a list and touches
/// no disk — and everything machine-specific is answered by
/// `MediaRootsResolver` and handed in. It is what lets the Android rules be
/// tested from Linux CI.
///
/// Where it differs is what it holds, and the difference is the whole
/// distinction between the two tools. `CleanerRoots` names the places the user
/// never goes; this names the places the user *lives*. Pictures, DCIM, Movies
/// are on the cleaner's protected list precisely so nothing is ever deleted
/// from them, and they are the entire subject here — the optimiser only ever
/// touches folders the user filled themselves, and `OffLimitsPaths` keeps it
/// out of everything else.
///
/// Every field is nullable, because an environment variable can be missing and
/// a rule pointing at `null` is dropped rather than guessed at.
final class MediaRoots extends Equatable {
  const MediaRoots({
    required this.appSupport,
    this.home,
    this.pictures,
    this.videos,
    this.downloads,
    this.camera,
    this.screenshots,
    this.externalStorage,
    this.appMedia,
    this.secondaryVolumes = const <String>[],
    this.grantedFolders = const <String>[],
  });

  /// This app's own support directory, which holds the cleaner's quarantine.
  /// Never walked; named so `OffLimitsPaths` can refuse it — a quarantined
  /// photo is a file the user is part way through deciding about, and rewriting
  /// it would make the restore give back something different from what went in.
  final String appSupport;

  /// The user's home directory. `null` on Android, where an app has none.
  final String? home;

  /// `~/Pictures`, or Android's shared `Pictures`.
  final String? pictures;

  /// `~/Videos` on Windows and Linux, `~/Movies` on macOS, `Movies` on Android.
  final String? videos;

  /// Where a browser puts things. Included because a downloaded video is the
  /// single largest file on a great many machines, and excluded from the
  /// cleaner for the opposite reason — there it is a `.msi` somebody paid for.
  final String? downloads;

  /// Android's `DCIM`: the camera roll, and the reason this feature exists.
  final String? camera;

  /// Android's `Pictures/Screenshots`. Named separately from [pictures] because
  /// screenshots are PNGs of flat interface colour and the estimator treats
  /// them differently from photographs — see
  /// `AppOptimizerPolicy.pngPhotographicBytesPerPixel`.
  final String? screenshots;

  /// Android's shared storage root, `/storage/emulated/0`.
  final String? externalStorage;

  /// Android's `Android/media`, where the messengers live.
  ///
  /// Scoped storage moved them there: since Android 11 an app that wants its
  /// media visible to the gallery writes under `Android/media/<package>`
  /// instead of a folder of its own at the top level, so `WhatsApp/Media` and
  /// `Telegram/Telegram Video` are here rather than beside `DCIM`. It is
  /// readable with all-files access, unlike its neighbour `Android/data`, and
  /// on a phone that has had a messenger on it for a few years it is very often
  /// larger than the camera roll.
  final String? appMedia;

  /// The shared roots of any other mounted volume — an SD card, in practice.
  ///
  /// Empty on every platform but Android, and on most Android phones. Where
  /// there is one it is usually where the large files went, which is the whole
  /// reason somebody fitted it.
  final List<String> secondaryVolumes;

  /// Folders the user handed over one at a time through the picker.
  final List<String> grantedFolders;

  @override
  List<Object?> get props => <Object?>[
        appSupport,
        home,
        pictures,
        videos,
        downloads,
        camera,
        screenshots,
        externalStorage,
        appMedia,
        secondaryVolumes,
        grantedFolders,
      ];
}
