import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Teal masthead with a circular portrait straddling its lower-left edge, over
/// an asymmetric two-column body.
///
/// Skills are chips rather than meters: a program or product audience reads
/// "worked with" better than an invented 4-out-of-5, and chips stay honest
/// about a level the user never really quantified.
class CompassTemplate extends ResumeTemplate {
  const CompassTemplate();

  @override
  String get id => 'compass';

  @override
  String get name => 'Compass Teal';

  @override
  String get description =>
      'Teal top bar with an overlapping round portrait, a two-column body and '
      'skills as chips.';

  @override
  String get bestFor => 'Product, Program, Strategy';

  @override
  TemplateCategory get category => TemplateCategory.corporate;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF0D9488),
    secondary: PdfColor.fromInt(0xFF134E4A),
    accent: PdfColor.fromInt(0xFFF0FDFA),
    ink: PdfColor.fromInt(0xFF134E4A),
    muted: PdfColor.fromInt(0xFF5C6B6A),
  );

  static const _pagePadding = 34.0;
  static const _barHeight = 104.0;
  static const _photoSize = 84.0;
  static const _photoLeft = 34.0;
  static const _columnGap = 22.0;

  static const _onTeal = PdfColor.fromInt(0xFFCCFBF1);
  static const _hairline = PdfColor.fromInt(0xFFD9E5E3);

  static const _maxExperiences = 5;
  static const _maxProjects = 3;
  static const _maxEducation = 3;
  static const _maxSkills = 12;

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
            _bar(ctx, sans),
            pw.SizedBox(height: 16),
            pw.Expanded(
              child: pw.ClipRect(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(
                    _pagePadding,
                    0,
                    _pagePadding,
                    26,
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 36, child: _sidebar(ctx, sans)),
                      pw.SizedBox(width: _columnGap),
                      pw.Expanded(flex: 64, child: _main(ctx, sans)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Teal band with the portrait hanging off its lower-left corner.
  ///
  /// The Stack is sized to bar + half the portrait so the overhang has real
  /// space; relying on overflow would clip the circle on some viewers. When no
  /// portrait decodes, that extra band is not reserved and the headline text
  /// slides back to the page margin — the layout must not leave a hole where a
  /// photo would have been.
  pw.Widget _bar(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;
    final photo = tryDecodePhoto(info.photo);
    final hasPhoto = photo != null;

    final textLeft = hasPhoto ? _photoLeft + _photoSize + 20 : _pagePadding;
    // Opposing left/right edges on a Positioned do not resolve to a width in
    // dart_pdf, so the headline box is measured explicitly.
    final textWidth = a4.width - textLeft - _pagePadding;

    return pw.SizedBox(
      width: a4.width,
      height: _barHeight + (hasPhoto ? _photoSize / 2 : 0),
      child: pw.Stack(
        children: [
          pw.Container(width: a4.width, height: _barHeight, color: p.primary),
          pw.Positioned(
            left: textLeft,
            top: 26,
            child: pw.SizedBox(
              width: textWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  clampedText(
                    info.fullName.isEmpty ? 'Your Name' : info.fullName,
                    style: pw.TextStyle(
                      font: sans.bold,
                      fontSize: 24,
                      color: p.onPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (info.title.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    clampedText(
                      info.title.toUpperCase(),
                      style: pw.TextStyle(
                        font: sans.semiBold,
                        fontSize: 9.4,
                        color: _onTeal,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasPhoto)
            pw.Positioned(
              left: _photoLeft,
              top: _barHeight - _photoSize / 2,
              child: pw.Container(
                width: _photoSize,
                height: _photoSize,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: p.paper,
                  border: pw.Border.all(color: p.paper, width: 4),
                ),
                child: pw.ClipOval(
                  child: pw.Image(
                    photo,
                    fit: pw.BoxFit.cover,
                    width: _photoSize,
                    height: _photoSize,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _sidebar(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;
    final info = data.personalInfo;

    final contact = <(String, String, ContactKind)>[
      ('Email', info.email, ContactKind.email),
      ('Phone', info.phone, ContactKind.phone),
      ('Location', info.location, ContactKind.plain),
      ('LinkedIn', info.linkedin, ContactKind.url),
      ('Web', info.website, ContactKind.url),
    ].where((e) => e.$2.trim().isNotEmpty).toList();

    final valueStyle = pw.TextStyle(
      font: sans.regular,
      fontSize: 8.8,
      color: p.muted,
      lineSpacing: 1.3,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (contact.isNotEmpty) ...[
          _heading('Contact', sans, p),
          ...contact.map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  clampedText(
                    c.$1.toUpperCase(),
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 6.4,
                      color: p.primary,
                      letterSpacing: 0.9,
                    ),
                  ),
                  // A URL in this ~180pt column needs to break at a path
                  // separator, not wherever the glyph run happens to stop.
                  // The label stays outside the link: it is the design's own
                  // word, not part of the address.
                  if (c.$3 == ContactKind.url)
                    urlText(c.$2, maxLines: 3, style: valueStyle)
                  else
                    contactLink(
                      c.$2,
                      c.$3,
                      child: clampedText(c.$2, maxLines: 2, style: valueStyle),
                    ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if (data.skills.isNotEmpty) ...[
          _heading('Skills', sans, p),
          pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: data.skills
                .take(_maxSkills)
                .map((s) => _chip(s.name, sans, p))
                .toList(),
          ),
          pw.SizedBox(height: 16),
        ],
        if (data.education.isNotEmpty) ...[
          _heading('Education', sans, p),
          ...data.education
              .take(_maxEducation)
              .map((e) => _education(e, sans, p)),
          pw.SizedBox(height: 6),
        ],
        ...data.customSections
            .take(2)
            .map((section) => _customSection(section, sans, p)),
      ],
    );
  }

  pw.Widget _main(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.personalInfo.summary.trim().isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(11),
            decoration: pw.BoxDecoration(
              color: p.accent,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: clampedText(
              data.personalInfo.summary,
              maxLines: 5,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.4,
                color: p.muted,
                lineSpacing: 1.65,
              ),
            ),
          ),
          pw.SizedBox(height: 15),
        ],
        if (data.experiences.isNotEmpty) ...[
          _heading('Experience', sans, p),
          ...data.experiences
              .take(_maxExperiences)
              .map((e) => _experience(e, sans, p)),
          pw.SizedBox(height: 4),
        ],
        if (data.projects.isNotEmpty) ...[
          _heading('Projects', sans, p),
          ...data.projects
              .take(_maxProjects)
              .map((pr) => _project(pr, sans, p)),
        ],
      ],
    );
  }

  pw.Widget _heading(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            label.toUpperCase(),
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 10,
              color: p.primary,
              letterSpacing: 1.7,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(width: double.infinity, height: 0.8, color: _hairline),
        ],
      ),
    );
  }

  pw.Widget _chip(String label, LoadedFamily sans, TemplatePalette p) {
    if (label.trim().isEmpty) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: p.accent,
        // pillRadius, never circular(999): an oversized radius makes dart_pdf
        // emit a degenerate path that floods the page.
        borderRadius: pillRadius(15),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFF99F6E4)),
      ),
      // A Wrap bounds its children to the Wrap's own width, so this measures
      // against the real column and marks a shortening rather than letting the
      // chip stretch to the full rail and stop mid-phrase (skills rule item 3).
      child: markedText(
        label,
        style: pw.TextStyle(
          font: sans.semiBold,
          fontSize: 8,
          color: p.secondary,
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
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (degree.isNotEmpty)
            clampedText(
              degree,
              maxLines: 2,
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 9.5,
                color: p.secondary,
                lineSpacing: 1.3,
              ),
            ),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.7,
              color: p.muted,
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
                fontSize: 7.7,
                color: p.primary,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            e.position,
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 11.2,
              color: p.secondary,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: clampedText(
                  e.company,
                  style: pw.TextStyle(
                    font: sans.semiBold,
                    fontSize: 9.5,
                    color: p.primary,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                clampedText(
                  range,
                  style: pw.TextStyle(
                    font: sans.regular,
                    fontSize: 7.9,
                    color: p.muted,
                  ),
                ),
              ],
            ],
          ),
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
    final tech = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
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
              fontSize: 7.7,
              color: p.muted,
            ),
            gap: 8,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
          ),
          if (pr.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              pr.description,
              maxLines: 3,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.1,
                color: p.muted,
                lineSpacing: 1.55,
              ),
            ),
          ],
          if (tech.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 4,
              runSpacing: 3,
              children: tech.map((t) => _chip(t, sans, p)).toList(),
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    clampedText(
                      item.title,
                      maxLines: 3,
                      style: pw.TextStyle(
                        font: sans.semiBold,
                        fontSize: 9,
                        color: p.secondary,
                        lineSpacing: 1.35,
                      ),
                    ),
                    if (item.subtitle.trim().isNotEmpty)
                      clampedText(
                        item.subtitle,
                        style: pw.TextStyle(
                          font: sans.regular,
                          fontSize: 8,
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
