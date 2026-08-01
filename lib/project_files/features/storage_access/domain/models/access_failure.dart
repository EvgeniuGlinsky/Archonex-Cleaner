/// What can go wrong between asking the platform for more reach and being
/// given it.
///
/// A hierarchy of its own rather than three more members of `CleanFailure`,
/// for the reason `QuarantineFailure` has one: a sealed class can only be extended
/// in its own library, so a shared hierarchy would make the cleaner and the
/// optimiser both own the access failures and the arrow point every way at
/// once. Two tools ask this question and neither of them owns the answer.
///
/// No member carries a message. They carry the flag a message would need,
/// because the sentence is a translation and belongs in an ARB file.
sealed class AccessFailure implements Exception {
  const AccessFailure();
}

/// The platform will not let the app reach outside its own folder, and asking
/// again is not going to change that.
///
/// A refusal the user *can* undo is not this — it is returned as a narrower
/// `StorageAccess` and the screen offers the button again. This is the other
/// case: once the system stops showing the sheet, only Settings will do, and
/// that is a different sentence.
final class StorageAccessDeniedFailure extends AccessFailure {
  const StorageAccessDeniedFailure({required this.canAskAgain});

  /// Whether asking is still worth an offer. False once the user has refused
  /// permanently — the OS stops showing the dialog and only Settings will do.
  final bool canAskAgain;
}
