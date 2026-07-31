---
name: flutter-feature
description: Use this skill whenever creating, modifying or extending a Flutter feature. This skill defines the mandatory architecture, file structure and coding style for the entire project.
---

# Flutter Feature Architecture

This project follows a strict architecture.

These rules are mandatory.

---

# Feature Structure

Every feature lives in

lib/project_files/features/<feature_name>/

A feature with a screen and data behind it has three layers.

```
feature_name/
│
├── ui/
├── domain/
└── data/
```

Add a layer when something belongs in it, never to fill the shape.

- `splash/` owns no data, so it has `ui/` alone.
- A feature that owns no screen has no page, view or bloc — its `ui/` is mappers and shared widgets, or it has no `ui/` at all.

A second feature gets its own directory rather than a subdirectory of the first as soon as something depends on it: `quarantine/` is separate from `storage_cleaner/` because the cleaner needs somewhere to put files and the quarantine owns retention, and that dependency has to be able to point one way. Each then owns its own failure hierarchy — a sealed class can only be extended in its own library, so one shared hierarchy would make the arrow point both ways.

---

# UI Layer

```
ui/
    feature_name_page.dart          dependency injection and BlocProvider only
    feature_name_view.dart          the screen

    bloc/
        feature_name_bloc.dart
        feature_name_event.dart
        feature_name_state.dart

    mappers/
        <domain_type>_ui.dart       String someKey(BuildContext) per domain value

    widgets/
        feature_name_body.dart      state + callbacks, nothing else
        feature_name_actions.dart   the bottom slot
        feature_name_callbacks.dart the action bundle
        …one file per extracted widget
```

Rules

- feature_name_page.dart is responsible ONLY for dependency injection and BlocProvider.
- feature_name_view.dart contains the actual screen.
- `mappers/` is not optional. No domain type carries user-facing copy, so everything a widget renders about a domain value is mapped here.
- A widget with more than one caller becomes its own file in `ui/widgets/`. A widget with exactly one caller stays private in that file as `_Name` — a file per single-use widget buys nothing and costs an import.
- Widgets inside widgets/ MUST never depend on their parent screen.

---

# Bloc

Business logic belongs ONLY inside Bloc.

Never place business logic inside Widgets.

Bloc MUST be split into

```
feature_name_bloc.dart
feature_name_event.dart
feature_name_state.dart
```

Every `on<Event>` registration passes an explicit `bloc_concurrency` transformer. Three are used, and each has one job.

- `restartable()` — the `<Feature>Started` event, which subscribes to a long-lived stream; a second start must not leave two subscriptions behind.
- `droppable()` — anything that opens a system dialog or a store sheet, or starts a run or a save; the OS shows one dialog, so extra taps must not queue up behind it.
- `sequential()` — everything else, because these handlers await a real file delete and the last tap has to be the one that wins.

`concurrent()` is used nowhere: no handler here is safe to interleave.

---

# Domain Layer

The domain layer contains interfaces and the models they pass.

```
domain/
    feature_repo.dart
    feature_storage.dart
    models/
```

Repositories inside domain MUST always be interfaces, declared as

```dart
abstract interface class MediaConverterRepo {}
```

`abstract interface class`, not `abstract class`: these exist to be implemented and never extended.

Models carry the rules that belong to them — `prunedFor`, `fromExtension`, `effectiveQuality` — so no bloc re-derives them.

The domain layer MUST NOT contain implementation details.

---

# Data Layer

Repository implementations belong ONLY here.

Name the implementation after what makes it different.

- One implementation with nothing to distinguish it takes `_impl`: `language_repo_impl.dart`.
- Two or more take the technology or platform behind them, grouped in a folder of their own: `data/file_system/io_junk_scan_repo.dart`, `data/access/android_storage_access_repo.dart`, `data/prefs_*_storage.dart` — each with its refusing sibling `unsupported_*_repo.dart` beside it, never in `platform/`.
- A sibling that genuinely works in a reduced way is named for what it does rather than `unsupported_`: `empty_quarantine_repo.dart` serves a platform that deletes nothing, and answers every call with a benign value instead of throwing.
- The pure part of a feature gets its own folder and no I/O at all: `data/rules/` holds the platform tables, `ProtectedPaths` and `DeletionGuard`. Splitting it that way is what makes the dangerous half unit-testable and the half that touches the disk a loop with nothing to decide.

If UseCases are required, they also belong here, in a folder of their own.

```
data/use_cases/login_use_case.dart
```

UseCases depend on the `domain/` interface, never on an implementation — that is what lets a test hand them a fake. Which implementation sits behind the interface is decided once, on the platform boundary in `data/platform/`.

