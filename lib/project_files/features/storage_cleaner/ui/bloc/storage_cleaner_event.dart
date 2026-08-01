part of 'storage_cleaner_bloc.dart';

sealed class StorageCleanerEvent extends Equatable {
  const StorageCleanerEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Reads the access level and the categories it makes reachable.
///
/// Also fires on returning to the screen, because all-files access can be
/// revoked from Settings while the app is in the background.
final class StorageCleanerStarted extends StorageCleanerEvent {
  const StorageCleanerStarted();
}

final class ScanRequested extends StorageCleanerEvent {
  const ScanRequested();
}

final class ScanCancelled extends StorageCleanerEvent {
  const ScanCancelled();
}

final class CleanRequested extends StorageCleanerEvent {
  const CleanRequested();
}

final class CleanCancelled extends StorageCleanerEvent {
  const CleanCancelled();
}

final class CategoryToggled extends StorageCleanerEvent {
  const CategoryToggled(this.category);

  final JunkCategory category;

  @override
  List<Object?> get props => <Object?>[category];
}

final class ItemToggled extends StorageCleanerEvent {
  const ItemToggled({required this.category, required this.path});

  final JunkCategory category;
  final String path;

  @override
  List<Object?> get props => <Object?>[category, path];
}

/// Opens the platform's permission flow.
final class AccessRequested extends StorageCleanerEvent {
  const AccessRequested();
}

/// Opens the folder picker.
final class ScanFolderRequested extends StorageCleanerEvent {
  const ScanFolderRequested();
}

/// Sends the user to the system settings page, once the sheet is gone for good.
final class AccessSettingsRequested extends StorageCleanerEvent {
  const AccessSettingsRequested();
}

final class FailureDismissed extends StorageCleanerEvent {
  const FailureDismissed();
}

/// Clears the result card and returns the screen to its pre-scan state.
final class ResultDismissed extends StorageCleanerEvent {
  const ResultDismissed();
}

/// The quarantine changed — a cleanup landed, or a restore emptied a batch.
///
/// Private to the bloc's own subscription rather than something a widget sends:
/// the banner is a view of the repository, not of anything the screen did.
final class _QuarantineChanged extends StorageCleanerEvent {
  const _QuarantineChanged(this.batches);

  final List<QuarantineBatch> batches;

  @override
  List<Object?> get props => <Object?>[batches];
}
