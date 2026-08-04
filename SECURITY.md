# Security Policy

This application deletes files and rewrites them in place. A bug in it costs
somebody their photographs, so security reports are read with that in mind.

## Reporting a vulnerability

Use GitHub's private reporting: **Security → Report a vulnerability** on
<https://github.com/EvgeniuGlinsky/Storage-Cleaner>. It reaches the maintainer
without the report becoming public first.

Please do not open a public issue for anything in the categories below.

Expect a first reply within about a week. This is a small project without a
security team, and there is no bounty programme.

## What is in scope

The things that would cost a user their data:

- **A protected path that is not protected.** Anything that makes the app offer
  to delete something outside the rules in `ProtectedPaths` — a traversal
  through a symlink, a path-normalisation difference between platforms, a rule
  matching further than it reads.
- **Data loss in the replace ladder.** `IoMediaOptimizeRepo` replaces a file
  with a re-encoded version through a sequence of renames. Any interleaving
  that can leave the user with neither file, or with a truncated one presented
  as the original, is the most serious class of bug this project has.
- **Verification that can be fooled.** The optimiser compares the re-encoded
  file's dimensions and duration against the original before dropping it. A
  file that passes that check while being materially shorter or lower quality
  defeats the one safeguard on an irreversible operation.
- **Quarantine escape.** A restore that writes outside the path it recorded, or
  a manifest entry that can be made to point somewhere else.
- **Anything that reaches the network.** The release build declares no
  `INTERNET` permission. If you find a way for the app to transmit anything,
  that is a report worth making regardless of how it happens.

## What is out of scope

- The app requires `MANAGE_EXTERNAL_STORAGE` on Android and asks for it
  explicitly. That it can then read files is the feature, not a vulnerability.
- Desktop builds run with the rights of the user who started them, and can
  delete what that user can delete. Same answer.
- A locked or in-use file being skipped is reported to the user as skipped. That
  is intended.
- Reports from automated scanners with no accompanying analysis of what an
  attacker could actually do.

## Verifying a release

Every GitHub release carries `SHA256SUMS.txt`:

```bash
sha256sum -c SHA256SUMS.txt
```

Android builds are signed with the project's release key; the fingerprint is on
the releases page. F-Droid builds from source on its own infrastructure and
signs with its own key, so those APKs are a different signature by design and
will not install over each other.

Windows and Linux builds are unsigned. Code signing certificates cost money this
project does not take, so a SmartScreen prompt on Windows is expected — check
the checksum rather than the signature.
