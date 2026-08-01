# Brand prompts

Copy-paste prompts for generating the artwork this project still needs. Written
for Midjourney, DALL·E, Ideogram or any image model that takes prose.

Everything below uses the app's real colours, read out of
`lib/core/theme/app_colors.dart`, so what comes back matches the screen it will
sit next to rather than a green that is nearly right.

## The palette

| Role | Hex | Where it comes from |
| --- | --- | --- |
| **Primary / seed** | `#17A47B` | `AppColors.seed` — the colour the whole theme is generated from |
| Freed space (light) | `#11785A` | The number a run gives back |
| Freed space (dark) | `#5FE3B4` | Same, on a dark background |
| Caution | `#9A6400` | A category that wants a second look |
| Danger | `#B3261E` | Deleting, and nothing else in the app |
| Neutral | `#5A6472` | Protected paths, secondary text |
| Dark surface | `#101B17` | A near-black with the seed's green in it |
| Light surface | `#F5FAF8` | An off-white with the same |

Green rather than blue on purpose: the sibling project, Archonex Converter, is
blue, and the two are meant to read as related and not identical.

## What the icon has to survive

Judge every candidate at **48 px** before anything else. An app icon is seen at
that size on a home screen and almost never larger, and most generated icons
turn into a coloured smudge there.

Concretely:

- One shape, readable in silhouette. Not a scene, not a composition.
- No text, no letters, no numbers. They are unreadable at 48 px and every model
  spells them wrong anyway.
- No gradients doing the work. A gradient is decoration on top of a shape that
  must already read in flat colour.
- Two colours, three at the very most.
- **Not a broom, a bin, a vacuum cleaner, a rocket or a sparkle.** Every app in
  this category uses those, which is exactly why the icon should not.

The honest metaphors for this app are *space returned* and *the same thing, made
smaller*: a container with room in it, a shape compressed without distortion, an
arrow inward.

## Prompt — app icon

```
A minimal, flat vector app icon. A rounded square container seen straight on,
with a solid emerald-green fill occupying the lower third and clear empty space
above it — the visual of a drive with room freed at the top. A single clean
downward chevron sits centred in the empty space, suggesting compaction.
Geometric, perfectly symmetrical, heavy weight so it reads at small sizes.
Two colours only: emerald green #17A47B on an off-white #F5FAF8 background.
No text, no letters, no gradient, no shadow, no outline, no 3D. Flat design,
solid shapes, generous margins. Centred composition on a square canvas.
```

Ask for four variations and judge them scaled to 48 px, not at full size.

### Dark variant

Same prompt, with the last colour line replaced:

```
Two colours only: mint green #5FE3B4 on a near-black #101B17 background.
```

### If the chevron reads as a download arrow

It will, sometimes, and that is the wrong idea entirely. Try instead:

```
…with two horizontal bars in the empty space above the fill, the upper bar
noticeably shorter than the lower — the same content, made smaller.
```

## Prompt — Android adaptive icon

Android needs the foreground and background as separate layers, because the
system masks them into whatever shape the launcher uses, and it animates them
independently.

**Foreground** (safe zone is the centre 66% — anything outside is cropped on
some launchers):

```
A single flat vector symbol, centred, on a fully transparent background.
[the shape settled on above], solid emerald green #17A47B, no background,
no container, no shadow. The symbol occupies the central 60% of the canvas
with empty transparent margin all around. PNG with alpha, 1024x1024.
```

**Background** — do not generate this. Export a flat `#F5FAF8` square (or
`#101B17` for the dark theme). A generated background layer means detail that
the launcher mask cuts through at a different place on every device.

## Prompt — Play feature graphic (1024×500)

Shown at the top of the store listing. It is a banner, not an icon, and it is
frequently cropped on the sides.

```
A wide minimal banner, 1024x500, for a storage cleaning app. Left third: the
app icon, large and centred vertically. Right two-thirds: generous empty space
with a subtle abstract representation of storage — a horizontal bar mostly
empty with a small filled section at one end, in emerald green #17A47B.
Background is a smooth very dark surface #101B17. Flat vector, no photography,
no text, no people, no devices, no 3D rendering. Calm and uncluttered, with
large empty margins.
```

Leave it wordless and add the title in an image editor afterwards. Models set
type badly, and Play will crop the sides on some layouts — text in the middle
third survives, text near an edge does not.

## Prompt — screenshot backdrop

Play wants screenshots on a background rather than bare. This is the plate the
device frames sit on:

```
A seamless abstract background, portrait 1080x1920, for app store screenshots.
A very subtle vertical gradient from #101B17 to #16241F, with a faint
large-radius emerald glow behind the centre. Extremely low contrast, no
pattern, no texture, no objects, nothing in focus. It must sit behind a device
screenshot without competing with it.
```

## Prompt — Windows `.ico` and macOS `.icns`

Same artwork as the app icon. Desktop icons appear at 16 px in a taskbar, which
is smaller than anything on a phone:

```
[the icon prompt above], simplified further for 16-pixel display: thicker
strokes, larger shapes, fewer elements, higher contrast between the two
colours.
```

## What to do with the results

Once you have a 1024×1024 master:

1. `flutter_launcher_icons` generates every platform's sizes from one file. Add
   it to `dev_dependencies`, point it at the master and the adaptive layers, and
   run it — nothing needs drawing twice.
2. Replace `web/favicon.png` and the four `web/icons/Icon-*.png`. The
   maskable variants need the symbol inside the centre 80%.
3. `windows/runner/resources/app_icon.ico` and the macOS
   `AppIcon.appiconset` are the two the tool sometimes leaves alone — check
   both after running it.
4. The theme colours in `web/manifest.json` are already `#17A47B`; if the icon
   settles on a different green, change them together.

The one thing worth checking after all of it: install on a real phone and look
at the home screen. Everything above is about what happens at 48 px, and that is
the only place to see it.
