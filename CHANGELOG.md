# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-08-02

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

[Unreleased]: https://github.com/EvgeniuGlinsky/storage-cleaner/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/EvgeniuGlinsky/storage-cleaner/releases/tag/v1.0.0
