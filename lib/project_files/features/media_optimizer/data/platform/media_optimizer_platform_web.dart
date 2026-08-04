import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/unsupported_encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/unsupported_media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/file_system/unsupported_media_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_optimize_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/media_scan_repo.dart';

/// Web. No file system, so all three are the refusing siblings.
///
/// The screen says so on the first frame — `UnsupportedMediaScanRepo.isSupported`
/// is false before any walk is attempted.
MediaScanRepo createMediaScanRepo() => const UnsupportedMediaScanRepo();

MediaOptimizeRepo createMediaOptimizeRepo() =>
    const UnsupportedMediaOptimizeRepo();

EncoderSupplyRepo createEncoderSupplyRepo() =>
    const UnsupportedEncoderSupplyRepo();
