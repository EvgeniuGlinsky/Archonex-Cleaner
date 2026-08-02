part of 'media_optimizer_bloc.dart';

sealed class MediaOptimizerEvent extends Equatable {
  const MediaOptimizerEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The bloc was built. Asks the platform, the encoders, the access and the disk.
///
/// Once, now. The bloc outlives the screen, so returning to it is
/// [MediaOptimizerResumed] rather than another one of these.
final class MediaOptimizerStarted extends MediaOptimizerEvent {
  const MediaOptimizerStarted();
}

/// The screen has been opened again.
///
/// Re-reads the access level and how full the disk is, and touches nothing else
/// unless the access moved. A run left going is the reason the bloc outlives
/// the screen at all; re-reading must not disturb it, and dropping the findings
/// underneath it would.
final class MediaOptimizerResumed extends MediaOptimizerEvent {
  const MediaOptimizerResumed();
}

/// The user moved the quality switch.
///
/// Everything already found is re-measured against the new preset rather than
/// walked again: the header of every file is already in hand, which is what
/// `MediaCandidate.probe` is kept for. A run in flight is not disturbed — the
/// files it is partway through were planned under the old setting and the
/// encoder has already been told.
final class OptimizeQualityChanged extends MediaOptimizerEvent {
  const OptimizeQualityChanged(this.quality);

  final OptimizeQuality quality;

  @override
  List<Object?> get props => <Object?>[quality];
}

final class MediaScanRequested extends MediaOptimizerEvent {
  const MediaScanRequested();
}

final class MediaScanCancelled extends MediaOptimizerEvent {
  const MediaScanCancelled();
}

final class OptimizeRequested extends MediaOptimizerEvent {
  const OptimizeRequested();
}

final class OptimizeCancelled extends MediaOptimizerEvent {
  const OptimizeCancelled();
}

final class MediaGroupToggled extends MediaOptimizerEvent {
  const MediaGroupToggled(this.kind);

  final MediaKind kind;

  @override
  List<Object?> get props => <Object?>[kind];
}

final class MediaCandidateToggled extends MediaOptimizerEvent {
  const MediaCandidateToggled({required this.kind, required this.path});

  final MediaKind kind;
  final String path;

  @override
  List<Object?> get props => <Object?>[kind, path];
}

final class OptimizerAccessRequested extends MediaOptimizerEvent {
  const OptimizerAccessRequested();
}

final class OptimizerFolderRequested extends MediaOptimizerEvent {
  const OptimizerFolderRequested();
}

/// Sends the user to the system settings page, once the sheet is gone for good.
final class OptimizerAccessSettingsRequested extends MediaOptimizerEvent {
  const OptimizerAccessSettingsRequested();
}

final class OptimizerFailureDismissed extends MediaOptimizerEvent {
  const OptimizerFailureDismissed();
}

final class OptimizerResultDismissed extends MediaOptimizerEvent {
  const OptimizerResultDismissed();
}
