import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Conservative two-column corporate layout: a full-height slate sidebar
/// carrying the "scannable" facts (contact, skills, education) against a white
/// main column that holds the narrative.
///
/// The sidebar is a fixed-width [pw.SizedBox] painted to the full page height
/// rather than a stretched Row child: `dart_pdf` resolves cross-axis stretch
/// against the tallest child, so a short sidebar would leave the slate band
/// ending mid-page.
class MeridianTemplate extends ResumeTemplate {
  const MeridianTemplate();

  @override
  String get id => 'meridian';

  @override
  String get name => 'Meridian Slate';

  @override
  String get description =>
      'Deep slate sidebar for contact, skills and education beside a clean '
      'white column of experience.';

  @override
  String get bestFor => 'Finance, Consulting, Operations';

  @override
  TemplateCategory get category => TemplateCategory.corporate;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF334155),
    secondary: PdfColor.fromInt(0xFF0F172A),
    accent: PdfColor.fromInt(0xFFF1F5F9),
    ink: PdfColor.fromInt(0xFF1E293B),
    muted: PdfColor.fromInt(0xFF64748B),
  );

  static const _sidebarWidth = 188.0;
  static const _sidebarPadding = 20.0;
  static const _mainPadding = 30.0;

  // Sidebar-only inks. They live against slate, so they are deliberately not
  // the palette's paper/muted values, which assume a white ground.
  static const _onSlate = PdfColor.fromInt(0xFFE2E8F0);
  static const _onSlateDim = PdfColor.fromInt(0xFF94A3B8);
  static const _slateRule = PdfColor.fromInt(0xFF475569);

  // Bounds on repeated content. Resume input is unbounded; without caps a
  // twenty-role history would run off the sheet instead of ending politely.
  static const _maxExperiences = 5;
  static const _maxProjects = 3;
  static const _maxSkills = 8;
  static const _maxEducation = 3;

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: _sidebarWidth,
              height: a4.height,
              child: pw.Container(
                color: p.primary,
                child: pw.ClipRect(child: _sidebar(ctx, sans)),
              ),
            ),
            pw.Expanded(
              child: pw.SizedBox(
                height: a4.height,
                child: pw.ClipRect(child: _main(ctx, sans)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _sidebar(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final info = data.personalInfo;
    final photo = tryDecodePhoto(info.photo);
    final photoSize = _sidebarWidth - _sidebarPadding * 2;

    final contact = <(String, String, ContactKind)>[
      ('Email', info.email, ContactKind.email),
      ('Phone', info.phone, ContactKind.phone),
      ('Location', info.location, ContactKind.plain),
      ('LinkedIn', info.linkedin, ContactKind.url),
      ('Web', info.website, ContactKind.url),
    ].where((e) => e.$2.trim().isNotEmpty).toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(
        _sidebarPadding,
        28,
        _sidebarPadding,
        24,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (photo != null) ...[
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(
                photo,
                fit: pw.BoxFit.cover,
                width: photoSize,
                height: photoSize,
              ),
            ),
            pw.SizedBox(height: 22),
          ],
          if (contact.isNotEmpty) ...[
            _sidebarHeading('Contact', sans, ctx.palette),
            ...contact.map((c) => _contactLine(c.$1, c.$2, sans, kind: c.$3)),
            pw.SizedBox(height: 16),
          ],
          if (data.skills.isNotEmpty) ...[
            _sidebarHeading('Skills', sans, ctx.palette),
            ...data.skills
                .take(_maxSkills)
                .map((s) => _skillBar(s, sans, ctx.palette)),
            pw.SizedBox(height: 16),
          ],
          if (data.education.isNotEmpty) ...[
            _sidebarHeading('Education', sans, ctx.palette),
            ...data.education
                .take(_maxEducation)
                .map((e) => _education(e, sans)),
          ],
        ],
      ),
    );
  }

  pw.Widget _sidebarHeading(
    String label,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        clampedText(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: sans.bold,
            fontSize: 9,
            color: p.accent,
            letterSpacing: 1.6,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(width: 26, height: 1.6, color: p.accent),
        pw.SizedBox(height: 9),
      ],
    );
  }

  pw.Widget _contactLine(
    String label,
    String value,
    LoadedFamily sans, {
    ContactKind kind = ContactKind.plain,
  }) {
    final valueStyle = pw.TextStyle(
      font: sans.regular,
      fontSize: 8.4,
      color: _onSlate,
      lineSpacing: 1.3,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            label.toUpperCase(),
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 6.4,
              color: _onSlateDim,
              letterSpacing: 0.9,
            ),
          ),
          pw.SizedBox(height: 1),
          // The sidebar's text column is 148pt; a real profile URL needs three
          // lines there, broken at path separators rather than mid-handle.
          // The label above stays outside the link: it is the design's own
          // word, not part of the address.
          if (kind == ContactKind.url)
            urlText(value, maxLines: 3, style: valueStyle)
          else
            contactLink(
              value,
              kind,
              child: clampedText(value, maxLines: 2, style: valueStyle),
            ),
        ],
      ),
    );
  }

  pw.Widget _skillBar(Skill s, LoadedFamily sans, TemplatePalette p) {
    // No FractionallySizedBox in dart_pdf: the fill is a flex split so it stays
    // correct at any sidebar width.
    final filled = skillRating(s);
    final empty = filled == null ? 0 : 5 - filled;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // This rail is 148pt: the narrowest place a skill name is set
          // anywhere in the catalog, and the one that used to cut a long name
          // dead at 29 characters. Skills rule item 3 — the cut is marked now,
          // and the width stays the design's own.
          markedText(
            s.name,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.4,
              color: _onSlate,
            ),
          ),
          // Skills rule item 5: no rating, no bar.
          if (filled != null) ...[
            pw.SizedBox(height: 3.5),
            pw.Container(
              height: 3,
              color: _slateRule,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: filled,
                    child: pw.Container(color: p.accent),
                  ),
                  if (empty > 0) pw.Expanded(flex: empty, child: pw.SizedBox()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _education(Education e, LoadedFamily sans) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final range = formatRange(e.startDate, e.endDate);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (degree.isNotEmpty)
            clampedText(
              degree,
              maxLines: 2,
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 8.8,
                color: const PdfColor.fromInt(0xFFFFFFFF),
                lineSpacing: 1.3,
              ),
            ),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.2,
              color: _onSlate,
              lineSpacing: 1.3,
            ),
          ),
          if (range.isNotEmpty || e.gpa.trim().isNotEmpty)
            clampedText(
              [
                range,
                if (e.gpa.trim().isNotEmpty) 'GPA ${e.gpa.trim()}',
              ].where((s) => s.isNotEmpty).join('  ·  '),
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 7.6,
                color: _onSlateDim,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _main(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;
    final info = data.personalInfo;

    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(_mainPadding, 44, _mainPadding, 30),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            info.fullName.isEmpty ? 'Your Name' : info.fullName,
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 26,
              color: p.secondary,
              letterSpacing: -0.3,
            ),
          ),
          if (info.title.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              info.title.toUpperCase(),
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 10.2,
                color: p.primary,
                letterSpacing: 1.9,
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            height: 1,
            color: const PdfColor.fromInt(0xFFCBD5E1),
          ),
          if (info.summary.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            clampedText(
              info.summary,
              maxLines: 5,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.6,
                color: p.muted,
                lineSpacing: 1.75,
              ),
            ),
          ],
          pw.SizedBox(height: 22),
          if (data.experiences.isNotEmpty) ...[
            _mainHeading('Experience', sans, p),
            ...data.experiences
                .take(_maxExperiences)
                .map((e) => _experience(e, sans, p)),
            pw.SizedBox(height: 4),
          ],
          if (data.projects.isNotEmpty) ...[
            _mainHeading('Projects', sans, p),
            ...data.projects
                .take(_maxProjects)
                .map((pr) => _project(pr, sans, p)),
            pw.SizedBox(height: 4),
          ],
          ...data.customSections
              .take(2)
              .map((section) => _customSection(section, sans, p)),
        ],
      ),
    );
  }

  pw.Widget _mainHeading(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            label.toUpperCase(),
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 10.6,
              color: p.primary,
              letterSpacing: 1.9,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            width: double.infinity,
            height: 1,
            color: const PdfColor.fromInt(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 17),
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
                    font: sans.bold,
                    fontSize: 11.4,
                    color: p.secondary,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 10),
                clampedText(
                  range,
                  style: pw.TextStyle(
                    font: sans.semiBold,
                    fontSize: 8.4,
                    color: p.muted,
                  ),
                ),
              ],
            ],
          ),
          if (e.company.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              e.company,
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 9.8,
                color: p.primary,
              ),
            ),
          ],
          if (e.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            clampedText(
              e.description,
              maxLines: 4,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _project(Project pr, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 13),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          titleWithUrl(
            title: pr.name,
            titleStyle: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 10.4,
              color: p.secondary,
            ),
            url: pr.link,
            urlStyle: pw.TextStyle(
              font: sans.regular,
              fontSize: 7.8,
              color: p.muted,
            ),
          ),
          if (pr.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              pr.description,
              maxLines: 3,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 1.55,
              ),
            ),
          ],
          if (pr.technologies.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              pr.technologies
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .join('  ·  '),
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 8.2,
                color: p.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _customSection(
    CustomSection section,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    if (section.items.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _mainHeading(
          section.sectionTitle.isEmpty ? 'Additional' : section.sectionTitle,
          sans,
          p,
        ),
        ...section.items
            .take(4)
            .map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    clampedText(
                      item.title,
                      maxLines: 2,
                      style: pw.TextStyle(
                        font: sans.semiBold,
                        fontSize: 9.6,
                        color: p.secondary,
                        lineSpacing: 1.35,
                      ),
                    ),
                    if (item.subtitle.trim().isNotEmpty)
                      clampedText(
                        item.subtitle,
                        style: pw.TextStyle(
                          font: sans.regular,
                          fontSize: 8.7,
                          color: p.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
