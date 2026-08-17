# Template audit — QA-5 (skills) and QA-11 (open-ended roles)

Evidence for `QA_TASKS.md` items **QA-5** and **QA-11**. Every row in the tables
below was produced by building the real PDF for all 13 templates and reading the
result, not by reading the source alone. Where a statement rests on code reading
only, it says so.

---

## 1. How this was established

**Rendering.** A temporary test harness drove `PdfRenderer.build` over
`resumeTemplates` and wrote one PDF per template per fixture. `Printing.raster`
does not work under `flutter_test`, so the PDFs were rasterized and text-extracted
outside Flutter with PyMuPDF 1.28.2 (`get_text("text")` for content, 2×–6× pixmaps
for the visual checks). The harness has been deleted; the fixtures are reproduced
in §6 so any row here can be regenerated.

**Fixtures** (all built on `sampleResume`, the app's own filler, so the results
describe realistic input rather than a synthetic worst case):

| id | Content |
|----|---------|
| A | 8 skills spanning levels 0–5, including one 62-character name and one 1-character name; 4 roles covering all four date shapes |
| B | 24 skills of ~45 characters each; same 4 roles |
| C | 6 short skills, one per level 0–5; same 4 roles |
| D | Skills only — no summary, roles, projects, education |
| E | `sampleResume` exactly as shipped (5 skills, 3 roles) |
| F | `sampleResume` plus one extra role — 4 roles, everything else identical |

**Code state.** Rendered against the working tree on `claude/flutter-resume-app`
while another agent was mid-edit on the QA-1..QA-4 URL work — by the end of this
audit all 13 template files plus `template.dart` were modified in the working
tree. Those edits touch link rendering only: `formatRange` is byte-identical to
HEAD and no skill-rendering code is changed by them (verified with `git diff`).
Every finding below was re-rendered and re-verified after those edits landed, and
came out identical.

> **Line numbers here are a hint, not an address.** They drifted three times
> during this audit. **Locate every reference by the symbol name given first**
> (`_skillMeter`, `_skillCloud`, `formatRange`, …); the line number is where it
> sat at the moment of writing.

---

## 2. The table

### 2a. Skills — what each design draws

| # | Template | Skill **name** drawn? | **Level** rendering | Cap | Name colour vs its own ground |
|---|----------|----------------------|---------------------|-----|-------------------------------|
| 1 | `aurora` Aurora Gradient | Yes, 1 line, clipped | **Proportional bar** (0–5, gradient fill on `#EDEAF7` track) | **none** | 17.2 : 1 |
| 2 | `meridian` Meridian Slate | Yes, 1 line, clipped | **Proportional bar** (0–5, accent fill on slate track) | 8 | 8.4 : 1 |
| 3 | `beacon` Beacon Navy | Yes, full, wraps to its own row | **None** — square bullet only, `level` unread | 10 | 14.7 : 1 |
| 4 | `ledger` Ledger Mono | Yes, full | **Segmented meter** — 5 discrete marks, n filled | 8 | 17.7 : 1 |
| 5 | `compass` Compass Teal | Yes, 1 line, clipped | **None** — `_chip(s.name…)` never receives `level` | 12 | 9.1 : 1 |
| 6 | `circuit` Circuit Blue | Yes, 1 line, clipped | **Binary** — `level >= 4` fills the chip | 16 | 13.4 : 1 (5.2 : 1 filled) |
| 7 | `terminal` Terminal Green | Yes, full, **lower-cased** | **Binary** — `level >= 4` recolours the token | 14 | 13.0 : 1 (10.2 : 1 strong) |
| 8 | `quill` Quill Academic | Yes, names joined with ` · `, 3-line clamp | **None** — `level` unread | 12 | 15.2 : 1 |
| 9 | `linen` Linen Minimal | Yes, names joined with `   ·   `, 3-line clamp | **None** — `level` unread | 10 | 17.7 : 1 |
| 10 | `coral` Coral Bloom | Yes, 1 line, clipped | **None** — `_chip(s.name…)` never receives `level` | 14 | 15.0 : 1 |
| 11 | `orchid` Orchid Editorial | Yes, 2 lines, clipped | **None** — square bullet only, `level` unread | 12 | 18.1 : 1 |
| 12 | `prism` Prism Cards | Yes, 1 line, clipped | **Binary** — `level >= 4` fills the chip | 16 | 15.2 : 1 (**4.2 : 1** filled) |
| 13 | `ember` Ember Dark | Yes, 1 line, clipped | **Proportional bar** (0–5, amber on umber track) | 12 | 15.6 : 1 |

