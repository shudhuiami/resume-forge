#!/usr/bin/env python3
"""Regenerate the sample-resume portrait in assets/sample/.

WHAT THIS IS
------------
`lib/data/sample_resume.dart` is the fixture behind the thirteen gallery
thumbnails and behind the editor's "Load sample data" action. Eight of the
thirteen designs reserve a portrait slot; with no photo in the fixture those
eight advertised themselves with the slot empty or collapsed, so the gallery
showed a *worse* version of the design than the design actually is.

This produces the portrait that fills it. It is drawn, not photographed:

  * no image is downloaded, and
  * no real person's likeness ships inside the app binary.

An abstract bust — head, neck, shoulders cropped by the frame — on a soft
studio ground. Deliberately not a face. At the size a gallery thumbnail draws
it (a 56-92pt slot on a 595pt page scaled into a ~160dp cell, so 15-25px on
screen) a face would be four pixels of noise; a high-contrast silhouette still
reads as a person. Anything more literal would also be a lie about whose
photograph it is.

BUDGET
------
`PhotoService.downscale` squares every imported photo to 512px on the longest
edge and re-encodes it at JPEG quality 85, because the portrait is stored
*inside* the resume document and that document is rewritten on every autosave.
This asset is produced at exactly those parameters — 512x512, quality 85,
4:2:0 chroma, baseline — so the fixture costs no more than a photo the user
picks themselves, and lands far under it because flat tone and a smooth ground
are what JPEG compresses best. The script prints the byte size it achieved.

BAKED COLOURS
-------------
Nothing here comes from `ColorScheme`, and nothing here may. This is a
*document* asset: it is printed on the resume page, inside templates that carry
their own independent, overwhelmingly light palettes. Taking the app's dark
chrome colours would bleed one colour world into the other. They are literals,
listed so they are auditable rather than mysterious:

    name           value     role
    -------------  --------  --------------------------------------------
    GROUND_CENTRE  #F1EEE9   backdrop behind the head, lightest point
    GROUND_EDGE    #C9C2B7   backdrop at the frame corners (vignette)
    FIGURE_TOP     #63605B   silhouette at the shoulders/head
    FIGURE_BOTTOM  #4E4B47   silhouette at the bottom crop

Warm neutrals on purpose. The portrait is drawn onto thirteen different
document palettes — coral pink, aurora violet, ember's dark surface — and a
saturated backdrop would fight whichever one it landed on. A neutral one reads
as "a photo" everywhere.

The two contrasts that matter are measured, not eyeballed, and printed on every
run:

  * silhouette against the ground, at the worst pairing (lightest figure stop
    against the lightest ground point) — the silhouette has to survive being
    drawn at 15px, so it is held to at least 3:1, the WCAG AA floor for a
    graphical object;
  * the ground's own edge against white paper — this is the only thing
    separating the portrait from the page in the four designs that frame it
    with no border, so it must be a visible step rather than nothing.

Usage:
    pip install pillow
    python assets/sample/generate_sample_portrait.py

Writes two files that must stay in step, and a test enforces that they do
(`test/data/sample_portrait_test.dart` decodes the Dart constant and compares
it byte-for-byte with the JPEG):

    assets/sample/portrait.jpg     the artifact, so a human can look at it
    lib/data/sample_portrait.dart  the same bytes as base64

The Dart copy exists because `sampleResume` is a plain top-level `final` that
the gallery and the editor read synchronously. Loading the portrait from the
asset bundle instead would make it a `Future`, and every caller would have to
become async to gain nothing. It is therefore *not* declared in `pubspec.yaml`
either — bundling it would ship the same bytes twice. Same arrangement as
`assets/brand/`, which is a build input rather than a runtime asset.
"""

from __future__ import annotations

import base64
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE = os.path.dirname(os.path.dirname(HERE))
JPEG_PATH = os.path.join(HERE, 'portrait.jpg')
DART_PATH = os.path.join(MOBILE, 'lib', 'data', 'sample_portrait.dart')

# --- palette (see the table in the module docstring) ------------------------

