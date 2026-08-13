#!/usr/bin/env python3
"""Regenerate the Resivo brand raster assets in assets/brand/.

The mark is a single upright A4 page in **one solid matte colour**, its
top-right corner folded away, and its contents — a portrait, two text lines and
a rising arrow — punched out as transparent holes so the layer behind shows
through.

Flat on purpose. Nothing here blends two colours into each other: the palette is
a matte near-black base carrying solid, unmixed accents. That is also why the
mark reads at all at 48px: an opaque #D8A657 page on an opaque #0E0E10 backdrop
is 8.73:1, and because the contents are holes, every one of them measures the
same 8.73:1 against the page it is cut from. One number carries the whole icon.

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

The geometry constants below are mirrored in `lib/screens/splash_screen.dart`
so the animated splash draws the same mark the launcher icon does.

--- how the reference logo was translated -----------------------------------

The supplied logo is a gold *outline* page on near-white, with the folded corner
filled dark, a gold portrait and gold/dark content lines inside it, and a gold
arrow sweeping out past the page.

Two things about it cannot be carried over literally, and both are consequences
of the app icon's ground being near-black rather than near-white:

* **Outline becomes solid.** The reference's page is a stroke about 0.086 of the
  page width. On the adaptive layer the page is 0.52 of 108dp, so at a 48px
  launcher icon the page is 26.5 x 37.4px and that stroke is 2.3px — a hairline
  that aliases to a smear, with every interior detail a thinner hairline still.
  A solid page with punched contents keeps the identical 8.73:1 everywhere and
  is what actually survives. The reference's silhouette is preserved; its
  figure/ground is inverted.
* **The dark fold becomes an absence.** The reference fills the folded corner
  solid near-black against a white page. On a near-black backdrop, painting that
  corner dark *is* cutting it away, so the fold is a 45 deg chamfer and the
  backdrop shows through it. Same drawing, same read, one less shape.

The arrow was the part at risk, and it was measured rather than guessed. A shaft
of 0.085 and a head of 0.125 of the page height — the proportions the reference
implies — resolve at 48px to 3.2px and 4.7px, a ratio of 1.47, and the head
disappears into the shaft: the mark reads as a plain diagonal line. The head is
therefore over-scaled relative to the reference. At ARROW_WIDTH 0.080 and a head
0.250 wide the ratio is 3.1, and the arrowhead is still a triangle at 48px.
Verified under circle, squircle, rounded-square and full-square masks.

Its *length* is the opposite trade. A head wide enough for 48px and as long as
it is wide takes 47% of the arrow, which at the 164dp the splash draws the same
geometry at reads as a huge head on a stub. ARROW_HEAD_LENGTH is therefore 0.215
against a 0.250 base — a swept head, wider than it is long — which is 36% of the
arrow and normal at splash size while losing nothing at 48px.

The reference's arrow also ends *outside* the page. That was built and rejected:
at 48px a gold arrowhead separated from the page by a gap of backdrop reads as a
speck of dirt rather than as an arrow, and moving the composition's centre of
mass off the page would break the native-splash handoff, which is measured
against the page and nothing else. The arrow instead runs to 0.93 of the page
width, so it still reads as heading out of the document without leaving it.

The reference's third content line was dropped. Three lines plus a portrait plus
an arrow leaves each line about 2px of gap at 48px, and the lower half closes up
into mush — the same reason the previous mark carried three bars and not five.

Usage:
    pip install pillow
    python assets/brand/generate_brand.py
"""

from __future__ import annotations

import math
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
# punched contents vanish with it.
#
# It is also within a couple of degrees of hue of the reference logo's gold,
# which samples at #C19C5E — so the app's existing accent is used as-is rather
# than importing a second, near-identical gold into the palette.
MARK = (0xD8, 0xA6, 0x57)

MONO_INK = (0xFF, 0xFF, 0xFF)

# --- geometry (mirrored in lib/screens/splash_screen.dart) -----------------
#
# Every fraction below is of the *page box*. Horizontal ones are fractions of
# the page width, vertical ones of the page height, except where a size has to
# stay circular or square in real space — radii and stroke widths — which are
# noted individually.

# A4, the only shape a resume is printed at.
PAGE_RATIO = 1 / 1.4142135623730951

# Corner radius as a fraction of page width.
PAGE_CORNER = 0.12

# The folded corner, as a fraction of the page width along the top edge. The
# crease is at 45 degrees in real space, so it drops PAGE_FOLD * PAGE_RATIO of
# the page height. 0.34 matches the reference; 0.28 stops reading at 48px and
# 0.42 turns the page into a pentagon.
PAGE_FOLD = 0.34

# The portrait: a head over a shoulder dome, both fractions of the page *width*
# so they stay circular. Centres are (x of width, y of height).
HEAD = (0.315, 0.235, 0.105)      # cx, cy, radius
SHOULDERS = (0.315, 0.435, 0.175)  # cx, cy (the dome's flat edge), radius

# Content lines, as fractions of the page box: (left, top, right, bottom).
# Stadium-ended (radius = half the bar height), matching AppTokens.radiusPill.
# Two, not three — see the docstring.
BARS = [
    (0.580, 0.360, 0.880, 0.445),  # beside the portrait's shoulders
    (0.155, 0.510, 0.875, 0.595),
]

