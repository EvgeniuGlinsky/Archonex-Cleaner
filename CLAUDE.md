## Localization (i18n)

- **Add a string**: add the key to every ARB file in `lib/l10n/` (`app_en.arb` is the template, one file per `AppLanguage`) and run `flutter gen-l10n`; generated `app_localizations*.dart` are gitignored — never hand-edit.
- **Use it**: `AppLocalizations.of(context)!.someKey` — no hardcoded copy anywhere, including domain models. Nothing checks parity for you: a key added to `app_en.arb` alone compiles, passes every test, and ships English to a Russian user.

## Failures

- **Add one**: `final class <Reason>Failure extends CleanFailure` in `storage_cleaner/domain/models/clean_failure.dart`, carrying numbers and paths for interpolation and never a sentence — a `String message` field compiles quietly and puts user-facing copy in the domain layer. Restoring has a hierarchy of its own, `RestoreFailure` in `quarantine/domain/models/`, because the cleaner depends on the quarantine and a sealed class can only be extended in its own library: two hierarchies keep the arrow pointing one way.
- **Reach another hierarchy**: one member that *wraps* it, never members that restate it. `AccessRefusedFailure` holds an `AccessFailure` and `CleanFailureUi` delegates to `AccessFailureUi`, because two tools ask `storage_access` the same question and copying its members into each would be two sealed lists to keep in step and two translations to drift apart. The wrapper is what keeps the arrow pointing one way while the state keeps a single nullable failure slot — a second slot beside it means a second listener, a second dismissal, and a screen that can show one notice while hiding another.
- **Use it**: a `FileSystemException` becomes a failure only in `data/`, because that is the only layer that knows what the OS actually refused. An outcome the report already carries stays out of the hierarchy — a locked file is `CleanReport.skippedCount`, not a failure, and a file too large to quarantine is `permanentCount`; adding either as a `CleanFailure` would mean two places saying the same number and a mapper for copy nobody reads.

## Protected paths

- **Add one**: a root in `ProtectedPaths._<platform>`, never a check at a call site. It takes a `p.Context` and a `CleanerRoots` rather than reading `Platform`, which is what lets every platform's answers be tested from whichever one CI runs on. A narrower path that must stay deletable inside a protected root goes in the platform's `_exceptions` list as a *directory* — `DCIM/.thumbnails`, the app's own cache under Android's `/data` — never as a pattern, and never by leaving the parent unprotected and trusting future rules to be narrow.
- **Use it**: the guard runs on every finding, after the rule has already called it junk. The two lists are deliberately not the same list — a mistake in one is caught by the other — and `protected_paths_test.dart` is the file to grow when anything here changes. It has already caught a real bug this way.

## Scan and clean jobs

- **Add one**: the job class is private, sits next to its repository and is built on `StreamController(onListen: _start)`, so the work begins on the first listener — a plain `StreamController()` starts crawling the disk the moment the use case returns, for a screen the user may have already left. Findings are flushed in batches (`AppCleanPolicy.foundBatchSize`, plus a timer for the tail), because one event per file is one bloc rebuild per file and a Windows `%TEMP%` holds tens of thousands.
- **Use it**: the two jobs end differently on purpose. A cancelled **scan** ends the stream with `ScanCancelledFailure` and hands over nothing — nothing was deleted, so there is nothing to report. A cancelled **clean** emits `CleanFinished` and closes normally, with `CleanReport.wasCancelled` set, because files are already gone and the count is owed to the user. The BLoC consumes with `emit.forEach`, holds `_activeScan`/`_activeClean` and cancels both in `close()`, or a walk outlives the screen that started it by minutes.

## Quarantine

- **Add one**: anything that moves a file aside goes through `QuarantineWriter`, opened per run by `QuarantineRepo.openBatch()`. The deleter offers each file and the writer answers whether it took it; a `false` means the caller deletes outright, and the report counts that separately.
- **Use it**: files are **moved, never copied** — a copy frees no space, and freeing space is what the button was pressed for, so a cross-volume `rename` throwing is the answer rather than a problem to work around. The index is a `manifest.json` beside the files, not `shared_preferences`: a wiped or restored preference store would orphan the files on disk. A restore checks every destination for occupancy before moving anything, because half a restore leaves the user not knowing which files came back.

## Platform boundaries

- **Add one**: `data/platform/<feature>_platform.dart` holding only a conditional export — `export '<feature>_platform_web.dart' if (dart.library.io) '<feature>_platform_io.dart';` — one file per side declaring the same factories, and beside every real implementation in `file_system/` or `access/` a refusing sibling the excluded side returns instead: `unsupported_<x>_repo.dart`, never in `platform/`. A sibling that genuinely works in a reduced way is named for what it does rather than `unsupported_`: `EmptyQuarantineRepo` answers every call benignly, because a quarantine on a platform that deletes nothing is correctly empty rather than broken.
- **Use it**: call the factory — `Platform.is*`, `kIsWeb` and `String.fromEnvironment` never appear in a widget or a BLoC, because a compile-time question asked at the call site breaks the web build, which no CI job builds. Inside the io side, `defaultTargetPlatform` is fair game and necessary: five platforms compile against `dart:io` and need different access repositories, and that is a runtime question. A refusal reports `isSupported => false` and errors its job's stream with `CleanUnsupportedFailure`, so the screen explains itself instead of scanning nothing and calling the device clean.

