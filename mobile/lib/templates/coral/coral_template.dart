import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Warm, people-first design for brand and social roles.
///
/// A coral-to-peach gradient band opens the page, a circular portrait straddles
/// its lower edge on the centre line, and the name block sits centred beneath —
/// deliberately *off* the gradient. White type on a peach stop measures around
/// 2.3:1, which is fine for a display name and unreadable for an 8pt contact
/// line, so all small text lives on paper where it prints cleanly.
///
/// Below the name block the page splits into an asymmetric two-column body.
class CoralTemplate extends ResumeTemplate {
  const CoralTemplate();

  @override
  String get id => 'coral';

  @override
  String get name => 'Coral Bloom';

  @override
  String get description =>
      'Soft coral-to-peach header with a centred portrait and name block, over '
      'a two-column body with skill chips.';

  @override
  String get bestFor => 'Marketing, Social, Brand';

  @override
  TemplateCategory get category => TemplateCategory.creative;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFFFB7185),
    secondary: PdfColor.fromInt(0xFFF97316),
    accent: PdfColor.fromInt(0xFFFFF1F2),
    ink: PdfColor.fromInt(0xFF2A1B1E),
    muted: PdfColor.fromInt(0xFF7C6A6D),
  );

  /// Gradient band height. Taller when a portrait has to sit on its edge, so
  /// the circle reads as an intentional overlap rather than a floating disc.
  static const _bandWithPhoto = 78.0;
  static const _bandBare = 88.0;
  static const _photoSize = 80.0;
  static const _pagePadding = 34.0;
  static const _hairline = PdfColor.fromInt(0xFFF6DDE0);

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;
    final hasPhoto = tryDecodePhoto(ctx.data.personalInfo.photo) != null;

    // dart_pdf never stretches a page's root widget to the page box; without an
    // explicit canvas the Column is vertically unbounded and Expanded collapses.
    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(ctx),
            _nameBlock(ctx, sans),
            // The portrait's overhang is paid for out of the name block's own
            // whitespace, so the body below starts at the same height whether
            // or not a photo was supplied and nothing drops off the page.
            pw.SizedBox(height: hasPhoto ? 12 : 22),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(
                  _pagePadding,
                  0,
                  _pagePadding,
                  _pagePadding,
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 61, child: _mainColumn(ctx, sans)),
                    pw.SizedBox(width: 22),
                    pw.Expanded(flex: 39, child: _sideColumn(ctx, sans)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gradient band plus the portrait overlapping its lower edge.
  ///
  /// The Stack is sized to band + half the photo so the overhang has real room;
  /// relying on overflow would clip the circle on some viewers.
  pw.Widget _header(TemplateContext ctx) {
    final p = ctx.palette;
    final photo = tryDecodePhoto(ctx.data.personalInfo.photo);
    final band = photo == null ? _bandBare : _bandWithPhoto;

    return pw.SizedBox(
      width: a4.width,
      height: band + (photo == null ? 0 : _photoSize / 2),
      child: pw.Stack(
        children: [
          pw.Container(
            width: a4.width,
            height: band,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.centerLeft,
                end: pw.Alignment.centerRight,
                colors: [
                  PdfColor.fromInt(0xFFFB7185),
                  PdfColor.fromInt(0xFFFB923C),
                  PdfColor.fromInt(0xFFFDBA74),
                ],
              ),
            ),
          ),
          if (photo != null)
            pw.Positioned(
              left: (a4.width - _photoSize) / 2,
              top: band - _photoSize / 2,
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

  /// Centred name, title and contact line, on paper for print contrast.
  pw.Widget _nameBlock(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;
    final hasPhoto = tryDecodePhoto(info.photo) != null;

    final contact = <(String, ContactKind)>[
      (info.email, ContactKind.email),
      (info.phone, ContactKind.phone),
      (info.location, ContactKind.plain),
      (info.linkedin, ContactKind.url),
      (info.website, ContactKind.url),
    ];

    final contactStyle = pw.TextStyle(
      font: sans.regular,
      fontSize: 8.2,
      color: p.muted,
      lineSpacing: 1.6,
    );

    return pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(
        _pagePadding,
        hasPhoto ? 8 : 20,
        _pagePadding,
        0,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          clampedText(
            info.fullName.isEmpty ? 'Your Name' : info.fullName,
            align: pw.TextAlign.center,
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 27,
              color: p.ink,
              letterSpacing: -0.3,
            ),
          ),
          if (info.title.trim().isNotEmpty) ...[
            pw.SizedBox(height: 7),
            clampedText(
              info.title.toUpperCase(),
              align: pw.TextAlign.center,
              style: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 10.2,
                color: p.primary,
                letterSpacing: 1.6,
              ),
            ),
          ],
          pw.SizedBox(height: 11),
          contactStrip(
            contact,
            style: contactStyle,
            alignment: pw.WrapAlignment.center,
          ),
          pw.SizedBox(height: hasPhoto ? 10 : 16),
          pw.Container(width: 46, height: 2, color: p.secondary),
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
          _sectionTitle('Profile', sans, p),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(13),
            decoration: pw.BoxDecoration(
              color: p.accent,
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: clampedText(
              data.personalInfo.summary,
              maxLines: 7,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9.4,
                color: p.ink,
                lineSpacing: 2.1,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
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
          _sectionTitle('Skills', sans, p),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: data.skills
                .take(14)
                .map((s) => _chip(s.name, sans, p))
                .toList(),
          ),
          pw.SizedBox(height: 20),
        ],
        if (data.education.isNotEmpty) ...[
          _sectionTitle('Education', sans, p),
          ...data.education.take(4).map((e) => _education(e, sans, p)),
          pw.SizedBox(height: 4),
        ],
        ...data.customSections
            .take(3)
            .map((section) => _customSection(section, sans, p)),
      ],
    );
  }

  pw.Widget _customSection(
    CustomSection section,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          section.sectionTitle.isEmpty ? 'More' : section.sectionTitle,
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
                        fontSize: 9.2,
                        color: p.ink,
                        lineSpacing: 1.45,
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
    );
  }

  pw.Widget _sectionTitle(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            label.toUpperCase(),
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 9.2,
              color: p.primary,
              letterSpacing: 1.4,
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: p.accent,
        borderRadius: pillRadius(17),
        border: pw.Border.all(color: _hairline, width: 0.7),
      ),
      // Skills rule item 3: a name too long for the column is marked, not cut.
      // The Wrap bounds this child to the column, so no explicit width is
      // needed here.
      child: markedText(
        label,
        style: pw.TextStyle(font: sans.semiBold, fontSize: 8.2, color: p.ink),
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            e.position,
            style: pw.TextStyle(font: sans.bold, fontSize: 11.2, color: p.ink),
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
                    color: p.secondary,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                pw.Text(
                  range,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    font: sans.regular,
                    fontSize: 8.2,
                    color: p.muted,
                  ),
                ),
              ],
            ],
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

  pw.Widget _project(Project pr, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 3,
            height: 30,
            decoration: pw.BoxDecoration(
              color: p.primary,
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // The link was never drawn here at all, so a project URL the
                // user typed silently never reached the PDF (QA-1).
                titleWithUrl(
                  title: pr.name,
                  titleStyle: pw.TextStyle(
                    font: sans.semiBold,
                    fontSize: 10.2,
                    color: p.ink,
                  ),
                  url: pr.link,
                  urlStyle: pw.TextStyle(
                    font: sans.regular,
                    fontSize: 8.2,
                    color: p.primary,
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
                      fontSize: 9,
                      color: p.muted,
                      lineSpacing: 1.75,
                    ),
                  ),
                ],
                if (pr.technologies.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  clampedText(
                    pr.technologies,
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 8,
                      color: p.secondary,
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
              fontSize: 9.4,
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
