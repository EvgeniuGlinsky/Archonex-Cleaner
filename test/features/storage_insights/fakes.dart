import 'dart:async';

import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_scan_job.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/insights_update.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/storage_insights_repo.dart';

/// Hand-written, one file for the feature. There is no mocking package in this
/// project and none is to be added — see `CLAUDE.md`.
class FakeStorageInsightsRepo implements StorageInsightsRepo {
  FakeStorageInsightsRepo({
    this.isSupported = true,
    this.updates = const <InsightsUpdate>[],
    this.failure,
    this.holdOpen = false,
  });

  @override
  bool isSupported;

  /// What the walk reports before it ends.
  List<InsightsUpdate> updates;

  /// Ends the stream with this instead of closing it.
  Object? failure;

  /// Leaves the stream open after the updates, so a test can assert that a
  /// measurement is still running. A job that finished before the assertion
  /// makes "cancel reached it" pass for the wrong reason.
  bool holdOpen;

  bool wasCancelled = false;
  int measureCount = 0;

  @override
  Future<InsightsScanJob> measure(StorageAccess access) async {
    measureCount++;

    return FakeInsightsScanJob(
      updates: updates,
      failure: failure,
      holdOpen: holdOpen,
      onCancel: () => wasCancelled = true,
    );
  }
}

class FakeInsightsScanJob implements InsightsScanJob {
  FakeInsightsScanJob({
    required List<InsightsUpdate> updates,
    Object? failure,
    bool holdOpen = false,
    void Function()? onCancel,
  })  : _updates = updates,
        _failure = failure,
        _holdOpen = holdOpen,
        _onCancel = onCancel {
    _controller = StreamController<InsightsUpdate>(onListen: _start);
  }

  final List<InsightsUpdate> _updates;
  final Object? _failure;
  final bool _holdOpen;
  final void Function()? _onCancel;

  late final StreamController<InsightsUpdate> _controller;

  @override
  Stream<InsightsUpdate> get updates => _controller.stream;

  @override
  Future<void> cancel() async {
    _onCancel?.call();

    if (!_controller.isClosed) {
      _controller.addError(const InsightsScanCancelledFailure());
      await _controller.close();
    }
  }

  /// Nothing is emitted until something listens, exactly as the real job does.
  Future<void> _start() async {
    for (final InsightsUpdate update in _updates) {
      if (_controller.isClosed) {
        return;
      }

      _controller.add(update);
    }

    if (_controller.isClosed) {
      return;
    }

    if (_failure != null) {
      _controller.addError(_failure);
    }

    if (_holdOpen) {
      return;
    }

    await _controller.close();
  }
}
