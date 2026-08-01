import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';

/// What this machine can actually encode, as opposed to what its platform
/// could in principle.
///
/// Asked once when the screen opens, and the reason the two questions are
/// separate: a Windows box can walk every folder on the disk and still have no
/// `ffmpeg`, in which case the honest screen finds the videos, reports what
/// they would save, and says it cannot do it. Answering that from the platform
/// alone would be a guess, and the same machine gives a different answer after
/// a download.
class GetEncoderSupportUseCase {
  const GetEncoderSupportUseCase(this._repo);

  final MediaOptimizeRepo _repo;

  Future<EncoderSupport> call() async {
    if (!_repo.isSupported) {
      return const EncoderSupport.none();
    }

    return _repo.support();
  }
}
