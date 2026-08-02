import 'package:flutter/foundation.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/notices/android_run_notice.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/notices/silent_run_notice.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';

/// Android alone. `defaultTargetPlatform` rather than a compile-time question,
/// for the reason the io side of every barrel here does it: five platforms
/// compile against `dart:io` and they do not all want the same thing.
RunNotice createRunNotice() {
  return defaultTargetPlatform == TargetPlatform.android
      ? AndroidRunNotice()
      : const SilentRunNotice();
}
