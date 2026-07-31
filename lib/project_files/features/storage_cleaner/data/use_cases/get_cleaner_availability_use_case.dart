import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';

/// Whether this build can do the job at all.
///
/// Both halves, because a platform that can find junk and not delete it would
/// be worse than one that admits it up front — and the screen asks one question
/// rather than two.
class GetCleanerAvailabilityUseCase {
  const GetCleanerAvailabilityUseCase({
    required JunkScanRepo scanRepo,
    required JunkCleanRepo cleanRepo,
  })  : _scanRepo = scanRepo,
        _cleanRepo = cleanRepo;

  final JunkScanRepo _scanRepo;
  final JunkCleanRepo _cleanRepo;

  bool call() => _scanRepo.isSupported && _cleanRepo.isSupported;
}
