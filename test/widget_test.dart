import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archonex_cleaner/core/theme/app_colors.dart';
import 'package:archonex_cleaner/core/theme/app_theme.dart';

/// The theme is the one thing every screen shares and nothing else tests.
///
/// `ArchonexApp` itself is deliberately not pumped here: it builds the real
/// quarantine repository, which reaches `path_provider` and has no platform to
/// answer it in a unit test. Each screen is covered by its own view test.
void main() {
  testWidgets('both themes carry the semantic colours widgets read',
      (tester) async {
    for (final (String name, ThemeData theme) in <(String, ThemeData)>[
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      late AppColors colors;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              // `AppColors.of` asserts the extension is registered. A theme
              // built without it fails here rather than at the first widget
              // that happens to need a colour Material does not define.
              colors = AppColors.of(context);

              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(colors.danger, isNotNull, reason: name);
      expect(colors.freed, isNotNull, reason: name);
      expect(colors.caution, isNotNull, reason: name);
    }
  });

  test('the two themes are actually different', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppColors.light.danger, isNot(AppColors.dark.danger));
  });
}
