part of 'media_optimizer_bloc.dart';

sealed class MediaOptimizerEvent extends Equatable {
  const MediaOptimizerEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The screen opened. Asks the platform, the encoders, the access and the disk.
final class MediaOptimizerStarted extends MediaOptimizerEvent {
  const MediaOptimizerStarted();
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
