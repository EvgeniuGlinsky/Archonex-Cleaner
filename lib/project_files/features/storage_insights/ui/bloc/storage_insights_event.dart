part of 'storage_insights_bloc.dart';

sealed class StorageInsightsEvent extends Equatable {
  const StorageInsightsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The screen opened. Asks the platform, the access and the disk.
///
/// Fires on every visit rather than once, unlike the two tools': this bloc is
/// built per screen, because nothing it starts is worth keeping alive. A
/// measurement is a couple of seconds and can simply be run again.
final class StorageInsightsStarted extends StorageInsightsEvent {
  const StorageInsightsStarted();
}

final class InsightsMeasureRequested extends StorageInsightsEvent {
  const InsightsMeasureRequested();
}

final class InsightsMeasureCancelled extends StorageInsightsEvent {
  const InsightsMeasureCancelled();
}

final class InsightsFailureDismissed extends StorageInsightsEvent {
  const InsightsFailureDismissed();
}

/// Opens the platform's permission flow. The same three the two tools have,
/// because the notice above the chart is the same widget and offers the same
/// three things — a screen that drew the notice and then did nothing when it
/// was pressed would be worse than not drawing it.
final class InsightsAccessRequested extends StorageInsightsEvent {
  const InsightsAccessRequested();
}

/// Opens the folder picker.
final class InsightsFolderRequested extends StorageInsightsEvent {
  const InsightsFolderRequested();
}

/// Sends the user to the system settings page, for a refusal with no way back.
final class InsightsAccessSettingsRequested extends StorageInsightsEvent {
  const InsightsAccessSettingsRequested();
}
