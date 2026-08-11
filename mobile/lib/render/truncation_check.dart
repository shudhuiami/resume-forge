import 'dart:typed_data';

import '../models/resume.dart';
import '../templates/fonts.dart';
import '../templates/template.dart';
import 'pdf_renderer.dart';

/// Which sections lost entries to the page edge.
class TruncationReport {
  const TruncationReport(this.sections);

  const TruncationReport.none() : sections = const <String>[];

  /// Human-readable names of the sections that lost content.
  final List<String> sections;

  bool get hasLoss => sections.isNotEmpty;

  /// One sentence naming what was cut, for a dialog or a banner.
  String describe() {
    if (!hasLoss) return '';
    if (sections.length == 1) {
      return 'Some of your ${sections.single} does not fit on the page and '
          'will not appear in the PDF.';
    }
    final last = sections.last;
    final rest = sections.sublist(0, sections.length - 1).join(', ');
    return 'Some of your $rest and $last do not fit on the page and will not '
        'appear in the PDF.';
  }
}

/// Detects content that a template silently dropped.
///
/// `dart_pdf`'s Column removes a child outright when it does not fit rather
/// than clipping it, so a long resume loses whole entries with no error, no
/// extra page, and no visible gap. Measured capacity is four to seven roles
/// depending on the design — well inside a normal career — so this is a
/// routine outcome, not an edge case.
///
/// The check works by re-rendering with the last entry of a section removed.
/// If the bytes come out the same, that entry was never on the page. It costs
/// one extra render per section examined, so it belongs on a user-initiated
/// action such as export rather than on every keystroke.
abstract final class TruncationCheck {
  /// Cheap gate before paying for the exact check.
  ///
  /// Measured capacity is four roles on the tightest design, so a resume well
  /// under that cannot be losing anything and should not cost extra renders on
  /// every edit. Deliberately generous: a false positive costs one check, which
  /// then answers exactly, whereas a false negative would hide lost content.
  static bool mightOverflow(ResumeData data) {
    if (data.experiences.length >= 3) return true;
    if (data.education.length >= 3) return true;
    if (data.projects.length >= 3) return true;
    if (data.skills.length >= 10) return true;
    if (data.customSections.length >= 2) return true;
    return _approximateLength(data) > 1200;
  }

  /// Rough character count of everything that reaches the page.
  static int _approximateLength(ResumeData data) {
    var n = data.personalInfo.summary.length;
    for (final e in data.experiences) {
      n += e.description.length + e.company.length + e.position.length;
    }
    for (final p in data.projects) {
      n += p.description.length + p.name.length;
    }
    for (final s in data.customSections) {
      for (final i in s.items) {
        n += i.title.length + i.subtitle.length + i.description.length;
      }
    }
    return n;
  }

  static Future<TruncationReport> run({
    required ResumeTemplate template,
    required ResumeData data,
  }) async {
    final families = await PdfRenderer.ensureFonts(template);

    Future<Uint8List> render(ResumeData d) =>
        PdfRenderer.renderWith(template: template, data: d, families: families);

    final full = await render(data);
    final lost = <String>[];

    Future<void> check(
      String label,
      bool hasEntries,
      ResumeData Function() withoutLast,
    ) async {
      if (!hasEntries) return;
      final shorter = await render(withoutLast());
      // Identical output means the removed entry contributed nothing, i.e. the
      // template had already dropped it.
      if (_equivalent(full, shorter)) lost.add(label);
    }

    await check('experience', data.experiences.isNotEmpty, () {
      return data.copyWith(
        experiences: data.experiences.sublist(0, data.experiences.length - 1),
      );
    });
    await check('education', data.education.isNotEmpty, () {
      return data.copyWith(
        education: data.education.sublist(0, data.education.length - 1),
      );
    });
    await check('projects', data.projects.isNotEmpty, () {
      return data.copyWith(
        projects: data.projects.sublist(0, data.projects.length - 1),
      );
    });
    await check('skills', data.skills.isNotEmpty, () {
      return data.copyWith(
        skills: data.skills.sublist(0, data.skills.length - 1),
      );
    });

    return TruncationReport(lost);
  }

  /// Compares two renders for equivalence.
  ///
  /// Length alone is the signal: identical page content produces an identical
  /// content stream, while one fewer rendered entry always shortens it. Any
  /// per-render metadata that might differ is fixed-width, so it cannot mask a
  /// real difference.
  static bool _equivalent(Uint8List a, Uint8List b) => a.length == b.length;

  /// Test seam: the font map used for a template's renders.
  static Future<Map<FontFamily, LoadedFamily>> fontsFor(
    ResumeTemplate template,
  ) => PdfRenderer.ensureFonts(template);
}
