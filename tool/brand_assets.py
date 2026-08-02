"""Generates every icon and store image in this repository from two sources.

Run by hand, output committed. It is deliberately not part of CI: the assets are
in the tree, and a job that regenerated them on every push would be re-deriving
files nobody changed from files nobody changed.

Python and Pillow rather than Dart and `package:image`, which is already a
dependency: the feature graphic needs real TTF text in three scripts including
Han, and `package:image` draws only bitmap fonts. Pillow covers the alpha masks,
the multi-size ICO and the text in one place, so there is one generator instead
of two.

    pip install pillow
    python tool/brand_assets.py

Sources live in `docs/brand/` and are never edited. Everything this writes is
derived, so a bad run is fixed by fixing the numbers here and running it again.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON_SOURCE = ROOT / "docs" / "brand" / "icon-source.png"
BANNER_SOURCE = ROOT / "docs" / "brand" / "banner-source.png"

# How far the source's colour is pulled back.
#
# The artwork arrived in a vivid blue that reads as loud next to the app it
# labels. Saturation is more than halved and the field is darkened in proportion
# to how saturated it already is, which is what keeps the broom white: white has
# no saturation, so the darkening term is zero there and only the blue moves.
# Picked by rendering the candidates side by side rather than by arithmetic.
MATTE_SATURATION = 0.55
MATTE_VALUE = 0.62

# Where the black corners end.
#
# The source is RGB with no alpha and its corners are filled with pure black,
# so the shape is separated by luminance alone. The threshold sits well under
# the darkest real colour in the artwork (the field bottom, luma ~98) and well
# over the corners (0). The mask is then eroded by two pixels at 1254 so the
# anti-aliased blend of black into blue falls outside it — otherwise every
# downscale carries a dark fringe. Two pixels here is a sixth of one pixel at
# the largest icon this writes.
CORNER_LUMA_THRESHOLD = 50
CORNER_ERODE_PX = 2

# How far the field colour is pushed out past the mask.
#
# A downscale blends RGB across the alpha boundary, so whatever colour sits in
# the transparent corner ends up in the edge pixels. Left as it came, that is
# black. Spreading the field outward first means the blend pulls in blue, and
# the corner reads clean at 48 px, which is the only size that matters.
CORNER_SPREAD_PX = 10

# Android's adaptive icon reserves the middle 72dp of 108dp; the rest is what
# the launcher's mask may cut away. The whole squircle is scaled into that
# circle, over a background of its own field colour, so the mask never crosses
# anything but flat colour whatever shape it is.
ADAPTIVE_SAFE_FRACTION = 72 / 108

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# Google Play's feature graphic, fixed by Play and not negotiable.
FEATURE_SIZE = (1024, 500)

# Roboto is what the app itself renders in, and it ships inside the Flutter SDK
# under Apache-2.0. Han is not in it, so Chinese falls back to a system face.
FLUTTER_FONTS = Path(
    os.environ.get("FLUTTER_ROOT", "C:/tools/flutter")
) / "bin" / "cache" / "artifacts" / "material_fonts"
CJK_FONT = Path("C:/Windows/Fonts/msyh.ttc")

FEATURE_TEXT = {
    "en-US": ("Storage Cleaner", "Free up space. Nothing leaves your device."),
    "ru": ("Storage Cleaner", "Освободите место. Ничего не покидает устройства."),
    "zh-CN": ("Storage Cleaner", "释放空间，数据不离开设备。"),
}


def matte(image: Image.Image) -> Image.Image:
    """Pulls the source back into the register the app is themed in."""
    hue, saturation, value = image.convert("HSV").split()

    faded = saturation.point(lambda p: int(p * MATTE_SATURATION))
    # value * (1 - k * saturation), done in integer channels: `multiply` is
    # exactly (a * b) / 255, which is the term needed.
    darkening = ImageChops.multiply(value, saturation).point(
        lambda p: int(p * (1.0 - MATTE_VALUE))
    )
    darkened = ImageChops.subtract(value, darkening)

    return Image.merge("HSV", (hue, faded, darkened)).convert("RGB")


def corner_mask(image: Image.Image) -> Image.Image:
    mask = image.convert("L").point(
        lambda p: 255 if p > CORNER_LUMA_THRESHOLD else 0
    )

    for _ in range(CORNER_ERODE_PX):
        mask = mask.filter(ImageFilter.MinFilter(3))

    return mask


def cut_corners(image: Image.Image) -> Image.Image:
    """The squircle with its black corners replaced by transparency."""
    mask = corner_mask(image)

    spread = image
    for _ in range(CORNER_SPREAD_PX):
        spread = spread.filter(ImageFilter.MaxFilter(3))

    out = Image.composite(image, spread, mask).convert("RGBA")
    out.putalpha(mask)

    return out


def keyed_mark(icon: Image.Image) -> Image.Image:
    """The artwork with its own background taken away.

    For the one place the icon is drawn onto the same colour it is made of: the
    splash. A rounded tile there sits on a field eight values away from its own
    and reads as a second background behind the first, which is the whole thing
    this app's launch was fixed to stop doing.

    The field is keyed by distance from a per-row reference rather than from one
    colour, because it is a gradient. The reference is the first opaque pixel on
    each row, which is always field: the artwork is centred and never reaches
    the squircle's edge. The broom is 200 away and the ring 58, so the two
    thresholds have a wide gap to sit in.
    """
    width, height = icon.size
    rgb = icon.convert("RGB").load()
    alpha = icon.split()[3].load()

    near, far = 26, 64
    mark = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out = mark.load()

    for y in range(height):
        reference = None
        for x in range(width):
            if alpha[x, y] > 250:
                reference = rgb[x, y]
                break

        if reference is None:
            continue

        for x in range(width):
            if alpha[x, y] < 250:
                continue

            r, g, b = rgb[x, y]
            distance = (
                (r - reference[0]) ** 2
                + (g - reference[1]) ** 2
                + (b - reference[2]) ** 2
            ) ** 0.5

            if distance <= near:
                continue
            if distance >= far:
                out[x, y] = (r, g, b, 255)
            else:
                out[x, y] = (r, g, b, int(255 * (distance - near) / (far - near)))

    return mark


def field_colour(image: Image.Image) -> tuple[int, int, int]:
    """The one blue everything else is keyed to.

    Read out of the finished artwork rather than chosen beside it, so the app's
    seed, the adaptive icon's background and the splash are the same number and
    cannot drift apart.
    """
    w, h = image.size
    samples = [
        image.getpixel((int(w * 0.05), int(h * 0.50))),
        image.getpixel((int(w * 0.50), int(h * 0.06))),
        image.getpixel((int(w * 0.95), int(h * 0.50))),
        image.getpixel((int(w * 0.50), int(h * 0.94))),
    ]
    samples = [s[:3] for s in samples]

    return tuple(sum(c[i] for c in samples) // len(samples) for i in range(3))


def flatten(icon: Image.Image, colour: tuple[int, int, int]) -> Image.Image:
    """Full square, no alpha — what iOS, Play and a maskable web icon want."""
    plate = Image.new("RGB", icon.size, colour)
    plate.paste(icon, (0, 0), icon)

    return plate


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def scaled(icon: Image.Image, size: int) -> Image.Image:
    return icon.resize((size, size), Image.LANCZOS)


def write_android(icon: Image.Image, colour: tuple[int, int, int]) -> None:
    print("android")
    res = ROOT / "android" / "app" / "src" / "main" / "res"

    for name, factor in DENSITIES.items():
        # 48dp is the legacy launcher icon, for the two API levels below
        # adaptive icons that this app still supports.
        save(scaled(icon, int(48 * factor)), res / f"mipmap-{name}" / "ic_launcher.png")

        # 108dp foreground, with the artwork inside the 72dp the mask cannot
        # reach. It keeps its own field: the background layer under it is the
        # same colour, so the squircle's edge has nothing to show against.
        edge = int(108 * factor)
        inner = int(edge * ADAPTIVE_SAFE_FRACTION)
        foreground = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
        art = scaled(icon, inner)
        foreground.paste(art, ((edge - inner) // 2, (edge - inner) // 2), art)
        save(foreground, res / f"mipmap-{name}" / "ic_launcher_foreground.png")

    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n"
    )
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(adaptive, encoding="utf-8")
    print(f"  {(anydpi / 'ic_launcher.xml').relative_to(ROOT)}")

    hex_colour = "#%02X%02X%02X" % colour
    colours = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Written by tool/brand_assets.py, out of the icon itself. Both are\n"
        "     the same blue on purpose: the launcher's mask, the window behind a\n"
        "     starting app and the icon's own field have to agree, or the icon\n"
        "     arrives framed by whatever they disagreed about. -->\n"
        "<resources>\n"
        f'    <color name="ic_launcher_background">{hex_colour}</color>\n'
        f'    <color name="splash_background">{hex_colour}</color>\n'
        "</resources>\n"
    )
    (res / "values" / "colors.xml").write_text(colours, encoding="utf-8")
    print(f"  {(res / 'values' / 'colors.xml').relative_to(ROOT)}  {hex_colour}")


def write_ios(icon: Image.Image, colour: tuple[int, int, int]) -> None:
    print("ios")
    appicon = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text(encoding="utf-8"))

    for entry in contents["images"]:
        if "filename" not in entry:
            continue

        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        pixels = int(round(points * scale))

        # No alpha anywhere in an iOS app icon: the store rejects it and the
        # system draws its own mask, so the corners are filled rather than cut.
        save(flatten(scaled(icon, pixels), colour), appicon / entry["filename"])


def write_macos(icon: Image.Image) -> None:
    print("macos")
    appicon = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(scaled(icon, size), appicon / f"app_icon_{size}.png")


def write_windows(icon: Image.Image) -> None:
    print("windows")
    target = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    sizes = [(s, s) for s in (16, 24, 32, 48, 64, 128, 256)]
    icon.save(target, sizes=sizes)
    print(f"  {target.relative_to(ROOT)}  {len(sizes)} sizes")


def write_web(icon: Image.Image, colour: tuple[int, int, int]) -> None:
    print("web")
    save(scaled(icon, 16), ROOT / "web" / "favicon.png")

    for size in (192, 512):
        save(scaled(icon, size), ROOT / "web" / "icons" / f"Icon-{size}.png")
        # A maskable icon is cropped by the browser to whatever shape the
        # platform likes, so it has to reach every edge. The artwork already
        # sits inside the safe circle.
        save(
            flatten(scaled(icon, size), colour),
            ROOT / "web" / "icons" / f"Icon-maskable-{size}.png",
        )


def write_app_asset(icon: Image.Image) -> None:
    print("app")
    save(scaled(keyed_mark(icon), 512), ROOT / "assets" / "brand" / "app_mark.png")


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FLUTTER_FONTS / name), size)


def fitted(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
    limit: int,
    path: str,
) -> ImageFont.FreeTypeFont:
    """The largest size at or below the font's own that stays inside `limit`."""
    size = font.size

    while size > 18 and draw.textlength(text, font=font) > limit:
        size -= 1
        font = ImageFont.truetype(path, size)

    return font


