import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// An engineering resume that reads like a well-commented schematic.
///
/// Structure: a pale blue header band, then a two-column body split by a single
/// hairline. Technologies, dates, and contact details are set in the monospace
/// family so the scannable machine-ish data separates visually from the prose,
/// and skills collapse into a compact tag cloud instead of a long list — the
/// right column has to hold four sections without running past the fold.
///
/// The column rule is drawn by a stretched Container inside the body Row rather
/// than a VerticalDivider with a guessed height, so it always ends exactly
/// where the columns do.
class CircuitTemplate extends ResumeTemplate {
  const CircuitTemplate();

  @override
  String get id => 'circuit';

  @override
  String get name => 'Circuit Blue';

  @override
  String get description =>
      'Two-column engineering layout with a monospace data track, tag-cloud '
      'skills, and a hairline column rule.';

  @override
  String get bestFor => 'Software, Data, Platform';

  @override
  TemplateCategory get category => TemplateCategory.tech;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans, FontFamily.mono};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF2563EB),
    secondary: PdfColor.fromInt(0xFF1E293B),
    accent: PdfColor.fromInt(0xFFEFF6FF),
    ink: PdfColor.fromInt(0xFF0F172A),
    muted: PdfColor.fromInt(0xFF64748B),
  );

  static const _pad = 40.0;
  static const _photoSize = 68.0;
  static const _hairline = PdfColor.fromInt(0xFFDBE3EE);

  static const _maxExperience = 4;
  static const _maxProjects = 3;
  static const _maxSkills = 16;
  static const _maxEducation = 3;
  static const _maxCustomSections = 2;
  static const _maxCustomItems = 3;

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final mono = ctx.family(FontFamily.mono);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: a4.width, height: 4, color: p.primary),
            _header(ctx, sans),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(_pad, 34, _pad, _pad),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(flex: 58, child: _mainColumn(ctx, sans, mono)),
                    pw.SizedBox(width: 20),
                    pw.Container(width: 0.8, color: _hairline),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 42, child: _sideColumn(ctx, sans, mono)),
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

    return pw.Container(
      width: a4.width,
      color: p.accent,
      padding: const pw.EdgeInsets.fromLTRB(_pad, 28, _pad, 30),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                clampedText(
                  info.fullName.isEmpty ? 'Your Name' : info.fullName,
                  style: pw.TextStyle(
                    font: sans.bold,
                    fontSize: 27,
                    color: p.secondary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (info.title.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  clampedText(
                    info.title,
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 12.5,
                      color: p.primary,
                    ),
                  ),
                ],
                pw.SizedBox(height: 11),
                _traceRule(p),
              ],
            ),
          ),
          if (photo != null) ...[
            pw.SizedBox(width: 18),
            pw.Container(
              width: _photoSize,
              height: _photoSize,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: p.primary, width: 1.2),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 7,
                verticalRadius: 7,
                child: pw.Image(
                  photo,
                  fit: pw.BoxFit.cover,
                  width: _photoSize,
                  height: _photoSize,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A trace: line, node, line, node — the one piece of ornament in the design.
  pw.Widget _traceRule(TemplatePalette p) {
    pw.Widget node() => pw.Container(
      width: 4,
      height: 4,
      decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: p.primary),
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 26, height: 1.4, color: p.primary),
        pw.SizedBox(width: 3),
        node(),
        pw.SizedBox(width: 3),
        pw.Container(
          width: 52,
          height: 1,
          color: const PdfColor.fromInt(0xFF93B4F5),
        ),
        pw.SizedBox(width: 3),
        node(),
      ],
    );
  }

  pw.Widget _mainColumn(
    TemplateContext ctx,
    LoadedFamily sans,
    LoadedFamily mono,
  ) {
    final data = ctx.data;
    final p = ctx.palette;
    final summary = data.personalInfo.summary.trim();
    final experiences = data.experiences.take(_maxExperience).toList();
    final projects = data.projects.take(_maxProjects).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) ...[
          _sectionTitle('Profile', sans, p),
          clampedText(
            summary,
            maxLines: 6,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 9.2,
              color: p.muted,
              lineSpacing: 3.4,
            ),
          ),
          pw.SizedBox(height: 32),
        ],
        if (experiences.isNotEmpty) ...[
          _sectionTitle('Experience', sans, p),
          ...experiences.map((e) => _experience(e, sans, mono, p)),
          pw.SizedBox(height: 22),
        ],
        if (projects.isNotEmpty) ...[
          _sectionTitle('Projects', sans, p),
          ...projects.map((pr) => _project(pr, sans, mono, p)),
        ],
      ],
    );
  }

  pw.Widget _sideColumn(
    TemplateContext ctx,
    LoadedFamily sans,
    LoadedFamily mono,
  ) {
    final data = ctx.data;
    final p = ctx.palette;
    final info = data.personalInfo;
    final skills = data.skills.take(_maxSkills).toList();
    final education = data.education.take(_maxEducation).toList();
    final customSections = data.customSections
        .take(_maxCustomSections)
        .toList();

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
      font: mono.regular,
      fontSize: 7.8,
      color: p.secondary,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Contact lives in the sidebar rather than the header band: stacked one
        // per line it reads as a data block in the monospace track, and it
        // gives the right column enough mass to balance the experience list.
        if (contact.isNotEmpty || links.isNotEmpty) ...[
          _sectionTitle('Contact', sans, p),
          for (final line in contact)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: clampedText(line, style: contactStyle),
            ),
          // Monospace is wide: a real profile URL takes two of the sidebar's
          // ~199pt lines, and must break at a path separator (URL rule).
          for (final line in links)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: urlText(line, maxLines: 3, style: contactStyle),
            ),
          pw.SizedBox(height: 18),
        ],
        if (skills.isNotEmpty) ...[
          _sectionTitle('Stack', sans, p),
          pw.Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final s in skills)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: s.level >= 4 ? p.primary : p.accent,
                    borderRadius: pillRadius(16),
                    border: pw.Border.all(
                      color: s.level >= 4 ? p.primary : _hairline,
                      width: 0.7,
                    ),
                  ),
                  // Skills rule item 3. The Wrap bounds this child to the rail,
                  // so a name wider than it is marked rather than stopped.
                  child: markedText(
                    s.name,
                    style: pw.TextStyle(
                      font: mono.regular,
                      fontSize: 7.8,
                      color: s.level >= 4 ? p.onPrimary : p.secondary,
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 20),
        ],
        if (education.isNotEmpty) ...[
          _sectionTitle('Education', sans, p),
          ...education.map((e) => _education(e, sans, mono, p)),
          pw.SizedBox(height: 6),
        ],
        for (final section in customSections) ...[
          _sectionTitle(
            section.sectionTitle.isEmpty ? 'More' : section.sectionTitle,
            sans,
            p,
          ),
          ...section.items
              .take(_maxCustomItems)
              .map((i) => _customItem(i, sans, mono, p)),
          pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  pw.Widget _sectionTitle(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 13),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 5.5, height: 5.5, color: p.primary),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: clampedText(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: sans.bold,
                fontSize: 9,
                color: p.secondary,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _experience(
    Experience e,
    LoadedFamily sans,
    LoadedFamily mono,
    TemplatePalette p,
  ) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 26),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            e.position,
            style: pw.TextStyle(font: sans.bold, fontSize: 11, color: p.ink),
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: clampedText(
                  e.company,
                  style: pw.TextStyle(
                    font: sans.semiBold,
                    fontSize: 9.4,
                    color: p.primary,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                clampedText(
                  range,
                  style: pw.TextStyle(
                    font: mono.regular,
                    fontSize: 7.4,
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
              maxLines: 3,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.2,
                color: p.muted,
                lineSpacing: 3.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _project(
    Project pr,
    LoadedFamily sans,
    LoadedFamily mono,
    TemplatePalette p,
  ) {
    final tech = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(6)
        .join(' / ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 24),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          titleWithUrl(
            title: pr.name,
            titleStyle: pw.TextStyle(
              font: sans.bold,
              fontSize: 10.2,
              color: p.ink,
            ),
            url: pr.link,
            urlStyle: pw.TextStyle(
              font: mono.regular,
              fontSize: 7.6,
              color: p.primary,
            ),
            gap: 8,
          ),
          if (pr.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              pr.description,
              maxLines: 2,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9,
                color: p.muted,
                lineSpacing: 3,
              ),
            ),
          ],
          if (tech.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            clampedText(
              tech,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 7.8,
                color: p.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _education(
    Education e,
    LoadedFamily sans,
    LoadedFamily mono,
    TemplatePalette p,
  ) {
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
          clampedText(
            degree,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 9.4,
              color: p.ink,
              lineSpacing: 2.2,
            ),
          ),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.8,
              color: p.muted,
              lineSpacing: 2.2,
            ),
          ),
          if (range.isNotEmpty)
            clampedText(
              range,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 7.6,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _customItem(
    CustomItem item,
    LoadedFamily sans,
    LoadedFamily mono,
    TemplatePalette p,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            item.title,
            maxLines: 3,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9.2,
              color: p.ink,
              lineSpacing: 2.2,
            ),
          ),
          if (item.subtitle.trim().isNotEmpty)
            clampedText(
              item.subtitle,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 7.4,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }
}
