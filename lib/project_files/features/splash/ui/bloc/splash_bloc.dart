import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/core/constants/app_durations.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/purge_expired_quarantine_use_case.dart';

part 'splash_event.dart';
part 'splash_state.dart';

/// Holds the splash for a short beat, and spends it on the one thing that has
/// to happen before any screen: reading the quarantine index and dropping
/// whatever has run out of retention.
///
/// Here rather than on a timer or a background task, because the app is not
/// running when a batch expires, and scheduling a background job whose only
/// purpose is to delete a temporary file is more machinery than the problem is
/// worth. The cost is that an expired batch survives until the next launch.
///
/// The purge runs *alongside* the beat rather than after it, so it usually
/// costs nothing at all.
class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc({required PurgeExpiredQuarantineUseCase purgeExpired})
      : _purgeExpired = purgeExpired,
        super(const SplashState()) {
    // droppable: re-entering the screen must not queue a second timer.
    on<SplashStarted>(_onStarted, transformer: droppable());
  }

  final PurgeExpiredQuarantineUseCase _purgeExpired;

  Future<void> _onStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    await Future.wait<void>(<Future<void>>[
      Future<void>.delayed(AppDurations.splash),
      _warmUp(),
    ]);

    emit(state.copyWith(status: SplashStatus.completed));
  }

  /// A quarantine directory that will not answer must not strand anyone on the
  /// splash screen. The app then starts with an empty undo list, which is the
  /// state it can honestly report — and the files are picked up by the next
  /// launch that can read them.
  Future<void> _warmUp() async {
    try {
      await _purgeExpired();
    } catch (_) {
      return;
    }
  }
}
