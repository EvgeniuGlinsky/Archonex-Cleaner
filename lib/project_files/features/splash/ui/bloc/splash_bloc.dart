import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/core/constants/app_durations.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/use_cases/restore_language_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/purge_expired_quarantine_use_case.dart';

part 'splash_event.dart';
part 'splash_state.dart';

/// Holds the splash for a short beat, and spends it on the two things that have
/// to happen before any screen: reading the quarantine index and dropping
/// whatever has run out of retention, and putting back the language the user
/// chose on an earlier run.
///
/// The purge is here rather than on a timer or a background task, because the
/// app is not running when a batch expires, and scheduling a background job
/// whose only purpose is to delete a temporary file is more machinery than the
/// problem is worth. The cost is that an expired batch survives until the next
/// launch.
///
/// The language read is here for a different reason: it is the one asynchronous
/// answer the very next screen needs. A repository that loaded it on its own
/// would repaint the app a frame after it opened, and the beat is long enough to
/// hide a preference read entirely.
///
/// Both run *alongside* the beat rather than after it, so they usually cost
/// nothing at all.
class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc({
    required PurgeExpiredQuarantineUseCase purgeExpired,
    required RestoreLanguageUseCase restoreLanguage,
  })  : _purgeExpired = purgeExpired,
        _restoreLanguage = restoreLanguage,
        super(const SplashState()) {
    // droppable: re-entering the screen must not queue a second timer.
    on<SplashStarted>(_onStarted, transformer: droppable());
  }

  final PurgeExpiredQuarantineUseCase _purgeExpired;
  final RestoreLanguageUseCase _restoreLanguage;

  Future<void> _onStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    await Future.wait<void>(<Future<void>>[
      Future<void>.delayed(AppDurations.splash),
      _warmUp(_purgeExpired.call),
      _warmUp(_restoreLanguage.call),
    ]);

    emit(state.copyWith(status: SplashStatus.completed));
  }

  /// Neither warm-up may strand anyone on the splash screen.
  ///
  /// A quarantine directory that will not answer leaves the app with an empty
  /// undo list, which is the state it can honestly report — the files are picked
  /// up by the next launch that can read them. A preference store that will not
  /// answer leaves the app in the device's language, which is where it started.
  static Future<void> _warmUp(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      return;
    }
  }
}