GROUND_CENTRE = (0xF1, 0xEE, 0xE9)
GROUND_EDGE = (0xC9, 0xC2, 0xB7)
FIGURE_TOP = (0x63, 0x60, 0x5B)
FIGURE_BOTTOM = (0x4E, 0x4B, 0x47)

# --- encode (mirrors PhotoService.maxEdge / .jpegQuality) -------------------

SIZE = 512
QUALITY = 85
# 4:2:0, which is what `package:image`'s encodeJpg defaults to and therefore
# what a user's imported photo is stored as.
SUBSAMPLING = 2

SUPERSAMPLE = 4

# --- geometry, as fractions of the square frame -----------------------------
#
# Portrait framing, not icon framing: the head sits above centre and the
# shoulders run off the bottom edge, the way a cropped headshot does. A UI
# avatar glyph centres the whole bust inside the box, which is what makes it
# read as an icon rather than as a photograph.

HEAD_CY = 0.350
HEAD_R = 0.158

# Behind the shoulders, so only the exposed part between chin and collar shows.
# Short and broad: a long thin neck turns the silhouette into a lightbulb.
NECK_HALF_W = 0.074
NECK_TOP = 0.450
NECK_BOTTOM = 0.620

# Shoulders as an ellipse whose centre is *below* the frame, so the silhouette
# is still at its widest where the crop cuts it. An ellipse centred inside the
# frame would taper back in toward the bottom edge, which reads as a tapering
# torso rather than as a shoulder line leaving the picture.
SHOULDER_CY = 0.985
SHOULDER_RX = 0.375
SHOULDER_RY = 0.420

# How fast the backdrop falls off from centre to corner. Above 1.0 the light
# pool behind the head stays open longer and the vignette gathers in the
# corners, which is how a lit studio backdrop actually falls off; a linear ramp
# reads as a grey wash over the whole frame.
VIGNETTE_GAMMA = 1.45


def _relative_luminance(rgb: tuple[int, int, int]) -> float:
    """WCAG relative luminance."""

    def channel(v: int) -> float:
        s = v / 255
        return s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = _relative_luminance(a), _relative_luminance(b)
    lo, hi = sorted((la, lb))
    return (hi + 0.05) / (lo + 0.05)


def _ground(size: int) -> Image.Image:
    """Soft radial backdrop: a pool of light behind the head, corners deeper."""
    # Pillow's radial_gradient is a 256x256 distance field, black at the centre
    # and saturating to white before the corners. Resizing it *is* the gradient,
    # which avoids a four-million-iteration Python loop for the same result.
    falloff = Image.radial_gradient('L').point(
        lambda v: int(255 * (v / 255) ** VIGNETTE_GAMMA)
    )
    mask = falloff.resize((size, size), Image.BICUBIC)

    centre = Image.new('RGB', (size, size), GROUND_CENTRE)
    edge = Image.new('RGB', (size, size), GROUND_EDGE)
    return Image.composite(edge, centre, mask)


def _figure_mask(size: int) -> Image.Image:
    """Alpha of the bust: head, neck, and shoulders cropped by the frame."""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)

    def box(x0: float, y0: float, x1: float, y1: float):
        return (x0 * size, y0 * size, x1 * size, y1 * size)

    # Neck first, so the head and shoulders close over its ends.
    draw.rectangle(
        box(0.5 - NECK_HALF_W, NECK_TOP, 0.5 + NECK_HALF_W, NECK_BOTTOM),
        fill=255,
    )
    draw.ellipse(
        box(
            0.5 - SHOULDER_RX,
            SHOULDER_CY - SHOULDER_RY,
            0.5 + SHOULDER_RX,
            SHOULDER_CY + SHOULDER_RY,
        ),
        fill=255,
    )
    draw.ellipse(
        box(0.5 - HEAD_R, HEAD_CY - HEAD_R, 0.5 + HEAD_R, HEAD_CY + HEAD_R),
        fill=255,
    )
    return mask


