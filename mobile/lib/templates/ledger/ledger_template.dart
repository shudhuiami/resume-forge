import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Audit-ledger typography: a serif reading face for prose, a monospace face
/// for every date, label and figure, and hairline rules that turn the page into
/// a table.
///
/// The mono/serif split is functional rather than decorative — monospace digits
/// keep the date column optically aligned down the page, which is exactly the
/// scan pattern this audience uses. No portrait: the design is deliberately
/// impersonal.
class LedgerTemplate extends ResumeTemplate {
  const LedgerTemplate();

  @override
  String get id => 'ledger';

  @override
  String get name => 'Ledger Mono';

  @override
  String get description =>
      'Ruled, table-like rows with monospace dates against a serif body — '
      'restrained and document-like.';

  @override
  String get bestFor => 'Accounting, Audit, Compliance';

  @override
  TemplateCategory get category => TemplateCategory.corporate;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.mono, FontFamily.serif};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF1F2937),
    secondary: PdfColor.fromInt(0xFF6B7280),
    accent: PdfColor.fromInt(0xFFF9FAFB),
    ink: PdfColor.fromInt(0xFF111827),
    muted: PdfColor.fromInt(0xFF4B5563),
  );

  static const _pagePadding = 44.0;
  static const _gutter = 92.0;
  static const _gutterGap = 14.0;
  static const _rule = PdfColor.fromInt(0xFFE5E7EB);

  static const _maxExperiences = 5;
  static const _maxProjects = 3;
  static const _maxEducation = 3;
  static const _maxSkills = 8;

  @override
  pw.Widget build(TemplateContext ctx) {
    final mono = ctx.family(FontFamily.mono);
    final serif = ctx.family(FontFamily.serif);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        child: pw.ClipRect(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(
              _pagePadding,
              36,
              _pagePadding,
              28,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _masthead(ctx, mono, serif),
                ..._sections(ctx, mono, serif),
              ],
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _masthead(
    TemplateContext ctx,
    LoadedFamily mono,
    LoadedFamily serif,
  ) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;

    final contact = <String>[
      info.email,
      info.phone,
      info.location,
      info.linkedin,
      info.website,
    ].where((e) => e.trim().isNotEmpty).join('   |   ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        clampedText(
          info.fullName.isEmpty ? 'Your Name' : info.fullName,
          style: pw.TextStyle(font: serif.bold, fontSize: 24, color: p.ink),
        ),
        if (info.title.trim().isNotEmpty) ...[
          pw.SizedBox(height: 6),
          clampedText(
            info.title.toUpperCase(),
            style: pw.TextStyle(
              font: mono.regular,
              fontSize: 8.4,
              color: p.secondary,
              letterSpacing: 1.8,
            ),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Container(width: double.infinity, height: 1.4, color: p.primary),
        pw.SizedBox(height: 2),
        pw.Container(width: double.infinity, height: 0.5, color: p.primary),
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          clampedText(
            contact,
            maxLines: 2,
            style: pw.TextStyle(
              font: mono.regular,
              fontSize: 7.4,
              color: p.secondary,
              lineSpacing: 1.5,
            ),
          ),
        ],
        pw.SizedBox(height: 12),
      ],
    );
  }

  List<pw.Widget> _sections(
    TemplateContext ctx,
    LoadedFamily mono,
    LoadedFamily serif,
  ) {
    final data = ctx.data;
    final p = ctx.palette;
    final out = <pw.Widget>[];

    if (data.personalInfo.summary.trim().isNotEmpty) {
      out.add(_sectionBar('Summary', mono, p));
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(0, 7, 0, 10),
          child: clampedText(
            data.personalInfo.summary,
            maxLines: 5,
            style: pw.TextStyle(
              font: serif.regular,
              fontSize: 9,
              color: p.muted,
              lineSpacing: 1.55,
            ),
          ),
        ),
      );
    }

    if (data.experiences.isNotEmpty) {
      out.add(_sectionBar('Experience', mono, p));
      out.addAll(
        data.experiences
            .take(_maxExperiences)
            .map((e) => _experienceRow(e, mono, serif, p)),
      );
      out.add(pw.SizedBox(height: 9));
    }

    if (data.education.isNotEmpty) {
      out.add(_sectionBar('Education', mono, p));
      out.addAll(
        data.education
            .take(_maxEducation)
            .map((e) => _educationRow(e, mono, serif, p)),
      );
      out.add(pw.SizedBox(height: 9));
    }

    if (data.projects.isNotEmpty) {
      out.add(_sectionBar('Projects', mono, p));
      out.addAll(
        data.projects
            .take(_maxProjects)
            .map((pr) => _projectRow(pr, mono, serif, p)),
      );
      out.add(pw.SizedBox(height: 9));
    }

    if (data.skills.isNotEmpty) {
      out.add(_sectionBar('Skills', mono, p));
      out.addAll(
        data.skills.take(_maxSkills).map((s) => _skillRow(s, mono, serif, p)),
      );
      out.add(pw.SizedBox(height: 9));
    }

    for (final section in data.customSections.take(2)) {
      if (section.items.isEmpty) continue;
      out.add(
        _sectionBar(
          section.sectionTitle.isEmpty ? 'Additional' : section.sectionTitle,
          mono,
          p,
        ),
      );
      out.addAll(
        section.items.take(4).map((item) => _customRow(item, mono, serif, p)),
      );
      out.add(pw.SizedBox(height: 9));
    }

    return out;
  }

  pw.Widget _sectionBar(String label, LoadedFamily mono, TemplatePalette p) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(6, 4.5, 6, 4.5),
      decoration: pw.BoxDecoration(
        color: p.accent,
        border: const pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFF1F2937), width: 0.8),
          bottom: pw.BorderSide(color: _rule, width: 0.6),
        ),
      ),
      child: clampedText(
        label.toUpperCase(),
        style: pw.TextStyle(
          font: mono.bold,
          fontSize: 8.2,
          color: p.ink,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  /// One ruled ledger line: mono gutter on the left, serif content on the
  /// right, hairline underneath.
  pw.Widget _row({required pw.Widget gutter, required pw.Widget content}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: _gutter, child: gutter),
          pw.SizedBox(width: _gutterGap),
          pw.Expanded(child: content),
        ],
      ),
    );
  }

  pw.Widget _monoGutter(String text, LoadedFamily mono, TemplatePalette p) {
    if (text.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1.5),
      child: clampedText(
        text,
        maxLines: 2,
        style: pw.TextStyle(
          font: mono.regular,
          fontSize: 7.4,
          color: p.secondary,
          lineSpacing: 1.4,
        ),
      ),
    );
  }

  pw.Widget _experienceRow(
    Experience e,
    LoadedFamily mono,
    LoadedFamily serif,
    TemplatePalette p,
  ) {
    return _row(
      gutter: _monoGutter(
        formatRange(e.startDate, e.endDate, current: e.current),
        mono,
        p,
      ),
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            e.position,
            style: pw.TextStyle(font: serif.bold, fontSize: 10.4, color: p.ink),
          ),
          if (e.company.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              e.company,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 8,
                color: p.primary,
                letterSpacing: 0.3,
              ),
            ),
          ],
          if (e.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            clampedText(
              e.description,
              maxLines: 4,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 8.6,
                color: p.muted,
                lineSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _educationRow(
    Education e,
    LoadedFamily mono,
    LoadedFamily serif,
    TemplatePalette p,
  ) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');

    return _row(
      gutter: _monoGutter(formatRange(e.startDate, e.endDate), mono, p),
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (degree.isNotEmpty)
            clampedText(
              degree,
              maxLines: 2,
              style: pw.TextStyle(
                font: serif.bold,
                fontSize: 9.8,
                color: p.ink,
                lineSpacing: 1.3,
              ),
            ),
          pw.SizedBox(height: 1.5),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: serif.regular,
              fontSize: 8.8,
              color: p.muted,
              lineSpacing: 1.35,
            ),
          ),
          if (e.gpa.trim().isNotEmpty)
            clampedText(
              'GPA ${e.gpa.trim()}',
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 7.4,
                color: p.secondary,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _projectRow(
    Project pr,
    LoadedFamily mono,
    LoadedFamily serif,
    TemplatePalette p,
  ) {
    final tech = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join(' / ');

    // The gutter is the date column; a URL is too wide for it and would break
    // mid-token, so the link rides on the title line instead.
    return _row(
      gutter: pw.SizedBox(),
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: clampedText(
                  pr.name,
                  style: pw.TextStyle(
                    font: serif.bold,
                    fontSize: 9.8,
                    color: p.ink,
                  ),
                ),
              ),
              if (pr.link.trim().isNotEmpty) ...[
                pw.SizedBox(width: 10),
                clampedText(
                  pr.link.trim(),
                  style: pw.TextStyle(
                    font: mono.regular,
                    fontSize: 7.2,
                    color: p.secondary,
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
                font: serif.regular,
                fontSize: 8.6,
                color: p.muted,
                lineSpacing: 1.5,
              ),
            ),
          ],
          if (tech.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              tech.toUpperCase(),
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 7.2,
                color: p.secondary,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _skillRow(
    Skill s,
    LoadedFamily mono,
    LoadedFamily serif,
    TemplatePalette p,
  ) {
    final filled = s.level.clamp(0, 5);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: _gutter,
            // Level marks are drawn boxes rather than glyphs: nothing here
            // depends on the mono face shipping a bullet or block character.
            child: pw.Row(
              children: List<pw.Widget>.generate(
                5,
                (i) => pw.Container(
                  width: 9,
                  height: 3,
                  margin: const pw.EdgeInsets.only(right: 3),
                  color: i < filled
                      ? p.primary
                      : const PdfColor.fromInt(0xFFE5E7EB),
                ),
              ),
            ),
          ),
          pw.SizedBox(width: _gutterGap),
          pw.Expanded(
            child: clampedText(
              s.name,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 9,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _customRow(
    CustomItem item,
    LoadedFamily mono,
    LoadedFamily serif,
    TemplatePalette p,
  ) {
    return _row(
      gutter: _monoGutter(item.subtitle.trim(), mono, p),
      content: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            item.title,
            maxLines: 2,
            style: pw.TextStyle(
              font: serif.bold,
              fontSize: 9.4,
              color: p.ink,
              lineSpacing: 1.35,
            ),
          ),
          if (item.description.trim().isNotEmpty)
            clampedText(
              item.description,
              maxLines: 2,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 8.6,
                color: p.muted,
                lineSpacing: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}
