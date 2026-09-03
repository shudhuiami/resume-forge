import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/resume.dart';
import '../fonts.dart';
import '../template.dart';

/// Maximum restraint: no colour fields, no rules except one, no photograph.
///
/// Restraint is only convincing if something still holds the page together, so
/// the composition does the work that decoration usually would. Every line sits
/// on one of two vertical axes — a narrow label rail and a wide content
/// measure — the name is the single large element, one hairline separates the
/// masthead from the body, and the contact details are pinned to the foot so
/// the page is anchored top and bottom rather than trailing off.
///
/// Only two ink values are used: near-black for anything a reader must read,
/// grey for labels and metadata. Body copy never drops to the grey — at 8pt on
/// white it would fall under 3:1 and the restraint would read as a printing
/// fault.
class LinenTemplate extends ResumeTemplate {
  const LinenTemplate();

  @override
  String get id => 'linen';

  @override
  String get name => 'Linen Minimal';

  @override
  String get description =>
      'Editorial minimalism: a large light-weight name, a single hairline, and '
      'a label rail holding everything to two axes.';

  @override
  String get bestFor => 'Architecture, Art direction, Senior IC';

  @override
  TemplateCategory get category => TemplateCategory.minimal;

  @override
  Set<FontFamily> get requiredFonts => {FontFamily.sans};

  @override
  TemplatePalette get palette => const TemplatePalette(
    primary: PdfColor.fromInt(0xFF111827),
    secondary: PdfColor.fromInt(0xFF9CA3AF),
    accent: PdfColor.fromInt(0xFFFFFFFF),
    ink: PdfColor.fromInt(0xFF111827),
    muted: PdfColor.fromInt(0xFF9CA3AF),
  );

  static const _padX = 62.0;
  static const _padTop = 74.0;
  static const _railW = 88.0;
  static const _railGap = 20.0;

  /// Band kept clear at the foot of the page for the pinned contact block.
  static const _footerReserve = 92.0;
  static final _contentW = a4.width - _padX * 2;

  static const _maxExperience = 4;
  static const _maxProjects = 3;
  static const _maxEducation = 2;
  static const _maxSkills = 10;
  static const _maxCustomSections = 2;
  static const _maxCustomItems = 3;

