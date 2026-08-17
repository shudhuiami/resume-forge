import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// A formal academic CV: one column, serif throughout, no photograph.
///
/// Two decisions carry the design. Sections are labelled in faux small caps —
/// a full-size initial followed by tracked-out capitals, assembled with
/// [pw.RichText] because Lora ships no small-caps variant — and the custom
/// sections (publications, certifications, fellowships) are promoted to a
/// cream panel directly beneath education rather than being exiled to a
/// sidebar, which is where an academic reader looks for them.
///
/// The rest is deliberately plain: a centred masthead over a double rule,
/// generous leading, and no colour beyond the oxblood used for labels.
class QuillTemplate extends ResumeTemplate {
  const QuillTemplate();

  @override
  String get id => 'quill';

  @override
  String get name => 'Quill Academic';

  @override
  String get description =>
      'Formal single-column CV in serif type, with small-caps section labels '
      'and publications given front-page prominence.';

  @override
  String get bestFor => 'Research, Academia, Medicine';

  @override
  TemplateCategory get category => TemplateCategory.academic;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.serif};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF7F1D1D),
    secondary: PdfColor.fromInt(0xFF292524),
    accent: PdfColor.fromInt(0xFFFEFCE8),
    ink: PdfColor.fromInt(0xFF292524),
    muted: PdfColor.fromInt(0xFF6B6259),
  );

  static const _pad = 52.0;
  static final _contentW = a4.width - _pad * 2;
  static const _rule = PdfColor.fromInt(0xFFD8D2C7);

  static const _maxExperience = 4;
  static const _maxProjects = 3;
  static const _maxEducation = 3;
  static const _maxCustomSections = 3;
  static const _maxCustomItems = 4;
  static const _maxSkills = 12;

  @override
  pw.Widget build(TemplateContext ctx) {
    final serif = ctx.family(FontFamily.serif);
    final data = ctx.data;
    final p = ctx.palette;

    final education = data.education.take(_maxEducation).toList();
    final customSections = data.customSections
        .take(_maxCustomSections)
        .toList();
    final experiences = data.experiences.take(_maxExperience).toList();
    final projects = data.projects.take(_maxProjects).toList();
    // Not capped here: [skillRun] applies _maxSkills itself, so the names the
    // cap removes are still counted in its `+N more` marker rather than
    // disappearing before it can see them.
    final skills = data.skills.map((s) => s.name).toList();
    final summary = data.personalInfo.summary.trim();

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        padding: const pw.EdgeInsets.fromLTRB(_pad, 48, _pad, 34),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _masthead(ctx, serif),
            if (summary.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _label('Profile', serif, p),
              clampedText(
                summary,
                maxLines: 5,
                align: pw.TextAlign.justify,
                style: pw.TextStyle(
                  font: serif.regular,
                  fontSize: 9.4,
                  color: p.ink,
                  lineSpacing: 3.8,
                ),
              ),
            ],
            // Skills rule item 1. Everything from education to the last project
            // grows with the resume, and competencies sat underneath it all as
            // the final plain child of a page-height Column — so a fourth
            // appointment was enough for dart_pdf to stop laying out before it
            // and drop the entire section, on a page that still had visible
            // white space. As a loose Flexible this block is measured after the
            // competencies line and takes only the space left over, so it is
            // the one that gives up an entry instead.
            if (education.isNotEmpty ||
                customSections.isNotEmpty ||
                experiences.isNotEmpty ||
                projects.isNotEmpty)
              pw.Flexible(
                fit: pw.FlexFit.loose,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  // Without this the inner Column takes MainAxisSize.max, sizes
                  // itself to the whole leftover budget rather than to its
                  // content, and drives Competencies onto the page foot.
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    // Skills rule item 2: each label travels with its first
                    // entry. As plain siblings the truncation could fall
                    // between them, and it did — the page came out with a
                    // "Selected Work" rule over an empty band.
                    if (education.isNotEmpty)
                      ...headedSection(
                        heading: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.SizedBox(height: 20),
                            _label('Education', serif, p),
                          ],
                        ),
                        entries: education
                            .map((e) => _education(e, serif, p))
                            .toList(),
                      ),
                    for (final section in customSections) ...[
                      pw.SizedBox(height: 18),
                      _customSection(section, serif, p),
                    ],
                    if (experiences.isNotEmpty)
                      ...headedSection(
                        heading: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.SizedBox(height: 18),
                            _label('Appointments', serif, p),
                          ],
                        ),
                        entries: experiences
                            .map((e) => _experience(e, serif, p))
                            .toList(),
                      ),
                    if (projects.isNotEmpty)
                      ...headedSection(
                        heading: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.SizedBox(height: 14),
                            _label('Selected Work', serif, p),
                          ],
                        ),
                        entries: projects
                            .map((pr) => _project(pr, serif, p))
                            .toList(),
                      ),
                  ],
                ),
              ),
            if (skills.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _label('Competencies', serif, p),
              // Skills rule item 4: names that do not fit the three lines are
              // counted rather than silently swallowed by the clamp.
              skillRun(
                skills,
                maxLines: 3,
                maxNames: _maxSkills,
                style: pw.TextStyle(
                  font: serif.regular,
                  fontSize: 9.2,
                  color: p.ink,
                  lineSpacing: 3.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Centred name over the contact line, closed by a thick/thin double rule.
  pw.Widget _masthead(TemplateContext ctx, LoadedFamily serif) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;

    final contact = <(String, bool)>[
      (info.email, false),
      (info.phone, false),
      (info.location, false),
      (info.linkedin, true),
      (info.website, true),
    ];

    final contactStyle = pw.TextStyle(
      font: serif.regular,
      fontSize: 8.2,
      color: p.muted,
      lineSpacing: 2,
    );

    return pw.SizedBox(
      width: _contentW,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          clampedText(
            info.fullName.isEmpty ? 'Your Name' : info.fullName,
            align: pw.TextAlign.center,
            style: pw.TextStyle(
              font: serif.bold,
              fontSize: 25,
              color: p.secondary,
              letterSpacing: 0.6,
            ),
          ),
          if (info.title.trim().isNotEmpty) ...[
            pw.SizedBox(height: 5),
            clampedText(
              info.title,
              align: pw.TextAlign.center,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 11,
                color: p.primary,
                letterSpacing: 1.4,
              ),
            ),
          ],
          pw.SizedBox(height: 8),
          contactStrip(
            contact,
            // One line only: this page is full at the sample content, and a
            // second contact line costs it the whole competencies section.
            maxLines: 1,
            separator: '  ·  ',
            style: contactStyle,
            alignment: pw.WrapAlignment.center,
          ),
          pw.SizedBox(height: 12),
          pw.Container(width: _contentW, height: 1.6, color: p.primary),
          pw.SizedBox(height: 2.6),
          pw.Container(width: _contentW, height: 0.5, color: p.primary),
        ],
      ),
    );
  }

  /// Faux small caps: full-size initial, then tracked capitals two points down.
  pw.Widget _label(String text, LoadedFamily serif, TemplatePalette p) {
    final trimmed = text.trim();
    final head = trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();
    final tail = trimmed.length > 1 ? trimmed.substring(1).toUpperCase() : '';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: head,
                  style: pw.TextStyle(
                    font: serif.bold,
                    fontSize: 10.5,
                    color: p.primary,
                    letterSpacing: 1.4,
                  ),
                ),
                pw.TextSpan(
                  text: tail,
                  style: pw.TextStyle(
                    font: serif.bold,
                    fontSize: 8.6,
                    color: p.primary,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 3.5),
          // Not _contentW: the same label is reused inside the narrower
          // publications panel, so the rule takes whatever width it is given.
          pw.Container(width: double.infinity, height: 0.5, color: _rule),
        ],
      ),
    );
  }

  pw.Widget _education(Education e, LoadedFamily serif, TemplatePalette p) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final range = formatRange(e.startDate, e.endDate);
    final trailing = [
      if (e.gpa.trim().isNotEmpty) 'GPA ${e.gpa.trim()}',
      if (range.isNotEmpty) range,
    ].join('  ·  ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                clampedText(
                  degree,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: serif.bold,
                    fontSize: 9.6,
                    color: p.ink,
                    lineSpacing: 2,
                  ),
                ),
                clampedText(
                  e.institution,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: serif.regular,
                    fontSize: 9,
                    color: p.muted,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            pw.SizedBox(width: 12),
            clampedText(
              trailing,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 8.2,
                color: p.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Publications, certifications, fellowships — the academic payload.
  ///
  /// Set on the cream accent so the block reads as the page's second focus
  /// after the masthead, with numbered entries in the citation-list manner.
  pw.Widget _customSection(
    CustomSection section,
    LoadedFamily serif,
    TemplatePalette p,
  ) {
    final items = section.items.take(_maxCustomItems).toList();
    if (items.isEmpty) return pw.SizedBox();

    return pw.Container(
      width: _contentW,
      padding: const pw.EdgeInsets.fromLTRB(14, 11, 14, 6),
      decoration: pw.BoxDecoration(
        color: p.accent,
        border: const pw.Border(
          left: pw.BorderSide(color: PdfColor.fromInt(0xFF7F1D1D), width: 2),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _label(
            section.sectionTitle.isEmpty
                ? 'Publications'
                : section.sectionTitle,
            serif,
            p,
          ),
          for (var i = 0; i < items.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 16,
                    child: clampedText(
                      '[${i + 1}]',
                      style: pw.TextStyle(
                        font: serif.bold,
                        fontSize: 8.4,
                        color: p.primary,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        clampedText(
                          items[i].title,
                          maxLines: 3,
                          style: pw.TextStyle(
                            font: serif.bold,
                            fontSize: 9,
                            color: p.ink,
                            lineSpacing: 2.2,
                          ),
                        ),
                        if (items[i].subtitle.trim().isNotEmpty)
                          clampedText(
                            items[i].subtitle,
                            maxLines: 2,
                            style: pw.TextStyle(
                              font: serif.regular,
                              fontSize: 8.4,
                              color: p.muted,
                              lineSpacing: 2,
                            ),
                          ),
                        if (items[i].description.trim().isNotEmpty)
                          clampedText(
                            items[i].description,
                            maxLines: 2,
                            style: pw.TextStyle(
                              font: serif.regular,
                              fontSize: 8.4,
                              color: p.muted,
                              lineSpacing: 2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily serif, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 13),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: clampedText(
                  e.position,
                  style: pw.TextStyle(
                    font: serif.bold,
                    fontSize: 10,
                    color: p.ink,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 12),
                clampedText(
                  range,
                  style: pw.TextStyle(
                    font: serif.regular,
                    fontSize: 8.2,
                    color: p.muted,
                  ),
                ),
              ],
            ],
          ),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: serif.regular,
              fontSize: 9.2,
              color: p.primary,
            ),
          ),
          if (e.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              e.description,
              maxLines: 3,
              align: pw.TextAlign.justify,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 3.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _project(Project pr, LoadedFamily serif, TemplatePalette p) {
    // The link is no longer folded into this run: joined behind the technology
    // list it was the part that ran off the end of the single line and was cut
    // mid-token (URL rule, item 6). It gets its own line below.
    final meta = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(6)
        .join(', ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // The link rides on the title line rather than taking one of its
          // own: this design's page is already full at the sample content, and
          // a fourteenth line here costs it the whole skills section.
          titleWithUrl(
            title: pr.name,
            titleStyle: pw.TextStyle(
              font: serif.bold,
              fontSize: 9.4,
              color: p.ink,
            ),
            url: pr.link,
            urlStyle: pw.TextStyle(
              font: serif.regular,
              fontSize: 8,
              color: p.primary,
            ),
            crossAxisAlignment: pw.CrossAxisAlignment.center,
          ),
          if (pr.description.trim().isNotEmpty)
            clampedText(
              pr.description,
              maxLines: 2,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 3.2,
              ),
            ),
          if (meta.isNotEmpty)
            clampedText(
              meta,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 8,
                color: p.primary,
              ),
            ),
        ],
      ),
    );
  }
}
