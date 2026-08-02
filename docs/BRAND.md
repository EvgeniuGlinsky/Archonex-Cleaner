# Brand

What the app looks like, where those colours come from, and how every icon in
the repository is made. This replaces the brief that used to live here asking
for artwork: the artwork arrived, and a document still requesting it would
describe a job already done.

## The two sources

`docs/brand/icon-source.png` and `docs/brand/banner-source.png` are the only
hand-made images in the project. Everything else — every launcher icon on six
platforms, the favicon, the Play listing icon and the feature graphic — is
generated from them by `tool/brand_assets.py` and committed.

Nothing is edited downstream of the generator. A change to an icon is a change
to a number in that script or to a source file, followed by a rerun; an icon
touched by hand is one nobody can reproduce.

## The palette

Every hex below is in `lib/core/theme/app_colors.dart`, and nowhere else in the
code.

| Role | Hex | Where it comes from |
| --- | --- | --- |
| **Primary / seed** | `#5572A1` | `AppColors.seed`, read out of the icon's own field |
| Primary, light theme | `#3F5F90` | generated from the seed by `ColorScheme.fromSeed` |
| Primary, dark theme | `#A8C8FF` | same, at dark-theme tone |
| Freed space (light) | `#2F6B55` | the number a run gives back |
| Freed space (dark) | `#8CC9AF` | same, on a dark background |
| Caution | `#8A6A3C` | a category that wants a second look |
| Danger | `#A34A42` | deleting, and nothing else in the app |
| Neutral | `#5A6472` | protected paths, secondary text |
| Light surface | `#F9F9FF` | generated |
| Dark surface | `#111318` | generated |

Two things about it are deliberate.

**It is muted.** This is a tool people point at their own files and press a
button that deletes them. The register to aim at is something that has been in
the toolbar for years, not something introducing itself. Every colour above was
pulled back from a louder original — the seed most of all, out of the vivid blue
the icon was drawn in.

**One green is left.** The freed-space figure stays green in a blue app, and
that is the whole reason it is still there: on a muted blue field it is the only
warm-shifted thing on the screen, so the number the user came for is now more
prominent than when the entire app was green around it.

## The one blue, in three places

The seed, the launcher's adaptive background (`ic_launcher_background` in
`android/app/src/main/res/values/colors.xml`) and the window shown while the app
starts (`splash_background`, same file) are the same number, and the generator
is what keeps them that way — it prints the colour it read out of the finished
icon and writes the Android resource itself.

They have to agree. Where they do not, the icon arrives framed: a bright square
inside a pale one at launch, or a launcher mask cutting a visible edge across
the icon's own background. Both are the failure this arrangement exists to
prevent, and both are invisible until you look at a real device.

## What an icon has to survive

Still the rule, for any future change:

- **Judge it at 48 px first.** An app icon is seen at that size on a home screen
  and almost never larger.
- **Android's mask can be any shape.** The artwork lives inside the central 66%
  of the adaptive foreground; the corners belong to the launcher.
- **iOS refuses alpha.** Its icons are full squares with the corners filled, and
  the system draws its own mask over them.
- **A maskable web icon reaches every edge.** The browser crops it; a
  transparent margin becomes a visible notch.

`tool/brand_assets.py` handles all four, and the reason for each is written next
to it there.

## After a change

1. `python tool/brand_assets.py`
2. Look at what it wrote — the corners especially, which is where a source
   without an alpha channel leaves black.
3. `flutter build apk --debug` and install on a real phone. Everything above is
   about what happens at 48 px on a home screen, and that is the only place to
   see it.
