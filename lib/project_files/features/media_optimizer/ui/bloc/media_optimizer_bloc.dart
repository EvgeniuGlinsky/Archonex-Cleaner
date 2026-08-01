import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_encoder_support_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizable_kinds_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizer_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/optimize_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/scan_for_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_group.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

part 'media_optimizer_event.dart';
part 'media_optimizer_state.dart';

class MediaOptimizerBloc extends Bloc<MediaOptimizerEvent, MediaOptimizerState> {
  MediaOptimizerBloc({
    required GetOptimizerAvailabilityUseCase getAvailability,
    required GetEncoderSupportUseCase getSupport,
    required GetOptimizableKindsUseCase getKinds,
    required GetStorageAccessUseCase getAccess,
    required RequestStorageAccessUseCase requestAccess,
    required AddAccessFolderUseCase addFolder,
    required OpenAccessSettingsUseCase openAccessSettings,
    required ScanForMediaUseCase scanForMedia,
    required OptimizeMediaUseCase optimizeMedia,
    required GetDeviceStorageUseCase getDeviceStorage,
  })  : _getAvailability = getAvailability,
        _getSupport = getSupport,
        _getKinds = getKinds,
        _getAccess = getAccess,
        _requestAccess = requestAccess,
        _addFolder = addFolder,
        _openAccessSettings = openAccessSettings,
        _scanForMedia = scanForMedia,
        _optimizeMedia = optimizeMedia,
        _getDeviceStorage = getDeviceStorage,
        super(const MediaOptimizerState()) {
    on<MediaOptimizerStarted>(_onStarted, transformer: restartable());

    // Each of these opens a system dialog or starts a run. The OS shows one
    // dialog, so a second tap must be dropped rather than queued behind it.
    on<MediaScanRequested>(_onScanRequested, transformer: droppable());
    on<OptimizeRequested>(_onOptimizeRequested, transformer: droppable());
    on<OptimizerAccessRequested>(_onAccessRequested, transformer: droppable());
    on<OptimizerFolderRequested>(_onFolderRequested, transformer: droppable());
    on<OptimizerAccessSettingsRequested>(
      _onAccessSettingsRequested,
      transformer: droppable(),
    );

    on<MediaScanCancelled>(_onScanCancelled, transformer: sequential());
    on<OptimizeCancelled>(_onOptimizeCancelled, transformer: sequential());
    on<MediaGroupToggled>(_onGroupToggled, transformer: sequential());
    on<MediaCandidateToggled>(_onCandidateToggled, transformer: sequential());
    on<OptimizerFailureDismissed>(_onFailureDismissed, transformer: sequential());
    on<OptimizerResultDismissed>(_onResultDismissed, transformer: sequential());
  }

  final GetOptimizerAvailabilityUseCase _getAvailability;
  final GetEncoderSupportUseCase _getSupport;
  final GetOptimizableKindsUseCase _getKinds;
  final GetStorageAccessUseCase _getAccess;
  final RequestStorageAccessUseCase _requestAccess;
  final AddAccessFolderUseCase _addFolder;
  final OpenAccessSettingsUseCase _openAccessSettings;
  final ScanForMediaUseCase _scanForMedia;
  final OptimizeMediaUseCase _optimizeMedia;
  final GetDeviceStorageUseCase _getDeviceStorage;

  MediaScanJob? _activeScan;
  OptimizeJob? _activeRun;

  @override
  Future<void> close() async {
    // A walk that opens the header of every file in a camera roll outlives the
    // screen by minutes if nothing stops it, and a transcode by rather longer.
    await _activeScan?.cancel();
    await _activeRun?.cancel();

    return super.close();
  }

  Future<void> _onStarted(
    MediaOptimizerStarted event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    if (!_getAvailability()) {
      emit(
        state.copyWith(
          isSupported: false,
          access: const StorageAccess.unavailable(),
          support: const EncoderSupport.none(),
          groups: const <MediaGroup>[],
        ),
      );

      return;
    }

    // Before the access, because it is the answer that decides whether the
    // screen offers a button at all and it does not depend on the other.
    emit(state.copyWith(isSupported: true, support: await _getSupport()));

    await _refreshAccess(emit, await _getAccess());
    await _refreshStorage(emit);
  }

  /// Re-reads how full the disk is.
  ///
  /// On arrival and again once a run has finished, which are the two moments
  /// the figure can have moved. A `null` answer is not a failure: the ring is
  /// not drawn and the rest of the screen is unaffected.
  Future<void> _refreshStorage(Emitter<MediaOptimizerState> emit) async {
    final DeviceStorageSnapshot? snapshot = await _getDeviceStorage();

    emit(state.copyWith(storage: snapshot, clearStorage: snapshot == null));
  }

