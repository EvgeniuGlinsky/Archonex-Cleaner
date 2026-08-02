import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';

/// The notice on every platform that does not need one.
///
/// Named for what it does rather than `Unsupported…`, on the rule the Platform
/// boundaries section of the skill sets out: a sibling that genuinely works in
/// a reduced way is not a refusal. A desktop does not freeze a process because
/// its window went behind another one, and an iPhone runs no optimiser at all,
/// so having nothing to show is the correct answer there rather than a missing
/// feature.
///
/// The stream is `Stream.empty()` rather than a controller: nobody will ever
/// press a button that was never drawn, and a controller would be one more
/// thing to close.
class SilentRunNotice implements RunNotice {
  const SilentRunNotice();

  @override
  Stream<void> get stopRequests => const Stream<void>.empty();

  @override
  Future<void> show({
    required String channelName,
    required String title,
    required String text,
    required String stopLabel,
    double? progress,
  }) async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> dispose() async {}
}
