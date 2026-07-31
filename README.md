# Archonex Cleaner

[![CI](https://github.com/EvgeniuGlinsky/Archonex-Cleaner/actions/workflows/ci.yml/badge.svg)](https://github.com/EvgeniuGlinsky/Archonex-Cleaner/actions/workflows/ci.yml)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Android%20%7C%20Linux%20%7C%20macOS-6c757d)](#platform-support)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Finds the temporary files your device left behind, and deletes them — with a way
back. Sibling of [Archonex Converter](https://github.com/EvgeniuGlinsky/Archonex-Converter),
same architecture, same offline promise: nothing leaves the device, and there is
no server anywhere in this project.

## What it is

A storage cleaner that is honest about two things most cleaners are not.

**What it can actually reach.** Every platform has a different answer, and on two
of them the honest answer is "almost nothing". The app says so on the screen
instead of scanning an empty sandbox and reporting the device clean — see
[Platform support](#platform-support).

**What deleting means.** Deleting is the one action here that cannot be taken
back, and the rules deciding what counts as junk are heuristics written by hand.
So a cleanup **moves files aside** rather than removing them, and they can be
restored for seven days — see [The quarantine](#the-quarantine).

## Status

The cleaner is implemented end to end: nine categories, five platform rule
tables, the quarantine with restore, and 134 tests. What is not built is the
second tool — see [Roadmap](#roadmap). There is no release yet; the download
table arrives with the first tag.

## What it finds

Nine categories, and every one of them has to be explainable in a line to
somebody about to delete it. Six arrive ticked; three do not, because they are
junk by every technical measure and occasionally the only copy of something.

| Category | Ticked by default | Why |
| --- | --- | --- |
| This app's cache | yes | Ours to empty, on every platform |
| Temporary files | yes | What installers and applications left in the system temp folder |
| Thumbnails | yes | Regenerated on demand; the cost is one slower scroll |
| Old logs | yes | Nobody is going to read them |
| Crash dumps | yes | Useful only to whoever was debugging that crash on the day |
| Empty folders | yes | Left behind by uninstallers |
| **Browser cache** | no | Frees real space, and costs a noticeably slower web for a day. That is a trade to make, not to discover |
| **Installers and archives** | no | A downloaded `.msi` may be the only copy of something paid for |
| **Recycle bin** | no | Already deleted once, deliberately. Emptying it is the one thing the user could have done without this app |

Selection is per category *and* per row: opening a category lets you untick the
one file you recognise, and the rest of the category still goes.

## What it will not touch

`data/rules/protected_paths.dart` is the file to be paranoid in, and it has the
largest test in the project. It is checked against **every** finding, after the
rule has already decided the finding is junk — the two are deliberately not the
same list, so a mistake in one is caught by the other.

Nothing at or below any of these is ever offered:

- **System roots** — `System32`, `WinSxS`, `Program Files`, `/usr`, `/bin`,
  `/etc`, `/System`, `/Library`, `/system`, `/data`
- **The user's own folders** — Documents, Desktop, Pictures, Videos, Music, DCIM
- **Cloud mirrors** — OneDrive, Dropbox, `Library/Mobile Documents`. Deleting
  from a live mirror deletes from the account
- **Configuration and keys** — `~/.config`, `~/.ssh`, `~/.gnupg`,
  `Application Support`, `Preferences`, keychains. The cache directories *beside*
  them are fair game, and the difference between the two is the whole point
- **`/var/tmp`**, alone among temporary directories: it is defined as surviving a
  reboot, which is exactly what the things in it are counting on
- **The app's own quarantine.** A cleaner that scans its own undo directory
  deletes the undo

Three more guards run on every single finding:

- **Symlinks are refused** before they are resolved, so a link into `System32` is
  never even measured.
- **A rule's root is never deleted, only emptied.** A `%TEMP%` that no longer
  exists breaks the next installer to run.
- **Nothing younger than an hour**, and longer where a rule asks for it — a
  browser cache wants a day. A file written ninety seconds ago is not junk left
  behind, it is junk *in use*.

There is exactly one exception to the protected list, and it exists so the rules
never have to be written to dodge the guard: the gallery thumbnail caches inside
Android's `DCIM` and `Pictures`, which are routinely the largest single thing a
phone is carrying. `ProtectedPaths.exceptions` names those two directories, and
`protected_paths_test.dart` checks that nothing beside them slips through with
them.

## The quarantine

A cleanup moves files into `<app support>/quarantine/<batch>/` and writes a
`manifest.json` beside them. Batches expire after seven days; the sweep runs on
the splash screen, because the app is not running when a week is up and a
background job whose only purpose is to delete a temporary file is more machinery
than the problem is worth. An expired batch therefore survives until the next
launch, which costs disk and nothing else.

Three things about it are worth knowing before touching it:

- **Files are moved, never copied.** A copy frees no space, and freeing space is
  what the user pressed the button for. `rename` across volumes throws on every
  platform, and that refusal is the answer rather than a problem to work around.
- **Large files go for good.** Above 256 MB per file, or 2 GB across the whole
  quarantine, the file is deleted outright — quarantining a 3 GB crash dump moves
  3 GB and frees nothing until the retention expires. The confirmation dialog
  names the count *before* the run, and the result card names it after, so nobody
  is offered an undo that covers half of what they deleted.
- **A restore is all or nothing at the destination.** Every original path is
  checked for occupancy before anything moves, because half a restore leaves the
  user not knowing which files came back.

The index lives beside the data rather than in `shared_preferences`
deliberately: a preference store that is wiped, or restored from another device's
backup, would leave the quarantined files on disk with nothing that knows where
they came from.

## Platform support

All six Flutter runners are present. What differs is how much of the device the
app is allowed to see, which is a platform question and not an implementation
one.

| Platform | Reach | How access works |
| --- | --- | --- |
| **Windows** | Full | A desktop process runs with the user's rights. Nothing to ask for |
| **Linux** | Full | Same. Shorter rule table, because almost everything reclaimable belongs to the package manager and needs root |
| **macOS** | Full | Same, and only because this build is **unsandboxed** — see below |
| **Android** | Full *or* app-only | Needs all-files access. Without it: the app's own caches, plus any folder handed over through the picker |
| **iOS** | App-only, permanently | The container, and no permission exists that widens it |
| **Web** | None | No file system. The screen says so on the first frame |

### Android

`MANAGE_EXTERNAL_STORAGE` is the difference between a cleaner that can see the
device and one that can see its own cache. It is requested, and a refusal is an
answer rather than an error: the app reports `appOnly`, offers the folder picker
instead, and the screen explains what is and is not covered. Once the system
stops showing the sheet, the notice points at Settings rather than repeating a
button that visibly does nothing.

Play requires a declaration for this permission, under the file manager use case.
A build that is refused it still runs.

**No rule names another app's cache.** `/sdcard/Android/data/<pkg>/cache` has
been unreadable to normal apps since Android 11 and no permission opens it,
all-files access included. A cleaner that claims to empty it is either lying or
shipping a privileged build.

The folder-picker fallback has one real limit: Android hands back `/` for a
folder it cannot resolve to a real path, and a rule rooted at `/` would be an
accidental scan of the whole device. Those picks are rejected rather than used.

### iOS

Two rows, both inside the app's own container, and that is the entire list.
Everything a phone cleaner advertises on iOS is either this or a lie — there is
no API that reaches another app's data and no permission to ask for. The screen
says so instead of offering a Grant button.

### macOS

The sandbox is off, and that is the whole macOS story. Inside it,
`NSHomeDirectory()` returns the app's container, so `~/Library/Caches` means the
app's own cache and nothing else — a sandboxed cleaner scans an empty machine and
reports it clean, which is worse than refusing to run.

The cost is that this build cannot go to the Mac App Store, which requires the
sandbox. A store build would use `SandboxStorageAccessRepo` and the app-only
ruleset iOS already has; both exist.

### Not scanned, deliberately

`C:\Windows\SoftwareDistribution\Download` and `C:\Windows\Prefetch` are
genuinely reclaimable and both need administrator rights. They stay in the
Windows table, flagged `needsElevation`, and are filtered out of every scan — an
app that asks for administrator rights to delete a file is an app people
uninstall. The rows exist so the next person to wonder finds the answer instead
of adding them, and a test checks they were declared *and* dropped.

## Roadmap

| Idea | Notes |
| --- | --- |
| **Space saver** — find large files in an expensive codec and re-encode them | The second tool, and the reason `AppRoute` is shaped for a second entry. A 4 GB H.264 video is typically 20–40% smaller as HEVC or AV1 at visually identical quality, and the Converter already has the FFmpeg engine and the codec tables this would need. It is a large feature of its own: the methodology — which formats are worth converting, to what, and at what quality — has to exist before any of the UI does |
| Large-file browser | The read-only half of the space saver: show what is big, sorted, and let the user decide. Cheap, and probably worth shipping first |
| Duplicate finder | Deliberately last. Hashing a terabyte to find two copies of a photo is a lot of disk for an answer that is usually "no", and doing it cheaply means a size-then-partial-hash-then-full-hash ladder |

## Stack

- Flutter (stable channel), Dart SDK `^3.10.0`
- [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) + [`bloc_concurrency`](https://pub.dev/packages/bloc_concurrency) — state management
- [`go_router`](https://pub.dev/packages/go_router) — routing
- [`equatable`](https://pub.dev/packages/equatable) — value equality
- [`path`](https://pub.dev/packages/path) — path arithmetic that knows which separator it is on. Named explicitly rather than leaned on transitively, because `ProtectedPaths` is tested against every platform's rules from whichever one CI runs on
- [`path_provider`](https://pub.dev/packages/path_provider) — the app's own cache and support directories
- [`permission_handler`](https://pub.dev/packages/permission_handler) — Android's all-files access, and nothing else
- [`file_picker`](https://pub.dev/packages/file_picker) — the folder-picker fallback. Nothing is ever picked *for* cleaning; the app only asks where it may look
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — reserved for the remembered category selection

No network dependency of any kind. The app issues no requests, rather than
issuing one nobody counted.

## Getting started

```bash
flutter pub get
flutter run
```

Requires the Flutter stable channel. The pinned revision this project was last
verified against is recorded in `.metadata`.

## Architecture

```
lib/
├── main.dart                        # runApp(ArchonexApp()) — nothing else
├── core/
│   ├── app/                         # root widget, app-wide providers
│   ├── constants/                   # spacing, radius, durations, byte units,
│   │                                #   clean policy, quarantine policy
│   ├── router/                      # AppRoute enum + GoRouter config
│   ├── theme/                       # app_colors, app_typography, app_theme
│   ├── utils/
│   └── widgets/                     # shared building blocks
└── project_files/features/<feature>/
    ├── data/                        # repo implementations, use cases, platform adapters
    ├── domain/                      # repo interfaces + models — no Flutter imports
    └── ui/                          # page, view, bloc/, widgets/, mappers/
```

Every feature follows the same three-layer split. `domain` declares interfaces
and models and depends on nothing; `data` implements them; `ui` holds the BLoC
and widgets and talks to `domain` only. Each screen is a `*_page.dart` (wires up
the BLoC) plus a `*_view.dart` (pure presentation), which is what keeps widget
tests able to drive a view without standing up the whole app.

Colours, type and every design token live in `lib/core/theme/`: `Color(0x…)`
appears in `app_colors.dart` and nowhere else, and a literal `fontSize` in
`app_typography.dart` and nowhere else.

**Before adding or changing a feature, read
[`.claude/skills/flutter-feature/SKILL.md`](.claude/skills/flutter-feature/SKILL.md).**
It is the mandatory standard for file structure, naming and coding style in this
repository, not a suggestion. `CLAUDE.md` beside it owns the rules whose
violation nothing catches at build time.

### Where the cleaner lives

`lib/project_files/features/storage_cleaner/` is the reference implementation of
the pattern, and it is split so that the dangerous part is the part with no I/O
in it:

- `domain/` — `JunkScanRepo`, `JunkCleanRepo`, `StorageAccessRepo` and the models
  (`JunkItem`, `JunkGroup`, `JunkCategory`, `CleanReport`, `StorageAccess`,
  `CleanFailure`)
- `data/rules/` — **the interesting directory.** Five pure tables saying where
  junk lives per platform, plus `ProtectedPaths` and `DeletionGuard`, which
  decide what may be offered. None of it touches a file system, all of it is
  unit-tested against every platform from whichever one CI runs on
- `data/file_system/` — the walker and the deleter. Loops with nothing to decide,
  because the rules and the guard already decided
- `data/access/` — one implementation per platform answer: Android's real one,
  the desktop constant, the sandbox constant, the web refusal
- `data/platform/` — the io/web split, one conditional export
- `data/use_cases/` — one file per action
- `ui/` — `StorageCleanerBloc` and the widget tree

`lib/project_files/features/quarantine/` is its own feature rather than a
directory inside the cleaner, because the dependency has to point one way: the
cleaner needs somewhere to put files, and the quarantine owns retention. It has
its own failure hierarchy (`RestoreFailure`) for the same reason — the cleaner's
`CleanFailure` cannot hold members the quarantine throws without the arrow
pointing both ways. The repository is an app-wide singleton in
`archonex_app.dart`: the batch the cleaner writes is the batch the quarantine
screen reads, and a second instance would be a second index of one directory.

`splash/` owns no data, so it has `ui/` alone — and it earns its beat by sweeping
expired quarantine batches while it runs. `language_selection/` is ported from
the Converter unchanged.

## Tests

```bash
flutter analyze
flutter test
```

134 tests, concentrated where being wrong is expensive:

- **`protected_paths_test.dart`** is the most important file in the repository. It
  checks all five platforms' lists — case sensitivity, `..` normalisation, the
  one exception and its boundaries — from whichever platform CI runs on. It has
  already caught one real bug: Android's own app cache lives under the protected
  `/data`, so without an exception the one directory unambiguously ours to empty
  was the one the guard refused.
- `deletion_guard_test.dart` — the four questions asked of every finding, one at
  a time, including a file dated in the future.
- `junk_ruleset_test.dart` — properties that must hold for every platform: no
  rule rooted at a protected path, no unfiltered deep walk, no age floor shorter
  than the policy, nothing needing elevation, and no rule naming another app's
  Android cache.
- `io_quarantine_repo_test.dart` — the one data-layer class with a test, against
  a real temporary directory and an injected clock: move-not-copy, name
  collisions, a file too large to keep, retention either side of the boundary, a
  taken destination, a partial restore, and a manifest that will not parse.
- Bloc tests for both screens, and a view test for the cleaner covering the
  confirmation dialog, the narrowed and sandboxed access notices, and the web
  refusal.

Fakes are hand written, one file per feature
(`test/features/<feature>/fakes.dart`) — there is no mocking package here and
none is to be added.

## CI

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on every
push to `main` and on every pull request, against a pinned Flutter version so a
Flutter release cannot turn CI red on its own.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
