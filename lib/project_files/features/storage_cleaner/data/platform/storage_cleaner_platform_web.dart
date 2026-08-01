import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/file_system/unsupported_junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/data/file_system/unsupported_junk_scan_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';

/// Web. There is no file system, so both are the refusing siblings.
///
/// The build exists so the project can be opened in a browser and read about,
/// not so it can clean anything. The cleaner screen says as much on the first
/// frame — `UnsupportedJunkScanRepo.isSupported` is false before any scan is
/// attempted.
JunkScanRepo createJunkScanRepo() => const UnsupportedJunkScanRepo();

JunkCleanRepo createJunkCleanRepo(QuarantineRepo quarantine) =>
    const UnsupportedJunkCleanRepo();