## Bloc state

- **Add one**: every question a widget asks about a state is a getter on the state class — `canScan`, `canClean`, `isBusy`, `selectedBytes`, `visibleGroups` — computed from the fields and never stored. Any `copyWith`, on a state or on a domain model, clears a nullable field through an explicit `bool clearX = false`, because `null` in that signature already means "leave it alone" and cannot also mean "unset it".
- **Use it**: widgets read `state.canX` and derive nothing, because two widgets deriving one condition separately is how a button ends up enabled while the handler refuses. `props` lists every field: leave one out and the screen never rebuilds when it changes, which no lint and no compiler will tell you. A model held in state needs value equality too — `CleanProgress` mixes in `Equatable` for exactly that reason.

## Selection

- **Add one**: a user's decision about a row is stored as an *exclusion* on the group, never as a selection. A scan that is still finding files while the user unticks rows would otherwise have to decide whether each new finding counts as selected, and every answer to that surprises somebody.
- **Use it**: turning a category off and on again clears its exclusions, because a remembered exclusion the row no longer shows is a file the user believes they are deleting and are not. A cleanup drops what it took and keeps what the user excluded — still on disk, still junk, back to selected so the next run can take it.

## Test fakes

- **Add one**: hand written, one file per feature — `test/features/<feature>/fakes.dart`. There is no mocking package here and none is to be added: `mockito`, `mocktail` and `bloc_test` are absent from `pubspec.yaml` on purpose, and an absence is the one thing reading the code cannot tell you.
- **Use it**: fake the `domain/` contract, never a `data/` implementation. A rule that cannot be tested through an interface is a missing interface, not a reason to reach past one. The exception is `IoQuarantineRepo`, which is tested against a real temporary directory: moving a file between two paths is the whole behaviour, and a fake file system would be testing the fake.

## Bloc and widget tests

- **Add one**: `Future<void> settle() => Future<void>.delayed(Duration.zero);` at the top of the file, awaited after every `add` — with no `bloc_test`, nothing else drains the event queue before an assertion reads `bloc.state`.
- **Use it**: in a widget test the bloc is built inside `BlocProvider.create`, never in `setUp`, because a bloc from `setUp` lives in another async zone and silently never receives the events — the test just does nothing, with no error pointing at the cause. A bloc test builds it in `setUp` and is right to. A test that needs a run to still be in flight sets `FakeJunkScanRepo.holdOpen`, because a job that completes before the assertion makes "cancel reached it" pass for the wrong reason.

## Injectable clock

- **Add one**: `DateTime Function()? now` on the repository constructor, stored as `_now = now ?? DateTime.now`. A seven-day retention and an hour-old file are otherwise untestable without waiting for them.
- **Use it**: every time-dependent rule reads `_now()` — `DeletionGuard` for the age floor, `IoQuarantineRepo` for expiry and for the batch id — and a widget that counts days down takes the clock as a parameter rather than reading `DateTime.now()` in `build`, so "one day left" is a literal in a widget test.

## Build-time configuration

- **Add one**: `static const X = String.fromEnvironment('ARCHONEX_X', defaultValue: …)` read once, on the platform boundary or in `lib/core/constants/`, with the reason for the default written next to it.
- **Use it**: `--dart-define=ARCHONEX_X=…` at build time, and the default is the safe value rather than the production one. Nothing in this app is configured this way yet; the pattern is here because the Converter needed it for the store split and this project will need it for the same kind of question.

## Constants and tokens

- **Add one**: every number encoding a product decision carries its reason next to it — `AppCleanPolicy.minimumAge` is an hour because a file written ninety seconds ago is junk *in use*, `AppQuarantinePolicy.maxEntryBytes` is 256 MB because quarantining a 3 GB dump frees nothing. A value the platform decides becomes a `static` getter over a private tier table rather than a `const`.
- **Use it**: `Theme.of(context)` read into a local on the first line of `build`, and no raw colour or font size anywhere — see the Theme section of the skill. Width-dependent counts come from `LayoutBuilder`, never `MediaQuery`, because `AppScreenLayout` caps content far below the window and the window would overstate the room.

## Where things live

- **App-wide**: repositories that outlive a screen — language, quarantine — are constructed once in `lib/core/app/archonex_app.dart` and provided from there. Anything holding an index of files on disk belongs here, because a per-screen instance would be a second index of one directory, and no test can catch it: every test injects a fake repository and none of them sees the wiring.
- **Feature-scoped**: everything else is built in that feature's `ui/<feature>_page.dart`, which wires the BLoC and holds no UI. `ui/<feature>_view.dart` is pure presentation, which is what lets a widget test drive a screen without standing up the app.

## Doc comments

- **Add one**: repositories, domain models, constants classes, platform barrels, jobs, rule tables and any use case carrying a guard open with one `///` sentence saying what it is, then a blank `///` and a paragraph naming the alternative that was rejected. That second paragraph is why `AppQuarantinePolicy`, `ProtectedPaths` and the platform barrels need no document outside the code.
- **Use it**: cross-reference by backticked class or file name, and say so outright when a file repeats a sibling's convention. A private single-use widget, a one-line use case and an event class earn nothing: there the name is the whole story.
