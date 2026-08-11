import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// A deliberately dark, terminal-emulator resume for engineers.
///
/// The inversion is the design, not an accident: the page carries a window
/// chrome bar, shell-prompt section headers (`~/experience`), a blinking-cursor
/// footer, and phosphor-green monospace headings. Body copy stays in the sans
/// family at a near-white tint — a full page of monospace prose is legible but
/// reads as a code listing rather than a resume, and the contrast between the
/// two families is what makes the terminal framing feel intentional.
///
/// Contrast is checked against the near-black page rather than assumed: the
/// green (#4ADE80) and the body tint (#D3E0D8) both clear 7:1 on #0B0F0C, and
/// the dimmest text used anywhere (#7E8F86, for de-emphasised metadata) still
/// clears 4.5:1.
class TerminalTemplate extends ResumeTemplate {
  const TerminalTemplate();

  @override
  String get id => 'terminal';

  @override
  String get name => 'Terminal Green';

  @override
  String get description =>
      'Dark terminal emulator with phosphor-green monospace headings and '
      'shell-prompt section markers.';

  @override
  String get bestFor => 'Backend, DevOps, Security';

  @override
  TemplateCategory get category => TemplateCategory.tech;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.mono, FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF4ADE80),
    secondary: PdfColor.fromInt(0xFF22D3EE),
    accent: PdfColor.fromInt(0xFF0B0F0C),
    paper: PdfColor.fromInt(0xFF0B0F0C),
    ink: PdfColor.fromInt(0xFFD3E0D8),
    muted: PdfColor.fromInt(0xFF7E8F86),
    onPrimary: PdfColor.fromInt(0xFF0B0F0C),
  );

  static const _pad = 46.0;
  static const _chromeHeight = 20.0;

  /// Band at the foot of the page kept clear for the shell prompt.
  static const _footerReserve = 44.0;
  static final _contentW = a4.width - _pad * 2;

  /// One shade up from the page, for panels that need to read as a surface
  /// without introducing a second hue.
  static const _panel = PdfColor.fromInt(0xFF121A15);
  static const _rule = PdfColor.fromInt(0xFF20362A);

  // Bounds on repeated content. Long input clips at the page edge rather than
  // paginating, so each list is capped at what the vertical budget can show.
  static const _maxExperience = 4;
  static const _maxProjects = 3;
  static const _maxSkills = 14;
  static const _maxEducation = 2;
  static const _maxCustomSections = 2;
  static const _maxCustomItems = 3;

  @override
  pw.Widget build(TemplateContext ctx) {
    final mono = ctx.family(FontFamily.mono);
    final sans = ctx.family(FontFamily.sans);
    final p = ctx.palette;

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        // A Stack rather than a Column with a Spacer: the footer must sit on
        // the page edge even when the body overflows, and a flexible gap goes
        // degenerate once free space turns negative.
        child: pw.Stack(
          children: [
            // Height is capped short of the page so the body can never reach
            // the footer, and the body sits in an Expanded rather than sizing
            // itself: a dart_pdf Column drops any child whose height exceeds
            // the remaining space *entirely*, so an unbounded inner Column of
            // overlong content erases the whole resume instead of trimming its
            // last section. Bounding it makes the overflow trim one entry at a
            // time.
            pw.SizedBox(
              width: a4.width,
              height: a4.height - _footerReserve,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _chrome(ctx, mono),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(_pad, 28, _pad, 0),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: _body(ctx, mono, sans),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Positioned(left: _pad, bottom: 20, child: _cursorLine(mono, p)),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> _body(
    TemplateContext ctx,
    LoadedFamily mono,
    LoadedFamily sans,
  ) {
    final data = ctx.data;
    final p = ctx.palette;
    final info = data.personalInfo;

    final experiences = data.experiences.take(_maxExperience).toList();
    final projects = data.projects.take(_maxProjects).toList();
    final skills = data.skills.take(_maxSkills).toList();
    final education = data.education.take(_maxEducation).toList();
    final customSections = data.customSections
        .take(_maxCustomSections)
        .toList();

    return [
      _identity(ctx, mono, sans),
      if (info.summary.trim().isNotEmpty) ...[
        pw.SizedBox(height: 18),
        _summary(info.summary, sans, p),
      ],
      if (experiences.isNotEmpty) ...[
        pw.SizedBox(height: 22),
        _sectionHeader('experience', mono, p),
        ...experiences.map((e) => _experience(e, mono, sans, p)),
      ],
      if (projects.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        _sectionHeader('projects', mono, p),
        ...projects.map((pr) => _project(pr, mono, sans, p)),
      ],
      if (skills.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        _sectionHeader('skills', mono, p),
        pw.SizedBox(width: _contentW, child: _skillCloud(skills, mono, p)),
      ],
      if (education.isNotEmpty || customSections.isNotEmpty) ...[
        pw.SizedBox(height: 22),
        pw.SizedBox(
          width: _contentW,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (education.isNotEmpty) ...[
                      _sectionHeader('education', mono, p),
                      ...education.map((e) => _education(e, mono, sans, p)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 22),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final section in customSections) ...[
                      _sectionHeader(
                        section.sectionTitle.isEmpty
                            ? 'notes'
                            : section.sectionTitle.toLowerCase(),
                        mono,
                        p,
                      ),
                      ...section.items
                          .take(_maxCustomItems)
                          .map((i) => _customItem(i, mono, sans, p)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  /// Window chrome. Sells the terminal framing in 20 points of height.
  pw.Widget _chrome(TemplateContext ctx, LoadedFamily mono) {
    final p = ctx.palette;
    final name = ctx.data.personalInfo.fullName.trim();
    final slug = name.isEmpty
        ? 'resume'
        : name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    pw.Widget dot(PdfColor color) => pw.Container(
      width: 5.5,
      height: 5.5,
      decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: color),
    );

    return pw.Container(
      width: a4.width,
      height: _chromeHeight,
      color: _panel,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          dot(const PdfColor.fromInt(0xFFF87171)),
          pw.SizedBox(width: 4),
          dot(const PdfColor.fromInt(0xFFFBBF24)),
          pw.SizedBox(width: 4),
          dot(p.primary),
          pw.Expanded(
            child: pw.Text(
              '$slug — bash — 80×24',
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 6.8,
                color: p.muted,
              ),
            ),
          ),
          // Balances the three dots so the title sits optically centred.
          pw.SizedBox(width: 34),
        ],
      ),
    );
  }

  pw.Widget _identity(
    TemplateContext ctx,
    LoadedFamily mono,
    LoadedFamily sans,
  ) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;

    final contact = <String>[
      info.email,
      info.phone,
      info.location,
      info.linkedin,
      info.website,
    ].where((e) => e.trim().isNotEmpty).take(5).toList();

    return pw.SizedBox(
      width: _contentW,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              clampedText(
                r'$ ',
                style: pw.TextStyle(
                  font: mono.bold,
                  fontSize: 9,
                  color: p.secondary,
                ),
              ),
              clampedText(
                'whoami',
                style: pw.TextStyle(
                  font: mono.regular,
                  fontSize: 9,
                  color: p.muted,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          clampedText(
            info.fullName.isEmpty ? 'your_name' : info.fullName,
            style: pw.TextStyle(
              font: mono.bold,
              fontSize: 26,
              color: p.primary,
              letterSpacing: -0.6,
            ),
          ),
          if (info.title.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            clampedText(
              '// ${info.title}',
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 11.5,
                color: p.secondary,
              ),
            ),
          ],
          if (contact.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final line in contact)
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      clampedText(
                        '· ',
                        style: pw.TextStyle(
                          font: mono.bold,
                          fontSize: 7.6,
                          color: p.primary,
                        ),
                      ),
                      clampedText(
                        line,
                        style: pw.TextStyle(
                          font: mono.regular,
                          fontSize: 7.6,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Summary as a quoted comment block, flagged by a green gutter rule.
  pw.Widget _summary(String text, LoadedFamily sans, TemplatePalette p) {
    return pw.Container(
      width: _contentW,
      padding: const pw.EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: pw.BoxDecoration(
        color: _panel,
        border: const pw.Border(
          left: pw.BorderSide(color: PdfColor.fromInt(0xFF4ADE80), width: 2.2),
        ),
      ),
      child: clampedText(
        text,
        maxLines: 4,
        style: pw.TextStyle(
          font: sans.regular,
          fontSize: 9.4,
          color: p.ink,
          lineSpacing: 3.4,
        ),
      ),
    );
  }

  /// `~/section` prompt with a rule running out to the right margin.
  pw.Widget _sectionHeader(String label, LoadedFamily mono, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          clampedText(
            '~/',
            style: pw.TextStyle(
              font: mono.regular,
              fontSize: 10,
              color: p.muted,
            ),
          ),
          clampedText(
            label,
            style: pw.TextStyle(
              font: mono.bold,
              fontSize: 10,
              color: p.primary,
              letterSpacing: 0.2,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(height: 0.7, color: _rule)),
        ],
      ),
    );
  }

  pw.Widget _experience(
    Experience e,
    LoadedFamily mono,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
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
                    fontSize: 11.2,
                    color: p.ink,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 10),
                clampedText(
                  range,
                  style: pw.TextStyle(
                    font: mono.regular,
                    fontSize: 8,
                    color: p.secondary,
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 2),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: mono.regular,
              fontSize: 9.2,
              color: p.primary,
            ),
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
                lineSpacing: 3.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _project(
    Project pr,
    LoadedFamily mono,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    final tech = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(6)
        .join(' · ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              clampedText(
                '> ',
                style: pw.TextStyle(
                  font: mono.bold,
                  fontSize: 9.4,
                  color: p.primary,
                ),
              ),
              pw.Expanded(
                child: clampedText(
                  pr.name,
                  style: pw.TextStyle(
                    font: sans.bold,
                    fontSize: 10.2,
                    color: p.ink,
                  ),
                ),
              ),
              if (pr.link.trim().isNotEmpty) ...[
                pw.SizedBox(width: 10),
                clampedText(
                  pr.link,
                  style: pw.TextStyle(
                    font: mono.regular,
                    fontSize: 7.6,
                    color: p.secondary,
                  ),
                ),
              ],
            ],
          ),
          if (pr.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12),
              child: clampedText(
                pr.description,
                maxLines: 2,
                style: pw.TextStyle(
                  font: sans.regular,
                  fontSize: 9,
                  color: p.muted,
                  lineSpacing: 3,
                ),
              ),
            ),
          ],
          if (tech.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12),
              child: clampedText(
                tech,
                style: pw.TextStyle(
                  font: mono.regular,
                  fontSize: 7.6,
                  color: p.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Skills as shell-style bracketed tokens.
  pw.Widget _skillCloud(
    List<Skill> skills,
    LoadedFamily mono,
    TemplatePalette p,
  ) {
    return pw.Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final s in skills)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4.5,
            ),
            decoration: pw.BoxDecoration(
              color: _panel,
              border: pw.Border.all(color: _rule, width: 0.7),
            ),
            child: pw.Text(
              s.name.toLowerCase(),
              maxLines: 1,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 8.2,
                color: s.level >= 4 ? p.primary : p.ink,
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _education(
    Education e,
    LoadedFamily mono,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    final degree = [
      e.degree,
      e.field,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final range = formatRange(e.startDate, e.endDate);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            degree,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 9.6,
              color: p.ink,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 1),
          clampedText(
            e.institution,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 9,
              color: p.muted,
              lineSpacing: 2,
            ),
          ),
          if (range.isNotEmpty)
            clampedText(
              range,
              style: pw.TextStyle(
                font: mono.regular,
                fontSize: 7.6,
                color: p.secondary,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _customItem(
    CustomItem item,
    LoadedFamily mono,
    LoadedFamily sans,
    TemplatePalette p,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            item.title,
            maxLines: 3,
            style: pw.TextStyle(
              font: sans.bold,
              fontSize: 9.4,
              color: p.ink,
              lineSpacing: 2.2,
            ),
          ),
          if (item.subtitle.trim().isNotEmpty)
            clampedText(
              item.subtitle,
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

  /// Footer prompt with a solid block cursor — the detail that reads as
  /// "terminal" rather than "dark theme".
  pw.Widget _cursorLine(LoadedFamily mono, TemplatePalette p) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        clampedText(
          r'$ ',
          style: pw.TextStyle(font: mono.bold, fontSize: 9, color: p.secondary),
        ),
        clampedText(
          'exit',
          style: pw.TextStyle(font: mono.regular, fontSize: 9, color: p.muted),
        ),
        pw.SizedBox(width: 4),
        pw.Container(width: 5.5, height: 9.5, color: p.primary),
      ],
    );
  }
}
