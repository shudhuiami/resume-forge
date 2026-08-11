---
name: flutter-ui-workflow
description: Disciplined end-to-end workflow for auditing, implementing, and verifying the UI of one Flutter screen or module. Use when the user runs /flutter-ui-workflow, names a screen/module to fix or polish, or asks for a Flutter UI audit, redesign, responsive pass, overflow fix, or visual verification. Handles one module at a time — not whole-app redesigns.
---

# Flutter UI Workflow

Runs a complete audit → implement → verify → report cycle over **one** screen or
closely related screen group.

```
/flutter-ui-workflow <module>
```

Examples:

```
/flutter-ui-workflow editor
/flutter-ui-workflow gallery
/flutter-ui-workflow preview
/flutter-ui-workflow resume-list
/flutter-ui-workflow export
```

## Scope rule — read this first

**This workflow operates on one module per run.** If the user names no module, or names
something that spans the whole app ("all screens", "the app", "everything"), do not
proceed with a global pass. Instead:

1. List the modules you can identify in `lib/`.
2. Ask which one to run against, or propose a sensible order.
3. Run against exactly one.

A single uncontrolled pass that rewrites every screen is the specific failure mode this
workflow exists to prevent. Multiple sequential runs are correct; one giant run is not.

## Preconditions

Verify before starting, and report honestly if any are missing:

- A Flutter project exists (`pubspec.yaml` + `lib/`)
- `flutter` and `dart` are on `PATH`
- Some visual verification route exists — `adb devices`, an iOS simulator, or
  Flutter Web + Chrome

If the SDK is missing, stop and say so. Do not run an audit that cannot be verified and
present it as though it were.

## Steps

Delegate the UI work to the **`flutter-ui-specialist`** agent, which carries the full
design-system, responsive, overflow, safe-area, keyboard, accessibility, and reporting
rules. This skill is the orchestration around it.

### 1. Audit

Have `flutter-ui-specialist` inspect the target module: purpose, navigation flow, state
and data dependencies, shared widgets already in use, theme components, expected user
actions, and current responsive behaviour.

### 2. Problem list

Produce a concrete, itemized defect list — not prose impressions. Assign each a severity:

| Severity | Meaning                                            |
| -------- | -------------------------------------------------- |
| **P0**   | Screen unusable, crash, critical flow inaccessible |
| **P1**   | Major workflow or interaction broken               |
| **P2**   | Responsive / usability / theme problem             |
| **P3**   | Visual polish                                      |

### 3. Implementation plan

State what will change, which existing components will be reused, and what (if anything)
new must be created. **Show this to the user before implementing.** Keep the smallest
reasonable diff.

### 4. Implement

Apply the plan to this module only. Reuse the existing design system — never introduce
ad-hoc colours, sizes, radii, or shadows. Do not touch unrelated modules. Do not move
business logic into widgets.

### 5. Format

```
dart format .
```

### 6. Analyze

```
flutter analyze
```

Fix what this surfaces in the touched files before continuing.

### 7. Tests

Run focused tests relevant to the module:

```
flutter test test/<module>/
```

Report actual results. **Never claim tests passed unless they ran.**

### 8. Run the app

Launch on the best available target:

1. Android emulator / device (`adb devices`)
2. iOS simulator
3. Flutter Web + Chrome (fallback)

### 9. Visual inspection

Navigate to the module and view the rendered result. Check console output for runtime
errors and overflow warnings.

### 10. Interaction verification

Exercise every interactive element on the screen. Confirm no dead buttons and no
clickable-looking element that does nothing. Test the keyboard-open state on any form.

### 11. Responsive verification

Check at minimum:

| Class        | Size     |
| ------------ | -------- |
| Phone small  | 360x800  |
| Phone normal | 390x844  |
| Phone large  | 430x932  |
| Tablet       | 768x1024 |

Check both normal and deliberately long content. Check empty, loading, and error states
where reachable.

### 12. Final report

Report all eleven items from the specialist's completion report — screens changed,
problems found, changes made, components reused, components created, responsive checks,
interactions tested, commands run with real results, runtime issues, remaining problems,
and **the exact platform visually verified**.

Append unresolved defects to `docs/ui/FLUTTER_UI_ISSUES.md` with the columns defined
there.

## Hard rules

- One module per run.
- Never report complete on the strength of `flutter analyze` alone.
- Never claim native Android/iOS verification when only Flutter Web was tested.
- If visual verification was impossible, say so and mark the work **unverified**.
- Report an inconsistent design system rather than silently starting a second one.
