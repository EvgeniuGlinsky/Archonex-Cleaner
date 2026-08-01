import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:storage_cleaner/core/router/app_route.dart';
import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/device_storage/ui/widgets/storage_ring.dart';
import 'package:storage_cleaner/project_files/features/home/ui/bloc/home_bloc.dart';
import 'package:storage_cleaner/project_files/features/home/ui/home_view.dart';
import 'package:storage_cleaner/project_files/features/language_selection/data/language_repo_impl.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/language_repo.dart';
import 'package:storage_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

import '../device_storage/fakes.dart';
import '../language_selection/fakes.dart';

void main() {
  late FakeDeviceStorageRepo storageRepo;
  late FakeLanguageStorage languageStorage;

  setUp(() {
    storageRepo = FakeDeviceStorageRepo();
    languageStorage = FakeLanguageStorage();
  });

  /// The narrowest phone still worth supporting, where a badge sharing a line
  /// with a `titleLarge` heading runs out of room first.
  const Size narrow = Size(360, 800);

  /// The bloc is built inside `BlocProvider.create`, never in `setUp`: one from
  /// `setUp` lives in another async zone and silently never receives its
  /// events, and the test then just does nothing with no error pointing at it.
  Future<void> pump(
    WidgetTester tester, {
    Size? surface,
    Locale device = const Locale('en'),
  }) async {
    if (surface != null) {
      tester.view
        ..physicalSize = surface
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    // A repository, not a bloc: building it here rather than in `setUp` is safe,
    // and it is the only way a test can choose the device language.
    final LanguageRepo languageRepo = LanguageRepoImpl(
      languageStorage,
      deviceLocales: () => <Locale>[device],
    );

    final GoRouter router = GoRouter(
      initialLocation: AppRoute.home.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.home.path,
          name: AppRoute.home.routeName,
          builder: (context, state) => BlocProvider<HomeBloc>(
            create: (_) => HomeBloc(
              getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
            )..add(const HomeStarted()),
            child: const HomeView(),
          ),
        ),
        GoRoute(
          path: AppRoute.storageCleaner.path,
          name: AppRoute.storageCleaner.routeName,
          builder: (context, state) =>
              const Scaffold(body: Text('cleaner screen')),
        ),
        GoRoute(
          path: AppRoute.mediaOptimizer.path,
          name: AppRoute.mediaOptimizer.routeName,
          builder: (context, state) =>
              const Scaffold(body: Text('optimizer screen')),
        ),
      ],
    );

    // The `ValueListenableBuilder` and the `locale:` are what `StorageCleanerApp`
    // does, reproduced here on purpose: switching the language is only finished
    // when the app has redrawn in it, and that last step lives above the screen
    // rather than inside it.
    await tester.pumpWidget(
      RepositoryProvider<LanguageRepo>.value(
        value: languageRepo,
        child: ValueListenableBuilder<AppLanguage>(
          valueListenable: languageRepo.selectedLanguageListenable,
          builder: (context, language, _) => MaterialApp.router(
            theme: AppTheme.light(),
            locale: Locale(language.code),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('both tools are on the screen from the first release',
      (tester) async {
    await pump(tester);

    // The product is two tools, and a screen showing one of them teaches the
    // user that it is one.
    expect(find.text('Clean up storage'), findsOneWidget);
    expect(find.text('Optimise files'), findsOneWidget);
  });

  testWidgets('both tools open, and neither carries a badge any more',
      (tester) async {
    // The badge was the promise made while the optimiser was a card and
    // nothing else. `AppTool.isAvailable` stays on the enum for the next
    // unfinished tool, and nothing shows it today.
    await pump(tester);

    expect(find.text('Soon'), findsNothing);

    await tester.tap(find.text('Optimise files'));
    await tester.pumpAndSettle();

    expect(find.text('optimizer screen'), findsOneWidget);
  });

  testWidgets('coming back from the second tool re-reads the disk too',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Optimise files'));
    await tester.pumpAndSettle();

    final int readsBeforeBack = storageRepo.readCount;

    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    // It rewrites files, so it moves the very figure this screen shows.
    expect(storageRepo.readCount, greaterThan(readsBeforeBack));
  });

  testWidgets('the cleaner opens and comes back to a re-read disk',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Clean up storage'));
    await tester.pumpAndSettle();

    expect(find.text('cleaner screen'), findsOneWidget);

    final int readsBeforeBack = storageRepo.readCount;

    // Popped rather than replaced, so the other tool is one tap away — and the
    // figure is read again, because the tool just moved it.
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    expect(find.text('Clean up storage'), findsOneWidget);
    expect(storageRepo.readCount, greaterThan(readsBeforeBack));
  });

  testWidgets('the ring shows what the disk actually reported', (tester) async {
    await pump(tester);

    expect(find.byType(StorageRing), findsOneWidget);
    expect(find.text('192 GB'), findsOneWidget);
    expect(find.text('used of 256 GB'), findsOneWidget);
  });

  testWidgets('a platform that cannot measure the disk draws no ring',
      (tester) async {
    // A ring at nought would read as an empty device, which is the one thing it
    // is certainly not saying.
    storageRepo.snapshot = null;

    await pump(tester);

    expect(find.byType(StorageRing), findsNothing);
    expect(find.text('Clean up storage'), findsOneWidget);
  });

  testWidgets('a long tool name still lays out on a narrow phone',
      (tester) async {
    // "Оптимизировать" is one word, and the widest thing either card has to
    // fit. The badge that used to share this line is gone, and the guard is
    // not: the icon beside the title cannot shrink either, and
    // `JunkCategoryTile` carries the full story of the bug both are written
    // around.
    await pump(tester, surface: narrow, device: const Locale('ru'));

    // Three lines of `titleLarge`, which lays out at 28 under the test font —
    // every glyph a square, so text wraps sooner here than on a device. A title
    // drawn one letter per row would be several hundred.
    expect(
      tester.getSize(find.text('Оптимизировать файлы')).height,
      lessThan(3 * 28.0 + 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the globe opens the language dialog and switching is immediate',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    // No continue button: the screen behind the dialog is already in Russian.
    expect(find.text('Очистить память'), findsOneWidget);
    expect(languageStorage.stored, isNotNull);
  });
}
