import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:archonex_cleaner/project_files/features/quarantine/data/use_cases/purge_expired_quarantine_use_case.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/splash/ui/bloc/splash_bloc.dart';
import 'package:archonex_cleaner/project_files/features/splash/ui/splash_view.dart';

/// Wires the splash dependencies. No UI lives here.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SplashBloc>(
      create: (_) => SplashBloc(
        purgeExpired: PurgeExpiredQuarantineUseCase(
          context.read<QuarantineRepo>(),
        ),
      )..add(const SplashStarted()),
      child: const SplashView(),
    );
  }
}
