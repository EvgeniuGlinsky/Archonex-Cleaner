import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';

/// Everything that can go wrong between asking for a scan and getting the
/// space back.
///
/// The hierarchy is sealed so the UI mapper switches exhaustively: a new
/// failure cannot be added without giving it user-facing copy. No member
/// carries a message — they carry the numbers and the paths a message would
/// need, because the sentence itself is a translation and belongs in an ARB
/// file, not in the domain layer.
sealed class CleanFailure implements Exception {
  const CleanFailure();
}

/// The platform refused to widen what the app may reach, and refused in a way
/// the user cannot undo from inside the app.
///
/// A member that *wraps* the other hierarchy rather than one that repeats it.
/// `AccessFailure` belongs to `storage_access/`, which the optimiser asks the
/// same question of; restating its members here would be two sealed lists to
/// keep in step, and `CleanFailureUi` delegates to `AccessFailureUi` instead.
/// This is the one place the cleaner's hierarchy reaches outside itself, and it
/// reaches downward.
final class AccessRefusedFailure extends CleanFailure {
  const AccessRefusedFailure(this.cause);

  final AccessFailure cause;
}

/// The user stopped a running scan.
final class ScanCancelledFailure extends CleanFailure {
  const ScanCancelledFailure();
}

/// There is no file system to clean — the web build, and nothing else.
final class CleanUnsupportedFailure extends CleanFailure {
  const CleanUnsupportedFailure();
}

/// The walk itself broke in a way no single path explains.
///
/// A *scan* failure, and only that. Nothing has been deleted when this is
/// raised, which is what its copy is allowed to promise — see [CleanRunFailure]
/// for the half of the screen where that promise would be a lie.
final class ScanFailure extends CleanFailure {
  const ScanFailure();
}

/// The deletion itself broke partway, after some files had already gone.
///
/// Separate from [ScanFailure] because the two are told to the user in opposite
/// terms and the run was reporting the scan's. "The scan could not finish.
/// Nothing was deleted." is true of a walk that fell over and false of a
/// cleanup that did — by the time a deletion can fail, files are gone, and the
/// sentence that says otherwise sends the user looking for them.
///
/// Carries no report. A run that ends this way has no trustworthy count: the
/// job stopped mid-batch and the tally it had is the tally of what it had got
/// around to telling the screen about, not of what left the disk. Saying so and
/// asking for a rescan is the honest answer, and the rescan is what produces a
/// list that means anything.
final class CleanRunFailure extends CleanFailure {
  const CleanRunFailure();
}

/// Two neighbouring hierarchies are deliberately not members of this one, for
/// the same reason in both cases: a sealed class can only be extended in its
/// own library, so one shared hierarchy would make the dependency arrow point
/// both ways.
///
/// Putting a cleanup back is `RestoreFailure` in
/// `quarantine/domain/models/restore_failure.dart` — the cleaner depends on the
/// quarantine and not the other way round. Being refused reach is
/// `AccessFailure` in `storage_access/domain/models/access_failure.dart`, which
/// the optimiser needs as much as the cleaner does and neither of them owns;
/// [AccessRefusedFailure] above is how it arrives here.
