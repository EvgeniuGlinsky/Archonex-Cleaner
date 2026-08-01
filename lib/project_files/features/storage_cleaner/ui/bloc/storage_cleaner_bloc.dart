import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/clean_junk_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_cleaner_availability_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/get_scannable_categories_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/use_cases/scan_for_junk_use_case.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_report.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/clean_update.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_group.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_item.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_job.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/scan_update.dart';

part 'storage_cleaner_event.dart';
part 'storage_cleaner_state.dart';

class StorageCleanerBloc extends Bloc<StorageCleanerEvent, StorageCleanerState> {
  StorageCleanerBloc({
    required GetCleanerAvailabilityUseCase getAvailability,
    required GetStorageAccessUseCase getAccess,
    required RequestStorageAccessUseCase requestAccess,
    required AddAccessFolderUseCase addScanFolder,
    required GetScannableCategoriesUseCase getCategories,
    required ScanForJunkUseCase scanForJunk,
    required CleanJunkUseCase cleanJunk,
    required WatchQuarantineUseCase watchQuarantine,
    required GetDeviceStorageUseCase getDeviceStorage,
  })  : _getAvailability = getAvailability,
        _getAccess = getAccess,
        _requestAccess = requestAccess,
        _addScanFolder = addScanFolder,
        _getCategories = getCategories,
        _scanForJunk = scanForJunk,
        _cleanJunk = cleanJunk,
        _watchQuarantine = watchQuarantine,
        _getDeviceStorage = getDeviceStorage,
        super(const StorageCleanerState()) {
    on<StorageCleanerStarted>(_onStarted, transformer: restartable());
    on<_QuarantineChanged>(_onQuarantineChanged, transformer: sequential());

    // Each of these either opens a system dialog or starts a run. The OS shows
    // one dialog, so a second tap must be dropped rather than queued behind it.
    on<ScanRequested>(_onScanRequested, transformer: droppable());
    on<CleanRequested>(_onCleanRequested, transformer: droppable());
    on<AccessRequested>(_onAccessRequested, transformer: droppable());
    on<ScanFolderRequested>(_onScanFolderRequested, transformer: droppable());

    on<ScanCancelled>(_onScanCancelled, transformer: sequential());
    on<CleanCancelled>(_onCleanCancelled, transformer: sequential());
    on<CategoryToggled>(_onCategoryToggled, transformer: sequential());
    on<ItemToggled>(_onItemToggled, transformer: sequential());
    on<FailureDismissed>(_onFailureDismissed, transformer: sequential());
    on<ResultDismissed>(_onResultDismissed, transformer: sequential());
  }

  final GetCleanerAvailabilityUseCase _getAvailability;
  final GetStorageAccessUseCase _getAccess;
  final RequestStorageAccessUseCase _requestAccess;
  final AddAccessFolderUseCase _addScanFolder;
  final GetScannableCategoriesUseCase _getCategories;
  final ScanForJunkUseCase _scanForJunk;
  final CleanJunkUseCase _cleanJunk;
  final WatchQuarantineUseCase _watchQuarantine;
  final GetDeviceStorageUseCase _getDeviceStorage;

  ScanJob? _activeScan;
  CleanJob? _activeClean;
  StreamSubscription<List<QuarantineBatch>>? _quarantineSubscription;

  @override
  Future<void> close() async {
    // A walk of a Windows `%TEMP%` outlives the screen that started it by
    // minutes if nothing stops it.
    await _activeScan?.cancel();
    await _activeClean?.cancel();
    await _quarantineSubscription?.cancel();

    return super.close();
  }

  Future<void> _onStarted(
    StorageCleanerStarted event,
    Emitter<StorageCleanerState> emit,
  ) async {
    await _quarantineSubscription?.cancel();
    _quarantineSubscription = _watchQuarantine().listen(
      (batches) => add(_QuarantineChanged(batches)),
    );

    final bool isSupported = _getAvailability();

    if (!isSupported) {
      emit(
        state.copyWith(
          isSupported: false,
          access: const StorageAccess.unavailable(),
          groups: const <JunkGroup>[],
        ),
      );

      return;
    }

    await _refreshAccess(emit, await _getAccess());
    await _refreshStorage(emit);
  }

  /// Re-reads how full the disk is.
  ///
  /// Called on arrival and again once a cleanup has finished, which are the two
  /// moments the figure can have moved — a scan reads the disk and changes
  /// nothing. Answering `null` is not a failure and is not reported as one: the
  /// ring is simply not drawn, and the rest of the screen is unaffected.
  Future<void> _refreshStorage(Emitter<StorageCleanerState> emit) async {
    final DeviceStorageSnapshot? snapshot = await _getDeviceStorage();

    emit(
      state.copyWith(storage: snapshot, clearStorage: snapshot == null),
    );
  }

