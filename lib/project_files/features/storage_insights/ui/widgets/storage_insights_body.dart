import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_insights_policy.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_access/ui/widgets/storage_access_notice.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_breakdown.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/bloc/storage_insights_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/mappers/storage_slice_ui.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_breakdown_ring.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_insights_callbacks.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/widgets/storage_slice_row.dart';

/// State and callbacks in, one column out.
///
/// A `Column` and not a `ListView`, for the reason `StorageCleanerBody` gives:
/// `AppScreenLayout` owns the screen's only scroll view. No `flutter_bloc` and
/// no `go_router`, which is what lets a widget test drive it with a literal.
class StorageInsightsBody extends StatelessWidget {
  const StorageInsightsBody({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final StorageInsightsState state;
  final StorageInsightsCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final StorageBreakdown breakdown = state.breakdown;
    final List<StorageSlice> slices = breakdown.slices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.access.isNarrowed) ...<Widget>[
          StorageAccessNotice(
            access: state.access,
            onGrantPressed: callbacks.onGrantAccessPressed,
            onAddFolderPressed: callbacks.onAddFolderPressed,
            onOpenSettingsPressed: callbacks.onOpenSettingsPressed,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.hasChart) ...<Widget>[
          _Ring(state: state, breakdown: breakdown),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (slices.isEmpty)
          _EmptyState(state: state)
        else ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final StorageSlice slice in slices)
                    StorageSliceRow(
                      slice: slice,
                      fraction: breakdown.fractionOf(slice.bytes),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // The one sentence that keeps the chart honest. Without it the
          // "system" row reads as a claim about what is in it, rather than as
          // an admission that nothing could look.
          _Note(text: l10n.insightsSystemNote),
          if (breakdown.isTruncated) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _Note(text: l10n.insightsTruncatedNotice(AppInsightsPolicy.maxFiles)),
          ],
        ],
      ],
    );
  }
}

/// The ring, saying two different things at two moments.
///
/// Before and during a measurement it is the disk as the platform describes it,
/// with whatever has been counted so far filling in. Afterwards it is the whole
/// breakdown. The figure in the middle is the used space either way, because
/// that is the number the screen exists to explain.
class _Ring extends StatelessWidget {
  const _Ring({required this.state, required this.breakdown});

  final StorageInsightsState state;
  final StorageBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final (String title, String caption) = switch (state) {
      StorageInsightsState(isMeasuring: true) => (
          FileSizeFormatter.format(breakdown.measuredBytes),
          state.location ?? l10n.insightsMeasuringLabel,
        ),
      StorageInsightsState(storage: final storage?) => (
          FileSizeFormatter.format(storage.usedBytes),
          l10n.storageUsedOf(FileSizeFormatter.format(storage.totalBytes)),
        ),
      _ => (
          FileSizeFormatter.format(breakdown.measuredBytes),
          l10n.insightsMeasuringLabel,
        ),
    };

    return StorageBreakdownRing(
      segments: <RingSegment>[
        for (final StorageSlice slice in breakdown.slices)
          if (slice.category != StorageSliceCategory.free)
            RingSegment(
              fraction: breakdown.fractionOf(slice.bytes),
              colour: slice.category.colour(context),
            ),
      ],
      title: title,
      caption: caption,
      isBusy: state.isMeasuring,
    );
  }
}

/// A quiet paragraph under the chart. Not a card: it is a footnote, and a card
/// would give it the same weight as the thing it is annotating.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

/// Three different nothings, told apart — the same three the cleaner has, and
/// for the same reason: one message for all of them would be wrong twice.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  static const double _iconSize = 40;
  static const double _markSize = 72;

  final StorageInsightsState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final (IconData icon, String title, String body) = switch (state) {
      StorageInsightsState(isSupported: false) => (
          Icons.block_outlined,
          l10n.insightsUnsupportedTitle,
          l10n.insightsUnsupportedBody,
        ),
      StorageInsightsState(foundNothing: true) => (
          Icons.search_off_outlined,
          l10n.insightsEmptyTitle,
          l10n.insightsEmptyBody,
        ),
      _ => (
          Icons.donut_large_outlined,
          l10n.insightsIdleTitle,
          l10n.insightsIdleBody,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Container(
            width: _markSize,
            height: _markSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              icon,
              size: _iconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
