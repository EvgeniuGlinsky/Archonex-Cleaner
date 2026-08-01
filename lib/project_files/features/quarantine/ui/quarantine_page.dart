import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/purge_quarantine_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/restore_quarantine_batch_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/data/use_cases/watch_quarantine_use_case.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/quarantine_repo.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/bloc/quarantine_bloc.dart';
import 'package:storage_cleaner/project_files/features/quarantine/ui/quarantine_view.dart';

/// Dependency injection and `BlocProvider`. No UI.
///
/// The repository is read from the app-wide provider rather than built here:
/// this screen and the cleaner both act on the same batches, and two instances
/// would be two indexes of one directory.
class QuarantinePage extends StatelessWidget {
  const QuarantinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final QuarantineRepo repo = context.read<QuarantineRepo>();

    return BlocProvider<QuarantineBloc>(
      create: (_) => QuarantineBloc(
        watchQuarantine: WatchQuarantineUseCase(repo),
        restoreBatch: RestoreQuarantineBatchUseCase(repo),
        purge: PurgeQuarantineUseCase(repo),
      )..add(const QuarantineStarted()),
      child: QuarantineView(now: DateTime.now),
    );
  }
}
