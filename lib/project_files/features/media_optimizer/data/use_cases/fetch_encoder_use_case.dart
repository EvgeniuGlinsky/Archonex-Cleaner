import 'package:storage_cleaner/project_files/features/media_optimizer/domain/encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_supply_job.dart';

/// Starts a download of the video encoder, and says whether one is worth
/// offering.
///
/// The guard is here rather than only on the state, because the platform's answer
/// and the user's screen are two different things to be wrong about: a phone can
/// have no HEVC encoder and no way to fetch one, and a bloc that offered the
/// button anyway would be offering a job that errors on its first frame.
class FetchEncoderUseCase {
  const FetchEncoderUseCase(this._repo);

  final EncoderSupplyRepo _repo;

  /// Whether fetching is possible here at all. Independent of whether it is
  /// *needed*, which is `EncoderSupport.videos`.
  bool get isSupported => _repo.isSupported;

  /// Roughly what the user is agreeing to download, for the sentence offering it.
  int get downloadBytes => _repo.downloadBytes;

  /// Nothing starts until the returned job is listened to.
  EncoderSupplyJob call() => _repo.fetch();
}
