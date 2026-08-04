import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing credentials, kept out of the repository and out of this file.
//
// `key.properties` is listed in `android/.gitignore` along with `*.jks`, so a
// clone never carries the key. It is absent far more often than it is present —
// on a fresh checkout, on a contributor's machine, in the analyse-and-test CI
// job — and every one of those still has to be able to build. See
// `docs/RELEASING.md` for how to create it and how the release workflow feeds
// it in from a secret.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()

if (hasKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "io.github.evgeniuglinsky.storagecleaner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.github.evgeniuglinsky.storagecleaner"
        // `MANAGE_EXTERNAL_STORAGE` and the settings screen that grants it both
        // arrived in Android 11 (API 30). Below that the app falls back to the
        // legacy storage permissions declared in the manifest, which is why
        // Flutter's default minimum is kept rather than raised to 30.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                // `rootProject.file`, not `file`. This block belongs to the
                // `:app` module, so a bare `file()` resolves a relative path
                // against `android/app/` — while `key.properties` itself sits in
                // `android/`, and both the release workflow and anyone following
                // `docs/RELEASING.md` write a path meaning "beside this file".
                // The mismatch costs nothing until the day it matters, and then
                // it is `Error: Missing keystore` against a path nobody wrote,
                // on a tag that has already been pushed. An absolute path is
                // returned unchanged either way.
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key rather than failing the build. A
            // debug-signed release is fine to run and impossible to publish —
            // no store accepts one — so the fallback costs nothing and keeps
            // `flutter build apk --release` working for anyone who just cloned
            // the repository. Publishing without a key is caught by the store,
            // not by us guessing on their behalf.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 on both counts, worth 3.1 MB of a 22.4 MB arm64 APK — a
            // seventh of it, measured rather than assumed, because most of what
            // is in a Flutter release is the engine and the AOT snapshot and
            // neither of those is something R8 can touch.
            //
            // The app ships no reflection of its own, and what does need
            // keeping is in `proguard-rules.pro` — the platform channel
            // surface, which Kotlin reaches by the string name of a method and
            // which looks unreachable from the bytecode.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