  Future<void> _onAccessRequested(
    OptimizerAccessRequested event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    try {
      await _refreshAccess(emit, await _requestAccess());
    } on AccessFailure catch (failure) {
      emit(state.copyWith(failure: OptimizeAccessRefusedFailure(failure)));
    }
  }

  /// Leaves for Settings and emits nothing.
  ///
  /// There is no state to move to: the app is going to the background, and what
  /// the user does there is read back by `MediaOptimizerStarted` when the screen
  /// is built again.
  Future<void> _onAccessSettingsRequested(
    OptimizerAccessSettingsRequested event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    await _openAccessSettings();
  }

  Future<void> _onFolderRequested(
    OptimizerFolderRequested event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    await _refreshAccess(emit, await _addFolder());
  }

  /// Access decides which kinds exist, so the two always move together.
  ///
  /// Which kinds is asked of the repository rather than derived from the access
  /// level, because it is a rule and `MediaRuleset` owns it. The case that
  /// forces that is an Android with all-files access refused:
  /// `StorageAccess.canScan` is true there — the cleaner can still empty its
  /// own cache — and this tool can reach nothing at all.
  ///
  /// Findings are dropped: they were measured under the old access, and a list
  /// mixing two walks is a list nobody can reason about.
  Future<void> _refreshAccess(
    Emitter<MediaOptimizerState> emit,
    StorageAccess access,
  ) async {
    final Set<MediaKind> kinds = await _getKinds(access);

    emit(
      state.copyWith(
        status: MediaOptimizerStatus.idle,
        isSupported: true,
        access: access,
        groups: kinds.map(MediaGroup.fresh).toList(growable: false),
        clearScanningLocation: true,
        clearReport: true,
        clearFailure: true,
      ),
    );
  }

  Future<void> _onScanRequested(
    MediaScanRequested event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    if (!state.canScan) {
      return;
    }

    // Every kind is walked, ticked or not. Unticking says "do not rewrite
    // these", and a user who reads the video figure and changes their mind
    // should not have to walk the device again to act on it.
    final Set<MediaKind> kinds =
        state.groups.map((group) => group.kind).toSet();

    final MediaScanJob job;

    try {
      job = await _scanForMedia(kinds: kinds, access: state.access);
    } on OptimizeFailure catch (failure) {
      emit(state.copyWith(failure: failure));

      return;
    }

    _activeScan = job;

    emit(
      state.copyWith(
        status: MediaOptimizerStatus.scanning,
        groups: state.groups
            .map(
              (group) => group.copyWith(
                candidates: const <MediaCandidate>[],
                excludedPaths: const <String>{},
                isTruncated: false,
              ),
            )
            .toList(growable: false),
        clearReport: true,
        clearFailure: true,
        clearScanningLocation: true,
      ),
    );

    await emit.forEach<MediaScanUpdate>(
      job.updates,
      onData: _applyScanUpdate,
      onError: (error, _) => state.copyWith(
        status: MediaOptimizerStatus.idle,
        failure: error is OptimizeFailure ? error : const MediaScanFailure(),
        clearScanningLocation: true,
      ),
    );

    _activeScan = null;

    // The stream closing says the walk is over, not that it found anything —
    // and not that it was not cancelled, which `onError` has already handled.
    if (state.isScanning) {
      emit(
        state.copyWith(
          status: MediaOptimizerStatus.scanned,
          clearScanningLocation: true,
        ),
      );
    }
  }

  MediaOptimizerState _applyScanUpdate(MediaScanUpdate update) {
    return switch (update) {
      MediaLocationChanged(:final String label) =>
        state.copyWith(scanningLocation: label),
      MediaFound(:final List<MediaCandidate> candidates) =>
        state.copyWith(groups: _merge(state.groups, candidates)),
      MediaScanTruncated(:final MediaKind kind) => state.copyWith(
          groups: state.groups
              .map(
                (group) =>
                    group.kind == kind ? group.copyWith(isTruncated: true) : group,
              )
              .toList(growable: false),
        ),
    };
  }

  /// Files a batch into the groups they belong to, in one pass.
  ///
  /// A batch routinely spans both kinds — a camera roll holds photographs and
  /// clips in the same folder — so this groups first and rebuilds the list
  /// once, rather than rebuilding it per finding.
  static List<MediaGroup> _merge(
    List<MediaGroup> groups,
    List<MediaCandidate> found,
  ) {
    final Map<MediaKind, List<MediaCandidate>> byKind =
        <MediaKind, List<MediaCandidate>>{};

    for (final MediaCandidate candidate in found) {
      byKind.putIfAbsent(candidate.kind, () => <MediaCandidate>[]).add(candidate);
    }

    return groups
        .map(
          (group) => byKind.containsKey(group.kind)
              ? group.withMore(byKind[group.kind]!)
              : group,
        )
        .toList(growable: false);
  }

