import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/core/theme/app_typography.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/ui/mappers/storage_slice_ui.dart';

/// One category, named, measured and drawn as a share of the disk.
///
/// The bar is the legend. There is no separate swatch column, because the bar
/// is already the colour and already the length — a swatch beside it would be
/// the same fact twice. Every row carries its name and its size in text, which
/// is what makes the palette's tritan pair legal at all: identity is never
/// colour alone here, and the ring above can be read by working down this list.
class StorageSliceRow extends StatelessWidget {
  const StorageSliceRow({
    required this.slice,
    required this.fraction,
    super.key,
  });

  static const double _barHeight = 6;

  /// What the size figure may take from the line it shares. "465.1 GB" is about
  /// 72 on a device; the rest is the name's, which is the same arithmetic
  /// `JunkCategoryTile` writes out in full.
  static const double _figureWidth = 84;

  final StorageSlice slice;

  /// `0`–`1` of the whole volume. The bar's length, and the percentage.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Color colour = slice.category.colour(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  slice.category.title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Text ink, never the series colour. The bar underneath is
                  // what carries identity.
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _figureWidth),
                child: Text(
                  FileSizeFormatter.format(slice.bytes),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(child: _Bar(fraction: fraction, colour: colour)),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: _percentWidth,
                child: Text(
                  l10n.insightsSharePercent(_percent),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const double _percentWidth = 38;

  /// Whole per cent, and never a rounded-down nought for something that is
  /// there: a row drawn at all has bytes in it, and "0%" beside a figure of
  /// 40 MB reads as a bug rather than as a small number.
  String get _percent {
    final int whole = (fraction * 100).round();

    return whole == 0 ? '<1' : '$whole';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.colour});

  final double fraction;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: LinearProgressIndicator(
        value: fraction.isNaN ? 0 : fraction.clamp(0.0, 1.0),
        minHeight: StorageSliceRow._barHeight,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(colour),
      ),
    );
  }
}
