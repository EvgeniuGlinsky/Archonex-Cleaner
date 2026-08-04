part of 'media_optimizer_bloc.dart';

enum MediaOptimizerStatus { idle, scanning, scanned, optimizing, optimized }

/// Everything the optimiser screen draws itself from.
///
/// Every question a widget asks is a getter here, computed and never stored, so
/// that two widgets cannot derive one condition differently — which is how a
/// button ends up enabled while the handler refuses. `props` lists every field:
/// leave one out and the screen never rebuilds when it changes, and no lint
/// says so.
final class MediaOptimizerState extends Equatable {
  const MediaOptimizerState({
    this.status = MediaOptimizerStatus.idle,
    this.isSupported = true,
    this.access = const StorageAccess.open(),
    this.support = const EncoderSupport(photos: true, videos: true),
    this.groups = const <MediaGroup>[],
    this.quality = OptimizeQuality.fallback,
    this.scanningLocation,
    this.progress,
    this.report,
    this.failure,
    this.storage,
    this.canBeGivenEncoder = false,
    this.encoderDownloadBytes = 0,
    this.encoderFetchProgress,
  });

  final MediaOptimizerStatus status;

  /// Whether this platform has media folders at all. False on web and iOS.
  final bool isSupported;

  final StorageAccess access;

  /// What this machine can encode, which is a different question from whether
  /// the platform could — see `GetEncoderSupportUseCase`.
  final EncoderSupport support;

  final List<MediaGroup> groups;

  /// How hard the user has asked the optimiser to press.
  ///
  /// Held here rather than read from the repository wherever it is needed,
  /// because every estimate on the screen is measured against it: a widget that
  /// went and asked separately could draw a saving from one preset beside a
  /// button offering another.
  final OptimizeQuality quality;

  /// The folder the walk is in, for the line under the bar.
  final String? scanningLocation;

  /// Non-null only while a run is going.
  final OptimizeProgress? progress;

  final OptimizeReport? report;
  final OptimizeFailure? failure;

  /// How full the disk is, or `null` where the platform will not say.
  final DeviceStorageSnapshot? storage;

  /// Whether a missing video encoder is something this platform can be handed.
  ///
  /// A property of the platform, read once — the three desktops can download one,
  /// the phones cannot. Held rather than asked at the call site so that no widget
  /// has to know a `EncoderSupplyRepo` exists.
  final bool canBeGivenEncoder;

  /// What that download weighs, for the sentence offering it. Zero where there
  /// is nothing to offer.
  final int encoderDownloadBytes;

  /// `0`–`1` while a download is running, `null` when none is.
  ///
  /// The presence of the fraction is what "a fetch is in flight" means, which is
  /// one field rather than a bool beside a double that could disagree with it.
  final double? encoderFetchProgress;

  bool get isScanning => status == MediaOptimizerStatus.scanning;

  bool get isOptimizing => status == MediaOptimizerStatus.optimizing;

  bool get isBusy => isScanning || isOptimizing;

  bool get hasScanned =>
      status == MediaOptimizerStatus.scanned ||
      status == MediaOptimizerStatus.optimized;

  /// Every media file measured, including the ones nothing can be done about.
  int get foundCount =>
      groups.fold(0, (sum, group) => sum + group.totalCount);

  /// The ones something can be done about.
  int get worthwhileCount =>
      groups.fold(0, (sum, group) => sum + group.worthwhile.length);

  bool get hasFindings => foundCount > 0;

  /// Whether anything on the screen can be acted on, as opposed to merely
  /// looked at. A scan that found four gigabytes of already-efficient HEVC has
  /// findings and nothing worth doing.
  bool get hasWorthwhile => worthwhileCount > 0;

  int get selectedCount =>
      groups.fold(0, (sum, group) => sum + group.selectedCount);

  int get selectedBytes =>
      groups.fold(0, (sum, group) => sum + group.selectedBytes);

  /// What the run is expected to free. An estimate, and named one wherever it
  /// is shown — `OptimizeReport.freedBytes` is the measured figure afterwards.
  int get estimatedSaving =>
      groups.fold(0, (sum, group) => sum + group.estimatedSaving);

