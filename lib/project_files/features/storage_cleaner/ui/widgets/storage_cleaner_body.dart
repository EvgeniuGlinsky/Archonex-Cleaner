import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/constants/app_spacing.dart';
import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';
import 'package:archonex_cleaner/project_files/features/device_storage/ui/widgets/storage_ring.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_group.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/bloc/storage_cleaner_bloc.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/mappers/storage_access_ui.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/clean_result_card.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/junk_category_tile.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/quarantine_banner.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/scan_summary_line.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/storage_access_notice.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/ui/widgets/storage_cleaner_callbacks.dart';

/// State and callbacks in, one scrolling column out.
///
/// It knows nothing about where the state came from: no `flutter_bloc` import,
/// no `go_router`, which is what lets a widget test drive it with a literal.
class StorageCleanerBody extends StatelessWidget {
  const StorageCleanerBody({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final StorageCleanerState state;
  final StorageCleanerCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final List<JunkGroup> groups = state.visibleGroups;

    return ListView(
      children: <Widget>[
        if (state.hasQuarantine) ...<Widget>[
          QuarantineBanner(
            fileCount: state.quarantinedFileCount,
            onPressed: callbacks.onQuarantinePressed,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.access.isNarrowed) ...<Widget>[
          StorageAccessNotice(
            access: state.access,
            onGrantPressed: callbacks.onGrantAccessPressed,
            onAddFolderPressed: callbacks.onAddFolderPressed,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.hasRing) ...<Widget>[
          _Ring(state: state),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.hasFindings) ...<Widget>[
          ScanSummaryLine(
            foundBytes: state.foundBytes,
            selectedCount: state.selectedCount,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (state.report != null) ...<Widget>[
          CleanResultCard(
            report: state.report!,
            onQuarantinePressed: callbacks.onQuarantinePressed,
            onDismissed: callbacks.onResultDismissed,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (groups.isEmpty)
          _EmptyState(state: state)
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: JunkCategoryTile(
                group: group,
                canEdit: state.canEditSelection,
                onToggled: () => callbacks.onCategoryToggled(group.category),
                onItemToggled: (path) => callbacks.onItemToggled(
                  ToggledItem(category: group.category, path: path),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The ring, saying three different things at three moments.
///
/// Before a scan it is the disk: the figure the user would have gone to the
/// system settings for. During one it is what has been found so far, growing.
/// After one it is what is ticked — the amount the button underneath will free,
/// so the number in the ring and the number on the button are always the same
/// number.
class _Ring extends StatelessWidget {
  const _Ring({required this.state});

  final StorageCleanerState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final (String title, String caption) = switch (state) {
      StorageCleanerState(isScanning: true) => (
          FileSizeFormatter.format(state.foundBytes),
          l10n.scanningLabel,
        ),
      StorageCleanerState(hasFindings: true) => (
          FileSizeFormatter.format(state.selectedBytes),
          l10n.readyToClean,
        ),
      StorageCleanerState(storage: final storage?) => (
          FileSizeFormatter.format(storage.usedBytes),
          l10n.storageUsedOf(FileSizeFormatter.format(storage.totalBytes)),
        ),
      // Only reachable while a scan that found nothing is still finishing —
      // `hasRing` keeps the widget out of the tree otherwise.
      _ => (FileSizeFormatter.format(0), l10n.readyToClean),
    };

    return StorageRing(
      usedFraction: state.usedFraction,
      junkFraction: state.selectedFraction,
      title: title,
      caption: caption,
      isBusy: state.isScanning,
    );
  }
}

/// Three different nothings, told apart.
///
/// "This platform cannot", "you have not scanned yet" and "there is nothing
/// here" all draw an empty list, and a single message for all three would be
/// wrong twice.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  static const double _iconSize = 48;
  static const double _markSize = 88;

  final StorageCleanerState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final (String title, String body, IconData icon) = switch (state) {
      // Through the mapper rather than the ARB keys directly, so there is one
      // sentence about an unsupported platform and not two that can drift.
      StorageCleanerState(isSupported: false) => (
          state.access.title(context),
          state.access.body(context),
          Icons.block_outlined,
        ),
      StorageCleanerState(hasScanned: true) => (
          l10n.emptyScanTitle,
          l10n.emptyScanBody,
          Icons.check_circle_outline,
        ),
      _ => (
          l10n.notScannedTitle,
          l10n.notScannedBody,
          Icons.search_outlined,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
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
