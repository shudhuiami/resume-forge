# App footprint

Measured 2026-08-11 against the 13-template catalog.

## What ships on mobile

| Item | Size | Notes |
|---|---:|---|
| Bundled fonts | 416 KB | 7 static cuts, Latin-subset |
| MaterialIcons | 9.3 KB | tree-shaken from 1,645 KB (99.4%) |
| CupertinoIcons | 1.4 KB | tree-shaken from 258 KB (99.4%) |
| **Total app assets** | **~427 KB** | |

Hand-written Dart is ~11,300 lines plus ~2,800 generated.

### Fonts

| File | Size |
|---|---:|
| Inter-Regular / SemiBold / Bold | 58.7 / 58.9 / 59.0 KB |
| Lora-Regular / Bold | 55.4 / 55.3 KB |
| JetBrainsMono-Regular / Bold | 56.2 / 56.1 KB |

These are static instances cut from upstream variable fonts and subset to
Latin-1 + Latin Extended-A + General Punctuation + currency
(`tool/build_fonts.py`). Shipping the variable originals unsubset would be
several megabytes **and** would silently render every weight at Regular, since
`dart_pdf` cannot instance a variable axis.

The subsetting done when the font pipeline was built is what keeps this number
small; there is no further easy win here. Adding a script beyond Latin — Cyrillic,
Greek, CJK — is the change that would move this materially, and would need to be
a deliberate product decision rather than a size optimisation.

## Web-only cost

| Item | Size | Notes |
|---|---:|---|
| CanvasKit | 37 MB | Flutter web renderer; not shipped on mobile |
| Vendored pdf.js | 1.4 MB | `printing` rasterizes via pdf.js on web and otherwise pulls it from a CDN; vendored so the app stays self-contained |
| `main.dart.js` | 3.8 MB | compiled Dart |
| NOTICES | 1.4 MB | bundled licence text |

The 44 MB `build/web` total is dominated by CanvasKit and is irrelevant to the
Android and iOS artifacts.

## Not measured

**APK and IPA size are unknown.** This environment has no Android SDK and no
Xcode, so neither artifact can be built. The asset payload above is measured and
real, but the packaged binary adds the Flutter engine (roughly 5–8 MB per ABI for
Android, before app code) and that figure is unverified here.

Anyone with a working Android toolchain should run:

```
flutter build apk --release --analyze-size
flutter build appbundle --release
```

and record the result, replacing this section.
