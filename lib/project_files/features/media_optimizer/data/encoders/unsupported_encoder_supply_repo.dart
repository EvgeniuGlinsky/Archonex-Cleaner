import 'package:storage_cleaner/project_files/features/media_optimizer/domain/encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_supply_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';

/// The answer on every platform where an encoder is not something you download.
///
/// The phones: their encoder is the operating system's, and a device whose media
/// stack has no HEVC encoder cannot be given one — there is no binary to fetch
/// and nowhere to run it. Web and iOS never reach a media file to begin with.
///
/// Named for what it is rather than `Empty…`, unlike `EmptyQuarantineRepo`: a
/// quarantine on a platform that deletes nothing is correctly empty, while a
/// download that cannot happen is genuinely unsupported, and the screen owes the
/// user a different sentence for it — see `EncoderNotice`.
class UnsupportedEncoderSupplyRepo implements EncoderSupplyRepo {
  const UnsupportedEncoderSupplyRepo();

  @override
  bool get isSupported => false;

  @override
  Future<bool> get isInstalled async => false;

  @override
  int get downloadBytes => 0;

  @override
  EncoderSupplyJob fetch() => const _RefusingSupplyJob();
}

/// Errors rather than closing, for the reason `UnavailableEncoder` does: a job
/// that quietly finished having done nothing is indistinguishable from one that
/// worked.
class _RefusingSupplyJob implements EncoderSupplyJob {
  const _RefusingSupplyJob();

  @override
  Stream<double> get progress =>
      Stream<double>.error(const EncoderFetchFailure());

  @override
  Future<void> cancel() async {}
}
