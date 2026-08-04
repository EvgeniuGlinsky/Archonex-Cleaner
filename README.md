# Storage Cleaner

[![CI](https://github.com/EvgeniuGlinsky/Storage-Cleaner/actions/workflows/ci.yml/badge.svg)](https://github.com/EvgeniuGlinsky/Storage-Cleaner/actions/workflows/ci.yml)
[![Release](https://github.com/EvgeniuGlinsky/Storage-Cleaner/actions/workflows/release.yml/badge.svg)](https://github.com/EvgeniuGlinsky/Storage-Cleaner/actions/workflows/release.yml)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20Android%20%7C%20Linux%20%7C%20macOS-6c757d)](#platform-support)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

## Download

Every file below downloads directly — the link is the file, not a page about it.

| Platform | File |
| --- | --- |
| Android, most phones since 2016 | [`storage-cleaner-1.1.2-android-arm64.apk`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-android-arm64.apk) |
| Android, older 32-bit devices | [`storage-cleaner-1.1.2-android-arm32.apk`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-android-arm32.apk) |
| Android, emulators and x86 tablets | [`storage-cleaner-1.1.2-android-x86_64.apk`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-android-x86_64.apk) |
| Android, if unsure | [`storage-cleaner-1.1.2-android-universal.apk`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-android-universal.apk) |
| Windows 10 and 11, 64-bit | [`storage-cleaner-1.1.2-windows-x64.zip`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-windows-x64.zip) |
| macOS 10.15 and later, Apple silicon and Intel | [`storage-cleaner-1.1.2-macos-universal.zip`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-macos-universal.zip) |
| Linux, 64-bit | [`storage-cleaner-1.1.2-linux-x64.tar.gz`](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/download/v1.1.2/storage-cleaner-1.1.2-linux-x64.tar.gz) |

Windows and Linux need no installer: unpack the archive anywhere and run
`storage_cleaner.exe`, or `storage_cleaner` on Linux. Everything the app needs
sits beside it in the same folder.

The links point at [1.1.2](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/tag/v1.1.2)
by name rather than at `latest`, because the version is part of every filename —
[the releases page](https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases)
is where a later one will be. Each release also carries `SHA256SUMS.txt`; check
a download with `sha256sum -c`.

The desktop builds are unsigned — code signing certificates cost money this
project does not take. Windows will show a SmartScreen prompt, and macOS will
say the app is *damaged*, which is what Gatekeeper says about anything without a
Developer ID. It is not damaged; clear the flag once:

```
xattr -dr com.apple.quarantine "/Applications/Storage Cleaner.app"
```

Two tools for one problem. **Clean up** finds the temporary files your device
left behind and deletes them, with a way back. **Optimise** finds the photos and
videos that weigh more than they need to and re-encodes them at the same
quality. Nothing leaves the device, and there is no server anywhere in this
project.

No ads, no accounts, no tracking — and no network permission in the release
build at all, which you can check for yourself before installing:

```
aapt2 dump permissions storage-cleaner-1.1.2-android-arm64.apk
```

## What it is

A storage app that is honest about three things most are not.

**What it can actually reach.** Every platform has a different answer, and on two
of them the honest answer is "almost nothing". The app says so on the screen
instead of scanning an empty sandbox and reporting the device clean — see
[Platform support](#platform-support).

**What deleting means.** Deleting is the one action in the cleaner that cannot be
taken back, and the rules deciding what counts as junk are heuristics written by
hand. So a cleanup **moves files aside** rather than removing them, and they can
be restored for seven days — see [The quarantine](#the-quarantine).

**What it is not worth doing.** The optimiser leaves most of what it finds alone
and says why on the row. A tool that offers to re-encode everything is a tool
that spends twenty minutes of battery to free three per cent — see
[Optimising files](#optimising-files).

## Status

All three tools are implemented end to end, and there are 436 tests. Version
1.1.2 is tagged and built by [`release.yml`](.github/workflows/release.yml) —
see [CHANGELOG.md](CHANGELOG.md) for what is in it.

The cleaner has nine categories, five platform rule tables and the quarantine
with restore. The optimiser has four header parsers, four encoders, and a
replace ladder that has never lost a file in any of the branches
`io_media_optimize_repo_test.dart` drives through it. The third tool measures
the disk by kind of file and answers "where did it all go" without touching
anything. A home screen lists all three and draws how full the disk actually is.

The app opens in the device's own language and never asks. The picker is a
dialog behind the globe in the corner, for the case the device is wrong about
it, and the choice is remembered — a language screen between the user and the
app on first launch is a question almost nobody needed asked.

## What it finds

Nine categories, and every one of them has to be explainable in a line to
somebody about to delete it. Six arrive ticked; three do not, because they are
junk by every technical measure and occasionally the only copy of something.

| Category | Ticked by default | Why |
| --- | --- | --- |
| This app's cache | yes | Android and iOS only, where the cache directory really is this app's. On desktop `getTemporaryDirectory()` *is* `%TEMP%`, so a row for it would be the system temp folder wearing the wrong name — the next category covers those bytes and describes them honestly |
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

## Optimising files

The second tool. It walks the folders you fill yourself, reads the header of
every large photo and video, works out which are bigger than they need to be,
and re-encodes those at the same resolution and the same visual quality.

### How it decides

One idea, and everything else follows from it: **compare how many bytes a file
spends per unit of picture against how many that format needs.**

Raw size says nothing — a 4 GB film can be efficient and a 40 MB clip wasteful —
and bitrate alone says almost nothing either, because a 4K clip legitimately
needs four times what 1080p does. Dividing by the pixel count, and for video by
the frame rate as well, is what removes resolution from the question and leaves
the part that is a judgement.

For **videos** the measure is bits per pixel per frame, compared against the
figure its own codec needs. Those live on `VideoCodec`, because the number *is*
the codec's identity here:

| Codec | Efficient at | Typically found at |
| --- | --- | --- |
| H.264 | 0.10 | 0.15–0.40 — every phone, every camera, every download |
| HEVC | 0.06 | the target, and what a file already in it is measured against |
| AV1 | 0.045 | better than anything this app can produce |
| VP9 | 0.065 | close enough to the target to leave alone |
| MPEG-4 part 2 | 0.20 | DivX, Xvid, camcorder `.avi` — the largest wins there are |
| Motion JPEG | 0.60 | every frame a separate JPEG. Enormous |

For **photographs** the measure is bytes per pixel. A JPEG above 0.30 was saved
generously and has room in it; below that it is already tight. A PNG above 1.0
is a photograph stored losslessly and becomes a JPEG; below that it is a
screenshot of flat interface colour, which is the one case PNG wins outright.

A file is only offered when the estimate clears **both** thresholds: at least
20% smaller *and* at least a megabyte. The fraction alone would offer a
two-megabyte photo for four hundred kilobytes; the megabyte alone would offer a
four-gigabyte film for the two per cent that is its container overhead.

### What it deliberately will not do

- **Change the container on its own.** An MKV rewrapped as an MP4 copies the
  video stream byte for byte into a different box and frees well under one per
  cent. It is the conversion that looks like it should help and does not. MKV
  and AVI files here become MP4 because they are being re-encoded anyway.
- **Touch anything already in HEVC or AV1 at a sensible density.** This is the
  branch that matters most on a phone. Without it the app spends twenty minutes
  of battery and a hot device to free three per cent of one video.
- **Reduce the resolution.** Every off-the-shelf video-compression package gets
  its savings this way, and it is exactly the quality loss this tool exists to
  avoid. The output is verified against the input's dimensions before it is
  allowed to replace it.
- **Convert a screenshot.** JPEG puts ringing around every letter of text and
  saves very little doing it.
- **Guess.** A file whose header will not say how long it is, or what encoded
  it, is left alone and listed as such. "Probably H.264" is how a tool ends up
  re-encoding an archive master.

Everything refused stays on the list with its reason beside it. Somebody staring
at a full disk needs to be told *why* nothing can be done about their largest
video, and a tool that silently drops those rows looks exactly like a tool that
failed to find them.

### What it will not touch at all

`data/rules/off_limits_paths.dart` is the paranoid file here, and it is the
inverse of the cleaner's rather than a copy: the cleaner protects your own
folders, and your own folders are this tool's entire subject. The walk starts
only at Pictures, Videos, DCIM, Downloads and anything you hand over through the
picker — never at a disk root — and this refuses findings inside them:

- **Cloud mirrors** — OneDrive, Dropbox, Google Drive, iCloud, Nextcloud and the
  rest, wherever they are mounted. Rewriting a synced file re-uploads every
  byte, which on a metered connection is a bill, and on a service with version
  history replaces a master with a lossy copy on every device on the account.
  Matched as whole path segments, so `Dropbox Party 2019` is a holiday.
- **Game and application data** — `SteamLibrary`, `steamapps`, `Program Files`,
  `AppData`, Android's `Android/`. A game's `intro.mp4` is an asset with a
  checksum beside it, not your video, and re-encoding it breaks the install in a
  way that looks like a corrupt download.
- **Working trees** — anything under `.git` or `node_modules`.
- **The Photos library on macOS**, which is a database rather than a folder: a
  rewritten original inside one is a photo the app can no longer open.
- **This app's own quarantine**, so a restore gives back what was taken.

### There is no undo, and why

The cleaner can promise one because a cleanup moves files aside. This tool
cannot: keeping the originals means the disk holding both copies, which frees
nothing, and freeing space is what the button was pressed for. The confirmation
dialog says so in as many words, along with how many files will end up under a
different extension.

What makes that safe rather than reckless is the order of six steps, per file:

1. Encode to a hidden working file **beside the original**, on the same volume —
   a rename across volumes is a copy, and copying four gigabytes to free two is
   not a saving.
2. **Verify.** Not just the size: an encoder that hit a corrupt frame and
   stopped writes a file that is valid, smaller and a third as long. The header
   is re-read and the dimensions and duration compared.
3. Carry the modification time across, so a gallery does not reorder itself and
   put every optimised photograph at the top as though taken today.
4. Rename the original aside, rename the replacement into place, then delete the
   original. Never a rename *over* a live file, which throws on Windows; never
   delete-then-rename, which has a window where neither file exists.
5. Any failure at any step deletes the working file and leaves the original
   exactly where it is. One file refusing does not end a run of two hundred, and
   the result card counts them.
6. A run sweeps the leavings of a crashed one before it starts, restoring a
   moved-aside original rather than deleting it.

The figure the screen shows before a run is an **estimate** and is labelled one
everywhere. The figure on the result card afterwards is measured from the disk.
Both are shown, so an estimate that was badly wrong is visible rather than
quietly replaced.

### Encoders

| Platform | Photos | Videos |
| --- | --- | --- |
| **Android** | the platform codec, hardware-assisted | `MediaCodec` → HEVC, written for this app |
| **Windows** | pure Dart, in an isolate | `ffmpeg`, from the `PATH` or fetched by the app |
| **Linux** | same | same |
| **macOS** | same | same |
| **iOS** | — | — |
| **Web** | — | — |

`MediaTranscoder.kt` is the only native code in this project, and it exists
because nothing on pub does the job: every video-compression package available
reduces the resolution to get its savings, none will write HEVC, and FFmpegKit
was retired in January 2025. It extracts, decodes onto a surface, encodes as
HEVC and muxes, keeping the width, height, frame rate, rotation and every other
track.

Whether a machine can encode is **asked**, not assumed from the platform. A
Windows box can walk the whole disk, work out that six gigabytes of video would
come back, and have no `ffmpeg`. Silently omitting the videos would report a
device with nothing to optimise, which is the same lie as a cleaner reporting an
empty sandbox as a clean phone — so the screen lists them, says what they would
save, and offers to fetch the encoder that would do it.

That fetch is a download the app performs and then *executes*, which is worth
the care it gets. What arrives is checked against a digest the publisher
published — written down beside a pinned link, or read from a `.sha256` URL
where the link moves — then unpacked into a working folder beside its
destination, moved into place as one file, and run once to prove it runs. It is
downloaded rather than bundled because a hundred megabytes shipped to every copy
of an app about freeing disk space is the wrong trade, and because bundling an
encoder is *distribution*, with the licence obligations that carries.

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

The optimiser asks a narrower version of the same question, and gets a different
answer in two places:

| Platform | Optimiser |
| --- | --- |
| **Windows**, **Linux**, **macOS** | Photos always. Videos where there is an `ffmpeg` — on the `PATH`, or fetched by the app when there is not |
| **Android** | Both, with all-files access. Without it, only folders handed over through the picker — an app's own container holds no photographs you took |
| **iOS** | Nothing. The photo library is behind an API that hands out copies rather than paths, and there is no permission that changes it |
| **Web** | Nothing |

`storage_access/` is its own feature because both tools ask this and neither owns
the answer. It started inside the cleaner and moved out the day the optimiser
needed it.

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
| **A desktop encoder without a download** | The gap is narrower than it was — a desktop with no `ffmpeg` is now offered one, and the app verifies it against its publisher's digest before running it. What is left is the first run on a metered connection, and the machines that have no network at all. Bundling is still the wrong answer: a hundred megabytes charged to every copy of an app about freeing disk space, including the ones that never open a video, and a download turned into distribution with the licence obligations that carries |
| **An iOS story** | Currently none, and honestly so. PhotoKit can replace an asset's rendition, which is a completely different API from anything here and the only route that exists |
| **HEIF and AVIF output** | Another 30% over JPEG for photographs. Needs a native encoder on every platform, and the desktops have none |
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
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — the language chosen by hand, and nothing else. The quarantine index is deliberately not here but a file beside its data
- [`disk_space_2`](https://pub.dev/packages/disk_space_2) — how full the disk is, which `dart:io` cannot answer on any platform. Chosen over `disk_space_plus` and `storage_space`, which are Android and iOS only; this fork also covers Windows and Linux, and on macOS and web the ring is simply not drawn
- [`image`](https://pub.dev/packages/image) — re-encoding a photograph on the three desktops, in an isolate. Pure Dart, so it needs nothing installed, which matters because the desktop video story is already "you may not have `ffmpeg`"
- [`flutter_image_compress`](https://pub.dev/packages/flutter_image_compress) — the same job on Android, through the platform codec. Roughly an order of magnitude faster, which is the difference between a camera roll taking a minute and taking an afternoon

Nothing on pub is used for video, and the reason is in
[Optimising files](#encoders).

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
├── main.dart                        # runApp(StorageCleanerApp()) — nothing else
├── core/
│   ├── app/                         # root widget, app-wide providers
│   ├── constants/                   # spacing, radius, durations, byte units,
│   │                                #   clean, quarantine and optimiser policy
│   ├── router/                      # AppRoute enum + GoRouter config
│   ├── theme/                       # app_colors, app_typography, app_theme
│   ├── utils/
│   └── widgets/                     # shared building blocks
└── project_files/features/
    ├── splash/                      # ui/ only — and it sweeps expired batches
    ├── home/                        # the front door: the tool list and the ring
    ├── device_storage/              # how full the disk is. No screen, one widget
    ├── language_selection/          # the globe dialog and what it remembers
    ├── storage_access/              # what this platform lets the app touch
    ├── media_optimizer/             # the second tool
    ├── storage_cleaner/             # the first tool
    └── quarantine/                  # where a cleanup puts things for seven days
        ├── data/                    # repo implementations, use cases, platform adapters
        ├── domain/                  # repo interfaces + models — no Flutter imports
        └── ui/                      # page, view, bloc/, widgets/, mappers/
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

### Where the two tools live

`lib/project_files/features/storage_cleaner/` is the reference implementation of
the pattern, and it is split so that the dangerous part is the part with no I/O
in it:

- `domain/` — `JunkScanRepo`, `JunkCleanRepo` and the models (`JunkItem`,
  `JunkGroup`, `JunkCategory`, `CleanReport`, `CleanFailure`)
- `data/rules/` — **the interesting directory.** Five pure tables saying where
  junk lives per platform, plus `ProtectedPaths` and `DeletionGuard`, which
  decide what may be offered. None of it touches a file system, all of it is
  unit-tested against every platform from whichever one CI runs on
- `data/file_system/` — the walker and the deleter. Loops with nothing to decide,
  because the rules and the guard already decided
- `data/platform/` — the io/web split, one conditional export
- `data/use_cases/` — one file per action
- `ui/` — `StorageCleanerBloc` and the widget tree

`storage_access/` beside it is the same shape at a smaller size, and its
`data/access/` holds one implementation per platform answer: Android's real one,
the desktop constant, the sandbox constant, the web refusal.

`lib/project_files/features/media_optimizer/` is the same split again, and it
adds two folders the cleaner has no use for:

- `data/rules/` — `SavingsEstimator`, which is the feature. One pure function
  deciding whether a file is worth re-encoding and into what, with more tests on
  it than anything else in the project. Beside it `OffLimitsPaths` and
  `OptimizeGuard`, and per-platform media roots
- `data/probes/` — four header parsers over a `ByteSource` rather than a file,
  which is what keeps them pure and their fixtures readable. An MP4's index is
  routinely written *after* gigabytes of frames, so they seek; a `.mp4` holding
  a Matroska stream is common enough that they dispatch on magic bytes and never
  on the extension
- `data/encoders/` — the `MediaEncoder` seam and its four implementations, plus
  `UnavailableEncoder` for the platforms and machines that have none. It is the
  interface every test fakes, because none of the real four run under
  `flutter test`
- `data/file_system/` — the walker, and `IoMediaOptimizeRepo`, which holds the
  replace ladder and is the one place in the app where being wrong loses
  somebody's photograph

`lib/project_files/features/quarantine/` is its own feature rather than a
directory inside the cleaner, because the dependency has to point one way: the
cleaner needs somewhere to put files, and the quarantine owns retention. It has
its own failure hierarchy (`RestoreFailure`) for the same reason — the cleaner's
`CleanFailure` cannot hold members the quarantine throws without the arrow
pointing both ways. The repository is an app-wide singleton in
`storage_cleaner_app.dart`: the batch the cleaner writes is the batch the quarantine
screen reads, and a second instance would be a second index of one directory.

`lib/project_files/features/storage_access/` is its own feature for the same
rule, arrived at from the other direction: it started inside the cleaner and
moved out the moment a second tool needed it. "May I touch this device" has five
genuinely different answers and neither tool owns them. It carries its own
`AccessFailure`, which reaches the cleaner's hierarchy wrapped in one member,
`AccessRefusedFailure` — a member that delegates rather than one that restates,
so there is a single list of access sentences and a single mapper.

`splash/` owns no data, so it has `ui/` alone — and it earns its beat by sweeping
expired quarantine batches while it runs.

`home/` is the front door and owns almost nothing: an `AppTool` enum, a bloc
that reads the disk, and two cards. The second card is on the screen from the
first release with a badge saying it is not finished, because the product is two
tools and a screen showing one of them teaches the user that it is one.

`device_storage/` has no screen at all — no page, no view, no bloc. Its `ui/` is
one widget, the ring, which both the home screen and the cleaner draw. It is the
example of the rule that a layer is added when something belongs in it rather
than to fill the shape.

`language_selection/` came from the Converter as a full screen and is no longer
one. It is a dialog now, opened from the globe, and it is not shown on first
launch: `LanguageRepoImpl` reads the device's own locales and answers with the
first one the app has an ARB for. A hand-made choice outranks the device and is
written to `shared_preferences`; a store that will not read costs the user their
choice rather than their launch.

## Tests

```bash
flutter analyze
flutter test
```

345 tests, concentrated where being wrong is expensive:

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
- `language_repo_impl_test.dart` — which language the app opens in, which is a
  question with four answers: the device's first preference, its second where
  the first has no ARB, English where neither does, and the hand-made choice
  that outranks all three. Plus a store that will not read, which must cost the
  choice and not the launch.
- **`savings_estimator_test.dart`** is the optimiser's equivalent, and the
  largest single file of the two. Every branch of the methodology written out as
  arithmetic anybody can check, from realistic figures rather than round ones: a
  camera JPEG at 0.5 bytes per pixel, a screenshot at 0.3, a phone clip at 0.15
  bits per pixel per frame, a 4 GB AV1 file left alone. The whole question is
  whether the thresholds sit in the right place for files people actually have,
  and a test using a 1000-byte photo would pass whatever the numbers were.
- `off_limits_paths_test.dart` — the same paranoia as `protected_paths_test.dart`
  applied to the inverse list, including the case that most matters: the camera
  roll, which the cleaner refuses outright and this tool exists to work inside.
- `media_probes_test.dart` — the header parsers against files built byte by byte
  in `fixtures.dart`. A checked-in binary would be shorter and worthless, because
  the risk in a header parser is an offset being wrong in a way that still yields
  a plausible number.
- `io_media_optimize_repo_test.dart` — the replace ladder, against a real
  temporary directory with a fake encoder. Every failure branch, not just the
  happy one: an output too large, wrong dimensions, unparseable, an encoder that
  threw, a destination name taken, a cancel mid-run, and the leavings of a run
  killed between the two renames. The question it asks each time is the same —
  given a file that came out badly, does the original survive?
- `arb_parity_test.dart` — key sets, placeholder sets including the ones inside
  ICU plural branches, and long strings left identical to the English by
  copy-paste. `gen-l10n` fills a missing key from the template and says nothing,
  so before this the failure was completely silent.
- Bloc tests for all four screens, and view tests covering both confirmation
  dialogs, the narrowed and sandboxed access notices, the web refusal, the
  "no encoder on this machine" notice, and a 360 dp phone in all three locales —
  the layout bug that only a device reports is now the one thing several tests
  exist to catch.

Fakes are hand written, one file per feature
(`test/features/<feature>/fakes.dart`) — there is no mocking package here and
none is to be added.

`integration_test/` is separate and **not** part of CI — it needs a real device:

```bash
flutter test integration_test/scan_probe_test.dart     -d windows
flutter test integration_test/optimize_probe_test.dart -d windows
flutter test integration_test/scan_probe_test.dart     -d <android-device-id>
flutter test integration_test/optimize_probe_test.dart -d <android-device-id>
```

The **scan probe** pumps the real `StorageCleanerApp` against the real machine and
deletes nothing. The unit tests answer whether the rules are right about every
platform; only a device answers the other half, and every one of those questions
fails *quietly* under `flutter test`:

- whether the paths the rules name exist here, and whether a walk of a real
  `%TEMP%` finishes in a sensible time;
- whether `disk_space_2` has a side for this platform, which a `null` snapshot
  is indistinguishable from by design;
- whether the system hands over a locale list at all — it is empty under
  `flutter test`, so an app that read it wrongly would still open in English on
  a Russian phone and pass everything;
- whether `shared_preferences` is registered, which a storage that swallows its
  own failures makes look exactly like a first run, for ever;
- whether the wiring in `storage_cleaner_app.dart` holds, which no widget test can
  reach: it builds `IoQuarantineRepo`, which needs `path_provider`, which has no
  platform to answer it in a unit test.

It prints what it found per category, and asserts the invariants that must hold
whatever that was: nothing protected was offered, no category came back that was
not asked for, and no path twice.

It has already earned its place. On this machine it reported 4.8 GB across eight
categories in 9 seconds — and on the first run, 696 MB of it under *This app's
cache*, which is how the desktop `getTemporaryDirectory()` mislabelling above was
found. A unit test could not have: the rule was correct about the path it named,
and wrong about what that path is.

The **optimise probe** has two halves. The *survey* walks the real media folders,
prints what it found and what it thinks could be saved, and **writes nothing**.
The *round trip* builds its own picture in a temporary directory and actually
re-encodes it, which is the only way to find out whether the encoders do what
the Dart side believes and whether the estimates are anywhere near the truth.

It earned its place on the first run too, and more expensively. A two-hour film
was reported at **0.96 frames a second** — an MP4 does not store its frame rate,
and the parser was reading part of a variable-rate sample table and dividing by
the whole track's duration. The file looked twenty-five times more wasteful than
it is and the app offered to free 12 GB it could not. Nothing in `test/` could
have caught it: the fixture had a single-row table, because a fixture written by
whoever wrote the parser shares its assumptions. There is a twenty-thousand-row
one now, and the same run also found the bytes-per-pixel estimate leaning
optimistic, which is the wrong direction for a promise.

## CI and releases

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on every
push to `main` and on every pull request, against a pinned Flutter version so a
Flutter release cannot turn CI red on its own.

`.github/workflows/release.yml` runs on a `v*` tag and nothing else. It checks
the tag against `pubspec.yaml` before building anything, re-runs analyse and
test — a tag can point at a commit whose checks never ran — then builds four
APKs, an app bundle, a Windows zip and a Linux tarball, and publishes them with
`SHA256SUMS.txt`.

Cutting a release, and creating the signing key it needs, is
[`docs/RELEASING.md`](docs/RELEASING.md).

## Privacy

Nothing is collected and nothing is sent, and that is a property of the build
rather than a promise: the release manifest declares no `INTERNET` permission,
so the operating system refuses every network call the app could make. See
[PRIVACY.md](PRIVACY.md), and verify it yourself with `aapt2 dump permissions`
on any release APK.

Security reports go through GitHub's private reporting — see
[SECURITY.md](SECURITY.md). This app deletes files and rewrites them in place,
so the classes of bug that matter most are listed there explicitly.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
