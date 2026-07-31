import 'package:archonex_cleaner/core/constants/app_byte_units.dart';

/// What the app is willing to hold onto after the user has said delete.
///
/// Deleting is the one thing here that cannot be taken back, and the rules
/// deciding what is junk are heuristics written by hand. So a cleanup moves
/// files aside rather than removing them, and the user has [retention] to
/// notice that something they wanted is gone.
///
/// The two ceilings below are what keeps that from being a lie. A cleaner whose
/// quarantine has swallowed the four gigabytes it just freed has freed nothing,
/// so past those sizes the file is deleted outright and the report says how
/// many went that way — see `CleanReport.permanentCount`.
class AppQuarantinePolicy {
  const AppQuarantinePolicy._();

  /// How long a cleanup can be undone for.
  ///
  /// A week covers "I needed that" arriving on the following Monday. Longer
  /// turns the quarantine into a second junk directory, which is the problem
  /// this app exists to solve.
  static const Duration retention = Duration(days: 7);

  /// Largest single file worth keeping a copy of.
  ///
  /// Above this the point of the cleanup is the file itself: quarantining a
  /// 3 GB crash dump moves 3 GB and frees nothing until the retention expires.
  static const int maxEntryBytes = 256 * AppByteUnits.megabyte;

  /// Everything the quarantine may hold at once, across all batches.
  ///
  /// Reached by a first run on a neglected machine long before it is reached by
  /// anything else. Once it is, the oldest batch is purged early rather than
  /// the new cleanup being refused — the user asked for space, and the promise
  /// of an undo is the thing that yields.
  static const int maxTotalBytes = 2 * AppByteUnits.gigabyte;

  /// Directory inside the app's own support directory that holds it all.
  ///
  /// Application support rather than the cache directory, which is the obvious
  /// place and the wrong one: the OS empties a cache directory whenever it
  /// likes, and an undo the system can delete without asking is not an undo.
  static const String directoryName = 'quarantine';

  /// The index, written beside the files it describes.
  ///
  /// Not in `shared_preferences`: a preference store that is wiped, or restored
  /// from another device's backup, would leave the quarantined files on disk
  /// with nothing that knows where they came from. Beside the data, the two can
  /// only be lost together.
  static const String manifestName = 'manifest.json';
}
