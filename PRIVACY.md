# Privacy Policy

**Storage Cleaner**
Last updated: 2 August 2026

## The short version

Storage Cleaner collects nothing, sends nothing, and cannot. It has no account,
no analytics, no crash reporting, no advertising and no network permission at
all.

## What the app collects

Nothing.

There is no data collection of any kind: no personal information, no device
identifiers, no usage statistics, no diagnostics, no advertising identifiers, no
contacts, no location.

## What the app sends

Nothing, and not as a promise — as a property of the build.

The Android release does not declare `android.permission.INTERNET`. Without it
the operating system refuses every network call the app could make, including
ones made on its behalf by a library. You can check this yourself on any release
APK, without trusting this document:

```
aapt2 dump permissions storage-cleaner-1.0.0-android-arm64.apk
```

The complete list it prints is:

| Permission | What it is for |
| --- | --- |
| `MANAGE_EXTERNAL_STORAGE` | Finding files outside the app's own folder to clean or shrink. Requested only when you press *Grant access*, and the app works without it on a reduced set of folders. |
| `READ_EXTERNAL_STORAGE` (Android 12 and below) | The same, on versions predating the permission above. |
| `WRITE_EXTERNAL_STORAGE` (Android 10 and below) | Deleting and rewriting files on those versions. |
| `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Added automatically by AndroidX. It is an internal marker that keeps the app's own broadcast receivers private to it, and grants nothing. |

There is no `INTERNET` in that list. That is the whole privacy story.

## What the app stores, and where

Everything stays on your device.

- **Quarantined files.** A cleanup moves files into a folder inside the app's
  own storage instead of deleting them, so they can be put back. They are
  deleted for good after 7 days, or when you empty the quarantine yourself. An
  index of them lives in a `manifest.json` beside them.
- **Your settings.** The chosen language, and which categories you have switched
  off, in the platform's standard preference store.
- **Nothing else.** The app keeps no history of what it scanned, no list of your
  files, and no record of what it deleted beyond the quarantine itself.

Uninstalling the app removes all of it — including anything still in quarantine,
which is worth knowing before uninstalling with files you meant to restore.

## Files the app changes

The cleaner deletes files, via a quarantine you can restore from for 7 days.

The optimiser re-encodes photos and videos **in place, permanently**. There is
no quarantine on that path and there cannot be: keeping the original means
holding both copies, which frees nothing, and freeing space is what the button
was pressed for. The confirmation dialog says so before anything happens.

Neither tool reads a file's contents for any purpose other than doing the job
you asked for, and neither sends any part of a file anywhere.

## Children

The app has no content, no accounts and no data collection, so there is nothing
here specific to children. It is not directed at them and does not knowingly
collect anything from anyone.

## Permissions on other platforms

Windows, macOS and Linux use the rights the process already has as your user
account, and ask for nothing extra. iOS is limited to the app's own container by
the system, which is why the cleaner finds very little there.

## Changes to this policy

Changes are committed to this file in the public repository, so the history of
this document is the history of the project. Anything material is also noted in
`CHANGELOG.md`.

## Verifying any of this

The app is open source under the Apache License 2.0. The source is at
<https://github.com/EvgeniuGlinsky/Storage-Cleaner> and the releases are built
in public by a GitHub Actions workflow you can read in `.github/workflows/`.

You do not have to take this document's word for anything in it.

## Contact

Open an issue at
<https://github.com/EvgeniuGlinsky/Storage-Cleaner/issues>.
