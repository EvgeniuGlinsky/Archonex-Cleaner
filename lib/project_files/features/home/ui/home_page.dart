import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/device_storage/data/platform/device_storage_platform.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/bloc/home_bloc.dart';
import 'package:archonex_cleaner/project_files/features/home/ui/home_view.dart';

/// Wires the home dependencies. No UI lives here.
///
/// The disk reader is built per screen rather than app-wide: it holds no index
/// and no state, only a method channel, so a second instance is a second object
/// and not a second source of truth. The quarantine is app-wide for the opposite
/// reason.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (_) => HomeBloc(
        getDeviceStorage: GetDeviceStorageUseCase(createDeviceStorageRepo()),
      )..add(const HomeStarted()),
      child: const HomeView(),
    );
  }
}