# The rising arrow. TAIL is the centre of the shaft's square end and APEX is the
# point of the head; both are (x of width, y of height). The shaft runs from
# TAIL to the centre of the head's base, so the two meet flush.
ARROW_TAIL = (0.150, 0.915)
ARROW_APEX = (0.934, 0.690)
# Shaft thickness, head length and head base width, all as fractions of the page
# *height* so the arrow keeps its proportions rather than being sheared by A4.
ARROW_WIDTH = 0.080
ARROW_HEAD_LENGTH = 0.215
ARROW_HEAD_WIDTH = 0.250

# Page height as a fraction of the canvas, per output.
#
# ADAPTIVE is the tight one: of a 108dp adaptive layer only the inner 72dp is
# ever shown and only the inner 66dp circle is *guaranteed* to survive masking.
# An A4 page's diagonal is 1.2247x its height, so a page whose corners must stay
# inside a 0.66-of-canvas circle can be at most 0.66/1.2247 = 0.539 high. 0.52
# keeps a margin on that, and still sits entirely inside the circle inscribed in
# the 72dp viewport, which is the tightest mask any launcher actually ships.
# The fold only removes material, so it cannot push the mark back out.
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


def _fold(draw: ImageDraw.ImageDraw, box, size: int) -> None:
    """Cut the top-right corner away along a 45 degree crease.

    Removing the whole half-plane beyond the crease rather than a triangle
    sized to the corner, so the cut cannot miss whatever the corner radius is
    doing.
    """
    x0, y0, x1, y1 = box
    cut = (x1 - x0) * PAGE_FOLD
    far = size * 3
    start = (x1 - cut - far, y0 - far)
    end = (x1 + far, y0 + cut + far)
    draw.polygon(
        [start, end, (end[0] + far, end[1]), (end[0] + far, start[1])], fill=0
    )


def _contents(draw: ImageDraw.ImageDraw, box) -> None:
    """Punch the portrait, the lines and the arrow out of the page."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0

    def at(fx: float, fy: float) -> tuple[float, float]:
        return (x0 + w * fx, y0 + h * fy)

    hx, hy = at(HEAD[0], HEAD[1])
    hr = w * HEAD[2]
    draw.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=0)

    sx, sy = at(SHOULDERS[0], SHOULDERS[1])
    sr = w * SHOULDERS[2]
    # Top half only: a dome, which is the shoulder line of a portrait crop.
    draw.pieslice((sx - sr, sy - sr, sx + sr, sy + sr), 180, 360, fill=0)

    for left, top, right, bottom in BARS:
        bx0, by0 = at(left, top)
        bx1, by1 = at(right, bottom)
        draw.rounded_rectangle(
            (bx0, by0, bx1, by1), radius=(by1 - by0) / 2, fill=0
        )

    tail = at(*ARROW_TAIL)
    apex = at(*ARROW_APEX)
    dx, dy = apex[0] - tail[0], apex[1] - tail[1]
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length

    head_len = h * ARROW_HEAD_LENGTH
    half_base = h * ARROW_HEAD_WIDTH / 2
    base = (apex[0] - ux * head_len, apex[1] - uy * head_len)

    draw.line(
        [tail, base], fill=0, width=max(1, round(h * ARROW_WIDTH))
    )
    draw.polygon(
        [
            apex,
            (base[0] - uy * half_base, base[1] + ux * half_base),
            (base[0] + uy * half_base, base[1] - ux * half_base),
        ],
        fill=0,
    )


def _page_mask(size: int, page_height: float, contents: bool = True) -> Image.Image:
    """Alpha mask of the folded page, with its contents punched out if asked.

    `contents=False` is the splash case: it is the mark's *first frame*, the
    empty page the animated splash then writes everything else onto.
    """
    box = _page_box(size, page_height)
    x0, y0, x1, y1 = box

    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (x0, y0, x1, y1), radius=(x1 - x0) * PAGE_CORNER, fill=255
    )
    _fold(draw, box, size)

    if contents:
        _contents(draw, box)
    return mask


def _mark_layer(
    size: int,
    page_height: float,
    fill: tuple = MARK,
    contents: bool = True,
) -> Image.Image:
    """The mark on transparency, in one solid colour.

    Colour is constant across the whole canvas and only alpha varies, which is
    why the downsample is clean: resampling a channel that holds a single value
    cannot introduce the dark fringe a non-premultiplied RGBA resize normally
    leaves around an edge. The supersample is only there to antialias the
    geometry — and the fold's crease and the arrow's diagonals need it more than
    the old all-orthogonal mark did.
    """
    big = size * SUPERSAMPLE
    layer = Image.new('RGBA', (big, big), (*fill, 255))
    layer.putalpha(_page_mask(big, page_height, contents=contents))
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

    # Both splash images are the mark with nothing written on it yet: the
    # animated Flutter splash opens on exactly this frame and fills the page in,
    # so the native-to-Flutter handoff has nothing visible change hands.
    _write(
        _mark_layer(SPLASH_CANVAS, PAGE_SPLASH, contents=False),
        'splash_logo.png',
    )
    _write(
        _mark_layer(1152, PAGE_ANDROID12, contents=False),
        'splash_android12.png',
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
