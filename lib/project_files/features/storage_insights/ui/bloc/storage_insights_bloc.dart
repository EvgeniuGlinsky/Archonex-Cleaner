import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/get_insights_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/data/use_cases/measure_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_breakdown.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

part 'storage_insights_event.dart';
part 'storage_insights_state.dart';

/// The measurement screen's state machine.
///
/// The simplest of the three: there is nothing to select, nothing to confirm
/// and nothing that changes the disk, so it has one job running at a time and
/// four events. Everything the screen asks about the state is a getter there,
/// computed and never stored.
class StorageInsightsBloc
    extends Bloc<StorageInsightsEvent, StorageInsightsState> {
  StorageInsightsBloc({
    required GetInsightsAvailabilityUseCase getAvailability,
    required GetStorageAccessUseCase getAccess,
    required RequestStorageAccessUseCase requestAccess,
    required AddAccessFolderUseCase addFolder,
    required OpenAccessSettingsUseCase openAccessSettings,
    required MeasureStorageUseCase measureStorage,
    required GetDeviceStorageUseCase getDeviceStorage,
  })  : _getAvailability = getAvailability,
        _getAccess = getAccess,
        _requestAccess = requestAccess,
        _addFolder = addFolder,
        _openAccessSettings = openAccessSettings,
        _measureStorage = measureStorage,
        _getDeviceStorage = getDeviceStorage,
        super(const StorageInsightsState()) {
    on<StorageInsightsStarted>(_onStarted, transformer: restartable());
    on<InsightsMeasureRequested>(_onMeasure, transformer: droppable());
    on<InsightsMeasureCancelled>(_onCancel, transformer: sequential());
    on<InsightsFailureDismissed>(_onDismissFailure, transformer: sequential());

    // Each opens a system dialog. The OS shows one, so a second tap is dropped
    // rather than queued behind it.
    on<InsightsAccessRequested>(_onAccessRequested, transformer: droppable());
    on<InsightsFolderRequested>(_onFolderRequested, transformer: droppable());
    on<InsightsAccessSettingsRequested>(
      _onAccessSettingsRequested,
      transformer: droppable(),
    );
  }

  final GetInsightsAvailabilityUseCase _getAvailability;
  final GetStorageAccessUseCase _getAccess;
  final RequestStorageAccessUseCase _requestAccess;
  final AddAccessFolderUseCase _addFolder;
  final OpenAccessSettingsUseCase _openAccessSettings;
  final MeasureStorageUseCase _measureStorage;
  final GetDeviceStorageUseCase _getDeviceStorage;

  InsightsScanJob? _activeScan;

  @override
  Future<void> close() async {
    // A walk of a whole phone outlives the screen that started it by minutes if
    // nothing stops it.
    await _activeScan?.cancel();

    return super.close();
  }

  Future<void> _onStarted(
    StorageInsightsStarted event,
    Emitter<StorageInsightsState> emit,
  ) async {
    if (!_getAvailability()) {
      emit(
        state.copyWith(
          isSupported: false,
          access: const StorageAccess.unavailable(),
        ),
      );

      return;
    }

    emit(
      state.copyWith(isSupported: true, access: await _getAccess()),
    );

    await _refreshStorage(emit);
  }

  /// How full the disk is, which is the denominator for every percentage on the
  /// screen and the only thing drawn before a measurement has run.
  Future<void> _refreshStorage(Emitter<StorageInsightsState> emit) async {
    final DeviceStorageSnapshot? snapshot = await _getDeviceStorage();

    emit(state.copyWith(storage: snapshot, clearStorage: snapshot == null));
  }

  Future<void> _onMeasure(
    InsightsMeasureRequested event,
    Emitter<StorageInsightsState> emit,
  ) async {
    if (!state.canMeasure) {
      return;
    }

    final InsightsScanJob job;

    try {
      job = await _measureStorage(state.access);
    } on InsightsFailure catch (failure) {
      emit(state.copyWith(failure: failure));

      return;
    }

    _activeScan = job;

    emit(
      state.copyWith(
        status: StorageInsightsStatus.measuring,
        measured: const <StorageSliceCategory, StorageSlice>{},
        isTruncated: false,
        clearLocation: true,
        clearFailure: true,
      ),
    );

    await emit.forEach<InsightsUpdate>(
      job.updates,
      onData: _apply,
      onError: (error, _) => state.copyWith(
        status: StorageInsightsStatus.idle,
        failure: error is InsightsFailure
            ? error
            : const InsightsScanFailure(),
      ),
    );

    _activeScan = null;

    if (state.status == StorageInsightsStatus.measuring) {
      emit(state.copyWith(status: StorageInsightsStatus.measured));
    }
  }

  /// Batches of totals, accumulated here rather than in the job.
  ///
  /// The job sends deltas so it can forget them, which is what keeps a walk of
  /// a hundred thousand files from holding a hundred thousand anything.
  StorageInsightsState _apply(InsightsUpdate update) {
    return switch (update) {
      InsightsLocationChanged() => state.copyWith(location: update.label),
      InsightsTruncated() => state.copyWith(isTruncated: true),
      InsightsMeasured() => state.copyWith(
          measured: <StorageSliceCategory, StorageSlice>{
            ...state.measured,
            for (final StorageSlice slice in update.slices)
              slice.category:
                  (state.measured[slice.category] ??
                          StorageSlice(category: slice.category, bytes: 0))
                      .plus(bytes: slice.bytes, fileCount: slice.fileCount),
          },
        ),
    };
  }

  Future<void> _onCancel(
    InsightsMeasureCancelled event,
    Emitter<StorageInsightsState> emit,
  ) async {
    await _activeScan?.cancel();
  }

  void _onDismissFailure(
    InsightsFailureDismissed event,
    Emitter<StorageInsightsState> emit,
  ) {
    emit(state.copyWith(clearFailure: true));
  }

  /// Access decides what there is to walk, so the totals go with it. A chart
  /// measured under one permission and labelled under another would be a
  /// picture of neither.
  Future<void> _onAccessRequested(
    InsightsAccessRequested event,
    Emitter<StorageInsightsState> emit,
  ) async {
    try {
      _applyAccess(emit, await _requestAccess());
    } on AccessFailure {
      // Not wrapped into an `InsightsFailure`: this screen offers the notice
      // that explains the refusal and keeps offering it, which says more than a
      // snack bar that disappears.
      _applyAccess(emit, await _getAccess());
    }
  }

  Future<void> _onFolderRequested(
    InsightsFolderRequested event,
    Emitter<StorageInsightsState> emit,
  ) async {
    _applyAccess(emit, await _addFolder());
  }

  /// Leaves for Settings and emits nothing. What the user does there is read
  /// back by [StorageInsightsStarted] when the screen is built again.
  Future<void> _onAccessSettingsRequested(
    InsightsAccessSettingsRequested event,
    Emitter<StorageInsightsState> emit,
  ) async {
    await _openAccessSettings();
  }

  void _applyAccess(
    Emitter<StorageInsightsState> emit,
    StorageAccess access,
  ) {
    emit(
      state.copyWith(
        status: StorageInsightsStatus.idle,
        access: access,
        measured: const <StorageSliceCategory, StorageSlice>{},
        isTruncated: false,
        clearLocation: true,
        clearFailure: true,
      ),
    );
  }
}
