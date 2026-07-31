import 'package:archonex_cleaner/project_files/features/quarantine/data/file_system/io_quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Every platform with a file system gets the real one — including iOS, where
/// the only thing it will ever hold is the app's own cache, and a seven-day
/// undo on that is as true as it is anywhere else.
QuarantineRepo createQuarantineRepo() => IoQuarantineRepo();
