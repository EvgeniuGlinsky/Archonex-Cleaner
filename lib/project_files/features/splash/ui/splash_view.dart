import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:storage_cleaner/core/router/app_route.dart';
import 'package:storage_cleaner/core/theme/app_colors.dart';
import 'package:storage_cleaner/project_files/features/splash/ui/bloc/splash_bloc.dart';
import 'package:storage_cleaner/project_files/features/splash/ui/widgets/splash_branding.dart';
import 'package:storage_cleaner/project_files/features/splash/ui/widgets/splash_layout.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashBloc, SplashState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onStatusChanged,
      // Not the theme's surface: this screen continues the window the system
      // already painted while the process started, and the two have to be one
      // colour or the app opens with a flash. See `AppColors.launchBackground`.
      child: const Scaffold(
        backgroundColor: AppColors.launchBackground,
        body: SplashLayout(body: SplashBranding()),
      ),
    );
  }

  void _onStatusChanged(BuildContext context, SplashState state) {
    if (state.status == SplashStatus.completed) {
      context.goNamed(AppRoute.home.routeName);
    }
  }
}
