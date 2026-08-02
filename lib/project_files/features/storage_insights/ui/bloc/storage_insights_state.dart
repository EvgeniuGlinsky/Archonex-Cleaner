part of 'storage_insights_bloc.dart';

enum StorageInsightsStatus { idle, measuring, measured }

/// Everything the measurement screen draws itself from.
///
/// The totals are kept as a map keyed by category, which is the one place this
/// state differs in shape from what the screen reads: the screen wants
/// [breakdown], a sorted list with the two derived rows on the end, and the
/// bloc wants somewhere to add a batch into. The map is the field; the list is
/// a getter, computed and never stored, so there is no second record of one
/// figure to disagree with the first.
final class StorageInsightsState extends Equatable {
  const StorageInsightsState({
    this.status = StorageInsightsStatus.idle,
    this.isSupported = true,
    this.access = const StorageAccess.open(),
    this.measured = const <StorageSliceCategory, StorageSlice>{},
    this.storage,
    this.location,
    this.isTruncated = false,
    this.failure,
  });

  final StorageInsightsStatus status;

  /// Whether this platform has a volume to measure. False on web and iOS.
  final bool isSupported;

  final StorageAccess access;

  /// What has been counted so far, by category.
  final Map<StorageSliceCategory, StorageSlice> measured;

  /// How full the platform says the volume is, or `null` where it will not say.
  final DeviceStorageSnapshot? storage;

  /// The folder the walk is in, for the line under the bar.
  final String? location;

  final bool isTruncated;
  final InsightsFailure? failure;

  bool get isMeasuring => status == StorageInsightsStatus.measuring;

  bool get hasMeasured => status == StorageInsightsStatus.measured;

  bool get canMeasure => isSupported && access.canScan && !isMeasuring;

  bool get hasFindings => measured.isNotEmpty;

  /// Drawn from the first batch onward, so the chart fills in as the walk runs
  /// rather than appearing at the end.
  bool get hasChart => storage != null || hasFindings;

  /// The rows, in the order they are drawn.
  StorageBreakdown get breakdown => StorageBreakdown(
        measured: measured.values.toList(growable: false),
        storage: storage,
        isTruncated: isTruncated,
      );

  /// Nothing on the volume the app may look at, and it has finished looking.
  bool get foundNothing => hasMeasured && !hasFindings;

  StorageInsightsState copyWith({
    StorageInsightsStatus? status,
    bool? isSupported,
    StorageAccess? access,
    Map<StorageSliceCategory, StorageSlice>? measured,
    DeviceStorageSnapshot? storage,
    String? location,
    bool? isTruncated,
    InsightsFailure? failure,
    bool clearStorage = false,
    bool clearLocation = false,
    bool clearFailure = false,
  }) {
    return StorageInsightsState(
      status: status ?? this.status,
      isSupported: isSupported ?? this.isSupported,
      access: access ?? this.access,
      measured: measured ?? this.measured,
      storage: clearStorage ? null : storage ?? this.storage,
      location: clearLocation ? null : location ?? this.location,
      isTruncated: isTruncated ?? this.isTruncated,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        isSupported,
        access,
        measured,
        storage,
        location,
        isTruncated,
        failure,
      ];
}
