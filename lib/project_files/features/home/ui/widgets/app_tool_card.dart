import 'package:flutter/material.dart';

import 'package:storage_cleaner/core/constants/app_radius.dart';
import 'package:storage_cleaner/core/constants/app_spacing.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/home/domain/models/app_tool.dart';
import 'package:storage_cleaner/project_files/features/home/ui/mappers/app_tool_ui.dart';

/// One thing the app can do, as a card big enough to be the answer to "what now".
///
/// A card rather than a list row: the home screen has two entries and no third,
/// and a two-row list reads as the top of a longer one that got cut off.
///
/// The "soon" badge is an overline above the title rather than a chip beside it.
/// The title is set in `titleLarge`, and on a narrow phone a single Russian word
/// — "Оптимизировать" — is wider than what a badge on the same line would leave
/// it: a `Flexible` next to a child that cannot shrink gets whatever is left,
/// which can be nothing. `JunkCategoryTile` carries the same rule and the story
/// of the bug that taught it.
class AppToolCard extends StatelessWidget {
  const AppToolCard({
    required this.tool,
    required this.onPressed,
    super.key,
  });

  static const double _markSize = 52;
  static const double _iconSize = 26;
  static const double _unavailableOpacity = 0.55;
  static const EdgeInsets _badgePadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);

  final AppTool tool;

  /// `null` disables the card. The caller decides, so a tool that is not
  /// available cannot be handed a handler that quietly does nothing.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : _unavailableOpacity,
      child: Card(
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: <Widget>[
                _Mark(icon: tool.icon, isEnabled: isEnabled),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (!isEnabled) ...<Widget>[
                        _SoonBadge(label: l10n.toolComingSoonBadge),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        tool.title(context),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tool.subtitle(context),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isEnabled) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.isEnabled});

  final IconData icon;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: AppToolCard._markSize,
      height: AppToolCard._markSize,
      decoration: BoxDecoration(
        color: isEnabled
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        size: AppToolCard._iconSize,
        color: isEnabled ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: AppToolCard._badgePadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
