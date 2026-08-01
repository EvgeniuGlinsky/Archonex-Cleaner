import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_encoder_support_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizable_kinds_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/get_optimizer_availability_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/optimize_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/scan_for_media_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_support.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_candidate.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_scan_update.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_report.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_verdict.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/ui/bloc/media_optimizer_bloc.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/add_access_folder_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/get_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/open_access_settings_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/data/use_cases/request_storage_access_use_case.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/access_failure.dart';
import 'package:storage_cleaner/project_files/features/storage_access/domain/models/storage_access.dart';

import '../device_storage/fakes.dart';
import '../storage_access/fakes.dart';
import 'fakes.dart';

/// There is no `bloc_test` here, so nothing else drains the event queue before
/// an assertion reads `bloc.state`.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeMediaScanRepo scanRepo;
  late FakeMediaOptimizeRepo optimizeRepo;
  late FakeStorageAccessRepo accessRepo;
  late FakeDeviceStorageRepo storageRepo;

  setUp(() {
    scanRepo = FakeMediaScanRepo();
    optimizeRepo = FakeMediaOptimizeRepo();
    accessRepo = FakeStorageAccessRepo();
    storageRepo = FakeDeviceStorageRepo();
  });

  MediaOptimizerBloc build() {
    late final MediaOptimizerBloc bloc;

    bloc = MediaOptimizerBloc(
      getAvailability: GetOptimizerAvailabilityUseCase(
        scanRepo: scanRepo,
        optimizeRepo: optimizeRepo,
      ),
      getSupport: GetEncoderSupportUseCase(optimizeRepo),
      getKinds: GetOptimizableKindsUseCase(scanRepo),
      getAccess: GetStorageAccessUseCase(accessRepo),
      requestAccess: RequestStorageAccessUseCase(accessRepo),
      addFolder: AddAccessFolderUseCase(accessRepo),
      openAccessSettings: OpenAccessSettingsUseCase(accessRepo),
      scanForMedia: ScanForMediaUseCase(scanRepo),
      optimizeMedia: OptimizeMediaUseCase(
        repo: optimizeRepo,
        support: () => bloc.state.support,
      ),
      getDeviceStorage: GetDeviceStorageUseCase(storageRepo),
    );

    return bloc;
  }

  Future<MediaOptimizerBloc> started() async {
    final MediaOptimizerBloc bloc = build();
    bloc.add(const MediaOptimizerStarted());
    await settle();

    return bloc;
  }

  Future<MediaOptimizerBloc> scanned() async {
    final MediaOptimizerBloc bloc = await started();
    bloc.add(const MediaScanRequested());
    await settle();

    return bloc;
  }

  group('start', () {
    test('offers a group per kind and reads the encoders', () async {
      final MediaOptimizerBloc bloc = await started();

      expect(
        bloc.state.groups.map((group) => group.kind),
        <MediaKind>[MediaKind.video, MediaKind.photo],
      );
      expect(bloc.state.support.videos, isTrue);
      await bloc.close();
    });

    test('a platform with no reachable media offers nothing', () async {
      scanRepo.isSupported = false;

      final MediaOptimizerBloc bloc = await started();

      expect(bloc.state.isSupported, isFalse);
      expect(bloc.state.canScan, isFalse);
      expect(bloc.state.groups, isEmpty);
      expect(bloc.state.support.hasAny, isFalse);
      await bloc.close();
    });

    test('a machine with no video encoder still opens the screen', () async {
      // The case the whole `EncoderSupport` question exists for: a desktop with
      // no ffmpeg can still walk the disk and say what it found.
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);

      final MediaOptimizerBloc bloc = await started();

      expect(bloc.state.isSupported, isTrue);
      expect(bloc.state.canScan, isTrue);
      expect(bloc.state.support.isPartial, isTrue);
      await bloc.close();
    });
  });

  group('scan', () {
    test('files findings into their kinds and ends scanned', () async {
      scanRepo.updates = <MediaScanUpdate>[
        const MediaLocationChanged(label: 'DCIM'),
        MediaFound(<MediaCandidate>[
          fakeCandidate(
            path: '/dcim/a.mp4',
            kind: MediaKind.video,
            sizeInBytes: 900000000,
            estimatedBytes: 400000000,
          ),
          fakeCandidate(path: '/dcim/b.jpg', sizeInBytes: 9000000),
        ]),
      ];

      final MediaOptimizerBloc bloc = await scanned();

      expect(bloc.state.status, MediaOptimizerStatus.scanned);
      expect(bloc.state.foundCount, 2);
      expect(bloc.state.worthwhileCount, 2);
      expect(bloc.state.estimatedSaving, 500000000 + 6000000);
      await bloc.close();
    });

    test('findings nothing can be done about are kept and not counted',
        () async {
      // The screen shows them with their reason, because "your largest video is
      // 4 GB and here is why nothing can be done" is the answer somebody with a
      // full disk actually needs.
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[
          fakeCandidate(
            path: '/dcim/big.mp4',
            kind: MediaKind.video,
            sizeInBytes: 4000000000,
            verdict: OptimizeVerdict.alreadyEfficient,
          ),
        ]),
      ];

      final MediaOptimizerBloc bloc = await scanned();

      expect(bloc.state.foundCount, 1);
      expect(bloc.state.worthwhileCount, 0);
      expect(bloc.state.hasWorthwhile, isFalse);
      expect(bloc.state.estimatedSaving, 0);
      expect(bloc.state.canOptimize, isFalse);
      await bloc.close();
    });

    test('both kinds are walked, ticked or not', () async {
      final MediaOptimizerBloc bloc = await started();
      bloc.add(const MediaGroupToggled(MediaKind.video));
      await settle();
      bloc.add(const MediaScanRequested());
      await settle();

      // Unticking says "do not rewrite these", not "do not look" — a user who
      // reads the figure and changes their mind must not have to walk again.
      expect(scanRepo.lastRequestedKinds, MediaKind.values.toSet());
      await bloc.close();
    });

    test('a second scan starts from nothing rather than appending', () async {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[fakeCandidate()]),
      ];

      final MediaOptimizerBloc bloc = await scanned();
      bloc.add(const MediaScanRequested());
      await settle();

      expect(scanRepo.scanCount, 2);
      expect(bloc.state.foundCount, 1);
      await bloc.close();
    });

    test('a truncated walk is reported on the kind it stopped in', () async {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[fakeCandidate()]),
        const MediaScanTruncated(kind: MediaKind.photo),
      ];

      final MediaOptimizerBloc bloc = await scanned();

      expect(
        bloc.state.groups
            .firstWhere((group) => group.kind == MediaKind.photo)
            .isTruncated,
        isTrue,
      );
      await bloc.close();
    });

    test('a failed walk goes back to idle and surfaces the failure', () async {
      scanRepo.failure = const MediaScanFailure();

      final MediaOptimizerBloc bloc = await scanned();

      expect(bloc.state.status, MediaOptimizerStatus.idle);
      expect(bloc.state.failure, isA<MediaScanFailure>());
      await bloc.close();
    });

    test('closing the bloc stops a walk that is still running', () async {
      scanRepo.holdOpen = true;

      final MediaOptimizerBloc bloc = await scanned();
      expect(bloc.state.isScanning, isTrue);

      await bloc.close();

      // A walk that opens the header of every file in a camera roll outlives
      // the screen by minutes otherwise.
      expect(scanRepo.wasCancelled, isTrue);
    });
  });

  group('selection', () {
    Future<MediaOptimizerBloc> withBoth() async {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[
          fakeCandidate(
            path: '/a.mp4',
            kind: MediaKind.video,
            sizeInBytes: 900000000,
            estimatedBytes: 400000000,
          ),
          fakeCandidate(
            path: '/b.jpg',
            sizeInBytes: 9000000,
            estimatedBytes: 3000000,
          ),
        ]),
      ];

      return scanned();
    }

    test('everything arrives ticked', () async {
      // Unlike the cleaner, where three categories arrive off because they are
      // occasionally the only copy of something. Nothing is destroyed here.
      final MediaOptimizerBloc bloc = await withBoth();

      expect(bloc.state.selectedCount, 2);
      expect(bloc.state.canOptimize, isTrue);
      await bloc.close();
    });

    test('unticking a kind drops it from the estimate', () async {
      final MediaOptimizerBloc bloc = await withBoth();
      bloc.add(const MediaGroupToggled(MediaKind.video));
      await settle();

      expect(bloc.state.selectedCount, 1);
      expect(bloc.state.estimatedSaving, 6000000);
      await bloc.close();
    });

    test('unticking one row leaves the rest of its kind', () async {
      final MediaOptimizerBloc bloc = await withBoth();
      bloc.add(
        const MediaCandidateToggled(kind: MediaKind.video, path: '/a.mp4'),
      );
      await settle();

      expect(bloc.state.selectedCount, 1);
      expect(
        bloc.state.groups
            .firstWhere((group) => group.kind == MediaKind.video)
            .isPartiallySelected,
        isFalse,
      );
      await bloc.close();
    });

    test('turning a kind off and on again clears its exclusions', () async {
      // A remembered exclusion the row no longer shows is a file the user
      // believes is being left alone and is not.
      final MediaOptimizerBloc bloc = await withBoth();
      bloc.add(
        const MediaCandidateToggled(kind: MediaKind.video, path: '/a.mp4'),
      );
      await settle();
      bloc.add(const MediaGroupToggled(MediaKind.video));
      await settle();
      bloc.add(const MediaGroupToggled(MediaKind.video));
      await settle();

      expect(bloc.state.selectedCount, 2);
      await bloc.close();
    });

    test('a kind with no encoder cannot be optimised even when ticked',
        () async {
      // The button is off rather than failing when pressed.
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);

      final MediaOptimizerBloc bloc = await withBoth();

      expect(bloc.state.canOptimize, isFalse);
      expect(bloc.state.hasBlockedKind, isTrue);

      bloc.add(const MediaGroupToggled(MediaKind.video));
      await settle();

      expect(bloc.state.canOptimize, isTrue);
      await bloc.close();
    });
  });

  group('optimize', () {
    Future<MediaOptimizerBloc> withOne() async {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[
          fakeCandidate(
            path: '/a.jpg',
            sizeInBytes: 9000000,
            estimatedBytes: 3000000,
          ),
        ]),
      ];

      return scanned();
    }

    test('reports what the run did and drops what it rewrote', () async {
      optimizeRepo.report =
          const OptimizeReport(freedBytes: 6000000, optimizedCount: 1);

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(bloc.state.status, MediaOptimizerStatus.optimized);
      expect(bloc.state.report?.freedBytes, 6000000);
      // The row described a file that no longer exists at that size.
      expect(bloc.state.foundCount, 0);
      await bloc.close();
    });

    test('a partial run keeps the rows and unticks them', () async {
      // A row still ticked after a run that skipped it invites a second attempt
      // at exactly the thing that did not work.
      optimizeRepo.report = const OptimizeReport(
        freedBytes: 0,
        optimizedCount: 0,
        skippedCount: 1,
      );

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(bloc.state.foundCount, 1);
      expect(bloc.state.selectedCount, 0);
      await bloc.close();
    });

    test('the disk is read again once a run has finished', () async {
      final int before = storageRepo.readCount;

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(storageRepo.readCount, greaterThan(before + 1));
      await bloc.close();
    });

    test('only the ticked files are handed over', () async {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[
          fakeCandidate(path: '/a.jpg'),
          fakeCandidate(path: '/b.jpg'),
        ]),
      ];

      final MediaOptimizerBloc bloc = await scanned();
      bloc.add(const MediaCandidateToggled(kind: MediaKind.photo, path: '/a.jpg'));
      await settle();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(
        optimizeRepo.lastCandidates?.map((candidate) => candidate.path),
        <String>['/b.jpg'],
      );
      await bloc.close();
    });

    test('closing the bloc stops a run that is still going', () async {
      optimizeRepo.holdOpen = true;

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();
      expect(bloc.state.isOptimizing, isTrue);

      await bloc.close();

      expect(optimizeRepo.wasCancelled, isTrue);
    });

    test('dismissing the result goes back to the findings', () async {
      optimizeRepo.report = const OptimizeReport(
        freedBytes: 0,
        optimizedCount: 0,
        failedCount: 1,
      );

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();
      bloc.add(const OptimizerResultDismissed());
      await settle();

      expect(bloc.state.report, isNull);
      expect(bloc.state.status, MediaOptimizerStatus.scanned);
      await bloc.close();
    });
  });

  group('access', () {
    test('a narrowed device offers nothing to scan until it is widened',
        () async {
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canRequestMore: true,
      );

      final MediaOptimizerBloc bloc = await started();

      expect(bloc.state.canScan, isFalse);
      expect(bloc.state.groups, isEmpty);

      accessRepo.granted = const StorageAccess(level: StorageAccessLevel.full);
      bloc.add(const OptimizerAccessRequested());
      await settle();

      expect(bloc.state.canScan, isTrue);
      expect(bloc.state.groups, hasLength(2));
      await bloc.close();
    });

    test('a refusal with no way back surfaces the failure, wrapped', () async {
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canRequestMore: true,
      );
      accessRepo.granted =
          const StorageAccess(level: StorageAccessLevel.appOnly);

      final MediaOptimizerBloc bloc = await started();
      bloc.add(const OptimizerAccessRequested());
      await settle();

      expect(
        bloc.state.failure,
        isA<OptimizeAccessRefusedFailure>().having(
          (f) => f.cause,
          'cause',
          isA<StorageAccessDeniedFailure>(),
        ),
      );
      await bloc.close();
    });

    test('a picked folder makes the tool usable', () async {
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canAddFolder: true,
      );
      accessRepo.picked = const StorageAccess(
        level: StorageAccessLevel.scopedFolders,
        grantedRoots: <String>['/storage/emulated/0/Trips'],
        canAddFolder: true,
      );

      final MediaOptimizerBloc bloc = await started();
      bloc.add(const OptimizerFolderRequested());
      await settle();

      expect(bloc.state.canScan, isTrue);
      await bloc.close();
    });
  });
}
