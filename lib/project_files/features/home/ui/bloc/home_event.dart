part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Reads the disk.
///
/// Added again when the user comes back from a tool, because the number this
/// screen exists to show is exactly the one a cleanup just moved. `restartable`
/// on the handler is what makes the second read safe while the first is still
/// in flight.
final class HomeStarted extends HomeEvent {
  const HomeStarted();
}
