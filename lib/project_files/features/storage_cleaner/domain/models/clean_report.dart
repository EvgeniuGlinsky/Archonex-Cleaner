import 'package:equatable/equatable.dart';

/// What one cleanup actually did.
///
/// [quarantinedCount] and [permanentCount] are separate because the difference
/// matters to the user and not to the app: only the first can be undone, and
/// the screen has to say which files fell on which side rather than offering an
/// undo that covers half of them.
final class CleanReport extends Equatable {
  const CleanReport({
    this.freedBytes = 0,
    this.quarantinedCount = 0,
    this.permanentCount = 0,
    this.skippedCount = 0,
    this.remainingPaths = const <String>{},
    this.batchId,
    this.wasCancelled = false,
  });

  /// Space the device got back. Counts everything that left its original path,
  /// including what went to quarantine — quarantined files are moved, not
  /// copied, wherever the file system allows it.
  final int freedBytes;

  /// Files moved aside and restorable for `AppQuarantinePolicy.retention`.
  final int quarantinedCount;

  /// Files deleted outright, because they were larger than
  /// `AppQuarantinePolicy.maxEntryBytes` or lived on another volume, where
  /// moving would have meant copying and freed nothing.
  final int permanentCount;

  /// Files the OS would not part with — locked by a running process, almost
  /// always.
  final int skippedCount;

  /// Everything the run handed back still sitting where it was found.
  ///
  /// Covers two groups the screen has to treat identically and [skippedCount]
  /// only counts one of: files the OS refused, and files a cancelled run never
  /// reached. Both are still on disk and still junk, and the list is what lets
  /// the screen keep their rows instead of guessing from the counts.
  ///
  /// The paths rather than the count, because keeping a row needs to know which
  /// row. The kept side rather than the removed one, because a finished run
  /// leaves a handful and a finished run is the common case — the inverse would
  /// be every path of a fifty-thousand-file cleanup, held for as long as the
  /// result card is up.
  final Set<String> remainingPaths;

  /// The batch the quarantined files went into, `null` when none did.
  final String? batchId;

  /// Whether the user stopped the run partway.
  ///
  /// A field on the report rather than a `CleanFailure` ending the stream,
  /// which is how the scan reports the same thing and is deliberately not how
  /// this does. A cancelled scan owes the user nothing; a cancelled cleanup has
  /// already deleted files and owes them the count — an error-terminated stream
  /// would throw that away to say something the user already knows.
  final bool wasCancelled;

  int get deletedCount => quarantinedCount + permanentCount;

  bool get didAnything => deletedCount > 0;

  /// Whether an undo is worth offering.
  bool get isRestorable => batchId != null && quarantinedCount > 0;

  CleanReport copyWith({
    int? freedBytes,
    int? quarantinedCount,
    int? permanentCount,
    int? skippedCount,
    Set<String>? remainingPaths,
    String? batchId,
    bool? wasCancelled,
    bool clearBatchId = false,
  }) {
    return CleanReport(
      freedBytes: freedBytes ?? this.freedBytes,
      quarantinedCount: quarantinedCount ?? this.quarantinedCount,
      permanentCount: permanentCount ?? this.permanentCount,
      skippedCount: skippedCount ?? this.skippedCount,
      remainingPaths: remainingPaths ?? this.remainingPaths,
      batchId: clearBatchId ? null : batchId ?? this.batchId,
      wasCancelled: wasCancelled ?? this.wasCancelled,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        freedBytes,
        quarantinedCount,
        permanentCount,
        skippedCount,
        remainingPaths,
        batchId,
        wasCancelled,
      ];
}