Contrast ratios computed from the palette constants and confirmed against the
rasterized pages. Caps are the `take(n)` applied to `data.skills`.

Summary of the level column: **4 designs show the full 0–5 scale** (aurora,
meridian, ledger, ember), **3 show a binary strong/normal split** at level ≥ 4
(circuit, terminal, prism), **6 show nothing at all** (beacon, compass, quill,
linen, coral, orchid).

### 2b. Open-ended roles — what each design prints

Four date shapes were rendered through every template. **All 13 agree, exactly,
in all four cases** — verified by extracting the text of all 13 PDFs and matching
the strings:

| Input | Printed, in all 13 templates |
|-------|------------------------------|
| `startDate: '2021-03'`, `current: true`, `endDate: ''` | `2021-03 — Present` (em dash U+2014, spaces either side) |
| `startDate: '2018-06'`, `endDate: '2021-02'` | `2018-06 — 2021-02` |
| `startDate: '2016-09'`, `endDate: ''`, `current: false` | `2016-09` — no dash, no trailing marker |
| no dates, `current: true` | `Present` alone |

The single source is `formatRange` in `lib/templates/template.dart` (≈491), and
every one of the 13 experience renderers calls it with `current: e.current` —
verified by grepping all 13 files and confirmed by the rendered text above. There
is no per-template divergence to reconcile.

Placement and styling do differ, which is design, not inconsistency:

| Placement | Templates |
|-----------|-----------|
| Right-aligned beside the job title | meridian, terminal, quill, linen, prism |
| Right-aligned beside the company | compass, circuit, coral |
| Left gutter beside the entry | beacon (88 pt), ledger (92 pt, mono) |
| Rounded "date pill" beside the title | aurora, ember |
| Own line **above** the job title | orchid |

---

## 3. Defects — content the user entered that does not reach the page

### D-1 (P1) — Quill and Linen drop the **entire** Skills section on a 4-role resume

**Verified by rendering.** With fixture F — `sampleResume` untouched plus one
extra role — `quill` and `linen` produce a PDF containing no Competencies /
Skills heading and none of the five skill names. With fixture E (3 roles,
the shipped sample) both render skills correctly, so this is a `pw.Column`
child-drop against the height budget, not an omission in the design.

Both put skills **last** in a height-bounded Column, so it is the first thing
evicted:

- `quill_template.dart` — `if (skills.isNotEmpty)` inside `build`, the final entry
  of the body Column (≈121), rendering `skills.map((s) => s.name).join(' · ')`
  (≈125).
- `linen_template.dart` — `if (skills.isNotEmpty)` inside `build` (≈178),
  rendering `skills.map((s) => s.name).join('   ·   ')` (≈184), inside the
  `height: a4.height - _footerReserve` box (≈100).

Four roles is an ordinary resume, and the Linen page still has visible whitespace
between Certifications and the pinned footer when the section disappears, so it
does not read as "the page is full".

`TruncationCheck` *does* flag this — it reports `[skills]` for both templates on
fixtures A and F — so the user sees a warning. The warning wording is wrong for
this case: `TruncationReport.describe()` says "Some of your skills does not fit",
when in fact all of it is gone.

### D-2 (P1) — Terminal draws an empty `~/skills` section

**Verified by rendering.** With fixture B, Terminal's own `_maxSkills = 14` takes
the first 14 names (~45 characters each) and **all 14 vanish**: the `~/skills`
heading and its rule render, and the entire chip cloud beneath is missing, leaving
a labelled empty band above `$ exit`. This is a distinct failure from D-1 because
the heading survives, so the page advertises a section it does not contain.

