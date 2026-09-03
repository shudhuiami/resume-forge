import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Deliberately the most demanding design in the catalog, built first as a
/// fidelity probe.
///
/// It exercises every capability the remaining templates might need: a
/// multi-stop linear gradient, a circular photo overlapping the gradient
/// boundary inside a Stack, an asymmetric two-column body, rounded cards,
/// proportional skill meters, and pill chips. If `dart_pdf` can render this,
/// the rest of the catalog is a styling exercise rather than a research
/// problem.
///
/// Known engine limit worked around here: there is no gradient-filled text, so
/// headings use solid colour.
class AuroraTemplate extends ResumeTemplate {
  const AuroraTemplate();

  @override
  String get id => 'aurora';

  @override
  String get name => 'Aurora Gradient';

  @override
  String get description =>
      'Gradient banner with an overlapping portrait, paired with a two-column '
      'body and soft skill meters.';

  @override
  String get bestFor => 'Design, Product, Marketing';

  @override
  TemplateCategory get category => TemplateCategory.creative;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF7C3AED),
    secondary: PdfColor.fromInt(0xFF06B6D4),
    accent: PdfColor.fromInt(0xFFF5F3FF),
    ink: PdfColor.fromInt(0xFF1B1830),
    muted: PdfColor.fromInt(0xFF6E6A85),
  );

  static const _bannerHeight = 132.0;
  static const _photoSize = 92.0;
  static const _pagePadding = 32.0;

  /// Field mark size and the gap to its value. 7.6pt beside 8.6pt type is the
  /// mark reading as a peer of the x-height rather than as a bullet; measured
  /// against the rail, the 13pt the pair costs changes no line count, for the
  /// shipped sample or for a pathological profile URL.
  static const _markSize = 7.6;
  static const _markGap = 5.4;

  /// Sidebar density. This was the one skills call site in the catalog with no
  /// cap, and an uncapped list is not a generous design — it is a list that
  /// takes the whole rail: at 24 skills the meters ran to the foot of the page
  /// and dart_pdf deleted the Education block underneath them outright. Ten
  /// matches the rail's other lists and leaves education its space.
  static const _maxSkills = 10;

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    // dart_pdf does not stretch a page's root widget to the page box, so the
    // canvas is sized explicitly. Without this the Column is vertically
    // unbounded, Expanded collapses, and any `width: double.infinity` child
    // balloons to fill the sheet.
    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _banner(ctx, sans),
            pw.SizedBox(height: 14),
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
                    pw.Expanded(flex: 34, child: _sidebar(ctx, sans)),
                    pw.SizedBox(width: 20),
                    pw.Expanded(flex: 66, child: _main(ctx, sans)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gradient band with the portrait straddling its lower edge.
  ///
  /// The Stack is sized to banner + half the photo so the overhang has room;
  /// relying on overflow would clip on some renderers.
  pw.Widget _banner(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;
    final photo = tryDecodePhoto(info.photo);
    final hasPhoto = photo != null;

    // Text column width is computed rather than expressed as left+right on the
    // Positioned: dart_pdf does not resolve opposing edge constraints into a
    // width, which silently truncated the name to whatever fit its intrinsic box.
    final textWidth =
        a4.width - _pagePadding * 2 - (hasPhoto ? _photoSize + 18 : 0);

    // Only reserve the portrait overhang when there is a portrait; otherwise
    // the banner leaves a dead band above the content.
    return pw.SizedBox(
      width: a4.width,
      height: _bannerHeight + (hasPhoto ? _photoSize / 2 : 0),
      child: pw.Stack(
        children: [
          pw.Container(
            width: a4.width,
            height: _bannerHeight,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: [
                  PdfColor.fromInt(0xFF7C3AED),
                  PdfColor.fromInt(0xFF6366F1),
                  PdfColor.fromInt(0xFF06B6D4),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: _pagePadding,
            top: 30,
            child: pw.SizedBox(
              width: textWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  clampedText(
                    info.fullName.isEmpty ? 'Your Name' : info.fullName,
                    style: pw.TextStyle(
                      font: sans.bold,
                      fontSize: 26,
                      color: p.onPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  clampedText(
                    info.title,
                    style: pw.TextStyle(
                      font: sans.regular,
                      fontSize: 12.5,
                      color: const PdfColor.fromInt(0xFFEDE9FE),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasPhoto)
            pw.Positioned(
              right: _pagePadding,
              top: _bannerHeight - _photoSize / 2,
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

    // QA-8. Aurora is the one design in the catalog that takes field marks —
    // see THE FIELD MARK RULE in template.dart for why the other twelve do
    // not. Its contact list is stacked and carries no field labels, and the
    // rail already speaks in geometry (the rule before every section title,
    // the pill chips, the meters), so a mark has somewhere to belong here.
    // Nothing is removed to make room: the value is still drawn in full, so a
    // parser reading the extracted text sees exactly what it saw before.
    final contact = <(FieldMark, String, ContactKind)>[
      (FieldMark.email, info.email, ContactKind.email),
      (FieldMark.phone, info.phone, ContactKind.phone),
      (FieldMark.location, info.location, ContactKind.plain),
      (FieldMark.profile, info.linkedin, ContactKind.url),
      (FieldMark.website, info.website, ContactKind.url),
    ].where((e) => e.$2.trim().isNotEmpty).toList();

    final contactStyle = pw.TextStyle(
      font: sans.regular,
      fontSize: 8.6,
      color: p.muted,
      lineSpacing: 1.4,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (contact.isNotEmpty) ...[
          _sectionTitle('Contact', sans, p),
          ...contact.map(
            (e) =>
                _contactRow(e.$1, e.$2, kind: e.$3, style: contactStyle, p: p),
          ),
          pw.SizedBox(height: 14),
        ],
        if (data.skills.isNotEmpty) ...[
          _sectionTitle('Skills', sans, p),
          ...data.skills.take(_maxSkills).map((s) => _skillMeter(s, sans, p)),
          pw.SizedBox(height: 14),
        ],
        if (data.education.isNotEmpty) ...[
          _sectionTitle('Education', sans, p),
          ...data.education.map((e) => _educationEntry(e, sans, p)),
          pw.SizedBox(height: 14),
        ],
        ...data.customSections.map(
          (section) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle(section.sectionTitle, sans, p),
              ...section.items.map(
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
                          color: p.ink,
                          lineSpacing: 1.3,
                        ),
                      ),
                      if (item.subtitle.trim().isNotEmpty)
                        clampedText(
                          item.subtitle,
                          style: pw.TextStyle(
                            font: sans.regular,
                            fontSize: 8.2,
                            color: p.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          ),
        ),
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
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: p.accent,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: clampedText(
              data.personalInfo.summary,
              maxLines: 6,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 9,
                color: p.ink,
                lineSpacing: 1.6,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
        ],
        if (data.experiences.isNotEmpty) ...[
          _sectionTitle('Experience', sans, p),
          ...data.experiences.map((e) => _experienceEntry(e, sans, p)),
        ],
        if (data.projects.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _sectionTitle('Projects', sans, p),
          ...data.projects.map((pr) => _projectEntry(pr, sans, p)),
        ],
      ],
    );
  }

  /// One contact line: its field mark, then the value.
  ///
  /// The value sits in an `Expanded` so a long URL is bounded by the rail
  /// rather than laid out unbounded beside a non-flex mark — URL rule item 5.
  /// Links keep the multi-line form: the text column is ~161pt after the mark,
  /// so a real LinkedIn URL needs two lines and must break at a path separator
  /// rather than mid-handle.
  pw.Widget _contactRow(
    FieldMark mark,
    String value, {
    required ContactKind kind,
    required pw.TextStyle style,
    required TemplatePalette p,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Nudged down so the mark centres on the first line's x-height
          // instead of hanging off its ascender.
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1.6),
            child: fieldMark(mark, size: _markSize, color: p.primary),
          ),
          pw.SizedBox(width: _markGap),
          pw.Expanded(
            // The mark is left out of the link: it is decoration, and the tap
            // target a reader aims at is the address itself.
            child: kind == ContactKind.url
                ? urlText(value, maxLines: 3, style: style)
                : contactLink(
                    value,
                    kind,
                    child: clampedText(value, maxLines: 2, style: style),
                  ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 14,
            height: 2.5,
            decoration: pw.BoxDecoration(
              color: p.primary,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: clampedText(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: sans.bold,
                fontSize: 9,
                color: p.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _skillMeter(Skill s, LoadedFamily sans, TemplatePalette p) {
    // dart_pdf has no FractionallySizedBox, so the fill is expressed as flex
    // against the remainder — which also keeps the meter correct at any
    // sidebar width rather than depending on a measured pixel value.
    final filled = skillRating(s);
    final empty = filled == null ? 0 : 5 - filled;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          markedText(
            s.name,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.6,
              color: p.ink,
            ),
          ),
          // Skills rule item 5: an unrated skill gets no track. An empty one
          // would read as a failed render, or as a rating the user never gave.
          if (filled != null) ...[
            pw.SizedBox(height: 3),
            pw.Container(
              height: 4,
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFEDEAF7),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: filled,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [p.primary, p.secondary],
                        ),
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
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

  pw.Widget _educationEntry(Education e, LoadedFamily sans, TemplatePalette p) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            degree,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9,
              color: p.ink,
              lineSpacing: 1.3,
            ),
          ),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.4,
              color: p.muted,
              lineSpacing: 1.3,
            ),
          ),
          if (formatRange(e.startDate, e.endDate).isNotEmpty)
            clampedText(
              formatRange(e.startDate, e.endDate),
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 7.8,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _experienceEntry(
    Experience e,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
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
                    fontSize: 10.5,
                    color: p.ink,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              _datePill(
                formatRange(e.startDate, e.endDate, current: e.current),
                sans,
                p,
              ),
            ],
          ),
          pw.SizedBox(height: 1),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9,
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
                fontSize: 8.8,
                color: p.muted,
                lineSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _datePill(String label, LoadedFamily sans, TemplatePalette p) {
    if (label.isEmpty) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: p.accent,
        borderRadius: pillRadius(14),
      ),
      child: pw.Text(
        label,
        maxLines: 1,
        style: pw.TextStyle(
          font: sans.semiBold,
          fontSize: 7.4,
          color: p.primary,
        ),
      ),
    );
  }

  pw.Widget _projectEntry(Project pr, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(9),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE7E3F5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // The link was never drawn here at all, so a project URL the user
            // typed silently never reached the PDF (QA-1). It goes on the title
            // line, where every other design in the catalog puts it and where
            // it costs the card no extra height.
            titleWithUrl(
              title: pr.name,
              titleStyle: pw.TextStyle(
                font: sans.semiBold,
                fontSize: 9.5,
                color: p.ink,
              ),
              url: pr.link,
              urlStyle: pw.TextStyle(
                font: sans.regular,
                fontSize: 8,
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
                  fontSize: 8.4,
                  color: p.muted,
                  lineSpacing: 1.45,
                ),
              ),
            ],
            if (pr.technologies.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Wrap(
                spacing: 4,
                runSpacing: 3,
                children: pr.technologies
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .map(
                      (t) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: p.accent,
                          borderRadius: pillRadius(12),
                        ),
                        child: pw.Text(
                          t,
                          style: pw.TextStyle(
                            font: sans.regular,
                            fontSize: 7,
                            color: p.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
