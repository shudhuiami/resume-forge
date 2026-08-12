#!/usr/bin/env python3
"""Regenerate the ResumeForge brand raster assets in assets/brand/.

The mark is a single upright A4 page in **one solid matte colour**, with its
content bars punched out as transparent holes so the layer behind shows
through. Three bars only — a header block and two lines — because the icon has
to survive being drawn at 48px, where a fourth line collapses into mush.

Flat on purpose. The mark used to be filled with a five-stop pink/violet/blue
ramp on a deep indigo base; the palette is now a matte near-black base carrying
solid, unmixed accents, and nothing here blends two colours into each other.
That is also why the page reads at all at 48px: an opaque #D8A657 page on an
opaque #0E0E10 backdrop is 8.73:1, and because the content bars are holes, the
bars measure the same 8.73:1 against the page they are cut from. One number
carries the whole icon.

Every colour here is a copy of a value that lives in Dart. They are duplicated
because a PNG cannot read `ColorScheme` at build time, so if the palette moves,
*this file has to move with it* and the assets have to be regenerated:

    assets/brand/generate_brand.py   Dart source of truth
    -------------------------------  ---------------------------------------
    BASE      #0E0E10                AppTheme.colorScheme.surface
    MARK      #D8A657                AppTheme.colorScheme.primary
    MONO_INK  #FFFFFF                (not a theme colour — see below)

MONO_INK is deliberately *not* from the palette: Android 13 recolours the
monochrome layer to the user's wallpaper and only reads its alpha, so the
silhouette is flat white and stays flat white whatever the accent does.

`test/brand/brand_assets_test.dart` samples the generated PNGs, the native
splash config and the Android window colour, and fails if any of them drift
away from those two Dart values, so the duplication is checked rather than
merely documented.

The geometry constants (PAGE_RATIO, PAGE_CORNER, BARS) are mirrored in
`lib/screens/splash_screen.dart` so the animated splash draws the same mark the
launcher icon does.

Usage:
    pip install pillow
    python assets/brand/generate_brand.py
"""

from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# --- palette (see the table in the module docstring) -----------------------

# Matte near-black. Neutral by measurement, not by intent: R and G are equal and
# B is two steps up, which is the most blue this is allowed to carry before it
# starts reading as a navy again.
BASE = (0x0E, 0x0E, 0x10)

# Matte amber. The one accent in the icon, and the only candidate that survives
# 48px: the eight solid card tints in the palette (clay, rust, ochre, olive,
# moss, teal, slate, plum) all measure between 1.38:1 and 1.68:1 against BASE,
# so a page filled with any of them is a dark shape on a dark shape and its
# punched bars vanish with it.
MARK = (0xD8, 0xA6, 0x57)

MONO_INK = (0xFF, 0xFF, 0xFF)

# --- geometry (mirrored in lib/screens/splash_screen.dart) -----------------

# A4, the only shape a resume is printed at.
PAGE_RATIO = 1 / 1.4142135623730951

# Corner radius as a fraction of page width.
PAGE_CORNER = 0.12

# Content bars, as fractions of the page box: (left, top, right, bottom).
# Stadium-ended (radius = half the bar height), matching AppTokens.radiusPill.
BARS = [
    (0.155, 0.200, 0.675, 0.340),  # header block
    (0.155, 0.460, 0.875, 0.560),
    (0.155, 0.660, 0.655, 0.760),
]

# Page height as a fraction of the canvas, per output.
#
# ADAPTIVE is the tight one: of a 108dp adaptive layer only the inner 72dp is
# ever shown and only the inner 66dp circle is *guaranteed* to survive masking.
# An A4 page's diagonal is 1.2247x its height, so a page whose corners must stay
# inside a 0.66-of-canvas circle can be at most 0.66/1.2247 = 0.539 high. 0.52
# keeps a margin on that, and still sits entirely inside the circle inscribed in
# the 72dp viewport, which is the tightest mask any launcher actually ships.
PAGE_MASTER = 0.60
PAGE_ADAPTIVE = 0.52

