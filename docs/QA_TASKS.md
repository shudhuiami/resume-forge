# QA report — triaged task list

Source: `Resume App QA Report.docx` (12 findings, 16 annotated screenshots).

Each item below records what QA reported, what the code actually does, and what
the work is. **Three of the twelve are not defects** — they are existing design
decisions or open product questions, and shipping a "fix" for them without a
decision would be worse than leaving them.

Verified while triaging, not assumed:
- 8 of 13 templates call `tryDecodePhoto`; 5 never do.
- `aurora_template.dart` contains no reference to `pr.link` at all.
- `meridian` and `beacon` both render `pr.link`.

---

## A. Confirmed defects

### QA-1 — Aurora Gradient never renders the project link
**P1.** QA: "The project link is not showing in the Aurora Gradient template."

Confirmed in code: Aurora has no `pr.link` reference, while Meridian and Beacon
both do. A user who fills in a project URL loses it silently on export — the
same class of failure as UI-016, where content the user typed does not reach
the PDF.

Work: render the link in Aurora, matching how the section already treats
secondary text. Then add a test that asserts **every** template that renders a
projects section also renders a non-empty `link`, so the next template cannot
ship with the same hole.

### QA-2 — Project link "appears broken" in Meridian Slate
**P2.** Both templates draw the link, so this is presentation, not omission.
Likely a long URL overflowing, wrapping mid-token, or colliding with the date
column. Needs the annotated screenshot compared against a render with a
realistic long URL (`https://github.com/user/some-long-repository-name`).

### QA-3 — Project link "appears broken" in Beacon Navy
**P2.** Same as QA-2, different layout. Fix together — one truncation/wrapping
rule for links, applied everywhere a link is drawn.

### QA-4 — LinkedIn and Website look broken in Beacon Navy
**P2.** QA: "When LinkedIn and Website links are added, they look odd… seemed
like broken." Contact-block links, not project links, but almost certainly the
same root cause: no rule for how a long URL behaves in a narrow column.

**QA-1 through QA-4 should be one piece of work** — a single "how this app draws
a URL" decision (strip scheme? truncate mid-path? never wrap mid-token?) applied
across all 13 templates, with one test that feeds every template a pathological
URL.

### QA-5 — Skills bars look wrong and skill names are missing
**P2.** QA: "The progress bars in the Skills section look a bit odd, and the
progress names are not visible… Also, some templates don't have them."

Partly true, partly by design. Skill-level rendering is genuinely inconsistent:
`beacon`, `coral` and `linen` draw no meter at all, while `meridian`, `aurora`
and `ledger` are meter-heavy. That inconsistency is deliberate per-design, but
"names not visible" is a real bug wherever it happens and needs reproducing per
template.

Work: reproduce with a realistic skill set, fix the missing labels, and decide
explicitly which designs are meant to show a meter. Record that decision — the
next QA pass will otherwise report it again.

---

## B. Feature requests

### QA-6 — Phone number: validation + country-code dropdown
**P2, largest item in the report.** QA wants a country-code dropdown that also
updates the placeholder to that country's phone format, reflected in every
template.

Scope honestly before starting: a full country-code list plus per-country
formatting is a dependency (`libphonenumber`-class) or a large hand-maintained
table, and this app currently ships **no** network and few dependencies. A
lighter version — free-text field, light validation, no reformatting — delivers
most of the value at a fraction of the size. Needs a product call.

### QA-7 — Date picker for date fields, in every template
**P2.** Today dates are typed. `MonthYearField` already exists and is
controller-backed, so this is a picker on top of an existing field rather than
new plumbing. Month/year granularity is what resumes use — a full day-precision
picker would be wrong.

### QA-8 — Field icons in all templates
**P3.** QA: "It would be better to have an appropriate icon for each field."
Design decision, not a defect: several templates are deliberately typographic
(Quill, Ledger, Linen). Applying icons to *all* templates would flatten the
distinctions the gallery advertises. Suggest: adopt per-design, not globally.

### QA-9 — Explicit Save button that returns to the list
**P2.** The editor autosaves and has no Save button by design. QA asking for one
is a signal the autosave is invisible — users cannot tell their work is safe.

Two possible answers, and they are different products: (a) add a real Save
action that pops to the list, or (b) keep autosave and make it *legible* (a
"Saved" state in the app bar). The new toast system makes (b) cheap. Recommend
deciding which before building.

---

## C. Not defects — decisions required

### QA-10 — "The image is not showing" in Ledger Mono, Terminal Green, Quill Academic, Linen Minimal, Orchid Editorial
**Not a bug.** Those five templates deliberately render no portrait, and three
say so in their own doc comments ("Deliberately photo-free: an editorial CV is a
byline, not a headshot"). The five QA listed are exactly the five that do not
call `tryDecodePhoto`.

The real issue is that **the app never tells the user this**. A photo added on a
photo-free design silently does not appear. Work: surface it — mark those
designs in the gallery, or warn in the editor when the chosen design ignores the
photo. Adding photos to all five is a product decision that would erase a
deliberate distinction between the designs.

### QA-11 — How should "I currently work here" be displayed?
**RESOLVED — no work required.** The audit extracted text from all 13 rendered
PDFs: every one prints `2021-03 — Present`, `2016-09` alone when the end is
blank and the switch is off, and `Present` alone when there are no dates. All 13
call one source, `formatRange`, with `current: e.current`. Only *placement*
differs — gutter, pill, or above the title — which is deliberate design
variation. There is nothing to reconcile.

### QA-12 — Do we need links for LinkedIn and website?
**Open question.** They are rendered as text today. Making them *tappable* in
the PDF is a `dart_pdf` annotation feature, not a layout change — worth doing if
recruiters open PDFs on screen, pointless if printed. Note this interacts with
QA-4: the display problem should be fixed regardless of the answer.

---

## Suggested order

1. **QA-1..QA-4** — one URL-rendering pass. Real data loss (Aurora) plus the
   most-reported visual complaint.
2. **QA-10** — cheap to surface, prevents silent photo loss.
3. **QA-5** — skill labels.
4. **QA-9**, then **QA-7** — both improve confidence in the editor.
5. **QA-11**, **QA-12**, **QA-8** — need a product decision first.
6. **QA-6** — largest, and the one most worth scoping down.


---

## D. Found while auditing — not in the QA report

### QA-13 — `TruncationCheck` never inspects `customSections`
**P1.** Ledger and Terminal both drop the whole Certifications section on a
four-role resume, and the truncation warning says nothing about it. The warning
is the app's only defence against silent content loss, and it has a blind spot.

### QA-14 — `catalog_test.dart` cannot catch any of this
**P2.** It asserts one A4 page and a parseable PDF. It never asserts that a
section present in the data appears in the output, so an empty page would pass.
Every defect in `TEMPLATE_AUDIT.md` was invisible to the suite.

### QA-15 — Level 0 renders as a blank meter
**P3.** In aurora, meridian and ember a zero-level skill draws an empty bar
(ledger draws 0 of 5 marks) — indistinguishable from a failed render, and
probably part of QA's "the bars look a bit odd".
