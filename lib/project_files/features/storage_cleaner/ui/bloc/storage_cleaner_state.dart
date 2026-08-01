part of 'storage_cleaner_bloc.dart';

enum StorageCleanerStatus {
  idle,
  scanning,
  scanned,
  cleaning,
  cleaned,
}

final class StorageCleanerState extends Equatable {
  const StorageCleanerState({
    this.status = StorageCleanerStatus.idle,
    this.isSupported = true,
    this.access = const StorageAccess.open(),
    this.groups = const <JunkGroup>[],
    this.scanningLocation,
    this.cleanProgress,
    this.report,
    this.failure,
    this.quarantinedFileCount = 0,
    this.storage,
  });

  final StorageCleanerStatus status;

  /// `false` where the build has no file system — web, and nothing else.
  final bool isSupported;

  final StorageAccess access;

  /// One group per category this platform can fill, in enum declaration order.
  ///
  /// Present from the first frame, empty of items until a scan runs: the screen
  /// shows what it is going to look for before it looks, which is what makes
  /// unticking a category before the scan possible.
  final List<JunkGroup> groups;

  /// Label of the root being walked right now, `null` when nothing is running.
  final String? scanningLocation;

  final CleanProgress? cleanProgress;

  /// The last cleanup's outcome. Survives until dismissed.
  final CleanReport? report;

  final CleanFailure? failure;

  /// Files still restorable, across every batch. Drives the banner only.
  final int quarantinedFileCount;

  /// How full the disk is, or `null` where this platform cannot say.
  final DeviceStorageSnapshot? storage;

  bool get isScanning => status == StorageCleanerStatus.scanning;

  bool get isCleaning => status == StorageCleanerStatus.cleaning;

  bool get isBusy => isScanning || isCleaning;

  bool get hasScanned =>
      status == StorageCleanerStatus.scanned ||
      status == StorageCleanerStatus.cleaned;

  int get foundCount =>
      groups.fold(0, (sum, group) => sum + group.totalCount);

  int get foundBytes => groups.fold(0, (sum, group) => sum + group.totalBytes);

  int get selectedCount =>
      groups.fold(0, (sum, group) => sum + group.selectedCount);

  int get selectedBytes =>
      groups.fold(0, (sum, group) => sum + group.selectedBytes);

  bool get hasFindings => foundCount > 0;

  /// Groups worth drawing a row for.
  ///
  /// Every one of them until a scan has finished — before, so the user can see
  /// what is about to be looked for and untick a category in advance; during, so
  /// the rows visibly fill up rather than appearing one by one out of an empty
  /// list that says nothing has been scanned. Afterwards it is the ones that
  /// found something, because nine rows of zero is a worse answer than four rows
  /// with numbers in them.
  List<JunkGroup> get visibleGroups => hasScanned
      ? groups.where((group) => !group.isEmpty).toList(growable: false)
      : groups;

  /// Files that will be deleted outright because they are too large to keep a
  /// copy of. The confirmation names the number.
  int get permanentSelectedCount => groups
      .expand((group) => group.selectedItems)
      .where((item) => item.sizeInBytes > AppQuarantinePolicy.maxEntryBytes)
      .length;

  bool get canScan => isSupported && access.canScan && !isBusy;

  bool get canClean => isSupported && !isBusy && selectedCount > 0;

  /// Whether unticking anything is currently allowed.
  ///
  /// Everywhere except during a cleanup, and each of the three moments for its
  /// own reason. **Before a scan** it is the whole point of drawing the rows at
  /// all — see [visibleGroups] — and the choice survives the run, because
  /// `_onScanRequested` empties `items` without touching `isSelected`. **During
  /// a scan** it is what the exclusion model in `JunkGroup` was built for: a
  /// list that is still filling up must be editable, or the machinery exists and
  /// cannot be reached. **During a cleanup** it must not be: the file list was
  /// taken at the start, so an unticked row would be claiming to spare a file
  /// that is being deleted as it is unticked.
  ///
  /// It read `hasScanned && !isBusy` until a device showed the first case dead:
  /// every checkbox on the screen greyed out before the first scan, on a screen
  /// whose own doc comment promised the opposite.
  bool get canEditSelection => isSupported && !isCleaning;

  /// How far the cleanup has got, `null` when none is running.
  double? get progress => cleanProgress?.fraction;

  bool get hasQuarantine => quarantinedFileCount > 0;

  /// Whether the ring at the top of the screen is worth drawing.
  ///
  /// A platform that cannot measure the disk still gets one the moment a scan
  /// has something to report, because the figure in the middle of it is the
  /// answer the user pressed the button for — the arc around it is context, not
  /// the point.
  bool get hasRing => storage != null || isScanning || hasFindings;

  /// How much of the whole disk is in use. `0` with no snapshot, which draws an
  /// empty track — honest, where a full one would be a guess.
  double get usedFraction => storage?.usedFraction ?? 0;

  /// The share of the disk the selected files take, painted inside the used arc.
  double get selectedFraction => storage?.fractionOf(selectedBytes) ?? 0;

  StorageCleanerState copyWith({
    StorageCleanerStatus? status,
    bool? isSupported,
    StorageAccess? access,
    List<JunkGroup>? groups,
    String? scanningLocation,
    CleanProgress? cleanProgress,
    CleanReport? report,
    CleanFailure? failure,
    int? quarantinedFileCount,
    DeviceStorageSnapshot? storage,
    bool clearScanningLocation = false,
    bool clearCleanProgress = false,
    bool clearReport = false,
    bool clearFailure = false,
    bool clearStorage = false,
  }) {
    return StorageCleanerState(
      status: status ?? this.status,
      isSupported: isSupported ?? this.isSupported,
      access: access ?? this.access,
      groups: groups ?? this.groups,
      scanningLocation: clearScanningLocation
          ? null
          : scanningLocation ?? this.scanningLocation,
      cleanProgress:
          clearCleanProgress ? null : cleanProgress ?? this.cleanProgress,
      report: clearReport ? null : report ?? this.report,
      failure: clearFailure ? null : failure ?? this.failure,
      quarantinedFileCount: quarantinedFileCount ?? this.quarantinedFileCount,
      storage: clearStorage ? null : storage ?? this.storage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        isSupported,
        access,
        groups,
        scanningLocation,
        cleanProgress,
        report,
        failure,
        quarantinedFileCount,
        storage,
      ];
}
