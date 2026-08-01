# R8 rules for the release build.
#
# Kept deliberately short. This app has no reflection of its own, no
# serialisation library, and no dependency injection that resolves classes by
# name, so the default rules that ship with AGP and the ones Flutter's Gradle
# plugin contributes cover nearly everything. What is here is what R8 cannot
# see from the bytecode alone.
#
# When adding to this file, say what calls the thing and cannot be seen calling
# it. A -keep with no reason attached is a rule nobody can ever safely remove.

# The one platform channel this project owns. `MainActivity` constructs
# `MediaTranscoderChannel` directly, so that class is reachable — but the
# `MediaCodec` and `MediaMuxer` pipeline underneath it is driven through
# framework callbacks, and the Dart side reaches it by the string name of a
# method rather than by a call R8 can follow. See `MediaTranscoder.kt`.
-keep class com.archonex.cleaner.MediaTranscoder { *; }
-keep class com.archonex.cleaner.MediaTranscoderChannel { *; }

# Flutter's embedding is entered from native code the shrinker never analyses:
# the engine loads `FlutterActivity` and its plugin registrant by name.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Play Core, which is not a dependency and is not going to be.
#
# The embedding ships `PlayStoreDeferredComponentManager` for apps that split
# themselves into downloadable feature modules. This one does not — it is a
# single APK, and on F-Droid and the GitHub releases there is no Play Store to
# ask — so those classes are never on the classpath and R8 stops on eight
# unresolved references before it emits anything.
#
# `-dontwarn` rather than adding the dependency: pulling in Play Core to satisfy
# a code path that cannot execute would put a proprietary library into a build
# that has no network permission at all.
-dontwarn com.google.android.play.core.**

# `MediaCodec` reports through a callback subclass instantiated by the platform.
-keepclassmembers class * extends android.media.MediaCodec$Callback {
    *;
}

# Android's own annotations, read at runtime by the support libraries.
-keepattributes *Annotation*

# Keep line numbers in a stack trace, and hide the original file name.
#
# A crash report from a release build is otherwise a list of `a.b.c(SourceFile)`
# and useless to act on. This costs a few kilobytes and is the difference
# between a bug report that can be fixed and one that cannot.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