Bloc MUST communicate ONLY with UseCases.

Flow

```
Bloc
    ↓
UseCase
    ↓
Repository Interface
    ↓
Repository Implementation
```

---

# Widget Structure

Every screen should be divided into small classes.

Avoid large build() methods.

A `build` returns one composition. When a branch needs an `if` or a `switch` over state, it becomes a named widget or a private method returning one, rather than a deeper tree.

---

# Screen Architecture

Every screen MUST follow this structure.

```
FeaturePage            dependency injection and BlocProvider only
    ↓
FeatureView            BlocListener, BlocBuilder, callbacks — no layout maths
    ↓
AppScreenLayout        lib/core/widgets — positioning only, slots via constructor
    ├── header:  AppScreenHeader(title:, subtitle:)
    ├── body:    FeatureBody(state:, callbacks:)
    └── bottom:  FeatureActions(state:, onConvertPressed:)
```

`AppScreenLayout` builds no content: every slot arrives through the constructor.

Correct example

```
AppScreenLayout(
    header: AppScreenHeader(...),
    body: FeatureBody(...),
    bottom: FeatureActions(...),
)
```

Incorrect

```
AppScreenLayout()

...

Widget build(...) {
    return Column(
        children: [
            Header(),
            Body(),
            Bottom(),
        ],
    );
}
```

A feature writes a layout of its own only where the shared one does not fit. `SplashLayout` is the single case, because splash has no header and no bottom.

Layout classes are responsible ONLY for alignment, spacing and positioning.

---

# Theme

Colours, type and everything else the design decides live in **one folder**, and
nowhere else:

```
lib/core/theme/
    app_colors.dart         every Color literal in the application
    app_typography.dart     every TextStyle literal in the application
    app_theme.dart          light() and dark(), assembled from the two above
```

Rules

- `Color(0x…)` appears in `app_colors.dart` and **nowhere else**. Not in a
  widget, not in `app_theme.dart`, not in a constants file. A grep for `Color(0x`
  outside that file is a bug.
- A literal `fontSize` or `fontWeight` appears in `app_typography.dart` and
  nowhere else. A widget that needs a variant does `theme.textTheme.titleMedium
  ?.copyWith(fontWeight: AppTypography.semiBold)` — a *named* weight, never the
  number 700.
- `app_theme.dart` defines nothing. It reads the other two files and
  `core/constants/`, and if a literal appears in it, it is in the wrong one of
  the three.
- A colour Material does not define — a destructive red, a "freed space" green, a
  "look at this first" amber — is a field on `AppColors`, which is a
  `ThemeExtension`. Widgets read it as `AppColors.of(context)`.
- `AppColors` is a `ThemeExtension` and **not** a pair of static getters taking a
  `Brightness`. The getters compile just as well and quietly return the light
  colour inside a dark dialog, because nothing forces the caller to pass the
  brightness actually in effect.
- Every widget reads `Theme.of(context)` into a local on the first line of
  `build` and uses that. No second call further down.
- A bundled font family is one constant (`AppTypography.fontFamily`) plus an
  `assets:` entry in `pubspec.yaml`. Nothing else in the app changes, and
  `null` — the platform's own UI font — is a legitimate value with a reason
  written next to it.

`widget_test.dart` pumps both themes and asserts the extension is registered on
each, because a theme built without it fails at whichever widget happens to need
a colour first rather than at the theme.

---

# Constants

Avoid magic numbers.

Avoid hardcoded values.

A value two files share lives in `lib/core/constants/app_*.dart`.

```dart
class AppSpacing {
    const AppSpacing._();

    static const double lg = 16;
}
```

A value only one widget uses is a private `static const` above that widget's fields, named for what it is.

```dart
static const double _gap = AppSpacing.lg;
static const double _iconSize = 28;
```

Widgets use those names instead of raw numbers — spacing, dimensions, radius, colors, durations, paddings, font sizes.

---

# Clean Code

Always write maintainable code.

Requirements

- Single Responsibility Principle
- Small methods
- Small widgets
- Meaningful naming
- No duplicated logic
- No dead code
- No unnecessary comments
- Prefer composition over inheritance

Extract code instead of making huge methods.

---

# Dependency Direction

Dependencies always point downward.

```
UI
    ↓
Bloc
    ↓
UseCase
    ↓
Repository Interface
    ↓
data/platform/<feature>_platform.dart      conditional export picks one
    ↓
real implementation    |    unsupported_ sibling
```

Never violate this direction.

---

# Goal

Generated code should be:

- modular
- reusable
- testable
- readable
- scalable
- predictable

Architecture consistency is more important than writing the fewest lines of code.

---

# Settled conventions

Each of these already holds across the codebase. Match it rather than inventing a second way.

