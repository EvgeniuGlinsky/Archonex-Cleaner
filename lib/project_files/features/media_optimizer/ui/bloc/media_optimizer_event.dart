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
