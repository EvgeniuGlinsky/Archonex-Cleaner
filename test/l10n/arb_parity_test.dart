import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one thing `CLAUDE.md` says nothing checks, now checked.
///
/// > Nothing checks parity for you: a key added to `app_en.arb` alone compiles,
/// > passes every test, and ships English to a Russian user.
///
/// That was true, and it stopped being affordable the moment a feature landed
/// with forty new keys across three files. The failure it catches is completely
/// silent — `flutter gen-l10n` fills a missing key from the template and says
/// nothing, so the app builds, every other test passes, and one screen is in
/// the wrong language for whoever notices first.
///
/// It reads the ARB files off disk rather than the generated Dart, because the
/// generated files are gitignored and are the very thing doing the papering
/// over.
void main() {
  final Directory l10n = Directory('lib/l10n');

  /// Read at load time, so `expect` is not available here — a missing file
  /// throws with its own path in the message, which is as clear as a matcher
  /// would have been.
  Map<String, Object?> read(String name) {
    final File file = File('${l10n.path}/$name');

    if (!file.existsSync()) {
      throw StateError('${file.path} is missing');
    }

    return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  }

  /// Message keys, without the `@metadata` entries or the locale header.
  Set<String> messageKeys(Map<String, Object?> arb) => arb.keys
      .where((key) => !key.startsWith('@'))
      .toSet();

  final Map<String, Object?> template = read('app_en.arb');
  final Map<String, String> translations = <String, String>{
    'ru': 'app_ru.arb',
    'zh': 'app_zh.arb',
  };

  test('the template is the file l10n.yaml says it is', () {
    // If this ever moves, every assertion below is comparing the wrong pair.
    final String config = File('l10n.yaml').readAsStringSync();

    expect(config, contains('template-arb-file: app_en.arb'));
    expect(config, contains('arb-dir: lib/l10n'));
  });

  test('there is one ARB per language and no orphans', () {
    // A file nobody generates from is a translation quietly going stale.
    final Set<String> present = l10n
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.arb'))
        .toSet();

    expect(present, <String>{'app_en.arb', ...translations.values});
  });

  group('every translation', () {
    translations.forEach((locale, fileName) {
      final Map<String, Object?> arb = read(fileName);

      test('$locale declares itself', () {
        expect(arb['@@locale'], locale);
      });

      test('$locale has every key the template has, and no extra', () {
        final Set<String> expected = messageKeys(template);
        final Set<String> actual = messageKeys(arb);

        expect(
          actual.difference(expected),
          isEmpty,
          reason: '$fileName has keys the template does not',
        );
        expect(
          expected.difference(actual),
          isEmpty,
          reason: '$fileName is missing keys, and would ship English for them',
        );
      });

      test('$locale interpolates the same placeholders', () {
        // The half a key count cannot catch. A translation that dropped
        // `{size}` compiles, and ships a sentence with the number missing.
        for (final String key in messageKeys(template)) {
          expect(
            _placeholdersIn(arb[key]),
            _placeholdersIn(template[key]),
            reason: '$fileName · $key',
          );
        }
      });

      test('$locale carries the same metadata blocks', () {
        // `gen-l10n` reads placeholder types from the template only, so a
        // metadata block here is documentation — but one that exists in two
        // files and disagrees is worse than one that exists in neither.
        expect(
          arb.keys.where((key) => key.startsWith('@') && key != '@@locale').toSet(),
          template.keys
              .where((key) => key.startsWith('@') && key != '@@locale')
              .toSet(),
          reason: fileName,
        );
      });

      test('$locale left nothing untranslated by copy-paste', () {
        // Not every identical string is a mistake — "Archonex Cleaner" is the
        // same everywhere — so this only looks at the ones long enough that
        // matching by accident is not plausible.
        const int longEnoughToBeProse = 25;

        final Iterable<String> copied = messageKeys(template).where((key) {
          final Object? source = template[key];
          final Object? target = arb[key];

          return source is String &&
              target is String &&
              source == target &&
              source.length >= longEnoughToBeProse;
        });

        expect(copied, isEmpty, reason: '$fileName has untranslated English');
      });
    });
  });
}

/// Every `{name}` in a message, including the ones inside a plural's branches.
///
/// ICU plural bodies are where the interesting mistakes live: a translator who
/// wrote `other{файлов}` instead of `other{{count} файлов}` produces a sentence
/// with no number in it, and nothing else in the toolchain minds.
Set<String> _placeholdersIn(Object? message) {
  if (message is! String) {
    return const <String>{};
  }

  return RegExp(r'\{(\w+)\}')
      .allMatches(message)
      .map((match) => match.group(1)!)
      // The ICU keyword, not a placeholder: `{count, plural, ...}` puts `count`
      // in already and the branch selectors are not interpolations.
      .where((name) => name != 'plural' && name != 'select')
      .toSet();
}
