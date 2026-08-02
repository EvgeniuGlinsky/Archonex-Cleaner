import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/device_storage/domain/models/device_storage_snapshot.dart';
import 'package:storage_cleaner/project_files/features/device_storage/ui/widgets/storage_ring.dart';
import 'package:storage_cleaner/project_files/features/home/ui/bloc/home_bloc.dart';
import 'package:storage_cleaner/project_files/features/home/ui/widgets/app_tool_card.dart';
import 'package:storage_cleaner/project_files/features/home/ui/widgets/home_callbacks.dart';

/// State and callbacks in, one column out.
///
/// No `flutter_bloc` import and no `go_router`, so a widget test can drive it
/// with a literal state — the same rule `StorageCleanerBody` follows, along
/// with the reason it is a `Column` rather than a list of its own.
class HomeBody extends StatelessWidget {
  const HomeBody({
    required this.state,
    required this.callbacks,
    super.key,
  });

  final HomeState state;
  final HomeCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final DeviceStorageSnapshot? storage = state.storage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Absent rather than zeroed where the platform cannot measure the disk.
        // A ring at nought would read as an empty device, which is the one thing
        // it is certainly not saying.
        if (storage != null) ...<Widget>[
          _Ring(storage: storage),
          const SizedBox(height: AppSpacing.xxl),
        ],
        ...state.tools.map(
          (tool) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: AppToolCard(
              tool: tool,
              onPressed:
                  tool.isAvailable ? () => callbacks.onToolPressed(tool) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.storage});

  final DeviceStorageSnapshot storage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return StorageRing(
      usedFraction: storage.usedFraction,
      title: FileSizeFormatter.format(storage.usedBytes),
      caption: l10n.storageUsedOf(
        FileSizeFormatter.format(storage.totalBytes),
      ),
    );
  }
}
