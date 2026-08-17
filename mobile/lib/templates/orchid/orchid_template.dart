import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Magazine-page typography for people who are hired for their words.
///
/// An oversized serif masthead, hairline rules instead of blocks of colour, and
/// wide margins. The body is a single reading column with a narrow right rail
/// carrying contact details and expertise — the same relationship a feature
/// spread has with its sidebar.
///
/// Deliberately photo-free: an editorial CV is a byline, not a headshot.
class OrchidTemplate extends ResumeTemplate {
  const OrchidTemplate();

  @override
  String get id => 'orchid';

  @override
  String get name => 'Orchid Editorial';

  @override
  String get description =>
      'Magazine-style layout: an oversized serif masthead, hairline rules, and '
      'a single reading column beside a narrow contact and expertise rail.';

  @override
  String get bestFor => 'Writing, Editorial, Communications';

  @override
  TemplateCategory get category => TemplateCategory.creative;

  /// Serif carries the masthead and the reading column; sans is used only for
  /// the letterspaced labels, where Lora's low-contrast caps read as mushy.
  @override
  Set<FontFamily> get requiredFonts => {FontFamily.serif, FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFFA21CAF),
    secondary: PdfColor.fromInt(0xFF4A044E),
    accent: PdfColor.fromInt(0xFFFDF4FF),
    ink: PdfColor.fromInt(0xFF211023),
    muted: PdfColor.fromInt(0xFF6B5A6E),
  );

  static const _sideMargin = 50.0;
  static const _topMargin = 50.0;
  static const _bottomMargin = 44.0;
  static const _rule = PdfColor.fromInt(0xFFDCCBE0);

  @override
  pw.Widget build(TemplateContext ctx) {
    final serif = ctx.family(FontFamily.serif);
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        padding: const pw.EdgeInsets.fromLTRB(
          _sideMargin,
          _topMargin,
          _sideMargin,
          _bottomMargin,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _masthead(ctx, serif, sans),
            pw.SizedBox(height: 20),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 68, child: _column(ctx, serif, sans)),
                  pw.SizedBox(width: 20),
                  // Full-height hairline: the Row sits inside an Expanded, so
                  // its height constraint is bounded and infinity resolves to it.
                  pw.Container(
                    width: 0.7,
                    height: double.infinity,
                    color: _rule,
                  ),
                  pw.SizedBox(width: 18),
                  pw.Expanded(flex: 32, child: _rail(ctx, serif, sans)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _masthead(
    TemplateContext ctx,
    LoadedFamily serif,
    LoadedFamily sans,
  ) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (info.title.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 9),
            child: clampedText(
              info.title.toUpperCase(),
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 8.4,
                color: p.primary,
                letterSpacing: 2.6,
              ),
            ),
          ),
        clampedText(
          info.fullName.isEmpty ? 'Your Name' : info.fullName,
          maxLines: 2,
          style: pw.TextStyle(
            font: serif.bold,
            fontSize: 38,
            color: p.secondary,
            lineSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(width: double.infinity, height: 0.9, color: p.secondary),
        if (info.summary.trim().isNotEmpty) ...[
          pw.SizedBox(height: 14),
          // Standfirst: set wider and looser than the body, as a feature intro.
          clampedText(
            info.summary,
            maxLines: 4,
            style: pw.TextStyle(
              font: serif.regular,
              fontSize: 10.4,
              color: p.ink,
              lineSpacing: 3.4,
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _column(
    TemplateContext ctx,
    LoadedFamily serif,
    LoadedFamily sans,
  ) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.experiences.isNotEmpty) ...[
          _sectionLabel('Experience', sans, p),
          ...data.experiences
              .take(5)
              .map((e) => _experience(e, serif, sans, p)),
          pw.SizedBox(height: 10),
        ],
        if (data.projects.isNotEmpty) ...[
          _sectionLabel('Selected work', sans, p),
          ...data.projects.take(4).map((pr) => _project(pr, serif, sans, p)),
          pw.SizedBox(height: 10),
        ],
        if (data.education.isNotEmpty) ...[
          _sectionLabel('Education', sans, p),
          ...data.education.take(3).map((e) => _education(e, serif, p)),
        ],
      ],
    );
  }

  pw.Widget _rail(TemplateContext ctx, LoadedFamily serif, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;
    final info = data.personalInfo;

    final contact = <String>[
      info.email,
      info.phone,
      info.location,
    ].where((e) => e.trim().isNotEmpty).toList();
    final links = <String>[
      info.linkedin,
      info.website,
    ].where((e) => e.trim().isNotEmpty).toList();

    final contactStyle = pw.TextStyle(
      font: serif.regular,
      fontSize: 9,
      color: p.ink,
      lineSpacing: 2,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (contact.isNotEmpty || links.isNotEmpty) ...[
          _sectionLabel('Contact', sans, p),
          ...contact.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: clampedText(line, maxLines: 2, style: contactStyle),
            ),
          ),
          // The rail is ~146pt: a real profile URL needs three lines there,
          // broken at path separators rather than mid-handle (URL rule).
          ...links.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: urlText(line, maxLines: 3, style: contactStyle),
            ),
          ),
          pw.SizedBox(height: 20),
        ],
        if (data.skills.isNotEmpty) ...[
          _sectionLabel('Expertise', sans, p),
          ...data.skills.take(12).map((s) => _skill(s, serif, p)),
          pw.SizedBox(height: 20),
        ],
        ...data.customSections.take(3).map((section) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionLabel(
                section.sectionTitle.isEmpty ? 'Notes' : section.sectionTitle,
                sans,
                p,
              ),
              ...section.items
                  .take(5)
                  .map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          clampedText(
                            item.title,
                            maxLines: 3,
                            style: pw.TextStyle(
                              font: serif.regular,
                              fontSize: 9,
                              color: p.ink,
                              lineSpacing: 2,
                            ),
                          ),
                          if (item.subtitle.trim().isNotEmpty)
                            clampedText(
                              item.subtitle,
                              style: pw.TextStyle(
                                font: sans.regular,
                                fontSize: 7.4,
                                color: p.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              pw.SizedBox(height: 6),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _sectionLabel(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            label.toUpperCase(),
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 8,
              color: p.primary,
              letterSpacing: 2.2,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Container(width: double.infinity, height: 0.6, color: _rule),
        ],
      ),
    );
  }

  pw.Widget _skill(Skill s, LoadedFamily serif, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 3, height: 3, color: p.primary),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: clampedText(
              s.name,
              maxLines: 2,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 9.2,
                color: p.ink,
                lineSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _experience(
    Experience e,
    LoadedFamily serif,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (range.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: clampedText(
                range,
                style: pw.TextStyle(
                  font: sans.regular,
                  fontSize: 7.4,
                  color: p.muted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          clampedText(
            e.position,
            maxLines: 2,
            style: pw.TextStyle(
              font: serif.bold,
              fontSize: 13.5,
              color: p.ink,
              lineSpacing: 1.6,
            ),
          ),
          pw.SizedBox(height: 2),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 8.8,
              color: p.primary,
              letterSpacing: 0.6,
            ),
          ),
          if (e.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            clampedText(
              e.description,
              maxLines: 4,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 9.4,
                color: p.muted,
                lineSpacing: 2.9,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _project(
    Project pr,
    LoadedFamily serif,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // The link was never drawn here at all, so a project URL the user
          // typed silently never reached the PDF (QA-1). Set in the sans face
          // the design already reserves for metadata.
          titleWithUrl(
            title: pr.name,
            titleStyle: pw.TextStyle(
              font: serif.bold,
              fontSize: 10.8,
              color: p.ink,
            ),
            url: pr.link,
            urlStyle: pw.TextStyle(
              font: sans.regular,
              fontSize: 8,
              color: p.primary,
            ),
            crossAxisAlignment: pw.CrossAxisAlignment.center,
          ),
          if (pr.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              pr.description,
              maxLines: 3,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 2.7,
              ),
            ),
          ],
          if (pr.technologies.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              pr.technologies.toUpperCase(),
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 7,
                color: p.primary,
                letterSpacing: 1.2,
              ),
            ),
          ],
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
                    fontSize: 10.2,
                    color: p.ink,
                    lineSpacing: 1.6,
                  ),
                ),
                clampedText(
                  e.institution,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: serif.regular,
                    fontSize: 9.4,
                    color: p.muted,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          if (range.isNotEmpty) ...[
            pw.SizedBox(width: 10),
            pw.Text(
              range,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                font: serif.regular,
                fontSize: 8,
                color: p.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
