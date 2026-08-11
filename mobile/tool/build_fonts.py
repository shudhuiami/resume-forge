#!/usr/bin/env python3
"""Regenerate the bundled static font cuts in assets/fonts/.

Upstream Google Fonts ships these families as variable fonts only, but
dart_pdf cannot instance a variable axis — it renders whatever the default
instance is. Bundling the variable originals would therefore make every
"bold" in an exported resume silently come out at Regular.

This script instances the weights we actually use and subsets them to Latin,
which takes the bundle from several megabytes to roughly 400 KB.

Usage:
    pip install fonttools brotli
    python3 tool/build_fonts.py
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl"

SOURCES = {
    "Inter": f"{BASE}/inter/Inter%5Bopsz,wght%5D.ttf",
    "Lora": f"{BASE}/lora/Lora%5Bwght%5D.ttf",
    "JetBrainsMono": f"{BASE}/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf",
}

# Latin-1 + Latin Extended-A covers European names; General Punctuation
# carries typographic quotes, en/em dashes, and the middot used as a separator.
UNICODES = "U+0020-00FF,U+0100-017F,U+2000-206F,U+20A0-20BF,U+2122,U+2192"

# (family, [(style, weight)], extra axis pins)
CUTS = [
    ("Inter", [("Regular", 400), ("SemiBold", 600), ("Bold", 700)], {"opsz": 14}),
    ("Lora", [("Regular", 400), ("Bold", 700)], {}),
    ("JetBrainsMono", [("Regular", 400), ("Bold", 700)], {}),
]

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts")


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, url in SOURCES.items():
            dest = os.path.join(tmp, f"{name}.ttf")
            print(f"fetching {name}")
            urllib.request.urlretrieve(url, dest)

        total = 0
        for family, cuts, extra in CUTS:
            for style, weight in cuts:
                font = TTFont(os.path.join(tmp, f"{family}.ttf"))
                location = {"wght": weight, **extra}
                inst = instancer.instantiateVariableFont(
                    font, location, inplace=False, updateFontNames=False
                )
                staged = os.path.join(tmp, f"{family}-{style}-full.ttf")
                inst.save(staged)

                out = os.path.abspath(
                    os.path.join(OUT_DIR, f"{family}-{style}.ttf")
                )
                subprocess.run(
                    [
                        "pyftsubset",
                        staged,
                        f"--output-file={out}",
                        f"--unicodes={UNICODES}",
                        "--layout-features=kern,liga,calt",
                        "--no-hinting",
                        "--desubroutinize",
                    ],
                    check=True,
                )
                size = os.path.getsize(out)
                total += size
                print(f"  {family}-{style}.ttf  {size / 1024:.1f} KB")

        print(f"total {total / 1024:.1f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
