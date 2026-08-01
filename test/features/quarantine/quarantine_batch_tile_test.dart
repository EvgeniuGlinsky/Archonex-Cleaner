import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/theme/app_theme.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/widgets/quarantine_batch_tile.dart';

import '../storage_cleaner/fakes.dart';

/// The countdown chip used to sit on the title's line, where it could take the
/// whole width and leave the title none — see the doc comment on
/// `JunkCategoryTile`, which carries the story of the bug all three tiles were
/// built with.
void main() {
  /// The narrowest phone still worth supporting.
  const Size narrow = Size(360, 800);

  /// Two lines of `titleMedium`, which lays out at 24 under the test font. The
  /// same string drawn one letter per row would be ten times this.
  const double maxTitleHeight = 2 * 24.0 + 2;

  Future<void> pump(WidgetTester tester, Locale locale) async {
    tester.view
      ..physicalSize = narrow
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuarantineBatchTile(
            batch: fakeBatch(fileCount: 3, sizeEach: 1024),
            // Seven days out from the batch's own date is the longest the
            // countdown ever reads — "Осталось 7 дней".
            now: DateTime.utc(2026, 7, 31),
            canAct: true,
            onRestorePressed: () {},
            onPurgePressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (String code, String title) in <(String, String)>[
    ('en', '3 files · 3 KB'),
    ('ru', '3 файла · 3 KB'),
    ('zh', '3 个文件 · 3 KB'),
  ]) {
    testWidgets('the $code batch title survives the countdown beside it',
        (tester) async {
      await pump(tester, Locale(code));

      expect(
        tester.getSize(find.text(title)).height,
        lessThan(maxTitleHeight),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
