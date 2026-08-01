import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_job.dart';

/// Rewrites the files a scan found, and finds nothing itself.
///
/// [support] is asked once, when the screen opens, and it is a real question
/// rather than a property of the platform: the desktop encoder is whatever
/// `ffmpeg` is on the path, and there may not be one. Answering it early is
/// what lets the screen say "these four videos would save 6 GB, and this
/// machine has no encoder for them" instead of offering a button that fails.
///
/// There is no quarantine here, unlike the cleaner. A rewritten file has no
/// undo: keeping the original for seven days would mean the disk holding both,
/// which frees nothing, and the whole point of the run is the space. The
/// confirmation dialog says so in as many words, and the replace ladder in
/// `IoMediaOptimizeRepo` is what makes that safe — no original is removed until
/// a verified, smaller replacement is on disk beside it.
abstract interface class MediaOptimizeRepo {
  bool get isSupported;

  /// What this machine can actually encode, right now.
  Future<EncoderSupport> support();

  /// Starts a run over [candidates], in the order given.
  OptimizeJob optimize({required List<MediaCandidate> candidates});
}
