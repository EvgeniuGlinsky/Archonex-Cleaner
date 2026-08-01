part of 'home_bloc.dart';

enum HomeStatus { initial, loading, ready }

final class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.storage,
  });

  final HomeStatus status;

  /// `null` where the platform cannot measure the disk, and while the first read
  /// is still out. Both mean the ring is not drawn.
  final DeviceStorageSnapshot? storage;

  List<AppTool> get tools => AppTool.values;

  bool get hasStorage => storage != null;

  /// Kept apart from [hasStorage]: a re-read after a cleanup already has a
  /// snapshot to keep showing, so the ring stays on screen with the old figure
  /// instead of blinking out and back.
  bool get isLoadingFirstRead =>
      status == HomeStatus.loading && storage == null;

  HomeState copyWith({
    HomeStatus? status,
    DeviceStorageSnapshot? storage,
    bool clearStorage = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      storage: clearStorage ? null : storage ?? this.storage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, storage];
}
