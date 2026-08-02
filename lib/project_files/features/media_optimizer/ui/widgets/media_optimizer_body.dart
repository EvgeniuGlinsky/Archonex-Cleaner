import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/ui/widgets/storage_ring.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_group.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/encoder_notice.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/media_group_tile.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/media_optimizer_callbacks.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/widgets/optimize_result_card.dart';
import 'package:storage_cleaner/project_files/features/storage_access/ui/widgets/storage_access_notice.dart';

/// State and callbacks in, one column out. No `flutter_bloc`, no `go_router`.
///
/// A `Column` and not a `ListView`, for the reason `StorageCleanerBody` gives:
/// `AppScreenLayout` owns the screen's only scroll view.
class MediaOptimizerBody extends StatelessWidget {
  const MediaOptimizerBody({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final MediaOptimizerState state;
  final MediaOptimizerCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final List<MediaGroup> groups = state.visibleGroups;

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
        if (state.hasRing) ...<Widget>[
          _Ring(state: state),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.hasBlockedKind) ...<Widget>[
          const EncoderNotice(),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (state.report != null) ...<Widget>[
          OptimizeResultCard(
            report: state.report!,
            onDismissed: callbacks.onResultDismissed,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        // Above the rows rather than instead of them. A device whose video is
        // all already efficient needs both halves of the answer: the sentence
        // saying why the button is off, and the four gigabytes of files it is
        // talking about, each with its own reason — which is what
        // `MediaCandidate` keeps refusals in the list for.
        if (state.hasNothingToDo) ...<Widget>[
          _EmptyState(state: state),
          if (groups.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        ],
        ...groups.map(
          (group) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: MediaGroupTile(
              group: group,
              canEdit: state.canEditSelection,
              onToggled: () => callbacks.onGroupToggled(group.kind),
              onCandidateToggled: (path) => callbacks.onCandidateToggled(
                ToggledCandidate(kind: group.kind, path: path),
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
/// Before a scan it is the disk. During one it is what has been found so far.
/// After one it is what the ticked files would give back — the figure the
/// button underneath names, so the two are always the same number.
///
/// The highlighted arc is the *saving* rather than the size of the files, which
/// is where this parts company with the cleaner's ring: the cleaner's files are
/// leaving, so their whole size is the answer, and these are staying and only
/// getting lighter.
class _Ring extends StatelessWidget {
  const _Ring({required this.state});

  final MediaOptimizerState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final (String title, String caption) = switch (state) {
      MediaOptimizerState(isScanning: true) => (
          FileSizeFormatter.format(state.estimatedSaving),
          l10n.scanningLabel,
        ),
      MediaOptimizerState(hasWorthwhile: true) => (
          FileSizeFormatter.format(state.estimatedSaving),
          l10n.couldBeSaved,
        ),
      MediaOptimizerState(storage: final storage?) => (
          FileSizeFormatter.format(storage.usedBytes),
          l10n.storageUsedOf(FileSizeFormatter.format(storage.totalBytes)),
        ),
      // Only reachable while a walk that found nothing actionable is still
      // finishing — `hasRing` keeps the widget out of the tree otherwise.
      _ => (FileSizeFormatter.format(0), l10n.couldBeSaved),
    };

    return StorageRing(
      usedFraction: state.usedFraction,
      junkFraction: state.savingFraction,
      title: title,
      caption: caption,
      isBusy: state.isScanning,
    );
  }
}

/// Four different nothings, told apart.
///
/// "This platform cannot", "you have not looked yet", "there is nothing here"
/// and "everything here is already as small as it goes" are four sentences, and
/// the last is the one a naive version of this screen gets wrong: a device full
/// of efficiently-encoded video is not a device with no video on it.
///
/// It got it wrong here too, for a while. Drawing this only when there were no
/// groups meant the fourth branch could not be reached — an already-efficient
/// device has groups, they are simply full of rows nothing can be done with.
/// `MediaOptimizerState.hasNothingToDo` is the question that distinguishes
/// them, and this widget asks it rather than working it out from the list.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});

  static const double _iconSize = 48;
  static const double _markSize = 88;

  final MediaOptimizerState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final (IconData icon, String title, String body) = switch (state) {
      MediaOptimizerState(isSupported: false) => (
          Icons.block_outlined,
          l10n.optimizerUnsupportedTitle,
          l10n.optimizerUnsupportedBody,
        ),
      // Before "already efficient", which would otherwise swallow it: a walk
      // that turned up nothing at all also has nothing worthwhile in it, and
      // the two are completely different pieces of news.
      MediaOptimizerState(hasScanned: true, hasFindings: false) => (
          Icons.search_off_outlined,
          l10n.optimizerFoundNothingTitle,
          l10n.optimizerFoundNothingBody,
        ),
      MediaOptimizerState(hasScanned: true) => (
          Icons.verified_outlined,
          l10n.optimizerNothingToDoTitle,
          l10n.optimizerNothingToDoBody,
        ),
      _ => (
          Icons.compress_rounded,
          l10n.optimizerIdleTitle,
          l10n.optimizerIdleBody,
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
