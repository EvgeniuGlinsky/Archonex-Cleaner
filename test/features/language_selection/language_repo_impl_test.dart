import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:archonex_cleaner/project_files/features/language_selection/data/language_repo_impl.dart';
import 'package:archonex_cleaner/project_files/features/language_selection/domain/models/app_language.dart';

import 'fakes.dart';

void main() {
  LanguageRepoImpl build({
    List<Locale> device = const <Locale>[Locale('en')],
    AppLanguage? stored,
    FakeLanguageStorage? storage,
  }) {
    return LanguageRepoImpl(
      storage ?? FakeLanguageStorage(stored: stored),
      deviceLocales: () => device,
    );
  }

  group('the device answers first', () {
    test('a matching system locale is in place before anything is read', () {
      final LanguageRepoImpl repo = build(
        device: const <Locale>[Locale('ru', 'RU')],
      );

      // Not after `restore()` — on the very first frame, which is what keeps the
      // splash screen from flashing English on a Russian phone.
      expect(repo.getSelectedLanguage(), AppLanguage.russian);
    });

    test('a system locale the app has no ARB file for falls back to English',
        () {
      final LanguageRepoImpl repo = build(
        device: const <Locale>[Locale('de', 'DE')],
      );

      expect(repo.getSelectedLanguage(), AppLanguage.english);
    });

    test('the second preference is taken when the first is not translated', () {
      // A device set to Ukrainian first and Russian second reads Russian, which
      // is a language they read — English may not be on their list at all.
      final LanguageRepoImpl repo = build(
        device: const <Locale>[Locale('uk'), Locale('ru')],
      );

      expect(repo.getSelectedLanguage(), AppLanguage.russian);
    });

    test('an empty locale list falls back to English', () {
      final LanguageRepoImpl repo = build(device: const <Locale>[]);

      expect(repo.getSelectedLanguage(), AppLanguage.english);
    });
  });

  group('a choice made by hand outranks it', () {
    test('restore puts back what an earlier run stored', () async {
      final LanguageRepoImpl repo = build(
        device: const <Locale>[Locale('ru')],
        stored: AppLanguage.chinese,
      );

      await repo.restore();

      expect(repo.getSelectedLanguage(), AppLanguage.chinese);
    });

    test('restore with nothing stored leaves the device answer alone',
        () async {
      final LanguageRepoImpl repo = build(
        device: const <Locale>[Locale('ru')],
      );

      await repo.restore();

      expect(repo.getSelectedLanguage(), AppLanguage.russian);
    });

    test('selecting writes through, so the next launch restores it', () async {
      final FakeLanguageStorage storage = FakeLanguageStorage();
      final LanguageRepoImpl repo = build(storage: storage);

      repo.selectLanguage(AppLanguage.chinese);
      await Future<void>.delayed(Duration.zero);

      expect(storage.written, <AppLanguage>[AppLanguage.chinese]);
      expect(storage.stored, AppLanguage.chinese);
    });
  });

  group('a store that will not answer', () {
    test('costs the user their choice, not their launch', () async {
      final FakeLanguageStorage storage = FakeLanguageStorage(
        stored: AppLanguage.chinese,
      )..isBroken = true;

      final LanguageRepoImpl repo = build(
        device: const <Locale>[Locale('ru')],
        storage: storage,
      );

      await repo.restore();

      expect(repo.getSelectedLanguage(), AppLanguage.russian);
    });

    test('a failed write still switches the language on screen', () async {
      final FakeLanguageStorage storage = FakeLanguageStorage()
        ..isBroken = true;
      final LanguageRepoImpl repo = build(storage: storage);

      repo.selectLanguage(AppLanguage.russian);
      await Future<void>.delayed(Duration.zero);

      expect(repo.getSelectedLanguage(), AppLanguage.russian);
      expect(storage.written, isEmpty);
    });
  });

  test('the listenable fires so the app root can rebuild with a new locale',
      () async {
    final LanguageRepoImpl repo = build();
    final List<AppLanguage> seen = <AppLanguage>[];

    repo.selectedLanguageListenable
        .addListener(() => seen.add(repo.getSelectedLanguage()));

    repo.selectLanguage(AppLanguage.russian);
    await Future<void>.delayed(Duration.zero);

    expect(seen, <AppLanguage>[AppLanguage.russian]);
  });
}
