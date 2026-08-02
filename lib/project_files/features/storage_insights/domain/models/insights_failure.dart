import 'package:equatable/equatable.dart';

/// Everything that can go wrong measuring the disk, and nothing that cannot.
///
/// A hierarchy of its own rather than a member of `CleanFailure`, following the
/// rule the Failures section of the skill sets out: a sealed class can only be
/// extended in its own library, and this feature does not sit under the
/// cleaner. There are three, and there is no member for "some folders were
/// unreadable" — that is not a failure, it is the answer, and it is what the
/// `system` slice is made of.
///
/// No member carries a sentence. `InsightsFailureUi` turns each into copy.
sealed class InsightsFailure extends Equatable {
  const InsightsFailure();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The user stopped the measurement.
///
/// The stream ends with this rather than with a partial answer, for the reason
/// a cancelled scan does everywhere in this app: half a disk measured is a
/// chart that adds up to nothing anybody can act on, and unlike a cleanup
/// nothing was written that the user is owed a count of.
final class InsightsScanCancelledFailure extends InsightsFailure {
  const InsightsScanCancelledFailure();
}

/// This platform has no volume the app can walk.
final class InsightsUnsupportedFailure extends InsightsFailure {
  const InsightsUnsupportedFailure();
}

/// The walk stopped on something the file system refused.
final class InsightsScanFailure extends InsightsFailure {
  const InsightsScanFailure();
}
