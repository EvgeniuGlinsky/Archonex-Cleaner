import 'package:flutter/material.dart';

import 'package:archonex_cleaner/core/utils/file_size_formatter.dart';
import 'package:archonex_cleaner/l10n/app_localizations.dart';

/// What the ring above it is made of: how much is ticked, out of how much there
/// was.
///
/// It used to carry the freed figure in display type and be a card of its own.
/// The ring took the figure — one number, once, in the place the eye lands — and
/// what was left was a card containing a sentence, so it stopped being a card.
class ScanSummaryLine extends StatelessWidget {
  const ScanSummaryLine({
    required this.foundBytes,
    required this.selectedCount,
    super.key,
  });

  final int foundBytes;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Text(
      '${l10n.selectedSummary(l10n.fileCount(selectedCount))}'
      ' · ${l10n.foundSummary(FileSizeFormatter.format(foundBytes))}',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium,
    );
  }
}
