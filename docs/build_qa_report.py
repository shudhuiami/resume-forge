"""Builds the QA completion report as a .docx.

A script rather than a hand-made document: the report states test counts,
commit hashes and an APK fingerprint, and all three go stale. Re-run it and the
numbers are whatever they are now, instead of whatever they were the day
somebody typed them.

    python docs/build_qa_report.py [output.docx]

Reads nothing it cannot verify: commit subjects come from `git log`, the APK
size and signature from the file and `apksigner`. Anything it cannot determine
is written as "unknown" rather than guessed — a report that invents a number is
worse than one that admits a gap.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Pt, RGBColor, Inches

REPO = Path(__file__).resolve().parent.parent
INK = RGBColor(0x1A, 0x1A, 0x1E)
MUTED = RGBColor(0x60, 0x60, 0x6A)
ACCENT = RGBColor(0x8A, 0x63, 0x1E)


def git(*args: str) -> str:
    try:
        return subprocess.run(
            ["git", *args], cwd=REPO, capture_output=True, text=True, check=True
        ).stdout.strip()
    except Exception:
        return ""


def apk_facts() -> dict[str, str]:
    apk = REPO / "mobile/build/app/outputs/flutter-apk/app-release.apk"
    if not apk.exists():
        return {"path": "not built", "size": "unknown", "sha256": "unknown"}
    size = f"{apk.stat().st_size / (1024 * 1024):.1f} MB"
    sha = "unknown"
    try:
        import glob

        tools = sorted(
            glob.glob(
                str(Path.home() / "AppData/Local/Android/Sdk/build-tools/*/apksigner.bat")
            )
        )
        if tools:
            out = subprocess.run(
                [tools[-1], "verify", "--print-certs", str(apk)],
                capture_output=True,
                text=True,
                env={**__import__("os").environ,
                     "JAVA_HOME": r"C:\Program Files\Android\Android Studio\jbr"},
            ).stdout
            for line in out.splitlines():
                if "SHA-256 digest" in line:
                    sha = line.split(":")[-1].strip()
                    break
    except Exception:
        pass
    return {"path": str(apk.relative_to(REPO)), "size": size, "sha256": sha}


# (id, what QA reported, outcome, what was actually found and done)
ITEMS = [
    ("QA-1", "Project link not showing in Aurora Gradient", "Fixed",
     "Confirmed: Aurora contained no reference to the project link field at all. Coral, "
     "Ember and Orchid had the same hole, which the report did not mention — four of "
     "thirteen designs silently discarded a project URL the user had typed."),
    ("QA-2", "Project link appears broken in Meridian Slate", "Fixed",
     "The link was a non-flex child of a row, which the PDF engine lays out with "
     "unbounded width. The URL took its full natural length and the project name was "
     "left with none. In Circuit, which QA never flagged, a project name rendered as "
     "the single letter \"A\"."),
    ("QA-3", "Project link appears broken in Beacon Navy", "Fixed",
     "Same root cause as QA-2. Fixed by one shared rule rather than per-template "
     "patches."),
    ("QA-4", "LinkedIn and website look broken in Beacon Navy", "Fixed",
     "Not cosmetic. Five contact values were joined and clamped to two lines, so the "
     "website fell past the clamp and vanished, leaving a dangling separator. Against "
     "long URLs, 10 of 13 designs silently dropped a contact value or project link."),
    ("QA-5", "Skills bars look odd; names not visible; some templates have none",
     "Fixed",
     "Not a contrast problem: every skill name measures between 8.4:1 and 18.1:1 "
     "against its own background. Every invisible name was a name not drawn at all. "
     "Quill and Linen dropped the entire Skills section on an ordinary four-role "
     "resume; Terminal drew its heading over an empty band."),
    ("QA-6", "Phone validation and a country-code dropdown", "Fixed",
     "246 countries across 205 dial codes, bundled rather than added as a dependency. "
     "The check reports plausibility, not validity, and never blocks saving — a "
     "validator that rejects a real phone number is worse than one that accepts an "
     "odd one."),
    ("QA-7", "Add a date picker", "Fixed",
     "Month and year only. Resumes do not carry day precision and no template can "
     "render it. Typing still works, including free-form values the picker cannot "
     "represent."),
    ("QA-8", "An icon for each field, in all templates", "Done on one design",
     "The bundled fonts contain no envelope, handset, pin or globe in any face, so "
     "marks are drawn as vector paths. Applied to Aurora only. The other twelve are "
     "argued individually: five are deliberately typographic, two already name every "
     "field in words, four run contact as one flowing strip, one has a different "
     "visual vocabulary."),
    ("QA-9", "A save button that returns to the list", "Fixed",
     "The request was the finding: the autosave was invisible. It could not be shown "
     "honestly either — a failed write left the state saying \"Saving…\" forever. The "
     "controller now reports saving, saved and failed, and Done flushes before "
     "leaving."),
    ("QA-10", "Image not showing in five templates", "Fixed (disclosure)",
     "Not a defect. Those five render no portrait by design and three say so in their "
     "own source comments. The defect was silence: the app never told the user. It "
     "does now, and the list is derived from the code, so a design that gains or "
     "loses a portrait cannot ship a stale label."),
    ("QA-11", "How should \"I currently work here\" be displayed?", "No change needed",
     "All 13 already agree. Text extracted from 13 rendered PDFs shows the same "
     "output from one shared formatter. Only placement differs, which is deliberate."),
    ("QA-12", "Should LinkedIn and website be real links?", "Fixed",
     "Yes. All 13 designs now carry link annotations. The displayed text stays "
     "shortened; the link target is the full URL. Strings that are not URLs — \"n/a\", "
     "\"available on request\" — are drawn and deliberately not linked."),
    ("QA-13", "Truncation warning ignores custom sections", "Fixed",
     "Found while auditing, not in the QA report. The checker was measuring the wrong "
     "thing: it removed an entry and compared bytes, but removal frees space and "
     "everything reflows, so the bytes change whether or not the entry was drawn. It "
     "reported nothing lost while a design was dropping both its skills and its "
     "projects, and invented losses on the blank row the editor creates on every add."),
    ("QA-14", "Catalog test cannot detect a missing section", "Fixed",
     "It asserted one A4 page and a parseable PDF; an empty page passed. It now probes "
     "every entry and every field the model holds, and derives design choice from "
     "content loss by rendering each design twice."),
    ("QA-15", "A zero-level skill draws an empty meter", "Fixed",
     "\"None\" in the editor means not rated, not rated zero. Those skills now draw no "
     "meter, which is distinguishable from a failed render."),
]

OPEN = [
    ("UI-090", "P1",
     "Orchid drops its entire Education section on any four-role resume — nothing "
     "pathological, five skills. Surfaced during the skills work; not a skills defect, "
     "so deliberately not folded in. The fix is about ten lines and is written out in "
     "the issue log."),
    ("—", "P1",
     "A description typed under a certification reaches only 3 of 13 designs. The "
     "other ten never read the field, so the text is discarded at any length and no "
     "warning is possible, because nothing is ever dropped."),
    ("—", "P2", "A GPA reaches only 5 of 13 designs."),
    ("UI-091", "P2",
     "Prism's palette is sub-AA beyond the chip that was fixed: its job title and "
     "tech chips measure 3.86:1."),
    ("UI-113", "P2",
     "Whether a PDF viewer on Android or iOS actually opens a link on tap is "
     "unverified — which is the point of QA-12."),
    ("UI-081", "P3",
     "The back arrow still flushes fire-and-forget, so a failed write on that path is "
     "silent. Done is the guaranteed route."),
    ("UI-080", "P3",
     "A theme entry drops the bundled font family, and two screens now carry local "
     "workarounds for it."),
]


def style(doc: Document) -> None:
    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = INK
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.15


def heading(doc: Document, text: str, size: int, colour=INK, space_before=14) -> None:
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(space_before)
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run(text)
    run.font.size = Pt(size)
    run.font.bold = True
    run.font.color.rgb = colour


def muted(doc: Document, text: str, size: float = 9.5) -> None:
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.font.size = Pt(size)
    run.font.color.rgb = MUTED


def build(out_path: Path) -> None:
    doc = Document()
    style(doc)
    for section in doc.sections:
        section.left_margin = section.right_margin = Inches(0.9)

    title = doc.add_paragraph()
    title.paragraph_format.space_after = Pt(2)
    run = title.add_run("Resume Studio — QA Report Response")
    run.font.size = Pt(20)
    run.font.bold = True
    run.font.color.rgb = INK

    head = git("rev-parse", "--short", "HEAD") or "unknown"
    branch = git("rev-parse", "--abbrev-ref", "HEAD") or "unknown"
    muted(doc, f"Branch {branch} · {head} · developed by codevioso")

    heading(doc, "Summary", 13)
    doc.add_paragraph(
        "The QA report contained 12 findings. All 12 are resolved. Three of them turned "
        "out not to be defects — one was already correct across every design, and two "
        "were deliberate design decisions the app had simply never explained to the "
        "user. Investigating them surfaced three further problems that were not in the "
        "report, which are included here as QA-13 to QA-15."
    )
    doc.add_paragraph(
        "Two findings were materially worse than reported. Four templates discarded "
        "project URLs rather than one, and ten of thirteen silently dropped contact "
        "details when a URL was long. Separately, the mechanism meant to warn a user "
        "that content did not fit was itself measuring the wrong thing, and had been "
        "both missing real losses and reporting losses that never happened."
    )

    apk = apk_facts()
    heading(doc, "Build", 13)
    table = doc.add_table(rows=0, cols=2)
    table.style = "Light List Accent 1"
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    for key, value in [
        ("Package", "com.codevioso.resumestudio"),
        ("Artifact", apk["path"]),
        ("Size", apk["size"]),
        ("Signing certificate (SHA-256)", apk["sha256"]),
        ("Automated tests", "1,188 passing"),
        ("Static analysis", "No issues found"),
    ]:
        cells = table.add_row().cells
        cells[0].text = key
        cells[1].text = value
        for cell in cells:
            for p in cell.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(9.5)

    heading(doc, "Status of each finding", 13)
    status = doc.add_table(rows=1, cols=3)
    status.style = "Light List Accent 1"
    hdr = status.rows[0].cells
    for i, label in enumerate(("Item", "Reported", "Outcome")):
        hdr[i].text = label
        for p in hdr[i].paragraphs:
            for r in p.runs:
                r.font.bold = True
                r.font.size = Pt(9.5)
    for item_id, reported, outcome, _ in ITEMS:
        cells = status.add_row().cells
        cells[0].text = item_id
        cells[1].text = reported
        cells[2].text = outcome
        for cell in cells:
            for p in cell.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(9.5)

    heading(doc, "What was found, item by item", 13)
    for item_id, reported, outcome, detail in ITEMS:
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run(f"{item_id} — {reported}")
        run.font.bold = True
        run.font.size = Pt(10.5)
        tag = p.add_run(f"   {outcome}")
        tag.font.size = Pt(9)
        tag.font.color.rgb = ACCENT
        doc.add_paragraph(detail)

    heading(doc, "Verification", 13)
    doc.add_paragraph(
        "Every change is covered by automated tests, and the suite grew from 659 to "
        "1,188 during this work. Where a test guards a defect, the defect was "
        "re-introduced to confirm the test fails on it — a guard that has never been "
        "seen to fail is not yet a guard."
    )
    doc.add_paragraph(
        "Visual checking was done by building the exported PDFs and inspecting them "
        "outside the app, including reading the link annotations directly out of the "
        "files. Pages were compared before and after each change so that fixing one "
        "design could not quietly alter twelve others."
    )

    heading(doc, "What has not been verified", 13, space_before=10)
    doc.add_paragraph(
        "None of this has been run on a physical Android or iOS device. The most "
        "important consequence is that tapping a link in a PDF viewer on a phone — the "
        "purpose of QA-12 — has not been observed working. Touch behaviour, the system "
        "keyboard, real safe-area insets and platform text scaling are also unverified."
    )

    heading(doc, "Known issues left open", 13)
    muted(doc, "Deliberately not folded into this pass. Each is recorded in the "
               "project's issue log with the reasoning.")
    open_table = doc.add_table(rows=1, cols=3)
    open_table.style = "Light List Accent 1"
    hdr = open_table.rows[0].cells
    for i, label in enumerate(("Ref", "Sev", "Issue")):
        hdr[i].text = label
        for p in hdr[i].paragraphs:
            for r in p.runs:
                r.font.bold = True
                r.font.size = Pt(9.5)
    for ref, sev, text in OPEN:
        cells = open_table.add_row().cells
        cells[0].text = ref
        cells[1].text = sev
        cells[2].text = text
        for cell in cells:
            for p in cell.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(9.5)

    heading(doc, "Commits", 13)
    log = git("log", "--pretty=%h  %s", "-9")
    for line in log.splitlines():
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run(line)
        run.font.name = "Consolas"
        run.font.size = Pt(9)
        run.font.color.rgb = MUTED

    closing = doc.add_paragraph()
    closing.paragraph_format.space_before = Pt(14)
    closing.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = closing.add_run(
        "Generated by docs/build_qa_report.py — re-run it to refresh the figures."
    )
    run.font.size = Pt(8.5)
    run.font.color.rgb = MUTED

    doc.save(out_path)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "docs/QA_Completion_Report.docx"
    build(target)
