import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_clean_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/data/file_system/io_junk_scan_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_clean_repo.dart';
import 'package:storage_cleaner/project_files/features/storage_cleaner/domain/junk_scan_repo.dart';

/// Android, iOS, macOS, Windows and Linux — everything with a file system.
///
/// The scanner and the deleter are the same class on all five: what differs per
/// platform is which rules they are given, and `JunkRuleset` answers that.
///
/// Which access repository sits behind the interface is no longer asked here
/// but in `storage_access/data/platform/`, because two tools now ask it and the
/// optimiser must not have to import the cleaner to find out whether it is
/// allowed to run.
JunkScanRepo createJunkScanRepo() => IoJunkScanRepo();

/// Takes the quarantine rather than building one: it is an app-wide singleton,
/// constructed in `storage_cleaner_app.dart` because the quarantine screen reads the
/// same object this writes into.
JunkCleanRepo createJunkCleanRepo(QuarantineRepo quarantine) =>
    IoJunkCleanRepo(quarantine: quarantine);