  /// How many ticked files would end up with a different name on disk.
  ///
  /// Counted separately because the confirmation dialog says it out loud: a
  /// file whose extension changes is a file every link and gallery reference to
  /// it stops finding.
  int get renamedSelectedCount =>
      groups.fold(0, (sum, group) => sum + group.renamedCount);

  List<MediaCandidate> get selectedCandidates => groups
      .expand((group) => group.selectedCandidates)
      .toList(growable: false);

  /// Groups worth drawing: all of them before a scan, only the ones that found
  /// something after.
  List<MediaGroup> get visibleGroups {
    if (!hasScanned && !isScanning) {
      return groups;
    }

    return groups.where((group) => !group.isEmpty).toList(growable: false);
  }

  /// Whether the screen owes the user a sentence rather than a list of rows.
  ///
  /// Not the same question as "did the scan find anything", which is what the
  /// screen used to ask by checking [visibleGroups] alone — and a device full of
  /// already-efficient HEVC answers yes to that. Its groups are not empty, so
  /// the rows were drawn, every one of them unactionable, under no heading and
  /// above a bare *Rescan*. The sentence explaining that a scan can succeed and
  /// still leave nothing to do sat in the ARB files with nothing able to reach
  /// it.
  ///
  /// Not asked mid-scan: the first worthwhile file may be the next one, and a
  /// screen that says "everything is already efficient" while it is still
  /// looking is saying something it does not know yet.
  bool get hasNothingToDo =>
      visibleGroups.isEmpty || (hasScanned && !isScanning && !hasWorthwhile);

  /// Groups as well as access, because the two are not the same question.
  ///
  /// An Android with all-files access refused answers `canScan` true — the
  /// cleaner can still empty its own cache there — while this tool can reach no
  /// folder the user ever put a photograph in. `groups` is empty in that case,
  /// which is `MediaRuleset`'s answer rather than a second copy of the rule.
  bool get canScan =>
      isSupported && access.canScan && groups.isNotEmpty && !isBusy;

  /// Ticked files, an encoder for each kind among them, and nothing in flight.
  ///
  /// The encoder check is here rather than only in the use case so the button
  /// is off rather than failing when pressed — but the use case repeats it, so
  /// the contract holds however the call was assembled.
  bool get canOptimize {
    if (!isSupported || isBusy || selectedCount == 0) {
      return false;
    }

    return groups
        .where((group) => group.selectedCount > 0)
        .every((group) => support.supports(group.kind));
  }

  /// Whether unticking anything is currently allowed.
  ///
  /// Everywhere except during a run, and each moment for its own reason —
  /// `StorageCleanerState.canEditSelection` carries the argument in full and
  /// this is the same one. **Before a scan** it is why the rows are drawn at
  /// all, and the choice survives the walk, because `_onScanRequested` empties
  /// `candidates` without touching `isSelected`. **During a scan** it is what
  /// the exclusion model in `MediaGroup` was built for: a list still filling up
  /// must be editable, or the machinery exists and cannot be reached. **During a
  /// run** it must not be: the file list was taken at the start, so an unticked
  /// row would be claiming to spare a file that is being rewritten as it is
  /// unticked.
  ///
  /// It read `!isBusy` until the cleaner's version of this comment was read
  /// beside it: that shut the whole list for the length of a walk over a camera
  /// roll, which is the one stretch of time the user has something to look at
  /// and a reason to change their mind.
  bool get canEditSelection => isSupported && !isOptimizing;

  /// Whether one group's box can be ticked, which [canEditSelection] alone does
  /// not answer: a kind this machine cannot encode is a kind no amount of
  /// ticking will act on, and `EncoderNotice` is where the reason is given.
  bool canEditGroup(MediaKind kind) =>
      canEditSelection && support.supports(kind);