  void _onQuarantineChanged(
    _QuarantineChanged event,
    Emitter<StorageCleanerState> emit,
  ) {
    emit(
      state.copyWith(
        quarantinedFileCount: event.batches.fold<int>(
          0,
          (sum, batch) => sum + batch.fileCount,
        ),
      ),
    );
  }

  Future<void> _onAccessRequested(
    AccessRequested event,
    Emitter<StorageCleanerState> emit,
  ) async {
    try {
      await _refreshAccess(emit, await _requestAccess());
    } on AccessFailure catch (failure) {
      // Wrapped rather than stored beside `failure`: one nullable slot on the
      // state means one listener and one dismissal, and the mapper unwraps it.
      emit(state.copyWith(failure: AccessRefusedFailure(failure)));
    }
  }

  Future<void> _onScanFolderRequested(
    ScanFolderRequested event,
    Emitter<StorageCleanerState> emit,
  ) async {
    await _refreshAccess(emit, await _addScanFolder());
  }

  /// Access decides which categories exist, so the two always move together.
  ///
  /// Findings are dropped: they were produced under the old access and a list
  /// mixing two scans is a list nobody can reason about.
  Future<void> _refreshAccess(
    Emitter<StorageCleanerState> emit,
    StorageAccess access,
  ) async {
    final Set<JunkCategory> categories = await _getCategories(access);

    emit(
      state.copyWith(
        status: StorageCleanerStatus.idle,
        isSupported: true,
        access: access,
        groups: categories.map(JunkGroup.fresh).toList(growable: false),
        clearScanningLocation: true,
        clearReport: true,
        clearFailure: true,
      ),
    );
  }

  Future<void> _onScanRequested(
    ScanRequested event,
    Emitter<StorageCleanerState> emit,
  ) async {
    if (!state.canScan) {
      return;
    }

    // Every category is scanned, ticked or not. Unticking says "do not delete
    // this", and a user who reads the browser-cache figure and changes their
    // mind should not have to scan the machine again to act on it.
    final Set<JunkCategory> categories =
        state.groups.map((group) => group.category).toSet();

    final ScanJob job;

    try {
      job = await _scanForJunk(categories: categories, access: state.access);
    } on CleanFailure catch (failure) {
      emit(state.copyWith(failure: failure));

      return;
    }

    _activeScan = job;

    emit(
      state.copyWith(
        status: StorageCleanerStatus.scanning,
        groups: state.groups
            .map((group) => group.copyWith(
                  items: const <JunkItem>[],
                  excludedPaths: const <String>{},
                  isTruncated: false,
                ))
            .toList(growable: false),
        clearReport: true,
        clearFailure: true,
        clearScanningLocation: true,
      ),
    );

    await emit.forEach<ScanUpdate>(
      job.updates,
      onData: _applyScanUpdate,
      onError: (error, _) => error is CleanFailure
          ? state.copyWith(
              status: StorageCleanerStatus.idle,
              failure: error,
              clearScanningLocation: true,
            )
          : state.copyWith(
              status: StorageCleanerStatus.idle,
              failure: const ScanFailure(),
              clearScanningLocation: true,
            ),
    );

    _activeScan = null;

    // The stream closing says the walk is over, not that it found anything —
    // and not that it was not cancelled, which `onError` has already handled by
    // putting the screen back to idle.
    if (state.isScanning) {
      emit(
        state.copyWith(
          status: StorageCleanerStatus.scanned,
          clearScanningLocation: true,
        ),
      );
    }
  }

  StorageCleanerState _applyScanUpdate(ScanUpdate update) {
    return switch (update) {
      ScanLocationChanged(:final String label) =>
        state.copyWith(scanningLocation: label),
      JunkFound(:final List<JunkItem> items) =>
        state.copyWith(groups: _merge(state.groups, items)),
      ScanTruncated(:final JunkCategory category) => state.copyWith(
          groups: state.groups
              .map(
                (group) => group.category == category
                    ? group.copyWith(isTruncated: true)
                    : group,
              )
              .toList(growable: false),
        ),
    };
  }

