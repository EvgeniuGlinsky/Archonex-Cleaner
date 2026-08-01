import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// Which kinds of file this machine can actually re-encode, asked once when the
/// screen opens.
///
/// A separate question from "does this platform have a file system", and the
/// reason the optimiser needs two: a Windows box can walk the whole disk and
/// still have no `ffmpeg` on the path, in which case the honest screen finds
/// the videos, reports what they would save, and says it cannot do it. Deciding
/// that from the platform alone would be a guess — the same Windows machine
/// gives a different answer after a download.
///
/// Photos are true nearly everywhere, because the fallback encoder is pure Dart
/// and needs nothing installed. Videos are the question.
final class EncoderSupport extends Equatable {
  const EncoderSupport({required this.photos, required this.videos});

  /// Nothing on this platform can be re-encoded at all — the web build, and
  /// iOS, where there is no user media the app can reach in the first place.
  const EncoderSupport.none()
      : photos = false,
        videos = false;

  final bool photos;
  final bool videos;

  bool get hasAny => photos || videos;

  /// Whether a run over this kind can start.
  bool supports(MediaKind kind) =>
      switch (kind) { MediaKind.photo => photos, MediaKind.video => videos };

  /// Whether the screen has to explain a gap. True when one side works and the
  /// other does not — a total refusal is a different notice.
  bool get isPartial => hasAny && !(photos && videos);

  @override
  List<Object?> get props => <Object?>[photos, videos];
}
