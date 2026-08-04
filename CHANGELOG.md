# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.1] — 2026-08-05

No change to the app. 1.1.0 was tagged but never published: the release
workflow builds five platforms and attaches them in one job, and the Windows
build stopped compiling, so four finished artefacts were thrown away with the
runner and the releases page stayed empty. This is that release, with the build
fixed.

### Fixed

- **The Windows build against a current Visual Studio.** The
  `permission_handler_windows` plugin compiles with `/std:c++20` and `/await`
  both, and `/await` is the legacy coroutine switch — it hides
  `__cpp_lib_coroutine`, the macro C++/WinRT branches on to reach `<coroutine>`
  rather than `<experimental/coroutine>`. MSVC 14.51 turned that header into a
  hard error, so the plugin now stops the build on any machine with a current
  toolchain. The flag is dropped from the target in `windows/CMakeLists.txt`,
  where it can be reached — the plugin itself lives in the pub cache and arrives
  on a runner unmodified — rather than silenced with a define that would keep
  the build on a header Microsoft has said it will remove.

### Changed

- **The downloads come first, and are downloads.** The README listed seven
  filenames as plain text below the pitch. They are the first thing on the page
  now, and each one links straight to its file.
- The repository slug is corrected wherever it appeared as `storage-cleaner`;
  the repository is `Storage-Cleaner`. The prose links survived on a redirect,
  the Actions badges did not.

## [1.1.0] — 2026-08-04

First published release.

### Added

- **Where the space went.** A third tool, above the two that act, because "what
  is filling this disk" is the question a full device raises and neither of the
  other two answered it. The disk is measured by kind of file and drawn as one
  arc per kind, with a row under it carrying the name, the size and the share.
  The palette was measured rather than chosen — five hues checked for contrast
  and for separation under three kinds of colour blindness — and every row
  carries a label and a figure, because colour alone is not enough to tell two
  of them apart.
- **How hard to compress.** Gentle, balanced and maximum, with balanced the old
  behaviour pressed a little further. Moving the switch re-measures everything
  already found without walking the disk again.
- **More of the phone reached.** Scoped storage moved the messengers' media
  under `Android/media` in Android 11 and the app was still looking at the four
  top-level folders from before that, so WhatsApp and Telegram were invisible —
  as was a second volume, which is unfortunate on a phone somebody fitted an SD
  card to. Both are looked at now, `.3gp` and `.3g2` are recognised, and the
  size floors came down from 16 MB to 8 for a video and from 1 MB to 512 KB for
  a photo, because a messenger's files are short, numerous and usually in the
  two worst codecs there are.
- **A run outlives the screen that started it.** Starting a two-hour transcode
  and pressing Back used to discard all of it, silently. The work now belongs to
  the app rather than to the screen, and on Android a foreground service and a
  wake lock keep it going with the phone in a pocket, with an ongoing
  notification carrying the count, the space freed so far and a Stop button —
  written in the language the app is set to, not the one the device is.
- **A desktop fetches its own video encoder.** Windows and Linux re-encode video
  through `ffmpeg`, which most machines do not have. Rather than reporting the
  lack, the app offers to fetch one, checks what arrives against the digest its
  publisher published, installs it beside its own data and ticks the kind of
  file that just became possible. It is downloaded rather than bundled because a
  hundred megabytes shipped to every copy of an app about freeing disk space is
  the wrong trade, and because bundling an encoder is distribution, with the
  licence obligations that carries.
- **An icon of its own.** Every launcher icon on five platforms, the two images
  Play insists on, the web favicons and the splash artwork are generated from
  one source picture, so no two of the forty can drift into being slightly
  different pictures. The colour the system paints before Flutter starts is
  written out of the same artwork, because a colour restated by hand drifts and
  the drift shows as a flash on every cold start.

### Changed

- **The application id is `io.github.evgeniuglinsky.storagecleaner`.**
  `com.archonex.cleaner` was a working title reversed into a domain nobody
  holds. Play and F-Droid both take this as the app's identity for the life of
  the listing and neither lets it be changed afterwards, so it had to be right
  before the first upload or never.
- **The whole screen scrolls, and stays upright.** The header used to be pinned
  above a list of its own, which left a 360×640 phone about 250 pixels to scroll
  in. It is inside the scroll view now; the primary action stays pinned, because
  a button you have to hunt for is the one thing a screen must not do. The
  language button moved into the app bar the other screens already had.
- **Tiles that use the width they were given.** Both tiles could put their
  figures beside the text they belong to and neither ever did, so every device
  fell through to a tall arrangement with most of the card empty. The figures sit
  on the ends of their own lines now, and the chrome around them gives back
  another 60 points of a 312-point row.

### Fixed

- **A cancelled transcode that carried on.** Releasing the encoder shut its
  worker down without setting the flag the encode loop reads, so an activity
  going away could leave an encode running against a muxer nobody would close.
  A cancel arriving between the request and the worker picking the job up was
  wiped by a reset that ran after it.
- **Access revoked while the app was away.** All-files access can be withdrawn
  from Settings at any time. Both tools re-read it on resume — leaving a scan or
  a run in flight strictly alone, and dropping findings only if the answer
  actually changed.

## [1.0.0] — 2026-08-02

Never published. Superseded by 1.1.0 before it was tagged, and kept here because
it is what the work above was added to.

First release.

### Added

- **Junk cleaner.** Scans the folders each platform actually leaves rubbish in —
  system temp, thumbnail caches, crash dumps, installer leftovers, the app's own
  cache — and lists what it finds by category, with the size and age of every
  file. Nothing is deleted without a confirmation that says how much is going
  and how much of it can be undone.
- **Quarantine.** Deleted files are moved aside rather than removed, and can be
  put back for 7 days. Files over 256 MB are deleted outright, because moving
  them frees nothing; the confirmation says how many, before the fact.
- **Media optimiser.** Re-encodes photos and videos to smaller formats without
  touching their resolution or length, typically freeing a third to a half.
  Video goes through a `MediaCodec` HEVC pipeline written for this app, because
  every video-compression package on pub gets its savings by downscaling, which
  is the one thing this is not allowed to do.
- **Protected paths.** A separate list from the rules, checked after a rule has
  already called something junk. Two lists that must agree, so a mistake in one
  is caught by the other.
- **Age floor.** Nothing under an hour old is offered, because a file written 90
  seconds ago is junk *in use*.
- **Verified replacement.** An optimised file is re-read and its dimensions and
  duration compared against the original before the original is dropped. An
  encoder that hits a corrupt frame and stops writes a file that is valid,
  smaller, and a third as long — size alone would not catch it.
- **Six platforms.** Android, Windows, macOS and Linux in full; iOS limited to
  the app's own container by the system; the web build explains that it cannot
  do this rather than pretending the device is clean.
- **Three languages.** English, Russian and Chinese, switchable from the globe
  icon and defaulting to the device locale.

### Privacy

- No network permission is declared in the release build, so no data can leave
  the device even in principle. No analytics, no crash reporting, no accounts,
  no advertising. See [PRIVACY.md](PRIVACY.md).

[Unreleased]: https://github.com/EvgeniuGlinsky/Storage-Cleaner/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/EvgeniuGlinsky/Storage-Cleaner/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/EvgeniuGlinsky/Storage-Cleaner/releases/tag/v1.1.0
