import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:storage_cleaner/core/router/app_router.dart';
import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/language_repo_impl.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/prefs_language_storage.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/models/app_language.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/platform/quarantine_platform.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/platform/storage_access_platform.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/storage_access_repo.dart';

/// Application root.
///
/// App-wide singletons are provided here; feature-scoped dependencies stay in
/// their own `*_page.dart`.
class StorageCleanerApp extends StatefulWidget {
  const StorageCleanerApp({super.key});

  @override
  State<StorageCleanerApp> createState() => _StorageCleanerAppState();
}

class _StorageCleanerAppState extends State<StorageCleanerApp> {
  // All three outlive every screen. The language repo keeps the chosen language
  // across the whole navigation stack, and the quarantine holds one index of
  // one directory — the cleaner writes batches into it and the quarantine
  // screen reads them, so a per-screen instance would be two indexes of the
  // same files, and no test would catch it: every test injects a fake.
  //
  // The access repository is here for the same reason and one of its own: on
  // Android it holds the folders the user handed over through the picker, in
  // memory, for the session. Built per screen it held them for one visit — pick
  // a folder in the cleaner, step back to the home screen, return, and the app
  // was down to its own cache again, with the optimiser never seeing the pick
  // at all.
  final GoRouter _router = AppRouter.create();
  final LanguageRepo _languageRepo = LanguageRepoImpl(PrefsLanguageStorage());
  final QuarantineRepo _quarantineRepo = createQuarantineRepo();
  final StorageAccessRepo _accessRepo = createStorageAccessRepo();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<LanguageRepo>.value(value: _languageRepo),
        RepositoryProvider<QuarantineRepo>.value(value: _quarantineRepo),
        RepositoryProvider<StorageAccessRepo>.value(value: _accessRepo),
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
