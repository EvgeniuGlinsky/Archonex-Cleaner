import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/device_storage/data/use_cases/get_device_storage_use_case.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/use_cases/fetch_encoder_use_case.dart';
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
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_quality.dart';
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
  late FakeOptimizeQualityRepo qualityRepo;
  late FakeEncoderSupplyRepo supplyRepo;

  setUp(() {
    scanRepo = FakeMediaScanRepo();
    optimizeRepo = FakeMediaOptimizeRepo();
    accessRepo = FakeStorageAccessRepo();
    storageRepo = FakeDeviceStorageRepo();
    qualityRepo = FakeOptimizeQualityRepo();
    supplyRepo = FakeEncoderSupplyRepo();
  });

  MediaOptimizerBloc build() {
    late final MediaOptimizerBloc bloc;

    bloc = MediaOptimizerBloc(
      getAvailability: GetOptimizerAvailabilityUseCase(
        scanRepo: scanRepo,
        optimizeRepo: optimizeRepo,
      ),
      getSupport: GetEncoderSupportUseCase(optimizeRepo),
      fetchEncoder: FetchEncoderUseCase(supplyRepo),
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
      quality: qualityRepo,
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

  /// One video and one photograph, both worth re-encoding.
  void findsBoth() {
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
  }

  /// Drains the event queue until [done], rather than counting `settle()`s.
  ///
  /// A fetch is several turns deep — the job's own stream, `emit.forEach`, and
  /// then a re-ask of the encoders — and a test that guessed how many would pass
  /// or fail on a refactor that changed the count by one.
  Future<void> pumpUntil(bool Function() done, {int turns = 400}) async {
    for (int turn = 0; turn < turns && !done(); turn++) {
      await settle();
    }
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

  group('coming back to the screen', () {
    setUp(() {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[fakeCandidate()]),
      ];
    });

    test('keeps the findings when nothing about the access moved', () async {
      // The bloc outlives the screen now, and this is the reason it was worth
      // doing: a user who walks their camera roll, steps back to the home
      // screen and returns should find the list they were reading.
      final MediaOptimizerBloc bloc = await scanned();
      final int found = bloc.state.groups
          .fold<int>(0, (sum, group) => sum + group.totalCount);

      bloc.add(const MediaOptimizerResumed());
      await settle();

      expect(
        bloc.state.groups.fold<int>(0, (sum, g) => sum + g.totalCount),
        found,
      );
      expect(found, greaterThan(0));
      await bloc.close();
    });

    test('drops them when the access was revoked while away', () async {
      // All-files access can be taken back from Settings, and a list measured
      // under the old one is a list nobody can reason about.
      final MediaOptimizerBloc bloc = await scanned();

      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canAddFolder: true,
      );
      scanRepo.kinds = const <MediaKind>{};

      bloc.add(const MediaOptimizerResumed());
      await settle();

      expect(bloc.state.groups, isEmpty);
      await bloc.close();
    });

    test('leaves a run that is still going completely alone', () async {
      optimizeRepo.holdOpen = true;

      final MediaOptimizerBloc bloc = await scanned();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(bloc.state.isOptimizing, isTrue);

      // Even a revoked access must not interrupt it. The files it is partway
      // through rewriting are on disk either way, and the report is owed.
      accessRepo.access = const StorageAccess(
        level: StorageAccessLevel.appOnly,
        canAddFolder: true,
      );

      bloc.add(const MediaOptimizerResumed());
      await settle();

      expect(bloc.state.isOptimizing, isTrue);
      expect(bloc.state.groups, isNotEmpty);
      await bloc.close();
    });
  });

  group('the quality preset', () {
    setUp(() {
      scanRepo.updates = <MediaScanUpdate>[
        MediaFound(<MediaCandidate>[fakeCandidate()]),
      ];
    });

    test('the one chosen on an earlier run is in force before the first walk',
        () async {
      qualityRepo.stored = OptimizeQuality.maximum;

      final MediaOptimizerBloc bloc = await scanned();

      expect(bloc.state.quality, OptimizeQuality.maximum);
      expect(scanRepo.lastRequestedQuality, OptimizeQuality.maximum);
      await bloc.close();
    });

    test('changing it re-measures without walking again', () async {
      final MediaOptimizerBloc bloc = await scanned();
      final int scans = scanRepo.scanCount;

      bloc.add(const OptimizeQualityChanged(OptimizeQuality.maximum));
      await settle();

      expect(bloc.state.quality, OptimizeQuality.maximum);
      expect(scanRepo.scanCount, scans, reason: 'the disk was walked again');
      expect(qualityRepo.stored, OptimizeQuality.maximum);
      await bloc.close();
    });

    test('and is refused outright while a run is going', () async {
      // The files in flight were planned under the old preset and the encoder
      // has already been told the old target.
      optimizeRepo.holdOpen = true;

      final MediaOptimizerBloc bloc = await scanned();
      bloc.add(const OptimizeRequested());
      await settle();

      bloc.add(const OptimizeQualityChanged(OptimizeQuality.maximum));
      await settle();

      expect(bloc.state.quality, OptimizeQuality.balanced);
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

    test('a kind with no encoder arrives unticked and holds nothing else back',
        () async {
      // It used to arrive ticked, and `canOptimize` wants an encoder for every
      // ticked group — so a desktop with no `ffmpeg` that found photographs
      // *and* video had the button off for both, including the one kind it could
      // have re-encoded. Unticking the video by hand was the only way through,
      // on a screen that never said so.
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);

      final MediaOptimizerBloc bloc = await withBoth();

      expect(bloc.state.hasBlockedKind, isTrue);
      expect(bloc.state.canOptimize, isTrue);

      // And the figure the button names is the photographs alone, because the
      // video is not going anywhere.
      expect(
        bloc.state.selectedCandidates.every((c) => c.path.endsWith('.jpg')),
        isTrue,
      );

      // Ticking it back on is refused rather than obeyed: the box is drawn
      // disabled for the same reason, and both ask `canEditGroup`.
      bloc.add(const MediaGroupToggled(MediaKind.video));
      await settle();

      expect(bloc.state.canOptimize, isTrue);
      expect(
        bloc.state.groups
            .firstWhere((group) => group.kind == MediaKind.video)
            .isSelected,
        isFalse,
      );
      await bloc.close();
    });
  });

  group('fetching the encoder', () {
    test('a desktop with no video encoder is offered one', () async {
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);

      final MediaOptimizerBloc bloc = build()..add(const MediaOptimizerStarted());
      await settle();

      expect(bloc.state.canFetchEncoder, isTrue);
      expect(bloc.state.encoderDownloadBytes, greaterThan(0));
      await bloc.close();
    });

    test('a machine that already encodes video is offered nothing', () async {
      // Otherwise a user with `ffmpeg` on their path is invited to download a
      // second copy of it.
      final MediaOptimizerBloc bloc = build()..add(const MediaOptimizerStarted());
      await settle();

      expect(bloc.state.canFetchEncoder, isFalse);
      await bloc.close();
    });

    test('a phone is offered nothing, because there is nothing to fetch',
        () async {
      supplyRepo.isSupported = false;
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);

      final MediaOptimizerBloc bloc = build()..add(const MediaOptimizerStarted());
      await settle();

      expect(bloc.state.canFetchEncoder, isFalse);
      expect(bloc.state.hasBlockedKind, isTrue, reason: 'and it says so');
      await bloc.close();
    });

    test('a fetch reports progress, then the screen can encode video',
        () async {
      // The whole mechanism in one test: the encoder object caches only a *yes*,
      // so re-asking after the download finds the new binary — with no wiring
      // between the thing that downloads and the thing that runs.
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);
      supplyRepo.installsEncoder = () => optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: true);
      findsBoth();

      final MediaOptimizerBloc bloc = await scanned();
      final List<double?> seen = <double?>[];
      final StreamSubscription<MediaOptimizerState> watch = bloc.stream
          .listen((state) => seen.add(state.encoderFetchProgress));

      bloc.add(const EncoderFetchRequested());
      await pumpUntil(() => !bloc.state.isFetchingEncoder && bloc.state.support.videos);

      expect(supplyRepo.fetchCount, 1);
      expect(seen.where((f) => f != null && f > 0), isNotEmpty);
      expect(bloc.state.support.videos, isTrue);
      expect(bloc.state.canFetchEncoder, isFalse);
      expect(bloc.state.hasBlockedKind, isFalse);

      // And the kind this app unticked itself is ticked again, which is what the
      // button was pressed for.
      expect(
        bloc.state.groups
            .firstWhere((group) => group.kind == MediaKind.video)
            .isSelected,
        isTrue,
      );

      await watch.cancel();
      await bloc.close();
    });

    test('a fetch leaves a kind the user unticked by hand unticked', () async {
      // "Unticked and now supported" also describes photographs the user just
      // turned off, and re-ticking those would overrule the one choice the
      // screen exists to offer.
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);
      supplyRepo.installsEncoder = () => optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: true);
      findsBoth();

      final MediaOptimizerBloc bloc = await scanned();
      bloc.add(const MediaGroupToggled(MediaKind.photo));
      await settle();

      bloc.add(const EncoderFetchRequested());
      await pumpUntil(() => !bloc.state.isFetchingEncoder && bloc.state.support.videos);

      expect(
        bloc.state.groups
            .firstWhere((group) => group.kind == MediaKind.photo)
            .isSelected,
        isFalse,
      );
      await bloc.close();
    });

    test('a failed fetch says so and offers the download again', () async {
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);
      supplyRepo.failure = const EncoderFetchFailure();

      final MediaOptimizerBloc bloc = build()..add(const MediaOptimizerStarted());
      await settle();

      bloc.add(const EncoderFetchRequested());
      await pumpUntil(() => bloc.state.failure != null);

      expect(bloc.state.failure, isA<EncoderFetchFailure>());
      expect(bloc.state.isFetchingEncoder, isFalse);
      expect(bloc.state.canFetchEncoder, isTrue);
      await bloc.close();
    });

    test('a cancelled fetch is not news', () async {
      // The user did it. A snack bar saying what they just asked for is noise.
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);
      supplyRepo.holdOpen = true;

      final MediaOptimizerBloc bloc = build()..add(const MediaOptimizerStarted());
      await settle();

      bloc.add(const EncoderFetchRequested());
      await pumpUntil(() => bloc.state.isFetchingEncoder);

      bloc.add(const EncoderFetchCancelled());
      await pumpUntil(() => !bloc.state.isFetchingEncoder);

      expect(supplyRepo.wasCancelled, isTrue);
      expect(bloc.state.failure, isNull);
      expect(bloc.state.canFetchEncoder, isTrue);
      await bloc.close();
    });

    test('closing the bloc stops a download nobody is watching', () async {
      optimizeRepo.encoderSupport =
          const EncoderSupport(photos: true, videos: false);
      supplyRepo.holdOpen = true;

      final MediaOptimizerBloc bloc = build()..add(const MediaOptimizerStarted());
      await settle();

      bloc.add(const EncoderFetchRequested());
      await pumpUntil(() => bloc.state.isFetchingEncoder);

      await bloc.close();

      expect(supplyRepo.wasCancelled, isTrue);
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

    // Worse here than on the cleaner: there is no quarantine on this path, so
    // everything already rewritten is gone for good. It used to raise
    // `MediaScanFailure`, whose sentence ends "Nothing was changed".
    test('a run that breaks partway is not reported as a failed search',
        () async {
      optimizeRepo.failure = const OptimizeRunFailure();

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(bloc.state.failure, isA<OptimizeRunFailure>());
      expect(bloc.state.failure, isNot(isA<MediaScanFailure>()));
      await bloc.close();
    });

    test('an unrecognised error from a run is a run failure, not a scan one',
        () async {
      optimizeRepo.failure = Exception('the encoder died mid-file');

      final MediaOptimizerBloc bloc = await withOne();
      bloc.add(const OptimizeRequested());
      await settle();

      expect(bloc.state.failure, isA<OptimizeRunFailure>());
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
