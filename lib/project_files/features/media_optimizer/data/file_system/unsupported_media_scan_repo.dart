import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_scan_job.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:archonex_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

/// Web, and iOS.
///
/// Two different reasons for the same answer. Web has no file system at all.
/// iOS has one and it holds nothing the user put there — the photo library sits
/// behind an API that hands out copies rather than paths, and no permission
/// widens that. Everything a phone cleaner advertises for iOS photographs is
/// either a copy into its own container or a lie.
///
/// A refusal rather than an empty result, per `CLAUDE.md`: a scan that finds
/// nothing and a platform that cannot look are different sentences, and a
/// screen that reported "no large files" on an iPhone full of them would be
/// the second wearing the first's clothes.
class UnsupportedMediaScanRepo implements MediaScanRepo {
  const UnsupportedMediaScanRepo();

  @override
  bool get isSupported => false;

  @override
  Future<Set<MediaKind>> kindsFor(StorageAccess access) async =>
      const <MediaKind>{};

  @override
  Future<MediaScanJob> scan({
    required Set<MediaKind> kinds,
    required StorageAccess access,
  }) async =>
      const _RefusingScanJob();
}

class _RefusingScanJob implements MediaScanJob {
  const _RefusingScanJob();

  @override
  Stream<MediaScanUpdate> get updates =>
      Stream<MediaScanUpdate>.error(const OptimizeUnsupportedFailure());

  @override
  Future<void> cancel() async {}
}
