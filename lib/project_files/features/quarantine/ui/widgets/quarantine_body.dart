import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/ui/bloc/quarantine_bloc.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/ui/widgets/quarantine_batch_tile.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/ui/widgets/quarantine_callbacks.dart';

/// State and callbacks in, one list out.
class QuarantineBody extends StatelessWidget {
  const QuarantineBody({
    required this.state,
    required this.callbacks,
    required this.now,
    super.key,
  });

  final QuarantineState state;
  final QuarantineCallbacks callbacks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return const _EmptyState();
    }

    return ListView(
      children: <Widget>[
        for (final QuarantineBatch batch in state.batches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: QuarantineBatchTile(
              batch: batch,
              now: now,
              canAct: state.canAct,
              onRestorePressed: () => callbacks.onRestorePressed(batch.id),
              onPurgePressed: () => callbacks.onPurgePressed(batch.id),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const double _iconSize = 48;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.inventory_2_outlined,
            size: _iconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.quarantineEmptyTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.quarantineEmptyBody(AppQuarantinePolicy.retention.inDays),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
