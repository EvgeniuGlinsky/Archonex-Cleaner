import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';

/// Whether this platform can do any of this at all.
///
/// Both halves are asked, because they can disagree in principle and the screen
/// has one answer to give. A platform that could walk but not rewrite is not a
/// hypothetical — it is a desktop with no `ffmpeg` — but that is a *machine*
/// question and `GetEncoderSupportUseCase` asks it. This one is about the
/// platform.
class GetOptimizerAvailabilityUseCase {
  const GetOptimizerAvailabilityUseCase({
    required MediaScanRepo scanRepo,
    required MediaOptimizeRepo optimizeRepo,
  })  : _scanRepo = scanRepo,
        _optimizeRepo = optimizeRepo;

  final MediaScanRepo _scanRepo;
  final MediaOptimizeRepo _optimizeRepo;

  bool call() => _scanRepo.isSupported && _optimizeRepo.isSupported;
}