  /// Whether the walk has returned a verdict on a group, or has simply not
  /// looked yet.
  ///
  /// The two look identical on a `MediaGroup` — no candidates either way — and
  /// they mean opposite things to a checkbox: nothing worth re-encoding *found*
  /// is a row that cannot be acted on, while nothing looked at yet is a row
  /// whose whole purpose is being ticked in advance.
  bool get isVerdictKnown => hasScanned && !isScanning;

  /// Whether a kind is present but cannot be acted on for want of an encoder.
  ///
  /// The case the notice exists for: a desktop with no video encoder yet and
  /// video among the kinds it can reach. Asked of the kinds rather than of the
  /// findings, so the sentence explaining an untickable row is on screen beside
  /// it from the start instead of arriving with the first scan.
  bool get hasBlockedKind =>
      groups.any((group) => !support.supports(group.kind));

  /// Whether a download is running.
  bool get isFetchingEncoder => encoderFetchProgress != null;

  /// Whether the screen may offer to fetch the encoder.
  ///
  /// Three conditions and each rules out a different wrong screen: a platform
  /// that cannot be handed one must not show a button, a machine that already has
  /// an encoder must not be offered another, and a download in flight must not be
  /// startable twice. Without the second, a user with `ffmpeg` on their path
  /// would be invited to download a second copy of it.
  bool get canFetchEncoder =>
      canBeGivenEncoder && !support.videos && !isFetchingEncoder;

  /// Whether the notice above the list has anything to say.
  ///
  /// Either something cannot be re-encoded, or something can be fixed by
  /// downloading — the second is true before a scan has found anything, because
  /// the fix is worth offering while the user is reading rather than after they
  /// have pressed a button that does nothing.
  bool get hasEncoderNotice =>
      hasBlockedKind || canFetchEncoder || isFetchingEncoder;

  double? get runProgress => progress?.fraction;

  bool get hasRing => storage != null || hasFindings;

  double get usedFraction => storage?.usedFraction ?? 0;

  /// What the ticked files would give back, as a slice of the whole disk.
  ///
  /// Nought where the disk will not say how big it is: a fraction of an unknown
  /// total is not a number, and drawing one would be inventing a denominator.
  double get savingFraction => storage?.fractionOf(estimatedSaving) ?? 0;

  MediaOptimizerState copyWith({
    MediaOptimizerStatus? status,
    bool? isSupported,
    StorageAccess? access,
    EncoderSupport? support,
    List<MediaGroup>? groups,
    OptimizeQuality? quality,
    String? scanningLocation,
    OptimizeProgress? progress,
    OptimizeReport? report,
    OptimizeFailure? failure,
    DeviceStorageSnapshot? storage,
    bool? canBeGivenEncoder,
    int? encoderDownloadBytes,
    double? encoderFetchProgress,
    bool clearScanningLocation = false,
    bool clearProgress = false,
    bool clearReport = false,
    bool clearFailure = false,
    bool clearStorage = false,
    bool clearEncoderFetchProgress = false,
  }) {
    return MediaOptimizerState(
      status: status ?? this.status,
      isSupported: isSupported ?? this.isSupported,
      access: access ?? this.access,
      support: support ?? this.support,
      groups: groups ?? this.groups,
      quality: quality ?? this.quality,
      scanningLocation: clearScanningLocation
          ? null
          : scanningLocation ?? this.scanningLocation,
      progress: clearProgress ? null : progress ?? this.progress,
      report: clearReport ? null : report ?? this.report,
      failure: clearFailure ? null : failure ?? this.failure,
      storage: clearStorage ? null : storage ?? this.storage,
      canBeGivenEncoder: canBeGivenEncoder ?? this.canBeGivenEncoder,
      encoderDownloadBytes: encoderDownloadBytes ?? this.encoderDownloadBytes,
      encoderFetchProgress: clearEncoderFetchProgress
          ? null
          : encoderFetchProgress ?? this.encoderFetchProgress,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        isSupported,
        access,
        support,
        groups,
        quality,
        scanningLocation,
        progress,
        report,
        failure,
        storage,
        canBeGivenEncoder,
        encoderDownloadBytes,
        encoderFetchProgress,
      ];
}