def _figure_fill(size: int) -> Image.Image:
    """The silhouette's own tone: one hue, lit from above.

    A single flat fill reads as clip art. One gentle vertical step within the
    same warm grey reads as a lit subject, which is the whole point of putting
    a portrait in the thumbnail at all — and it costs nothing in bytes, because
    a vertical ramp is the cheapest thing a JPEG stores.
    """
    ramp = Image.linear_gradient('L').resize((size, size), Image.BICUBIC)
    top = Image.new('RGB', (size, size), FIGURE_TOP)
    bottom = Image.new('RGB', (size, size), FIGURE_BOTTOM)
    return Image.composite(bottom, top, ramp)


def _portrait() -> Image.Image:
    big = SIZE * SUPERSAMPLE
    image = _ground(big)
    image.paste(_figure_fill(big), (0, 0), _figure_mask(big))
    return image.resize((SIZE, SIZE), Image.LANCZOS)


DART_HEADER = '''// GENERATED by assets/sample/generate_sample_portrait.py -- do not hand-edit.
//
// The placeholder portrait carried by [sampleResume], as base64 JPEG.
//
// Drawn rather than photographed: an abstract bust on a soft studio ground, so
// no real person's likeness ships in the binary and nothing had to be
// downloaded to build it. See the generator for the geometry, the baked colour
// table and the measured contrasts.
//
// Inlined rather than loaded from `assets/`: `sampleResume` is a synchronous
// top-level `final` that the gallery and the editor read during build, and
// putting the bytes behind `rootBundle` would turn it into a `Future` that
// every caller would have to await. `assets/sample/portrait.jpg` holds the
// identical bytes for humans to look at, and
// `test/data/sample_portrait_test.dart` fails if the two ever drift apart.
//
// Encoded at PhotoService's own budget -- 512x512, JPEG quality 85, 4:2:0 --
// because this photo lives inside the resume document, which is rewritten on
// every autosave.

import 'dart:convert';
import 'dart:typed_data';

/// Decoded once, lazily: nothing pays for it until a resume is rendered.
final Uint8List samplePortraitJpeg = base64Decode(_samplePortraitBase64);

const _samplePortraitBase64 =
'''


def _write_dart(jpeg: bytes) -> None:
    text = base64.b64encode(jpeg).decode('ascii')
    # 72 characters, plus four of indent and two quotes, is 78 -- inside the
    # 80 columns the rest of the codebase wraps at. A multiple of four so each
    # line is a whole number of base64 quanta; Dart concatenates adjacent
    # string literals before decoding, so the split point is cosmetic either
    # way.
    width = 72
    chunks = [text[i : i + width] for i in range(0, len(text), width)]
    body = '\n'.join(f"    '{c}'" for c in chunks)
    with open(DART_PATH, 'w', encoding='utf8', newline='\n') as f:
        f.write(DART_HEADER + body + ';\n')


def main() -> int:
    print('sample portrait ->', HERE)

    image = _portrait()
    image.save(
        JPEG_PATH,
        format='JPEG',
        quality=QUALITY,
        subsampling=SUBSAMPLING,
        optimize=True,
    )
    jpeg = open(JPEG_PATH, 'rb').read()
    _write_dart(jpeg)

    print(f'  portrait.jpg          {image.width}x{image.height}  {len(jpeg)} bytes')
    print(f'  sample_portrait.dart  base64            {len(jpeg) * 4 // 3} bytes')
    # Every figure stop against every ground stop, so the number quoted is the
    # weakest pairing that occurs anywhere in the frame rather than a
    # convenient one.
    pairings = [
        _contrast(f, g)
        for f in (FIGURE_TOP, FIGURE_BOTTOM)
        for g in (GROUND_CENTRE, GROUND_EDGE)
    ]
    paper = (0xFF, 0xFF, 0xFF)

    print('  measured:')
    print(f'    silhouette on ground, weakest pairing  {min(pairings):.2f}:1')
    print(f'    silhouette on ground, strongest        {max(pairings):.2f}:1')
    print(
        '    ground edge on white paper             '
        f'{_contrast(GROUND_EDGE, paper):.2f}:1'
    )
    print(
        '    ground centre on white paper           '
        f'{_contrast(GROUND_CENTRE, paper):.2f}:1'
    )

    if min(pairings) < 3.0:
        print('  FAIL: the silhouette drops below 3:1 somewhere in the frame')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
