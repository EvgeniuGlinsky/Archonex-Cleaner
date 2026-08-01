import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:archonex_cleaner/project_files/features/home/domain/models/app_tool.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Holds the one thing the home screen has to go and find out: how full the
/// device is.
///
/// The tool list is not state — it is `AppTool.values`, the same on every
/// launch — so nothing here loads it and nothing can get it wrong.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required GetDeviceStorageUseCase getDeviceStorage})
      : _getDeviceStorage = getDeviceStorage,
        super(const HomeState()) {
    on<HomeStarted>(_onStarted, transformer: restartable());
  }

  final GetDeviceStorageUseCase _getDeviceStorage;

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));

    final DeviceStorageSnapshot? snapshot = await _getDeviceStorage();

    emit(
      state.copyWith(
        status: HomeStatus.ready,
        storage: snapshot,
        clearStorage: snapshot == null,
      ),
    );
  }
}
