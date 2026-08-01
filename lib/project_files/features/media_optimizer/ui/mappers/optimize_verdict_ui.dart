import 'package:flutter/widgets.dart';

import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';

/// Why a file is being left alone, in a few words.
///
/// Every finding the screen shows and cannot act on carries one of these. A
/// tool that silently dropped them would look, to somebody staring at a full
/// disk and a three-gigabyte video, exactly like a tool that failed to find it.
///
/// `worthIt` has no sentence here on purpose: those rows show a saving instead,
/// which is a better answer than any adjective, and the switch stays exhaustive
/// so a verdict added without copy does not compile.
extension OptimizeVerdictUi on OptimizeVerdict {
  String? reason(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return switch (this) {
      OptimizeVerdict.worthIt => null,
      OptimizeVerdict.alreadyEfficient => l10n.verdictAlreadyEfficient,
      OptimizeVerdict.unreadable => l10n.verdictUnreadable,
      OptimizeVerdict.unsupportedFormat => l10n.verdictUnsupportedFormat,
    };
  }
}
