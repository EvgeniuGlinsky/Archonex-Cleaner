import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/optimize_quality_repo.dart';

/// `shared_preferences` behind `OptimizeQualityRepo`.
///
/// The enum's *name* is stored, not its index, for the reason
/// `PrefsLanguageStorage` gives at length: an index means whatever position the
/// entry happens to occupy, so inserting a preset between two others would
/// quietly move everybody who had chosen the one below it — and here that would
/// mean somebody who asked for gentle getting maximum, on their originals, with
/// no way back. A name that no longer matches reads as unset.
///
/// The store is built lazily behind an optional override: this is constructed
/// while the app root is still building, and a test needs a way in that does
/// not involve a platform channel.
class PrefsOptimizeQualityRepo implements OptimizeQualityRepo {
  PrefsOptimizeQualityRepo([SharedPreferencesAsync? prefs]) : _prefs = prefs;

  static const String _key = 'optimizer.quality';

  SharedPreferencesAsync? _prefs;
  OptimizeQuality _selected = OptimizeQuality.fallback;

  SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();

  @override
  OptimizeQuality get selected => _selected;

  @override
  void select(OptimizeQuality quality) {
    _selected = quality;
    unawaited(_write(quality));
  }

  /// A store that will not answer costs the user the preset they picked, not
  /// their run: the optimiser opens on the default instead of not at all.
  @override
  Future<void> restore() async {
    final String? name;

    try {
      name = await _store.getString(_key);
    } catch (_) {
      return;
    }

    if (name == null) {
      return;
    }

    for (final OptimizeQuality quality in OptimizeQuality.values) {
      if (quality.name == name) {
        _selected = quality;

        return;
      }
    }
  }

  Future<void> _write(OptimizeQuality quality) async {
    try {
      await _store.setString(_key, quality.name);
    } catch (_) {
      return;
    }
  }
}
