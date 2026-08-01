import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';

/// Everything that can go wrong between asking what is worth shrinking and
/// getting the space back.
///
/// Its own hierarchy rather than members of `CleanFailure`, for the reason
/// every hierarchy here has one: a sealed class can only be extended in its own
/// library, and the optimiser and the cleaner are siblings with no dependency
/// between them. Nothing carries a sentence — the members carry the kind or the
/// flag a sentence would interpolate, because the sentence is a translation.
///
/// A file that could not be re-encoded is deliberately *not* in here. That is
/// `OptimizeReport.failedCount`, for the same reason a locked file is
/// `CleanReport.skippedCount`: one file refusing does not end a run of two
/// hundred, and putting it here would mean two places reporting one number.
sealed class OptimizeFailure implements Exception {
  const OptimizeFailure();
}

/// The platform refused to widen what the app may reach, permanently.
///
/// The wrapping member, matching `AccessRefusedFailure` on the cleaner's side.
/// The access sentences live in `storage_access/` because both tools hit them.
final class OptimizeAccessRefusedFailure extends OptimizeFailure {
  const OptimizeAccessRefusedFailure(this.cause);

  final AccessFailure cause;
}

/// The user stopped a running scan.
///
/// A cancelled scan ends the stream with this and hands over nothing, because
/// nothing was written and a half-measured folder is not a list anyone can act
/// on. A cancelled *run* does the opposite — see `OptimizeReport.wasCancelled`.
final class MediaScanCancelledFailure extends OptimizeFailure {
  const MediaScanCancelledFailure();
}

/// There is nothing here to walk, or nowhere the user's own media lives.
///
/// The web build, and iOS: the photo library is behind an API no app can
/// rewrite through, and the container this app can reach holds nothing the user
/// put there.
final class OptimizeUnsupportedFailure extends OptimizeFailure {
  const OptimizeUnsupportedFailure();
}

/// There is no encoder on this machine for that kind of file.
///
/// A desktop without `ffmpeg` on the path, or a device whose media stack offers
/// no HEVC encoder. Carries the kind rather than a sentence, because the two
/// cases need different instructions and the screen decides which.
final class NoEncoderFailure extends OptimizeFailure {
  const NoEncoderFailure(this.kind);

  final MediaKind kind;
}

/// The walk itself broke in a way no single path explains.
///
/// Nothing has been rewritten — a scan only reads — so this ends the run and
/// says so.
final class MediaScanFailure extends OptimizeFailure {
  const MediaScanFailure();
}