# The two splash images are sized to *land on screen* at the same height the
# Flutter splash draws its first frame at, so the mark does not jump when one
# hands off to the other. lib/screens/splash_screen.dart resolves to a 164dp
# page on a 390dp-wide phone and opens at 0.88 scale, which is 144dp.
#
# flutter_native_splash treats its source image as the 4x asset, so a 640px
# canvas is 160dp and the page needs 144/160 of it.
SPLASH_CANVAS = 640
PAGE_SPLASH = 0.90
# Android 12's splash icon window is a fixed 288dp with the art masked to a
# 192dp circle, so 144dp of page is 0.50 of the canvas — and its diagonal,
# 176dp, still clears the mask.
PAGE_ANDROID12 = 0.50

SUPERSAMPLE = 4


def _page_box(size: int, page_height: float) -> tuple[float, float, float, float]:
    h = size * page_height
    w = h * PAGE_RATIO
    return ((size - w) / 2, (size - h) / 2, (size + w) / 2, (size + h) / 2)


def _page_mask(size: int, page_height: float, bars: bool = True) -> Image.Image:
    """Alpha mask of the page, with its content bars punched out if asked.

    `bars=False` is the splash case: it is the mark's *first frame*, the blank
    page the animated splash then writes the bars onto.
    """
    x0, y0, x1, y1 = _page_box(size, page_height)
    w, h = x1 - x0, y1 - y0

    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((x0, y0, x1, y1), radius=w * PAGE_CORNER, fill=255)

    if bars:
        for left, top, right, bottom in BARS:
            bx0, by0 = x0 + w * left, y0 + h * top
            bx1, by1 = x0 + w * right, y0 + h * bottom
            draw.rounded_rectangle(
                (bx0, by0, bx1, by1), radius=(by1 - by0) / 2, fill=0
            )
    return mask


def _mark_layer(
    size: int,
    page_height: float,
    fill: tuple = MARK,
    bars: bool = True,
) -> Image.Image:
    """The mark on transparency, in one solid colour.

    Colour is constant across the whole canvas and only alpha varies, which is
    why the downsample is clean: resampling a channel that holds a single value
    cannot introduce the dark fringe a non-premultiplied RGBA resize normally
    leaves around an edge. The gradient version had to supersample to hide that;
    this one supersamples only to antialias the geometry.
    """
    big = size * SUPERSAMPLE
    layer = Image.new('RGBA', (big, big), (*fill, 255))
    layer.putalpha(_page_mask(big, page_height, bars=bars))
    return layer.resize((size, size), Image.LANCZOS)


def _backdrop(size: int) -> Image.Image:
    """The matte base, flat edge to edge.

    Nothing is blended into it — no centre lift, no bloom under the page. A
    matte surface that brightens toward the middle is a gradient wearing a
    different name, and it is exactly what the palette moved away from.
    """
    return Image.new('RGB', (size, size), BASE)


def _write(image: Image.Image, name: str) -> None:
    path = os.path.join(OUT_DIR, name)
    image.save(path)
    print(f'  {name}  {image.width}x{image.height}  {os.path.getsize(path) / 1024:.1f} KB')


def main() -> int:
    print('brand assets ->', OUT_DIR)

    backdrop = _backdrop(1024)

    master = backdrop.convert('RGBA')
    master.alpha_composite(_mark_layer(1024, PAGE_MASTER))
    # iOS rejects an alpha channel in an app icon, and the master is opaque
    # anyway, so it is flattened here rather than left for the generator.
    _write(master.convert('RGB'), 'icon_master.png')

    _write(backdrop, 'icon_background.png')
    _write(_mark_layer(1024, PAGE_ADAPTIVE), 'icon_foreground.png')
    # Themed icons: Android tints the opaque parts and shows the theme
    # background through the holes, so the mark is a flat silhouette.
    _write(_mark_layer(1024, PAGE_ADAPTIVE, fill=MONO_INK), 'icon_monochrome.png')

    # Both splash images are the mark without its content bars: the animated
    # Flutter splash opens on exactly this frame and writes the bars in, so the
    # native-to-Flutter handoff has nothing visible change hands.
    _write(_mark_layer(SPLASH_CANVAS, PAGE_SPLASH, bars=False), 'splash_logo.png')
    _write(
        _mark_layer(1152, PAGE_ANDROID12, bars=False), 'splash_android12.png'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