def write_play(icon: Image.Image, colour: tuple[int, int, int]) -> None:
    print("play")
    banner = Image.open(BANNER_SOURCE).convert("RGB")
    banner = matte(banner)

    # Crop to the feature graphic's ratio from the middle, then scale. The
    # source was drawn with the broom on the right and the left two thirds left
    # empty, which is where the text goes.
    target_ratio = FEATURE_SIZE[0] / FEATURE_SIZE[1]
    w, h = banner.size
    if w / h > target_ratio:
        new_w = int(h * target_ratio)
        banner = banner.crop(((w - new_w) // 2, 0, (w - new_w) // 2 + new_w, h))
    else:
        new_h = int(w / target_ratio)
        banner = banner.crop((0, (h - new_h) // 2, w, (h - new_h) // 2 + new_h))
    banner = banner.resize(FEATURE_SIZE, Image.LANCZOS)

    for locale, (name, tagline) in FEATURE_TEXT.items():
        graphic = banner.copy()
        draw = ImageDraw.Draw(graphic)

        # The name is Latin in every locale, so it is always Roboto Bold; only
        # the line under it changes face, and only where Roboto has no glyphs.
        title_font = load_font("roboto-bold.ttf", 76)
        body_font = (
            ImageFont.truetype(str(CJK_FONT), 32)
            if locale == "zh-CN"
            else load_font("roboto-regular.ttf", 32)
        )

        # Play crops the feature graphic differently in different places, so
        # nothing important goes near an edge. The right of the image is the
        # broom, and text is kept out of it: a translated line is whatever
        # length the language makes it, and Russian is half again as long as
        # English. Shrinking to fit beats writing shorter copy in one language
        # to suit a layout.
        left, baseline, limit = 72, 196, 620
        body_font = fitted(draw, tagline, body_font, limit, str(CJK_FONT)
                           if locale == "zh-CN" else str(FLUTTER_FONTS / "roboto-regular.ttf"))

        draw.text((left, baseline), name, font=title_font, fill=(255, 255, 255))
        draw.text(
            (left, baseline + 104),
            tagline,
            font=body_font,
            fill=(226, 232, 240),
        )

        images = ROOT / "fastlane" / "metadata" / "android" / locale / "images"
        save(graphic, images / "featureGraphic.png")
        # Play's own listing icon: 512, square, and shown under Play's mask.
        save(flatten(scaled(icon, 512), colour), images / "icon.png")


def main() -> None:
    source = Image.open(ICON_SOURCE).convert("RGB")
    icon = cut_corners(matte(source))
    colour = field_colour(icon)

    print(f"field colour #%02X%02X%02X\n" % colour)

    write_android(icon, colour)
    write_ios(icon, colour)
    write_macos(icon)
    write_windows(icon)
    write_web(icon, colour)
    write_app_asset(icon)
    write_play(icon, colour)

    print(f"\ndone — brand blue is #%02X%02X%02X" % colour)


if __name__ == "__main__":
    main()
