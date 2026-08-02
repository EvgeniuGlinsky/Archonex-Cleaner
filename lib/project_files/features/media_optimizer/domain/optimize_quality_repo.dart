import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';

/// Remembers how hard the user asked the optimiser to press.
///
/// A repository rather than a field on the bloc, and provided app-wide, for the
/// reason `LanguageRepo` is: it is a preference, it outlives every screen, and
/// the value has to be in hand before the first walk rather than a frame after
/// it. There is no listenable here, though — nothing outside the optimiser
/// cares what it says, so the bloc reads it once and holds it in its state.
abstract interface class OptimizeQualityRepo {
  /// What is in force now. Answers `OptimizeQuality.fallback` until [restore]
  /// has been awaited, which is the same answer a first run gives.
  OptimizeQuality get selected;

  /// Stores a new choice. The value in [selected] moves first: the estimates on
  /// screen are re-run against it immediately, and a store that will not take
  /// the write costs the user their choice on the next launch rather than this
  /// tap — the same trade `LanguageRepoImpl` makes.
  void select(OptimizeQuality quality);

  /// Puts back the choice made on an earlier run, if there was one.
  Future<void> restore();
}
