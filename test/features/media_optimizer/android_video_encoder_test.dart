import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/android_video_encoder.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

import 'fakes.dart';

/// The one encoder driven directly rather than through its `MediaEncoder`
/// interface, because what is under test is the seam itself: how the Dart side
/// behaves when the platform channel answers badly, or is not there at all.
///
/// `flutter test` registers no channels, so `MissingPluginException` is not a
/// case that has to be simulated here — it is the default. That is the same
/// thing another platform's build sees, and it is why the rule in `CLAUDE.md`
/// is that this exception is answered as "no" rather than raised.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MediaCandidate candidate = fakeCandidate(
    path: '/storage/emulated/0/DCIM/Camera/VID_0001.mp4',
    kind: MediaKind.video,
    sizeInBytes: 400 * 1024 * 1024,
  );

  group('when the channel is not registered at all', () {
    test('availability is answered as no, not raised', () async {
      expect(await AndroidVideoEncoder().isAvailable, isFalse);
    });

    // Reached from `MediaOptimizerBloc.close()`, which runs while the screen is
    // being torn down — there is nothing above it left to catch anything. This
    // caught only `PlatformException`, and its sibling three methods up caught
    // both.
    test('cancelling is silent rather than throwing into dispose', () async {
      await expectLater(AndroidVideoEncoder().cancel(), completes);
    });
  });

  group('when the transcode fails', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('io.github.evgeniuglinsky.storagecleaner/transcoder'),
        (call) async {
          calls.add(call);

          if (call.method == 'transcode') {
            throw PlatformException(code: 'encode_failed');
          }

          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('io.github.evgeniuglinsky.storagecleaner/transcoder'),
        null,
      );
    });

    test('the failure arrives through the stream', () async {
      final Stream<double> encode = AndroidVideoEncoder().encode(
        candidate: candidate,
        outputPath: '/storage/emulated/0/DCIM/Camera/.working-VID_0001.mp4',
      );

      await expectLater(encode, emitsError(isA<PlatformException>()));
      expect(calls.single.method, 'transcode');
    });

    // Cancelling is the consumer that never reaches `await transcode`, which is
    // why the failure is put onto the stream instead of left on the future.
    //
    // What this asserts is that cancelling is clean and does not hang — not
    // that no error escapes to the zone, which was tried and could not be made
    // to discriminate: `setMockMethodCallHandler` completes its futures in the
    // zone that registered the handler, so a `runZonedGuarded` inside the test
    // body never sees them, and the check passed with the fix reverted. A test
    // that cannot fail is worse than no test, so it is not here.
    test('a consumer that stops listening leaves nothing hanging', () async {
      final StreamSubscription<double> subscription =
          AndroidVideoEncoder().encode(
        candidate: candidate,
        outputPath: '/storage/emulated/0/DCIM/Camera/.working-VID_0001.mp4',
      ).listen(null, onError: (Object _) {});

      await expectLater(subscription.cancel(), completes);
    });
  });
}
