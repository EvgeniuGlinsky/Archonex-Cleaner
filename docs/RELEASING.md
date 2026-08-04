# Releasing

Everything a release needs that is not in the repository, and why it is not.

The short version: create a signing key once, put it in GitHub Secrets, then
every release is a version bump and a tag. `.github/workflows/release.yml` does
the rest.

## The signing key

Android requires every APK to be signed, and requires **the same key forever**.
Google Play refuses an update signed with a different one, and there is no
appeal and no reset — losing this file means publishing under a new listing and
asking every user to reinstall by hand.

So it is not in the repository, and it must not be. `android/.gitignore` already
lists `key.properties`, `**/*.jks` and `**/*.keystore`.

### Create it, once

```bash
keytool -genkeypair -v \
  -keystore ~/storage-cleaner-upload.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload
```

`-validity 10000` is about 27 years. Play rejects a key that expires before
2033, and a key that expires is a key you cannot ship an update with.

Keep the file and the passwords in a password manager. Not in the repository,
not in a chat window, not in a note beside the project.

### Build locally with it

Create `android/key.properties` — untracked, and the build reads it if present:

```properties
storeFile=/absolute/path/to/storage-cleaner-upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Without this file the release build falls back to the debug key. That is
deliberate: a fresh clone still builds, and a debug-signed release is something
no store will accept, so the mistake cannot travel further than your own device.

Check which key an APK carries:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

`CN=Android Debug` means the fallback was used.

### Give it to CI

Four secrets, under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 storage-cleaner-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |

On macOS `base64 -w0` is `base64` with no flag; on Windows use
`certutil -encode` and strip the header and footer lines.

The workflow fails loudly if `ANDROID_KEYSTORE_BASE64` is missing rather than
falling through to the debug key, because at that point an artefact is about to
be published and the fallback would produce one nobody can install over.

## Cutting a release

1. Update `CHANGELOG.md`. The entry is what the release notes point at.
2. Bump `version:` in `pubspec.yaml`. The `+N` build number must increase on
   every Play upload, even a re-upload of the same version name.
3. Commit both.
4. Tag and push:

   ```bash
   git tag v1.1.0
   git push origin main --tags
   ```

The tag must match `pubspec.yaml` — `v1.1.0` against `version: 1.1.0+2`. The
workflow checks this first and stops before building anything if they disagree,
which is almost always a tag pushed before the bump was committed.

To undo a tag pushed too early, delete it locally and remotely, then re-tag:

```bash
git tag -d v1.1.0 && git push origin :refs/tags/v1.1.0
```

Deleting the tag does not delete a release that was already created. Delete that
from the Releases page too, or the next run will fail on a name that exists.

## Building by hand

Rarely needed, since the workflow covers all four platforms. When it is:

```bash
flutter build apk --release --split-per-abi   # four APKs
flutter build appbundle --release             # Play
flutter build windows --release               # build/windows/x64/runner/Release
flutter build linux --release                 # needs ninja-build, libgtk-3-dev
flutter build macos --release                 # build/macos/Build/Products/Release
```

Only the first three can be built from one machine, and which three depends on
which machine. Nothing on Windows produces a Linux or a macOS build; that is
what the runners are for.

Pack a `.app` with `ditto -c -k --keepParent`, never `zip -r`. A bundle keeps
symlinks in `Contents/Frameworks` pointing at the current version of each
framework, and `zip` follows them — the archive comes out with several copies of
every framework and an app that will not launch. The release job uses `ditto`
for that reason, and the size is how you can tell: 47 MB of bundle packs to 20.

**After a rename, delete `build/` first.** CMake caches the project and binary
name from the previous configure, and a stale cache fails with a wall of
`Error evaluating generator expression` that says nothing about the cause. CI
never hits this — a fresh checkout has no cache — so it is a local trap only.

## Two things in the Android build that look wrong and are not

**The Kotlin workaround in `android/build.gradle.kts`.** It applies
`org.jetbrains.kotlin.android` to the `disk_space_2` subproject. Without it the
release build fails with `Could not find method kotlin()`. It looks like dead
configuration for a plugin that already works; it is not, and removing it breaks
the release build only — debug builds carry on fine, so the damage shows up at
the worst moment.

**`-dontwarn com.google.android.play.core.**` in `proguard-rules.pro`.** Flutter's
embedding references Play Core for downloadable feature modules. This app is a
single APK and has no network permission at all, so those classes are never on
the classpath, and R8 stops on eight unresolved references before emitting
anything. Answered by telling R8 not to warn rather than by adding a proprietary
dependency to satisfy a code path that cannot run.

## Publishing to the stores

The workflow publishes to GitHub Releases and stops there. Both stores want a
human to press the button, and one of them wants an argument prepared first:

- **F-Droid** — see `metadata/`. No account, no fee, no permission review.
  Worth doing first and independently of Play.
- **Google Play** — see `docs/PLAY_SUBMISSION.md`. `MANAGE_EXTERNAL_STORAGE`
  needs a declaration, and the category this app is filed under is not one of
  the ones Google names. Read that document before opening the console.
