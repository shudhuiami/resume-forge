# Flutter UI Issues

Defect log for ResumeForge Flutter UI work. Populated by the
`flutter-ui-specialist` agent and the `/flutter-ui-workflow` skill.

## Severity

| Level  | Meaning                                             |
| ------ | --------------------------------------------------- |
| **P0** | Screen unusable / crash / critical flow inaccessible |
| **P1** | Major workflow or interaction broken                |
| **P2** | Responsive / usability / theme problem              |
| **P3** | Visual polish                                       |

## Type

`overflow` · `responsive` · `theme` · `keyboard` · `safe-area` · `navigation` ·
`state` · `accessibility` · `interaction` · `performance` · `dead-control` · `polish`

## Device

Record the device the issue was **observed** on, including the verification platform —
e.g. `390x844 (web/chrome)`, `Pixel 6 emulator (android)`. Never record a device that
was not actually used.

## Status

`open` · `in-progress` · `fixed` · `wont-fix` · `cannot-reproduce`

---

## Issues

| ID | Module | Screen | Severity | Type | Device | Expected | Actual | Evidence | Status |
| -- | ------ | ------ | -------- | ---- | ------ | -------- | ------ | -------- | ------ |
| UI-001 | editor | EditorScreen | P2 | tooling | 390x844 (web/chrome) | A harness entry point boots straight into the editor so its pixels can be inspected at each viewport | `lib/main_harness.dart` rendered a blank page for every SCREEN value, including ones that render fine from `main.dart`. Engine booted (`flutter-view` present) but no frame painted, and no error surfaced through `FlutterError.onError`, `PlatformDispatcher.onError`, or `ErrorWidget.builder` | Harness deleted rather than left as a silently broken dev tool. Editor renders correctly in widget tests | open |
| UI-002 | editor | EditorScreen | P2 | tooling | 390x844 (web/chrome) | Editor pixels visually verified at 360/390/430/768 | **RESOLVED.** Now verified at all four viewports plus the Preview tab. The blocker was never the harness: `1 << 32 == 0` on dart2js made resume creation throw, so the two-tap path into the editor died every time. Original note follows. **Not visually verified.** Reaching the editor needs two taps and Flutter renders to a canvas: coordinate clicks are flaky and enabling the semantics tree injects DOM overlays that swallow pointer events. Layout is instead verified by widget tests at all four viewports with realistic, pathological, and empty content | `test/screens/editor_responsive_test.dart` plus captured screenshots at 360/390/430/768 | fixed |
| UI-003 | preview | PdfPageView | P2 | state | n/a | Preview tab rasterization verified on-device | `Printing.raster` is platform-bound and the preview tab was never reached in a browser session. Raster sizing maths is unit-tested; the actual pixels are unverified | `test/render/pdf_raster_test.dart` covers DPI/clamping only | open |
| UI-004 | app | all | P3 | performance | n/a | Preview latency measured on a low-end Android profile | No Android SDK, emulator, or `adb` in this environment. Task 9 remains unmeasured; template mass-production proceeds on the untested assumption that the debounce-and-rasterize loop is fast enough on budget hardware | — | open |
| UI-005 | gallery | GalleryScreen | P3 | state | 390x844 (web/chrome) | An empty catalog shows an explanation rather than a blank screen | `GridView.builder` over `resumeTemplates` renders nothing at all when the list is empty. Unreachable today — the registry is a non-empty `const` list — so an empty state here would be untestable dead code, but a runtime-loaded catalog would expose it | `lib/templates/registry.dart` guarantees at least `AuroraTemplate()` | open |
| UI-006 | gallery | _Thumbnail | P3 | polish | 768x1024 (web/chrome) | Thumbnails are rasterized at the size the tile actually renders at | Every thumbnail rasterizes at a fixed `logicalWidth: 200, pixelRatio: 2` and the cache is keyed on template id alone, so a 234px tablet tile upscales a 400px raster and reads slightly soft. Fixing it needs a width-aware cache key, which is a render-layer decision, not a layout one | `lib/screens/gallery_screen.dart` `_ThumbnailState._load`; visible when comparing 360 and 768 screenshots | open |
| UI-007 | resume-list | _ResumeTile | P3 | polish | 390x844 (web/chrome) | A resume edited more than a month ago reads as a date | `_relative()` falls back to `2026-07`, so the row says "edited 2026-07" — a stamp rather than a phrase, and ambiguous about the day | `lib/screens/resume_list_screen.dart` `_ResumeTile._relative`; screenshot of a seeded 40-day-old document | open |
| UI-008 | gallery, resume-list | GalleryScreen, ResumeListScreen | P2 | tooling | 390x844 (web/chrome) | Both screens confirmed on a real Android or iOS device | Verified on Flutter Web in Chromium only — no Android SDK, emulator, `adb`, or iOS simulator exists here. Touch behaviour, platform scroll physics, real safe-area insets (notch, gesture bar) and native text scaling are therefore unverified for both screens | Screenshots at 360/390/430/768 plus landscape; `test/screens/gallery_layout_test.dart` and `test/screens/resume_list_layout_test.dart` | open |
| UI-009 | preview | PdfPageView / PreviewEngine | P2 | state | 390x844, 360x800 (web/chrome) | Typing and switching tabs never fails a render | An intermittent render/raster failure puts the preview into its stale state ("Showing the last good preview") and it stays there until retried. Seen three times across browser sessions, always shortly after a tab switch during an in-flight render. Not reproduced under instrumentation (a temporary `debugPrint` on the controller's error path logged nothing across six provocation cycles), so the exception text is still unknown. The UI now survives it — the last good page is kept and Retry works — but the underlying failure is a render-layer defect and is unfixed. Suspects: overlapping `Printing.raster` calls through pdf.js on web, and `ResumeFonts.loadBytes` using `.buffer.asUint8List()` without offset/length, which returns the whole backing buffer if the web bundle hands back a view | Screenshots `before-390x844-c-preview-busy.png`, `v2-360x800-g-export-progress.png` | open |
| UI-010 | preview, export | ResumePreview | P2 | state | n/a | A resume that runs to two pages can be seen and understood | `PdfRaster.firstPageToPng` renders page index 0 only, and nothing in the UI says a second page exists. A user whose content overflows page one gets a preview that silently disagrees with the exported PDF, which breaks the "what you see is what you get" guarantee. Fixing it needs a page count out of the rasterizer plus a pager in the preview — a render-layer change, not a layout one | `lib/render/pdf_raster.dart` `firstPageToPng`; `pages: const [0]` | open |
| UI-011 | preview, export | EditorScreen preview tab, export action | P2 | tooling | 390x844 (web/chrome) | Preview and export confirmed on a real Android or iOS device | Verified on Flutter Web in Chromium only — no Android SDK, emulator, `adb`, or iOS simulator here. Two things are therefore unverified where they matter most: `Printing.sharePdf` opens a real share sheet (on web it silently downloads, so the dismissed-vs-shared distinction was never exercised), and PDFium rasterization on device (the web path is pdf.js). Storage-permission and out-of-space failure messages have never been seen fire | Screenshots at 360/390/430/768 plus landscape; `test/screens/editor_export_test.dart` takes the failure path only | open |
| UI-012 | export | EditorScreen | P3 | interaction | 390x844 (web/chrome) | A finished export is acknowledged | On success nothing is shown, on the assumption that the platform share sheet is its own confirmation. That holds on mobile but not on web, where the file downloads with no in-app trace and the progress snackbar has already closed. Left silent rather than risking a snackbar racing a native sheet on the platforms that were not testable here | `lib/screens/editor_screen.dart` `_export`; `ExportStatus.shared` has no UI branch | open |
| UI-013 | export | PdfExport | P3 | dead-control | n/a | Every shipped capability is reachable | `PdfExport.printDocument` — the system print / save-as-PDF path — has no entry point anywhere in the UI. It is tested but unreachable, so on desktop web there is no "print" and on Android no "save to Files" short of the share sheet. Adding a second export action is a product decision, not a layout fix | `lib/render/pdf_export.dart`; no call sites outside `test/render/pdf_export_test.dart` | open |
| UI-014 | preview | ResumePreview | P3 | polish | 390x844 (web/chrome) | The busy marker does not sit on top of the document | The "Updating" pill is anchored inside the page's top-right corner, which is exactly where most templates put the header, so mid-render it covers the last few characters of the person's name. There is ample empty chrome above and below the page to move it into, but that means restructuring the preview from a single letterboxed page into a page-plus-gutter layout | Screenshot `after-390x844-c-busy.png` | open |

| UI-015 | editor | _EditorForm | P2 | responsive | 768x1024 (web/chrome) | Single-line fields stop at a readable measure on a tablet | Form stretched edge to edge across ~736px, reading as an admin table rather than a document editor. Found only by looking at the running app; every widget test passed because nothing overflowed | Fixed: 640px max form width, matching the resume list. `test/screens/editor_responsive_test.dart` covers both tablet and phone | fixed |

| UI-016 | editor, export | EditorScreen | **P1** | state | n/a | A resume never silently loses a job | Templates drop content that does not fit rather than flowing to a second page, and measured capacity is only 4-7 roles depending on the design — inside a normal career. Content vanished with no warning, no extra page, and no visible gap, and the preview agreed with the export because both were truncated identically. **Partly fixed:** export now detects the loss and asks the user to confirm. The underlying one-page limit remains; UI-010 (multi-page) is the real fix | `lib/render/truncation_check.dart`; measured capacity per template recorded in the commit message | in-progress |

<!--
Row template:

| UI-001 | editor | EditorPage | P1 | keyboard | 360x800 (web/chrome) | Submit stays reachable with keyboard open | Submit hidden behind keyboard | console: no overflow; screenshot | open |
-->
