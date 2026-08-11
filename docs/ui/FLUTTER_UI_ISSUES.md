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
| UI-002 | editor | EditorScreen | P2 | tooling | 390x844 (web/chrome) | Editor pixels visually verified at 360/390/430/768 | **Not visually verified.** Reaching the editor needs two taps and Flutter renders to a canvas: coordinate clicks are flaky and enabling the semantics tree injects DOM overlays that swallow pointer events. Layout is instead verified by widget tests at all four viewports with realistic, pathological, and empty content | `test/screens/editor_responsive_test.dart` — 14 tests, zero RenderFlex overflow | open |
| UI-003 | preview | PdfPageView | P2 | state | n/a | Preview tab rasterization verified on-device | `Printing.raster` is platform-bound and the preview tab was never reached in a browser session. Raster sizing maths is unit-tested; the actual pixels are unverified | `test/render/pdf_raster_test.dart` covers DPI/clamping only | open |
| UI-004 | app | all | P3 | performance | n/a | Preview latency measured on a low-end Android profile | No Android SDK, emulator, or `adb` in this environment. Task 9 remains unmeasured; template mass-production proceeds on the untested assumption that the debounce-and-rasterize loop is fast enough on budget hardware | — | open |

<!--
Row template:

| UI-001 | editor | EditorPage | P1 | keyboard | 360x800 (web/chrome) | Submit stays reachable with keyboard open | Submit hidden behind keyboard | console: no overflow; screenshot | open |
-->
