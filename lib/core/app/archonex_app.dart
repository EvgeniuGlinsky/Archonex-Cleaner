import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:archonex_cleaner/core/router/app_router.dart';
import 'package:archonex_cleaner/core/theme/app_theme.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/data/language_repo_impl.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/data/platform/quarantine_platform.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Application root.
///
/// App-wide singletons are provided here; feature-scoped dependencies stay in
/// their own `*_page.dart`.
class ArchonexApp extends StatefulWidget {
  const ArchonexApp({super.key});

  @override
  State<ArchonexApp> createState() => _ArchonexAppState();
}

class _ArchonexAppState extends State<ArchonexApp> {
  // Both outlive every screen. The language repo keeps the chosen language
  // across the whole navigation stack, and the quarantine holds one index of
  // one directory — the cleaner writes batches into it and the quarantine
  // screen reads them, so a per-screen instance would be two indexes of the
  // same files, and no test would catch it: every test injects a fake.
  final GoRouter _router = AppRouter.create();
  final LanguageRepo _languageRepo = LanguageRepoImpl();
  final QuarantineRepo _quarantineRepo = createQuarantineRepo();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<LanguageRepo>.value(value: _languageRepo),
        RepositoryProvider<QuarantineRepo>.value(value: _quarantineRepo),
      ],
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: _languageRepo.selectedLanguageListenable,
        builder: (context, language, _) => MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: Locale(language.code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
        ),
      ),
    );
  }
}
