import 'package:archonex_cleaner/project_files/features/quarantine/data/file_system/empty_quarantine_repo.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';

/// Web deletes nothing, so its quarantine is permanently and correctly empty.
QuarantineRepo createQuarantineRepo() => EmptyQuarantineRepo();
