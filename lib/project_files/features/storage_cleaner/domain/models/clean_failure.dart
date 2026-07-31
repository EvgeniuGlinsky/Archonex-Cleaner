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

/// The platform will not let the app look where the rules point.
///
/// Android without all-files access, in practice. Carries what the app *can*
/// still reach, so the screen can offer the narrower scan instead of only
/// reporting the refusal.
final class StorageAccessDeniedFailure extends CleanFailure {
  const StorageAccessDeniedFailure({required this.canAskAgain});

  /// Whether asking is still worth an offer. False once the user has refused
  /// permanently — the OS stops showing the dialog and only Settings will do.
  final bool canAskAgain;
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
final class ScanFailure extends CleanFailure {
  const ScanFailure();
}

/// Putting a cleanup back has its own hierarchy, in
/// `quarantine/domain/models/restore_failure.dart`. The cleaner depends on the
/// quarantine and not the other way round, so its failures cannot live here.
