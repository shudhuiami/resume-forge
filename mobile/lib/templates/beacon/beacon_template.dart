import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Institutional single-column layout: a navy masthead over a gold rule, with
/// every entry hung off a fixed left gutter that carries its dates.
///
/// The gutter is a fixed-width [pw.SizedBox] inside a Row rather than a
/// right-aligned date on the same line as the title: a constant date column is
/// what makes a dense single-column résumé scannable, and it keeps long job
/// titles from squeezing the date to an ellipsis.
class BeaconTemplate extends ResumeTemplate {
  const BeaconTemplate();

  @override
  String get id => 'beacon';

  @override
  String get name => 'Beacon Navy';

  @override
  String get description =>
      'Navy masthead with a gold rule above a single-column body, dates set in '
      'a fixed left gutter.';

  @override
  String get bestFor => 'Management, Legal, Policy';

  @override
  TemplateCategory get category => TemplateCategory.corporate;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF1E3A8A),
    secondary: PdfColor.fromInt(0xFFB45309),
    accent: PdfColor.fromInt(0xFFEFF6FF),
    ink: PdfColor.fromInt(0xFF1F2937),
    muted: PdfColor.fromInt(0xFF5B6478),
  );

  static const _pagePadding = 36.0;
  static const _bandHeight = 118.0;
  static const _ruleHeight = 3.0;
  static const _gutter = 88.0;
  static const _gutterGap = 14.0;
  static const _photoSize = 66.0;

  static const _onNavy = PdfColor.fromInt(0xFFDBEAFE);

  static const _maxExperiences = 5;
  static const _maxProjects = 3;
  static const _maxEducation = 3;
  static const _maxSkills = 10;

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _band(ctx, sans),
            pw.Container(
              width: a4.width,
              height: _ruleHeight,
              color: p.secondary,
            ),
            pw.Expanded(
              child: pw.ClipRect(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(
                    _pagePadding,
                    20,
                    _pagePadding,
                    24,
                  ),
                  child: _body(ctx, sans),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _band(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;
    final photo = tryDecodePhoto(info.photo);

    final contact = <String>[
      info.email,
      info.phone,
      info.location,
      info.linkedin,
      info.website,
    ].where((e) => e.trim().isNotEmpty).join('   ·   ');

    return pw.Container(
      width: a4.width,
      height: _bandHeight,
      color: p.primary,
      padding: const pw.EdgeInsets.symmetric(horizontal: _pagePadding),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                clampedText(
                  info.fullName.isEmpty ? 'Your Name' : info.fullName,
                  style: pw.TextStyle(
                    font: sans.bold,
                    fontSize: 25,
                    color: p.onPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                if (info.title.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  clampedText(
                    info.title.toUpperCase(),
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 9.6,
                      color: _onNavy,
                      letterSpacing: 2.2,
                    ),
                  ),
                ],
                if (contact.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  clampedText(
                    contact,
                    maxLines: 2,
                    style: pw.TextStyle(
                      font: sans.regular,
                      fontSize: 8.2,
                      color: _onNavy,
                      lineSpacing: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (photo != null) ...[
            pw.SizedBox(width: 18),
            pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(
                photo,
                fit: pw.BoxFit.cover,
                width: _photoSize,
                height: _photoSize,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _body(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.personalInfo.summary.trim().isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: pw.BoxDecoration(
              color: p.accent,
              border: pw.Border(
                left: pw.BorderSide(color: p.secondary, width: 2.5),
              ),
            ),
            child: clampedText(
              data.personalInfo.summary,
              maxLines: 5,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.4,
                color: p.ink,
                lineSpacing: 1.65,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
        ],
        if (data.experiences.isNotEmpty) ...[
          _heading('Experience', sans, p),
          ...data.experiences
              .take(_maxExperiences)
              .map((e) => _experience(e, sans, p)),
          pw.SizedBox(height: 6),
        ],
        if (data.projects.isNotEmpty) ...[
          _heading('Selected Projects', sans, p),
          ...data.projects
              .take(_maxProjects)
              .map((pr) => _project(pr, sans, p)),
          pw.SizedBox(height: 6),
        ],
        if (data.education.isNotEmpty) ...[
          _heading('Education', sans, p),
          ...data.education
              .take(_maxEducation)
              .map((e) => _education(e, sans, p)),
          pw.SizedBox(height: 6),
        ],
        if (data.skills.isNotEmpty) ...[
          _heading('Core Skills', sans, p),
          _gutterRow(
            '',
            pw.Wrap(
              spacing: 14,
              runSpacing: 6,
              children: data.skills
                  .take(_maxSkills)
                  .map((s) => _skillItem(s, sans, p))
                  .toList(),
            ),
            sans,
            p,
          ),
          pw.SizedBox(height: 10),
        ],
        ...data.customSections
            .take(2)
            .map((section) => _customSection(section, sans, p)),
      ],
    );
  }

  pw.Widget _heading(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          clampedText(
            label.toUpperCase(),
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 10.4,
              color: p.secondary,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Container(
              height: 0.8,
              color: const PdfColor.fromInt(0xFFD6DCE8),
            ),
          ),
        ],
      ),
    );
  }

  /// One body row: fixed date gutter on the left, content on the right.
  pw.Widget _gutterRow(
    String gutterText,
    pw.Widget content,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: _gutter,
          child: gutterText.isEmpty
              ? pw.SizedBox()
              : clampedText(
                  gutterText,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: sans.semiBold,
                    fontSize: 8,
                    color: p.muted,
                    lineSpacing: 1.35,
                  ),
                ),
        ),
        pw.SizedBox(width: _gutterGap),
        pw.Expanded(child: content),
      ],
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 15),
      child: _gutterRow(
        formatRange(e.startDate, e.endDate, current: e.current),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            clampedText(
              e.position,
              style: pw.TextStyle(
                font: sans.bold,
                fontSize: 11.2,
                color: p.primary,
              ),
            ),
            if (e.company.trim().isNotEmpty) ...[
              pw.SizedBox(height: 1.5),
              clampedText(
                e.company,
                style: pw.TextStyle(
                  font: sans.semiBold,
                  fontSize: 9.6,
                  color: p.ink,
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
        sans,
        p,
      ),
    );
  }

  pw.Widget _project(Project pr, LoadedFamily sans, TemplatePalette p) {
    final tech = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join('  ·  ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: _gutterRow(
        '',
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: clampedText(
                    pr.name,
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 10.2,
                      color: p.primary,
                    ),
                  ),
                ),
                if (pr.link.trim().isNotEmpty) ...[
                  pw.SizedBox(width: 10),
                  clampedText(
                    pr.link,
                    style: pw.TextStyle(
                      font: sans.regular,
                      fontSize: 7.9,
                      color: p.muted,
                    ),
                  ),
                ],
              ],
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
            if (tech.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              clampedText(
                tech,
                style: pw.TextStyle(
                  font: sans.semiBold,
                  fontSize: 8.2,
                  color: p.secondary,
                ),
              ),
            ],
          ],
        ),
        sans,
        p,
      ),
    );
  }

  pw.Widget _education(Education e, LoadedFamily sans, TemplatePalette p) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: _gutterRow(
        formatRange(e.startDate, e.endDate),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (degree.isNotEmpty)
              clampedText(
                degree,
                maxLines: 2,
                style: pw.TextStyle(
                  font: sans.semiBold,
                  fontSize: 10.2,
                  color: p.primary,
                  lineSpacing: 1.3,
                ),
              ),
            clampedText(
              [
                e.institution,
                if (e.gpa.trim().isNotEmpty) 'GPA ${e.gpa.trim()}',
              ].where((s) => s.trim().isNotEmpty).join('  ·  '),
              maxLines: 2,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 1.35,
              ),
            ),
          ],
        ),
        sans,
        p,
      ),
    );
  }

  pw.Widget _skillItem(Skill s, LoadedFamily sans, TemplatePalette p) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 3.5, height: 3.5, color: p.secondary),
        pw.SizedBox(width: 5),
        pw.Text(
          s.name,
          maxLines: 1,
          style: pw.TextStyle(font: sans.regular, fontSize: 9.2, color: p.ink),
        ),
      ],
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
        _heading(
          section.sectionTitle.isEmpty ? 'Additional' : section.sectionTitle,
          sans,
          p,
        ),
        ...section.items
            .take(4)
            .map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: _gutterRow(
                  item.subtitle.trim(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      clampedText(
                        item.title,
                        maxLines: 2,
                        style: pw.TextStyle(
                          font: sans.semiBold,
                          fontSize: 9.8,
                          color: p.primary,
                          lineSpacing: 1.35,
                        ),
                      ),
                      if (item.description.trim().isNotEmpty)
                        clampedText(
                          item.description,
                          maxLines: 2,
                          style: pw.TextStyle(
                            font: sans.regular,
                            fontSize: 8.6,
                            color: p.muted,
                            lineSpacing: 1.45,
                          ),
                        ),
                    ],
                  ),
                  sans,
                  p,
                ),
              ),
            ),
      ],
    );
  }
}