Cause is structural: inside `terminal_template.dart`'s `if (skills.isNotEmpty)`
block (≈162), the section header `_sectionHeader('skills', …)` (≈164) and the
cloud `pw.SizedBox(width: _contentW, child: _skillCloud(skills, …))` (≈165) are
two separate Column children. The cloud is one indivisible widget, so it is
dropped whole while the header stays. This is exactly the "some templates don't
have them" QA reported.

### D-3 (P2) — Long skill names are silently truncated mid-phrase in 8 of 13

**Verified by rendering.** The 62-character name
`Enterprise Resource Planning Systems Integration and Migration` came out as:

| Rendered as | Chars kept | Templates |
|-------------|-----------|-----------|
| Full name | 62 | beacon, ledger, terminal |
| `Enterprise Resource Planning Systems Integration and` (2 lines, clipped) | 53 | orchid |
| `Enterprise Resource Planning Systems` (1 line, clipped) | 37 | aurora, circuit, compass, coral, ember, prism |
| `Enterprise Resource Planning` (1 line, clipped) | 29 | meridian |

There is no ellipsis and no other signal — in the chip designs the chip simply
stretches to the full column width and the text stops. `TruncationCheck` does not
catch this: it only detects *dropped entries*, never a clipped one, so nothing
warns the user.

Where the clamp happens — symbol first, line at time of writing:

| Template | Symbol | ≈line |
|----------|--------|-------|
| aurora | `_skillMeter` | 362 |
| meridian | `_skillBar` | 221 |
| compass | `_chip` | 335 |
| circuit | inline chip under `for (final s in skills)` | 291 |
| coral | `_chip` | 377 |
| prism | `_chip` | 386 |
| ember | `_skillMeter` | 332 |
| orchid | `_skill` | 304 |

Beacon (`_skillItem`, ≈471) and Terminal (`_skillCloud`, ≈579) avoid it because
their `Wrap` lets an over-wide child take its own row; Ledger (`_skillRow`, ≈481)
avoids it because the name sits in an `Expanded` across the full content width.

Whether this is a defect or the documented `clampedText` guard working as
intended is a decision, not a fact — but the *inconsistency* across designs is
not defensible, and three templates prove the full name fits.

### D-4 (P2) — Aurora has no skills cap and evicts Education

**Verified by rendering.** In `aurora_template.dart`'s `_sidebar`, the skills line
is `...data.skills.map((s) => _skillMeter(s, sans, p))` (≈240) — the only skills
call site in the catalog with no `take(n)`. With 24 skills (fixture B), Aurora
renders 20 meters, the last ending at y = 794.9 pt of an 809.9 pt content box, and
the **Education section is gone entirely** from the sidebar. Every other template
caps at 8–16 so its sidebar cannot be monopolised this way.

### D-5 (P3) — Prism's filled skill chip is below WCAG AA

**Computed from the palette, confirmed legible in the render.** For `level >= 4`,
`prism_template.dart`'s `_chip` (≈386) draws `p.onPrimary` (`#FFFFFF`) on
`p.primary` (`#8B5CF6`) at 8.2 pt: **4.23 : 1**, under the 4.5 : 1 AA threshold
for text this size. Circuit's equivalent treatment is 5.17 : 1 and passes. Not
invisible — flagged because Ember's doc comment shows the catalog does take
contrast on the printed page seriously.

---

## 4. Design variation — not defects

- **Meter vs no meter.** 4 designs draw a 0–5 meter, 3 a binary highlight, 6
  nothing. The editor already discloses this: the Skills `FormSectionCard`
  subtitle reads "Rated out of five. Some designs show the rating, some just the
  name." (`lib/screens/editor_screen.dart`, ≈1155). QA's "some templates don't have
  them" is *partly* this and partly D-2 — they are different problems and should
  be answered separately.
- **Different caps** (8–16) — each design's density is deliberate.
- **Date placement** (gutter / pill / above title / inline) — see §2b.
- **Terminal lower-cases skill names** (`_skillCloud`, `s.name.toLowerCase()`,
  ≈599) — in keeping with a shell-prompt design, but it is a
  content transform: a user's `SQL` prints as `sql` and `C#` as `c#`. Worth a
  decision, not a bug report.