  /// Files a batch into the groups they belong to, in one pass.
  ///
  /// A batch routinely spans two categories — the empty-folder rule and the
  /// temp rule walk the same directory — so this groups first and rebuilds the
  /// list once, rather than rebuilding it per item.
  static List<JunkGroup> _merge(List<JunkGroup> groups, List<JunkItem> found) {
    final Map<JunkCategory, List<JunkItem>> byCategory =
        <JunkCategory, List<JunkItem>>{};

    for (final JunkItem item in found) {
      byCategory.putIfAbsent(item.category, () => <JunkItem>[]).add(item);
    }

    return groups
        .map(
          (group) => byCategory.containsKey(group.category)
              ? group.withMore(byCategory[group.category]!)
              : group,
        )
        .toList(growable: false);
  }

  Future<void> _onScanCancelled(
    ScanCancelled event,
    Emitter<StorageCleanerState> emit,
  ) async {
    await _activeScan?.cancel();
  }

  Future<void> _onCleanRequested(
    CleanRequested event,
    Emitter<StorageCleanerState> emit,
  ) async {
    if (!state.canClean) {
      return;
    }

    final List<JunkItem> items = state.groups
        .expand((group) => group.selectedItems)
        .toList(growable: false);

    final CleanJob job;

    try {
      job = _cleanJunk(items: items);
    } on CleanFailure catch (failure) {
      emit(state.copyWith(failure: failure));

      return;
    }

    _activeClean = job;

    emit(
      state.copyWith(
        status: StorageCleanerStatus.cleaning,
        clearReport: true,
        clearFailure: true,
        clearCleanProgress: true,
      ),
    );

    await emit.forEach<CleanUpdate>(
      job.updates,
      onData: (update) => switch (update) {
        CleanProgress() => state.copyWith(cleanProgress: update),
        CleanFinished(:final CleanReport report) => state.copyWith(
            status: StorageCleanerStatus.cleaned,
            report: report,
            // What went is gone, so what is left on screen has to be what is
            // left on disk. Re-scanning is the user's call; clearing is not.
            groups: _withoutDeleted(state.groups, report),
            clearCleanProgress: true,
          ),
      },
      onError: (error, _) => state.copyWith(
        status: StorageCleanerStatus.scanned,
        failure: error is CleanFailure ? error : const ScanFailure(),
        clearCleanProgress: true,
      ),
    );

    _activeClean = null;

    await _refreshStorage(emit);
  }

  /// Drops everything the run took, keeping what it skipped.
  ///
  /// A skipped file is still on disk and still junk, so it stays on the list
  /// where the next run can try again. Selection is dropped with the items,
  /// because an exclusion naming a path that no longer exists is noise.
  static List<JunkGroup> _withoutDeleted(
    List<JunkGroup> groups,
    CleanReport report,
  ) {
    if (!report.didAnything) {
      return groups;
    }

    return groups
        .map(
          (group) => group.copyWith(
            items: group.isSelected
                ? group.items
                    .where((item) => group.isExcluded(item.path))
                    .toList(growable: false)
                : group.items,
            excludedPaths: const <String>{},
          ),
        )
        .toList(growable: false);
  }

  Future<void> _onCleanCancelled(
    CleanCancelled event,
    Emitter<StorageCleanerState> emit,
  ) async {
    await _activeClean?.cancel();
  }

  void _onCategoryToggled(
    CategoryToggled event,
    Emitter<StorageCleanerState> emit,
  ) {
    emit(
      state.copyWith(
        groups: state.groups
            .map(
              (group) => group.category == event.category
                  ? group.copyWith(
                      isSelected: !group.isSelected,
                      // Turning a category back on turns all of it on. A
                      // remembered exclusion the row no longer shows is a file
                      // the user thinks they are deleting and is not.
                      excludedPaths: const <String>{},
                    )
                  : group,
            )
            .toList(growable: false),
      ),
    );
  }

  void _onItemToggled(
    ItemToggled event,
    Emitter<StorageCleanerState> emit,
  ) {
    emit(
      state.copyWith(
        groups: state.groups
            .map(
              (group) => group.category == event.category
                  ? group.toggleItem(event.path)
                  : group,
            )
            .toList(growable: false),
      ),
    );
  }

  void _onFailureDismissed(
    FailureDismissed event,
    Emitter<StorageCleanerState> emit,
  ) {
    emit(state.copyWith(clearFailure: true));
  }

  void _onResultDismissed(
    ResultDismissed event,
    Emitter<StorageCleanerState> emit,
  ) {
    emit(
      state.copyWith(
        status: state.hasFindings
            ? StorageCleanerStatus.scanned
            : StorageCleanerStatus.idle,
        clearReport: true,
      ),
    );
  }
}
