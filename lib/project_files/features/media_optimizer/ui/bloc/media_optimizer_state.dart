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

  bool get canEditSelection => !isBusy;

  /// Whether a kind was found but cannot be acted on for want of an encoder.
  ///
  /// The case the notice exists for: a desktop with no `ffmpeg` that has just
  /// found six gigabytes of re-encodable video.
  bool get hasBlockedKind => groups.any(
        (group) => group.hasWorthwhile && !support.supports(group.kind),
      );

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
    bool clearScanningLocation = false,
    bool clearProgress = false,
    bool clearReport = false,
    bool clearFailure = false,
    bool clearStorage = false,
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
      ];
}