- **Skill name colour.** No template draws a skill name in a colour or size that
  makes it invisible. The tightest is Prism's filled chip (D-5); the rest sit
  between 8.4 : 1 and 18.1 : 1. **QA's "the progress names are not visible" is not
  reproducible as a contrast problem** — every instance found traces to D-1 or
  D-2, where the name is not drawn at all.

---

## 5. Not reported by QA, observed while looking at rendered pages

1. **`TruncationCheck` never checks custom sections.**
   `TruncationCheck.run` (`lib/render/truncation_check.dart`, the four
   `await check(...)` calls at ≈102-121) covers experience, education, projects
   and skills — `data.customSections` is not checked at all. Verified by
   rendering: with fixture A, `ledger` and `terminal` both drop the entire
   Certifications section, and `TruncationCheck.run` returns `[skills]` and
   `[education]` respectively — no mention of the loss the user would actually
   notice. A user's certifications, publications or languages can vanish with no
   warning whatsoever.

2. **`catalog_test.dart` cannot catch any of this.** It asserts the PDF is one
   A4 page and parses (`test/templates/catalog_test.dart`, the "keeps
   pathological content on one page" test, ≈84) but never asserts that a section the data
   contains actually appears in the output. A template that renders an empty page
   would pass. This is why D-1 and D-2 shipped.

3. **Two leftover harnesses are sitting in the test tree.** Both untracked, both
   self-described as temporary, neither mine (mine was deleted):
   - `mobile/test/render/zz_url_harness_test.dart` — dereferences
     `Platform.environment['URL_HARNESS_OUT']!` at the top of `main()`, so a
     plain `flutter test` fails during collection on that file.
   - `mobile/test/zzz_qa79_capture_harness_test.dart` — a QA-7/QA-9 visual
     capture harness; it is at least gated with `@Tags(['capture'])`.

   Left in place because other agents may still be using them. Neither should be
   committed.

4. **The truncation warning under-states the loss.**
   `TruncationReport.describe()` (`lib/render/truncation_check.dart`, ≈20) always
   says "Some of your X does not fit". For D-1 the correct statement is that all
   of it is gone.

5. **Skill level 0 renders as a blank meter.** The editor's slider labels level 0
   "None" (`_SkillSlider._labels`, `editor_screen.dart`). Verified by rendering
   fixture C: in Aurora, Meridian and Ember a level-0 skill draws an entirely
   unfilled track, and in Ledger zero of five marks — visually indistinguishable
   from a meter that failed to render, which is a plausible part of what QA meant
   by "the progress bars look a bit odd". In the six designs that ignore `level`
   entirely, a level-0 and a level-5 skill are identical.

---

## 6. Reproducing

Fixture A skills (levels chosen to exercise 0 through 5, plus one long and one
1-character name):

```dart
const [
  Skill(id: 'sk-1', name: 'Design systems', level: 5),
  Skill(id: 'sk-2',
        name: 'Enterprise Resource Planning Systems Integration and Migration',
        level: 3),
  Skill(id: 'sk-3', name: 'C', level: 0),
  Skill(id: 'sk-4', name: 'Prototyping', level: 1),
  Skill(id: 'sk-5', name: 'User research', level: 2),
  Skill(id: 'sk-6', name: 'Accessibility', level: 4),
  Skill(id: 'sk-7', name: 'Figma', level: 5),
  Skill(id: 'sk-8', name: 'Data visualisation', level: 0),
]
```

Fixture A roles — the four date shapes:

```dart
const [
  Experience(id: 'exp-1', startDate: '2021-03', endDate: '', current: true,  …),
  Experience(id: 'exp-2', startDate: '2018-06', endDate: '2021-02',          …),
  Experience(id: 'exp-3', startDate: '2016-09', endDate: '',                 …),
  Experience(id: 'exp-4', startDate: '',        endDate: '', current: true,  …),
]
```

Fixture F, the one that reproduces D-1 most cheaply:

```dart
sampleResume.copyWith(
  experiences: [...sampleResume.experiences, /* any fourth role */],
)
```

Build with `PdfRenderer.build(template: t, data: fixture)` from a
`TestWidgetsFlutterBinding.ensureInitialized()` test, write the bytes to disk, and
inspect outside Flutter — `Printing.raster` throws `MissingPluginException` under
`flutter_test`. Delete the harness afterwards.