This file owns the shapes — where a file goes, what it is called, what it declares. `CLAUDE.md` owns the rules whose violation nothing catches at build time: failures, jobs, protected paths, the quarantine, bloc state, selection, tests, doc comments. A rule belongs in one of the two, never both.

## Use cases

- **Add one**: one use case per file in `data/use_cases/`, plus the result type it needs — a single public method named `call`, a `const` constructor taking `domain/` interfaces (named required parameters once there are several), and no state. It returns a domain model, a `Stream`, a `Future` or a job handle, never an `Either` or `Result` wrapper: a partial outcome gets a named model (`CleanReport`), and a failure is thrown.
- **Use it**: a use case repeats the screen's guards on purpose — `ScanForJunkUseCase` re-checks `isSupported` and `access.canScan` — so the contract holds however the call was assembled and a bloc never decides whether a platform has a file system. A repository that outlives a screen publishes changes as a `ValueListenable`, and a `watch*UseCase` adapts it to the `Stream` the bloc lives on, emitting the current value on subscribe so a screen opened after the change still sees it.

## Domain models

- **Add one**: `final class X extends Equatable` with a `const` constructor, every field `final` and `props` last — or an enum with fields where the model is a closed set. `copyWith` goes only on the models the UI mutates; how it clears a nullable field is in `CLAUDE.md`, because a state class answers to the same rule. A model that has to sit inside a sealed hierarchy mixes `Equatable` in rather than extending it.
- **Use it**: the rules live on the model — `JunkCategory.selectedByDefault`, `JunkGroup.selectedItems`, `QuarantineBatch.daysLeftAt`, `StorageAccess.isNarrowed` — so no bloc re-derives them and no two widgets derive them differently. A field the model could compute but two platforms answer differently stays a field: `StorageAccess.canRequestMore` is one, because iOS and Android are both `appOnly` and only one of them has anything to ask for.

## Rule tables

- **Add one**: one file per platform in `data/rules/`, each a `const X._()` static holder returning `List<JunkRule>` from a `CleanerRoots`. Pure: no `dart:io`, no `Platform`, no plugin. Everything machine-specific is resolved once by `CleanerRootsResolver` and handed in, which is what lets the Windows table be tested from Linux CI. A row that must exist but never run carries the reason as a flag (`needsElevation`) and is filtered out in `JunkRuleset.of`, with `declaredFor` left public so a test can prove it was declared *and* dropped.
- **Use it**: adding a location is a row. Adding a *kind* of matching is a `JunkRuleMode`, and there are four, which has been enough. `JunkRuleset` is the only place a platform is asked which table to use, so the walker never asks.

## Key–value storage

- **Add one**: `abstract interface class <X>Storage` in the feature's `domain/` root and `prefs_<x>_storage.dart` implementing it — one typed key per field named `'namespace.field'`, a `DateTime` stored as a `_millis` int, and `read()` returning `null` on a first run. `SharedPreferencesAsync` is built lazily behind an optional positional override, because the object is constructed while the app root is still building and a test needs a way in.
- **Use it**: clocks, periods and expiry are the repository's rules, which is what lets them be tested without a platform plugin; storage only reads and writes. A failed read or write is caught and answered from memory, so a broken store costs the user their next launch rather than this one. Nothing uses this yet — the quarantine index is deliberately a file beside its data, see `CLAUDE.md`.

## Screen callbacks

- **Add one**: `ui/widgets/<feature>_callbacks.dart` — `@immutable`, a `const` constructor, only `VoidCallback` and `ValueChanged<T>` fields where `T` is a domain type or a small record the row needs, importing `foundation.dart` and domain models and nothing else. Eleven separate parameters would make every widget signature a wall of arguments; one bundle keeps the widgets receiving nothing but functions.
- **Use it**: the view builds it in a private `_callbacks(context)` whose entries are one-line `_add(context, Event())` calls, apart from a navigation or a confirmation that is not an event. `context.read<Repo>()` appears only in `<feature>_page.dart` and `context.read<Bloc>()` only in `<feature>_view.dart`; nothing under `ui/widgets/` imports `flutter_bloc` or `go_router`.

## Routing

- **Add one**: one `AppRoute` enum entry carrying `path`, with `routeName => name` as the single source of truth, and one `GoRoute` in `app_router.dart`; a child route takes a relative path and nests under its parent.
- **Use it**: navigate with `goNamed`, or `pushNamed` for a detour that has to come back — the quarantine is pushed so returning lands on the scan results still on screen. A screen reachable both ways asks `GoRouter.of(context).canPop()` rather than guessing. Routes take no arguments: a screen reads what it needs from an app-wide repository.
