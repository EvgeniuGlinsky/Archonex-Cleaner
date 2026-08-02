import 'package:storage_cleaner/project_files/features/media_optimizer/data/notices/silent_run_notice.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';

/// A tab has no notification to keep, and nothing to keep it for: the web build
/// runs no optimiser.
RunNotice createRunNotice() => const SilentRunNotice();
