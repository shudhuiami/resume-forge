# Resume Studio

A no-signup resume builder. Pick a design, fill in one form, watch a live
preview, export a print-ready PDF. No accounts, no backend, no network — every
resume stays on the device.

## Requirements

- **Flutter 3.44.9** (Dart 3.12.2) or newer on the stable channel
- For Android: Android SDK + a device or emulator
- For iOS: Xcode + a simulator (macOS only)

```
flutter --version
flutter doctor
```

## Run it

```
cd mobile
flutter pub get
flutter run                      # pick a device when prompted
flutter run -d chrome            # web, if you have no device attached
```

Everything needed to build is committed — fonts are bundled and there are no
API keys, `.env` files, or services to start.

## Tests

```
flutter test        # 643 tests
flutter analyze     # expected: no issues
dart format .
```

## What to look at first

The app boots to an empty resume list. Tap **Create your first resume** → pick a
design → fill in the form → **Preview** tab → the share icon to export.

Two things are worth trying deliberately, because they are where the
interesting behaviour lives:

1. **Switch designs with content already entered** (the palette icon in the
   editor's app bar). Content is meant to survive untouched — that is the
   product's core promise.
2. **Add six or seven roles.** A warning banner should appear saying content
   will not fit. See the known issue below.

## Known issues

The full log is in [`docs/ui/FLUTTER_UI_ISSUES.md`](../docs/ui/FLUTTER_UI_ISSUES.md).
The ones you will notice while using the app:

- **UI-016 (P1) — templates silently drop content that does not fit.** Measured
  capacity is 4 roles on the tightest design (circuit, terminal, quill, linen),
  5 on most, 7 on aurora. `dart_pdf`'s `Column` removes a child outright rather
  than flowing to a second page. The app now detects this and warns while
  editing and again at export, but the content is still lost from the PDF. The
  real fix is multi-page flow (UI-010), which is not implemented.
- **UI-009 — an intermittent preview render failure.** The preview drops to
  "Showing the last good preview" and needs a Retry. Seen a handful of times on
  web, never reproduced under instrumentation, cause unknown.
- **UI-010 — only page one is ever previewed.** Currently masked because every
  template fits one page.

## Verification status

**Everything visual was checked on Flutter Web in Chromium only.** This project
was built in an environment with no Android SDK, no emulator, no `adb`, and no
Xcode, so **nothing here has run on a real Android or iOS device.** Specifically
unverified on native:

- `Printing.sharePdf` opening a real share sheet (on web it silently downloads)
- PDFium rasterization for the preview (web uses pdf.js)
- Storage-permission and out-of-space failure paths
- Real safe-area insets, platform scroll physics, native text scaling
- **Preview latency on low-end hardware** — the debounce-and-rasterize loop has
  never been measured on a budget phone, and the gallery now rasterizes 13
  thumbnails into one grid

Running this on a real device is the single most useful thing that can happen to
it next.

## Layout

```
mobile/
  lib/
    models/       resume data model (freezed + JSON)
    data/         Hive repository, photo import
    render/       PDF build, rasterize, export, truncation check
    state/        editor controller (preview, autosave)
    templates/    13 designs + the registry that lists them
    screens/      resume list, gallery, editor
    widgets/      preview, form fields
  test/           643 tests
  tool/           build_fonts.py — regenerates the bundled font cuts
```

Two things are worth knowing before touching `templates/`, and both live at the
top of `lib/templates/template.dart`:

- **The hazard notes.** Three `dart_pdf` behaviours that each cost a full
  debugging cycle to find, and all three fail **silently** — passing tests over
  visibly broken output.
- **The URL rule.** How this app draws a URL, in six numbered points: display
  form, breaking, shortening, and the two layout traps that made links look
  broken. Use `urlText`, `titleWithUrl` and `contactStrip` rather than passing a
  link to `pw.Text`. `test/templates/url_rule_test.dart` holds every design in
  the registry to it.