  Future<void> _onScanCancelled(
    MediaScanCancelled event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    await _activeScan?.cancel();
  }

  Future<void> _onOptimizeRequested(
    OptimizeRequested event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    if (!state.canOptimize) {
      return;
    }

    final List<MediaCandidate> candidates = state.selectedCandidates;

    final OptimizeJob job;

    try {
      job = _optimizeMedia(candidates: candidates);
    } on OptimizeFailure catch (failure) {
      emit(state.copyWith(failure: failure));

      return;
    }

    _activeRun = job;

    emit(
      state.copyWith(
        status: MediaOptimizerStatus.optimizing,
        clearReport: true,
        clearFailure: true,
        clearProgress: true,
      ),
    );

    await emit.forEach<OptimizeUpdate>(
      job.updates,
      onData: (update) => switch (update) {
        OptimizeProgress() => state.copyWith(progress: update),
        OptimizeFinished(:final OptimizeReport report) => state.copyWith(
            status: MediaOptimizerStatus.optimized,
            report: report,
            // What was rewritten is a different file now — smaller, sometimes
            // differently named — so the rows describing the old ones go. What
            // was skipped or failed is on disk exactly as measured and stays,
            // where the next run can try again.
            groups: _withoutRewritten(state.groups, report, candidates),
            clearProgress: true,
          ),
      },
      onError: (error, _) => state.copyWith(
        status: MediaOptimizerStatus.scanned,
        failure: error is OptimizeFailure ? error : const MediaScanFailure(),
        clearProgress: true,
      ),
    );

    _activeRun = null;

    await _refreshStorage(emit);
  }

  /// Drops the rows a run rewrote.
  ///
  /// The report says how many were rewritten but not which, and matching them
  /// back would mean the job carrying a list of paths for the sake of a screen
  /// refresh. Where every file went through, the whole selection goes; where
  /// some did not, the selection is cleared and the rows stay, because a row
  /// still ticked after a run that skipped it would invite a second attempt at
  /// exactly the thing that did not work.
  static List<MediaGroup> _withoutRewritten(
    List<MediaGroup> groups,
    OptimizeReport report,
    List<MediaCandidate> attempted,
  ) {
    // A run that reached nothing at all — cancelled on the first file — leaves
    // the list exactly as it was, because nothing about it has changed.
    if (report.attemptedCount == 0) {
      return groups;
    }

    if (report.optimizedCount == attempted.length) {
      return groups
          .map(
            (group) => group.without(
              attempted.map((candidate) => candidate.path).toSet(),
            ),
          )
          .toList(growable: false);
    }

    return groups
        .map(
          (group) => group.copyWith(
            isSelected: false,
            excludedPaths: const <String>{},
          ),
        )
        .toList(growable: false);
  }

  Future<void> _onOptimizeCancelled(
    OptimizeCancelled event,
    Emitter<MediaOptimizerState> emit,
  ) async {
    await _activeRun?.cancel();
  }

  void _onGroupToggled(
    MediaGroupToggled event,
    Emitter<MediaOptimizerState> emit,
  ) {
    emit(
      state.copyWith(
        groups: state.groups
            .map(
              (group) => group.kind == event.kind
                  ? group.copyWith(
                      isSelected: !group.isSelected,
                      // Turning a group back on turns all of it on. A
                      // remembered exclusion the row no longer shows is a file
                      // the user believes is being left alone and is not.
                      excludedPaths: const <String>{},
                    )
                  : group,
            )
            .toList(growable: false),
      ),
    );
  }

  void _onCandidateToggled(
    MediaCandidateToggled event,
    Emitter<MediaOptimizerState> emit,
  ) {
    emit(
      state.copyWith(
        groups: state.groups
            .map(
              (group) => group.kind == event.kind
                  ? group.toggleCandidate(event.path)
                  : group,
            )
            .toList(growable: false),
      ),
    );
  }

  void _onFailureDismissed(
    OptimizerFailureDismissed event,
    Emitter<MediaOptimizerState> emit,
  ) {
    emit(state.copyWith(clearFailure: true));
  }

  void _onResultDismissed(
    OptimizerResultDismissed event,
    Emitter<MediaOptimizerState> emit,
  ) {
    emit(
      state.copyWith(
        status: state.hasFindings
            ? MediaOptimizerStatus.scanned
            : MediaOptimizerStatus.idle,
        clearReport: true,
      ),
    );
  }
}
