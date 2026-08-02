import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:storage_cleaner/core/utils/file_size_formatter.dart';
import 'package:storage_cleaner/l10n/app_localizations.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';

/// Keeps the shade in step with the run, and listens for the Stop on it.
///
/// It lives in `MediaOptimizerScope`, above the navigator, and that is the
/// whole design: the user who most needs this notification is the one who left
/// the optimiser screen an hour ago. A listener inside the screen would stop
/// updating the moment they walked away, leaving a progress bar frozen at
/// whatever per cent it happened to be on.
///
/// Being under `Localizations` is the other half of it. Every word the service
/// displays is formatted here and handed across already translated — including
/// on the next update after the user changes the language mid-run, which is
/// why the copy is sent with every step rather than once at the start.
class RunNoticeListener extends StatefulWidget {
  const RunNoticeListener({
    required this.notice,
    required this.child,
    super.key,
  });

  final RunNotice notice;
  final Widget child;

  @override
  State<RunNoticeListener> createState() => _RunNoticeListenerState();
}

class _RunNoticeListenerState extends State<RunNoticeListener> {
  StreamSubscription<void>? _stopRequests;

  @override
  void initState() {
    super.initState();

    _stopRequests = widget.notice.stopRequests.listen((_) {
      if (!mounted) {
        return;
      }

      context.read<MediaOptimizerBloc>().add(const OptimizeCancelled());
    });
  }

  @override
  void dispose() {
    unawaited(_stopRequests?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MediaOptimizerBloc, MediaOptimizerState>(
      // The run starting or stopping, and every step in between. Not every
      // rebuild: a tick of the ring or a tapped checkbox is not news the shade
      // needs, and each one of these crosses a channel.
      listenWhen: (previous, current) =>
          previous.isOptimizing != current.isOptimizing ||
          previous.progress != current.progress,
      listener: _apply,
      child: widget.child,
    );
  }

  void _apply(BuildContext context, MediaOptimizerState state) {
    if (!state.isOptimizing) {
      unawaited(widget.notice.hide());

      return;
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final OptimizeProgress? progress = state.progress;

    unawaited(
      widget.notice.show(
        channelName: l10n.runNoticeChannelName,
        title: l10n.runNoticeTitle,
        // The count and the space freed, not the file name. A path in a
        // notification is truncated to nothing useful, and "12 of 84" is what
        // somebody glancing at a locked phone actually wants to know.
        text: progress == null
            ? l10n.runNoticePreparing
            : l10n.runNoticeBody(
                progress.doneCount,
                progress.totalCount,
                FileSizeFormatter.format(progress.freedBytes),
              ),
        stopLabel: l10n.runNoticeStopLabel,
        progress: state.runProgress,
      ),
    );
  }
}
