import 'package:equatable/equatable.dart';

/// What one run actually did, measured from the disk rather than estimated.
///
/// [freedBytes] is the sum of what each file lost, taken after the replacement
/// landed. The figure the screen showed before the run was an estimate and was
/// labelled one; this is the other number, and the result card shows both so
/// that an estimate which was badly wrong is visible rather than quietly
/// replaced.
///
/// The three counts beside it are outcomes, not failures. A file the encoder
/// could not read, a destination name already taken, an output that came out
/// larger than the input — none of those end a run of two hundred files, and
/// each has its own line on the card. Folding them into `OptimizeFailure` would
/// mean two places reporting one number.
final class OptimizeReport extends Equatable {
  const OptimizeReport({
    this.freedBytes = 0,
    this.optimizedCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.renamedCount = 0,
    this.wasCancelled = false,
  });

  /// What the disk gained, summed per file after each replacement.
  final int freedBytes;

  /// Files replaced by a smaller version.
  final int optimizedCount;

  /// Files left exactly as they were, deliberately: the encode produced
  /// something no smaller, or the new name was already taken.
  final int skippedCount;

  /// Files the encoder could not process. The original is untouched in every
  /// one of these cases — that is the whole design of the replace ladder.
  final int failedCount;

  /// How many of [optimizedCount] ended up with a different extension.
  final int renamedCount;

  /// Whether the user stopped it part way. The counts above are still owed to
  /// them: those files are already rewritten.
  final bool wasCancelled;

  int get attemptedCount => optimizedCount + skippedCount + failedCount;

  bool get didAnything => optimizedCount > 0;

  /// Whether anything happened that the card has to explain rather than
  /// celebrate.
  bool get hasCaveats => skippedCount > 0 || failedCount > 0 || wasCancelled;

  @override
  List<Object?> get props => <Object?>[
        freedBytes,
        optimizedCount,
        skippedCount,
        failedCount,
        renamedCount,
        wasCancelled,
      ];
}