  @override
  pw.Widget build(TemplateContext ctx) {
    final sans = ctx.family(FontFamily.sans);
    final data = ctx.data;
    final p = ctx.palette;

    final summary = data.personalInfo.summary.trim();
    final experiences = data.experiences.take(_maxExperience).toList();
    final projects = data.projects.take(_maxProjects).toList();
    final education = data.education.take(_maxEducation).toList();
    // Not capped here: [skillRun] applies _maxSkills itself, so the names the
    // cap removes are still counted in its `+N more` marker.
    final skills = data.skills.map((s) => s.name).toList();
    final customSections = data.customSections
        .take(_maxCustomSections)
        .toList();

    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Container(
        color: p.paper,
        // Stack, not a Column with a Spacer: the footer rule must hold the
        // bottom margin even if the body runs long, and a flexible gap would
        // collapse the moment free space went negative.
        child: pw.Stack(
          children: [
            // Capped short of the page foot so the body cannot run into the
            // pinned contact block. Inside that cap a dart_pdf Column simply
            // drops the children that no longer fit, which trims a trailing
            // section rather than overprinting the footer.
            pw.SizedBox(
              width: a4.width,
              height: a4.height - _footerReserve,
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(_padX, _padTop, _padX, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _masthead(ctx, sans),
                    pw.SizedBox(height: 26),
                    // The one hairline in the design.
                    pw.Container(width: _contentW, height: 0.6, color: p.ink),
                    pw.SizedBox(height: 26),
                    if (summary.isNotEmpty)
                      _entry(
                        'Profile',
                        sans,
                        p,
                        clampedText(
                          summary,
                          maxLines: 5,
                          style: pw.TextStyle(
                            font: sans.regular,
                            fontSize: 8.6,
                            color: p.ink,
                            lineSpacing: 3.4,
                          ),
                        ),
                      ),
                    // Skills rule item 1. These four blocks are the ones that
                    // grow with the resume, and Skills sat below them as the
                    // last plain child of a box capped short of the footer — so
                    // a fourth role was enough for dart_pdf to stop laying out
                    // before it and delete the section outright, while the page
                    // still showed white space above the pinned contact block.
                    // A loose Flexible is measured after Skills and takes only
                    // what is left, so it gives up an entry instead.
                    if (experiences.isNotEmpty ||
                        projects.isNotEmpty ||
                        education.isNotEmpty ||
                        customSections.isNotEmpty)
                      pw.Flexible(
                        fit: pw.FlexFit.loose,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          // Without this the inner Column takes
                          // MainAxisSize.max, sizes itself to the whole
                          // leftover budget rather than to its content, and
                          // drives Skills down onto the footer reserve.
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            if (experiences.isNotEmpty)
                              _entry(
                                'Experience',
                                sans,
                                p,
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: experiences
                                      .map((e) => _experience(e, sans, p))
                                      .toList(),
                                ),
                              ),
                            if (projects.isNotEmpty)
                              _entry(
                                'Selected work',
                                sans,
                                p,
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: projects
                                      .map((pr) => _project(pr, sans, p))
                                      .toList(),
                                ),
                              ),
                            if (education.isNotEmpty)
                              _entry(
                                'Education',
                                sans,
                                p,
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: education
                                      .map((e) => _education(e, sans, p))
                                      .toList(),
                                ),
                              ),
                            for (final section in customSections)
                              _entry(
                                section.sectionTitle.isEmpty
                                    ? 'Also'
                                    : section.sectionTitle,
                                sans,
                                p,
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: section.items
                                      .take(_maxCustomItems)
                                      .map((i) => _customItem(i, sans, p))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (skills.isNotEmpty)
                      _entry(
                        'Skills',
                        sans,
                        p,
                        // Skills rule item 4: names the three-line budget
                        // cannot hold are counted, not swallowed.
                        skillRun(
                          skills,
                          maxLines: 3,
                          maxNames: _maxSkills,
                          separator: '   ·   ',
                          style: pw.TextStyle(
                            font: sans.regular,
                            fontSize: 8.6,
                            color: p.ink,
                            lineSpacing: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            pw.Positioned(left: _padX, bottom: 46, child: _footer(ctx, sans)),
          ],
        ),
      ),
    );
  }

  pw.Widget _masthead(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;

    return pw.SizedBox(
      width: _contentW,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Inter ships no Light weight here, so the airy look comes from size
          // plus positive tracking rather than a thinner face.
          clampedText(
            info.fullName.isEmpty ? 'Your Name' : info.fullName,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 33,
              color: p.ink,
              letterSpacing: 0.4,
            ),
          ),
          if (info.title.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            clampedText(
              info.title.toUpperCase(),
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 8,
                color: p.muted,
                letterSpacing: 2.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One label-rail row: tiny grey label left, content on the wide measure.
  pw.Widget _entry(
    String label,
    LoadedFamily sans,
    TemplatePalette p,
    pw.Widget child,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 24),
      child: pw.SizedBox(
        width: _contentW,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: _railW,
              child: clampedText(
                label.toUpperCase(),
                maxLines: 2,
                style: pw.TextStyle(
                  font: sans.regular,
                  fontSize: 7,
                  color: p.muted,
                  letterSpacing: 1.6,
                  lineSpacing: 2,
                ),
              ),
            ),
            pw.SizedBox(width: _railGap),
            pw.Expanded(child: child),
          ],
        ),
      ),
    );
  }

  pw.Widget _experience(Experience e, LoadedFamily sans, TemplatePalette p) {
    final range = formatRange(e.startDate, e.endDate, current: e.current);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 13),
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
                    font: sans.semiBold,
                    fontSize: 9.4,
                    color: p.ink,
                  ),
                ),
              ),
              if (range.isNotEmpty) ...[
                pw.SizedBox(width: 10),
                clampedText(
                  range,
                  style: pw.TextStyle(
                    font: sans.regular,
                    fontSize: 7.6,
                    color: p.muted,
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 1),
          clampedText(
            e.company,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.6,
              color: p.ink,
            ),
          ),
          if (e.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            clampedText(
              e.description,
              maxLines: 3,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 8.2,
                color: p.ink,
                lineSpacing: 3.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _project(Project pr, LoadedFamily sans, TemplatePalette p) {
    // The link is no longer folded into this run: joined behind the technology
    // list it was the part that ran off the end of the single line and was cut
    // mid-token (URL rule, item 6). It gets its own line below.
    final meta = pr.technologies
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(5)
        .join(', ');

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 11),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // The link rides on the title line rather than taking one of its
          // own: this design pins a contact block to the page foot and the
          // body has to stay clear of it.
          titleWithUrl(
            title: pr.name,
            titleStyle: pw.TextStyle(
              font: sans.semiBold,
              fontSize: 9,
              color: p.ink,
            ),
            url: pr.link,
            urlStyle: pw.TextStyle(
              font: sans.regular,
              fontSize: 7.6,
              color: p.muted,
            ),
            crossAxisAlignment: pw.CrossAxisAlignment.center,
          ),
          if (pr.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              pr.description,
              maxLines: 2,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 8.2,
                color: p.ink,
                lineSpacing: 3,
              ),
            ),
          ],
          if (meta.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            clampedText(
              meta,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 7.6,
                color: p.muted,
              ),
            ),
          ],
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
      padding: const pw.EdgeInsets.only(bottom: 9),
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
                    font: sans.semiBold,
                    fontSize: 9,
                    color: p.ink,
                    lineSpacing: 2,
                  ),
                ),
                clampedText(
                  e.institution,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: sans.regular,
                    fontSize: 8.4,
                    color: p.ink,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          if (range.isNotEmpty) ...[
            pw.SizedBox(width: 10),
            clampedText(
              range,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 7.6,
                color: p.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _customItem(CustomItem item, LoadedFamily sans, TemplatePalette p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          clampedText(
            item.title,
            maxLines: 2,
            style: pw.TextStyle(
              font: sans.regular,
              fontSize: 8.6,
              color: p.ink,
              lineSpacing: 2.6,
            ),
          ),
          if (item.subtitle.trim().isNotEmpty)
            clampedText(
              item.subtitle,
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 7.6,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }

  /// Contact pinned to the foot, on the same two axes as everything above.
  pw.Widget _footer(TemplateContext ctx, LoadedFamily sans) {
    final p = ctx.palette;
    final info = ctx.data.personalInfo;

    final contact = <(String, ContactKind)>[
      (info.email, ContactKind.email),
      (info.phone, ContactKind.phone),
      (info.location, ContactKind.plain),
    ].where((e) => e.$1.trim().isNotEmpty).toList();
    final links = <String>[
      info.linkedin,
      info.website,
    ].where((e) => e.trim().isNotEmpty).toList();

    if (contact.isEmpty && links.isEmpty) return pw.SizedBox();

    final itemStyle = pw.TextStyle(
      font: sans.regular,
      fontSize: 8,
      color: p.ink,
    );

    return pw.SizedBox(
      width: _contentW,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: _railW,
            child: clampedText(
              'CONTACT',
              style: pw.TextStyle(
                font: sans.regular,
                fontSize: 7,
                color: p.muted,
                letterSpacing: 1.6,
              ),
            ),
          ),
          pw.SizedBox(width: _railGap),
          pw.Expanded(
            child: pw.Wrap(
              spacing: 16,
              runSpacing: 5,
              children: [
                for (final (value, kind) in contact)
                  contactLink(
                    value,
                    kind,
                    child: pw.Text(value, maxLines: 1, style: itemStyle),
                  ),
                // A Wrap child is bounded by the strip, so the URL rule sizes
                // each link against that rather than being cut mid-token by the
                // one-line clamp.
                for (final line in links) urlText(line, style: itemStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
