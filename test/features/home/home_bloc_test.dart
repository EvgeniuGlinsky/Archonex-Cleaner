import 'package:flutter_test/flutter_test.dart';

import 'package:archonex_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:archonex_cleaner/project_files/features/home/domain/models/app_tool.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/bloc/home_bloc.dart';

import '../device_storage/fakes.dart';

/// There is no `bloc_test` here, so nothing else drains the event queue before
/// an assertion reads `bloc.state`.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeDeviceStorageRepo storageRepo;

  setUp(() => storageRepo = FakeDeviceStorageRepo());

  HomeBloc build() =>
      HomeBloc(getDeviceStorage: GetDeviceStorageUseCase(storageRepo));

  test('it reads the disk on arrival', () async {
    final HomeBloc bloc = build()..add(const HomeStarted());
    await settle();

    expect(bloc.state.status, HomeStatus.ready);
    expect(bloc.state.storage, FakeDeviceStorageRepo.fakeSnapshot);
    expect(bloc.state.hasStorage, isTrue);

    await bloc.close();
  });

  test('a platform that cannot measure the disk leaves no snapshot', () async {
    storageRepo.snapshot = null;

    final HomeBloc bloc = build()..add(const HomeStarted());
    await settle();

    expect(bloc.state.status, HomeStatus.ready);
    expect(bloc.state.hasStorage, isFalse);

    await bloc.close();
  });

  test('coming back from a tool re-reads, because the tool moved the figure',
      () async {
    final HomeBloc bloc = build()..add(const HomeStarted());
    await settle();

    bloc.add(const HomeStarted());
    await settle();

    expect(storageRepo.readCount, 2);

    await bloc.close();
  });

  test('a re-read keeps the old figure on screen instead of blinking out',
      () async {
    final HomeBloc bloc = build()..add(const HomeStarted());
    await settle();

    // The moment a second read is in flight the ring must still be drawable.
    expect(bloc.state.isLoadingFirstRead, isFalse);
    expect(bloc.state.hasStorage, isTrue);

    await bloc.close();
  });

  test('the tool list is the enum, not something that can fail to load', () {
    final HomeBloc bloc = build();

    expect(bloc.state.tools, AppTool.values);
    expect(bloc.state.tools.first, AppTool.cleaner);

    bloc.close();
  });
}
