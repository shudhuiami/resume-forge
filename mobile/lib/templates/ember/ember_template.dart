import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// The catalog's one deliberately dark *document*.
///
/// Every other template is ink on paper; this one is a printed black card, the
/// way a film or photography credit sheet is. That choice only survives if the
/// contrast is real, so the palette is picked against the charcoal ground
/// rather than inherited: body copy sits around 8:1 and the amber accents
/// around 8.3:1 on `paper`, comfortably past WCAG AA at these sizes.
///
/// [TemplatePalette.secondary] — a deep umber — is never used for type. At this
/// value it fails against the ground; it earns its place as the unfilled track
/// of the skill meters, where being barely-there is the point.
class EmberTemplate extends ResumeTemplate {
  const EmberTemplate();

  @override
  String get id => 'ember';

  @override
  String get name => 'Ember Dark';

  @override
  String get description =>
      'A dark charcoal page with warm amber accents and a ringed portrait — a '
      'credit sheet rather than a sheet of paper.';

  @override
  String get bestFor => 'Film, Photography, Creative direction';

  @override
  TemplateCategory get category => TemplateCategory.creative;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFFF59E0B),
    secondary: PdfColor.fromInt(0xFF78350F),
    accent: PdfColor.fromInt(0xFF1C1917),
    paper: PdfColor.fromInt(0xFF1C1917),
    ink: PdfColor.fromInt(0xFFF6F1EA),
    muted: PdfColor.fromInt(0xFFB9B1A8),
    // Amber is a light fill; type on top of it must go dark, not white.
    onPrimary: PdfColor.fromInt(0xFF1C1917),
  );

  /// One step up from the page, so panels read as raised without a border.
  static const _surface = PdfColor.fromInt(0xFF272220);
  static const _hairline = PdfColor.fromInt(0xFF3D3733);
  static const _pagePadding = 34.0;
  static const _photoSize = 74.0;

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        // Painting the ground first matters more here than anywhere else: an
        // unpainted region would print as white and read as a rendering bug.
        color: p.paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(ctx, sans),
            pw.Container(width: a4.width, height: 0.8, color: _hairline),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(
                  _pagePadding,
                  22,
                  _pagePadding,
                  _pagePadding,
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 62, child: _mainColumn(ctx, sans)),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 38, child: _sideColumn(ctx, sans)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _header(TemplateContext ctx, LoadedFamily sans) {
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
      color: _surface,
      padding: const pw.EdgeInsets.fromLTRB(_pagePadding, 32, _pagePadding, 30),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (photo != null) ...[
            pw.Container(
              width: _photoSize,
              height: _photoSize,
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: p.primary, width: 1.2),
              ),
              child: pw.ClipOval(
                child: pw.Image(
                  photo,
                  fit: pw.BoxFit.cover,
                  width: _photoSize - 10,
                  height: _photoSize - 10,
                ),
              ),
            ),
            pw.SizedBox(width: 18),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                clampedText(
                  info.fullName.isEmpty ? 'Your Name' : info.fullName,
                  style: pw.TextStyle(
                    font: sans.bold,
                    fontSize: 27,
                    color: p.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                if (info.title.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  clampedText(
                    info.title.toUpperCase(),
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 10,
                      color: p.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
                if (contact.isNotEmpty) ...[
                  pw.SizedBox(height: 9),
                  clampedText(
                    contact,
                    maxLines: 2,
                    style: pw.TextStyle(
                      font: sans.regular,
                      fontSize: 8.3,
                      color: p.muted,
                      lineSpacing: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _mainColumn(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.personalInfo.summary.trim().isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(13),
            decoration: pw.BoxDecoration(
              color: _surface,
              borderRadius: pw.BorderRadius.circular(8),
              // Uniform only: dart_pdf asserts when a BoxDecoration pairs a
              // borderRadius with a one-sided Border, and that assert fires at
              // save() time rather than at build time.
              border: pw.Border.all(color: p.primary, width: 0.7),
            ),
            child: clampedText(
              data.personalInfo.summary,
              maxLines: 7,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.4,
                color: p.ink,
                lineSpacing: 2,
              ),
            ),
          ),
          pw.SizedBox(height: 24),
        ],
        if (data.experiences.isNotEmpty) ...[
          _sectionTitle('Experience', sans, p),
          ...data.experiences.take(5).map((e) => _experience(e, sans, p)),
          pw.SizedBox(height: 4),
        ],
        if (data.projects.isNotEmpty) ...[
          _sectionTitle('Selected work', sans, p),
          ...data.projects.take(4).map((pr) => _project(pr, sans, p)),
        ],
      ],
    );
  }

  pw.Widget _sideColumn(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.skills.isNotEmpty) ...[
          _sectionTitle('Craft', sans, p),
          ...data.skills.take(12).map((s) => _skillMeter(s, sans, p)),
          pw.SizedBox(height: 16),
        ],
        if (data.education.isNotEmpty) ...[
          _sectionTitle('Education', sans, p),
          ...data.education.take(4).map((e) => _education(e, sans, p)),
          pw.SizedBox(height: 4),
        ],
        ...data.customSections
            .take(3)
            .map(
              (section) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    section.sectionTitle.isEmpty
                        ? 'More'
                        : section.sectionTitle,
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
                                  font: sans.semiBold,
                                  fontSize: 9.1,
                                  color: p.ink,
                                  lineSpacing: 1.35,
                                ),
                              ),
                              if (item.subtitle.trim().isNotEmpty)
                                clampedText(
                                  item.subtitle,
                                  style: pw.TextStyle(
                                    font: sans.regular,
                                    fontSize: 8.5,
                                    color: p.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  pw.SizedBox(height: 4),
                ],
              ),
            ),
      ],
    );
  }

  pw.Widget _sectionTitle(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 5, height: 5, color: p.primary),
          pw.SizedBox(width: 7),
          pw.Expanded(
            child: clampedText(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: sans.bold,
                fontSize: 9.2,
                color: p.primary,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Amber fill over an umber track, expressed as flex.
  ///
  /// dart_pdf has no FractionallySizedBox, and a measured pixel width would go
  /// wrong the moment the column flex changes.
  pw.Widget _skillMeter(Skill s, LoadedFamily sans, TemplatePalette p) {
    final filled = s.level.clamp(0, 5);
    final empty = 5 - filled;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            s.name,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 9.1,
              color: p.ink,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 4,
            decoration: pw.BoxDecoration(
              color: p.secondary,
              borderRadius: pw.BorderRadius.circular(1.75),
            ),
            child: pw.Row(
              children: [
                if (filled > 0)
                  pw.Expanded(
                    flex: filled,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        color: p.primary,
                        borderRadius: pw.BorderRadius.circular(1.75),
                      ),
                    ),
                  ),
                if (empty > 0) pw.Expanded(flex: empty, child: pw.SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 20),
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
                    fontSize: 11.2,
                    color: p.ink,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                _datePill(range, sans, p),
              ],
            ],
          ),
          pw.SizedBox(height: 2),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9.4,
              color: p.primary,
            ),
          ),
          if (e.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              e.description,
              maxLines: 4,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 1.85,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _datePill(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pillRadius(14),
        border: pw.Border.all(color: _hairline, width: 0.7),
      ),
      child: pw.Text(
        label,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(font: sans.semiBold, fontSize: 7.9, color: p.muted),
      ),
    );
  }

  pw.Widget _project(Project pr, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _hairline, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            clampedText(
              pr.name,
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 10.2,
                color: p.ink,
              ),
            ),
            if (pr.description.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              clampedText(
                pr.description,
                maxLines: 3,
                style: pw.TextStyle(
                  font: sans.regular,
                  fontSize: 9,
                  color: p.muted,
                  lineSpacing: 1.75,
                ),
              ),
            ],
            if (pr.technologies.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              clampedText(
                pr.technologies,
                style: pw.TextStyle(
                  font: sans.semiBold,
                  fontSize: 8.1,
                  color: p.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  pw.Widget _education(Education e, LoadedFamily sans, TemplatePalette p) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final range = formatRange(e.startDate, e.endDate);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            degree,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9.3,
              color: p.ink,
              lineSpacing: 1.4,
            ),
          ),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.8,
              color: p.muted,
              lineSpacing: 1.4,
            ),
          ),
          if (range.isNotEmpty)
            clampedText(
              range,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 8.1,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }
}
