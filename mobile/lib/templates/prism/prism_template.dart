import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// A portfolio-shaped resume: every block is a card on a tinted page.
///
/// The page itself is lilac rather than white, so white cards read as raised
/// surfaces without needing shadows — `dart_pdf` has no blur, and a fake shadow
/// drawn as a grey offset rectangle looks like a printing fault.
///
/// A multi-stop gradient bar runs the full page width at the top: the only
/// saturated element, which keeps the rest of the page calm.
class PrismTemplate extends ResumeTemplate {
  const PrismTemplate();

  @override
  String get id => 'prism';

  @override
  String get name => 'Prism Cards';

  @override
  String get description =>
      'Rounded cards on a soft lilac page under a multi-stop accent bar, with '
      'skill chips and dedicated project cards.';

  @override
  String get bestFor => 'Design, UX, Portfolio';

  @override
  TemplateCategory get category => TemplateCategory.creative;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF8B5CF6),
    secondary: PdfColor.fromInt(0xFF06B6D4),
    accent: PdfColor.fromInt(0xFFF5F3FF),
    ink: PdfColor.fromInt(0xFF1E1B33),
    muted: PdfColor.fromInt(0xFF6A6585),
  );

  static const _barHeight = 8.0;
  static const _pagePadding = 28.0;
  static const _cardRadius = 12.0;
  static const _card = PdfColor.fromInt(0xFFFFFFFF);
  static const _cardBorder = PdfColor.fromInt(0xFFE6E0FA);
  static const _photoSize = 56.0;

  /// Fill for a filled skill chip — one step down the violet ramp from
  /// [palette]'s `primary`, and the only place the two differ.
  ///
  /// White on `primary` (#8B5CF6) measures **4.23 : 1**, and the chip sets its
  /// label at 8.2 pt, which WCAG counts as normal text and holds to 4.5 : 1.
  /// It is not illegible, but this catalog checks contrast on the printed page
  /// rather than eyeballing it, and 4.23 fails. White on #7C3AED measures
  /// **5.70 : 1** and passes, while staying unmistakably the same violet — the
  /// gradient bar, the card titles and the borders are untouched. A darker fill
  /// also happens to be the right signal: the filled chip means "strongest".
  ///
  /// Public only so `test/templates/skills_test.dart` can recompute the ratio
  /// from the constant itself rather than from a number copied into a comment,
  /// which is how 4.23 survived review in the first place.
  static const strongChipFill = PdfColor.fromInt(0xFF7C3AED);

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        // The page tint, not the card colour — cards paint white on top.
        color: p.accent,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: a4.width,
              height: _barHeight,
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.centerLeft,
                  end: pw.Alignment.centerRight,
                  colors: [
                    PdfColor.fromInt(0xFF8B5CF6),
                    PdfColor.fromInt(0xFF6366F1),
                    PdfColor.fromInt(0xFF0EA5E9),
                    PdfColor.fromInt(0xFF06B6D4),
                    PdfColor.fromInt(0xFF22D3EE),
                  ],
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(_pagePadding),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _headerCard(ctx, sans),
                    pw.SizedBox(height: 14),
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(flex: 62, child: _leftColumn(ctx, sans)),
                          pw.SizedBox(width: 12),
                          pw.Expanded(flex: 38, child: _rightColumn(ctx, sans)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _headerCard(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;
    final photo = tryDecodePhoto(info.photo);

    final contact = <(String, bool)>[
      (info.email, false),
      (info.phone, false),
      (info.location, false),
      (info.linkedin, true),
      (info.website, true),
    ];

    final contactStyle = pw.TextStyle(
      font: sans.regular,
      fontSize: 8.3,
      color: p.muted,
      lineSpacing: 1.6,
    );

    return _shell(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (photo != null) ...[
            pw.ClipRRect(
              horizontalRadius: 14,
              verticalRadius: 14,
              child: pw.Image(
                photo,
                fit: pw.BoxFit.cover,
                width: _photoSize,
                height: _photoSize,
              ),
            ),
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                clampedText(
                  info.fullName.isEmpty ? 'Your Name' : info.fullName,
                  style: pw.TextStyle(
                    font: sans.bold,
                    fontSize: 25,
                    color: p.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                if (info.title.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  clampedText(
                    info.title,
                    style: pw.TextStyle(
                      font: sans.semiBold,
                      fontSize: 11.2,
                      color: p.primary,
                    ),
                  ),
                ],
                pw.SizedBox(height: 6),
                contactStrip(contact, style: contactStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _leftColumn(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.personalInfo.summary.trim().isNotEmpty) ...[
          _shell(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _cardTitle('Profile', sans, p),
                clampedText(
                  data.personalInfo.summary,
                  maxLines: 6,
                  style: pw.TextStyle(
                    font: sans.regular,
                    fontSize: 9.4,
                    color: p.muted,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if (data.experiences.isNotEmpty) ...[
          _shell(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _cardTitle('Experience', sans, p),
                ...data.experiences.take(5).map((e) => _experience(e, sans, p)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if (data.projects.isNotEmpty) ...[
          _cardTitle('Projects', sans, p),
          ...data.projects.take(4).map((pr) => _projectCard(pr, sans, p)),
        ],
      ],
    );
  }

  pw.Widget _rightColumn(TemplateContext ctx, LoadedFamily sans) {
    final data = ctx.data;
    final p = ctx.palette;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (data.skills.isNotEmpty) ...[
          _shell(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _cardTitle('Skills', sans, p),
                pw.Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: data.skills
                      .take(16)
                      .map((s) => _chip(s, sans, p))
                      .toList(),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if (data.education.isNotEmpty) ...[
          _shell(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _cardTitle('Education', sans, p),
                ...data.education.take(4).map((e) => _education(e, sans, p)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        ...data.customSections
            .take(3)
            .map(
              (section) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: _shell(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _cardTitle(
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
                                      lineSpacing: 1.45,
                                    ),
                                  ),
                                  if (item.subtitle.trim().isNotEmpty)
                                    clampedText(
                                      item.subtitle,
                                      style: pw.TextStyle(
                                        font: sans.regular,
                                        fontSize: 8.4,
                                        color: p.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  /// The one card chrome every block shares.
  pw.Widget _shell({required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: _card,
        borderRadius: pw.BorderRadius.circular(_cardRadius),
        border: pw.Border.all(color: _cardBorder, width: 0.8),
      ),
      child: child,
    );
  }

  pw.Widget _cardTitle(String label, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 12,
            height: 2.5,
            decoration: pw.BoxDecoration(
              color: p.secondary,
              borderRadius: pw.BorderRadius.circular(1.25),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: clampedText(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: sans.bold,
                fontSize: 9.2,
                color: p.ink,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Skill chip. Level 4+ gets the saturated treatment so the strongest skills
  /// are legible at a glance without a meter taking up rail width.
  pw.Widget _chip(Skill s, LoadedFamily sans, TemplatePalette p) {
    if (s.name.trim().isEmpty) return pw.SizedBox();
    final strong = s.level >= 4;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: strong ? strongChipFill : p.accent,
        borderRadius: pillRadius(17),
        border: pw.Border.all(
          color: strong ? strongChipFill : _cardBorder,
          width: 0.8,
        ),
      ),
      // Skills rule item 3. The Wrap bounds this to the card, so a long name is
      // marked with `…` instead of stretching the chip and stopping mid-phrase.
      child: markedText(
        s.name,
        style: pw.TextStyle(
          font: sans.semiBold,
          fontSize: 8.2,
          color: strong ? p.onPrimary : p.ink,
        ),
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
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
                    fontSize: 10.8,
                    color: p.ink,
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
                    fontSize: 8,
                    color: p.muted,
                  ),
                ),
              ],
            ],
          ),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9.2,
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
                fontSize: 9.1,
                color: p.muted,
                lineSpacing: 1.85,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _projectCard(Project pr, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: _shell(
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
                font: sans.regular,
                fontSize: 7.8,
                color: p.secondary,
              ),
              gap: 8,
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
              pw.SizedBox(height: 5),
              pw.Wrap(
                spacing: 4,
                runSpacing: 3,
                children: pr.technologies
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .take(8)
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
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                          style: pw.TextStyle(
                            font: sans.regular,
                            fontSize: 7.6,
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

  pw.Widget _education(Education e, LoadedFamily sans, TemplatePalette p) {
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
              font: sans.semiBold,
              fontSize: 9.2,
              color: p.ink,
              lineSpacing: 1.4,
            ),
          ),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.7,
              color: p.muted,
              lineSpacing: 1.4,
            ),
          ),
          if (range.isNotEmpty)
            clampedText(
              range,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 8,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }
}
