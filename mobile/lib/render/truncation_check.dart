import 'dart:convert';
import 'dart:typed_data';

import '../models/resume.dart';
import '../templates/fonts.dart';
import '../templates/template.dart';
import 'pdf_renderer.dart';

/// Which sections lost entries to the page edge.
class TruncationReport {
  const TruncationReport(this.sections, {this.emptied = const <String>[]});

  const TruncationReport.none()
    : sections = const <String>[],
      emptied = const <String>[];

  /// Human-readable names of the sections that lost content.
  ///
  /// A custom section is named by the title the user typed for it, so the
  /// warning says "Certifications" rather than "custom sections".
  final List<String> sections;

  /// The subset of [sections] where *nothing* reached the page.
  ///
  /// Kept apart because the two are different messages to the user: losing the
  /// tail of a list is a trim, losing all of it is a section that is simply
  /// absent from the resume they are about to send.
  final List<String> emptied;

  bool get hasLoss => sections.isNotEmpty;

  /// One sentence naming what was cut, for a dialog or a banner.
  String describe() {
    if (!hasLoss) return '';
    final gone = sections.where(emptied.contains).toList();
    final partial = sections.where((s) => !emptied.contains(s)).toList();

    if (gone.isEmpty) {
      return 'Some of your ${_join(partial)} '
          '${partial.length == 1 ? 'does' : 'do'} not fit on the page and '
          'will not appear in the PDF.';
    }
    if (partial.isEmpty) {
      return 'None of your ${_join(gone)} will fit on the page, so '
          '${gone.length == 1 ? 'it' : 'they'} will not appear in the PDF '
          'at all.';
    }
    return 'None of your ${_join(gone)} will fit on the page, and some of '
        'your ${_join(partial)} ${partial.length == 1 ? 'does' : 'do'} not '
        'fit either. That content will not appear in the PDF.';
  }

  static String _join(List<String> names) {
    if (names.length == 1) return names.single;
    final rest = names.sublist(0, names.length - 1).join(', ');
    return '$rest and ${names.last}';
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
/// ## How a section is tested
///
/// Each section is probed by re-rendering with the **text of its last entry
/// replaced by a shadow**: the same characters rotated (rot-13 for letters,
/// +5 for digits), so the string keeps its length, its spaces, and its
/// punctuation, and only the glyphs change. If the document comes out
/// byte-identical, none of those glyphs were painted — the entry is not on the
/// page. `dart_pdf` never registers a glyph it did not paint, which is what
/// makes the comparison exact rather than approximate.
///
/// Two earlier designs of this check were weaker, and both are worth naming so
/// they are not reintroduced:
///
/// * **Removing the last entry instead of shadowing it.** Removal frees the
///   space that entry wanted, so the rest of the section can reflow into it and
///   the bytes change — even when the removed entry was never drawn. That is
///   not theoretical: measured against the catalog, a resume with 24 long
///   skills had Quill dropping both its skills *and* its projects while the
///   removal probe reported no loss at all, because deleting one skill was
///   enough for the rest to fit. Shadowing changes nothing about the layout, so
///   the only thing it can change is the ink.
/// * **Comparing byte *lengths*.** A shadow is the same length as what it
///   replaces, so length comparison is blind to it; and even for removal two
///   different pages routinely come out the same size. Whole documents are
///   compared, with `/CreationDate` and the `/ID` derived from it masked —
///   those are the only two fields that differ between two renders of
///   identical content, verified across the whole catalog.
///
/// Shadowing the **last** entry is what catches both failures a section can
/// have: if the tail was evicted the last entry is gone, and if the whole
/// section was evicted the last entry is gone too. When a section is flagged,
/// one extra render tells the two apart by probing its *first* entry, so the
/// warning can say "none of it fits" rather than "some of it".
///
/// It costs one render per populated section, so it belongs on a user-initiated
/// action such as export, or behind a debounce — never on every keystroke.
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
    // A single custom section is enough to overflow a design if the user put
    // half a career in it — "Publications" with six entries is one section by
    // the count above and four more entries than any design reserves room for.
    var customItems = 0;
    for (final s in data.customSections) {
      customItems += s.items.length;
    }
    if (customItems >= 3) return true;
    return _approximateLength(data) > 1800;
  }

  /// Rough character count of everything that reaches the page.
  ///
  /// Every string the model can hold is counted. An earlier version counted the
  /// summary, experience, projects and custom items only, which left education,
  /// skill names, dates, and the whole contact block invisible to the gate: two
  /// degrees with long institution names and nine skills are under every count
  /// threshold above and contributed nothing here, so a resume that was
  /// genuinely at risk could be waved through unchecked.
  static int _approximateLength(ResumeData data) {
    final info = data.personalInfo;
    var n =
        info.fullName.length +
        info.title.length +
        info.email.length +
        info.phone.length +
        info.location.length +
        info.summary.length +
        info.linkedin.length +
        info.website.length;
    for (final e in data.experiences) {
      n +=
          e.company.length +
          e.position.length +
          e.startDate.length +
          e.endDate.length +
          e.description.length;
    }
    for (final e in data.education) {
      n +=
          e.institution.length +
          e.degree.length +
          e.field.length +
          e.startDate.length +
          e.endDate.length +
          e.gpa.length;
    }
    for (final s in data.skills) {
      n += s.name.length;
    }
    for (final p in data.projects) {
      n +=
          p.name.length +
          p.description.length +
          p.link.length +
          p.technologies.length;
    }
    for (final s in data.customSections) {
      n += s.sectionTitle.length;
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

    Future<String> render(ResumeData d) async => _canonical(
      await PdfRenderer.renderWith(
        template: template,
        data: d,
        families: families,
      ),
    );

    final full = await render(data);
    final lost = <String>[];
    final emptied = <String>[];

    /// [shadowEntry] returns [data] with entry [i] of this section shadowed, or
    /// null when that entry holds no text a shadow could change — an entry with
    /// nothing in it cannot be lost.
    Future<void> check(
      String label,
      int count,
      ResumeData? Function(int i) shadowEntry,
    ) async {
      if (count == 0 || lost.contains(label)) return;

      // The last entry that has any text in it, not simply the last entry. The
      // editor adds a new row the moment you tap "add", so a half-filled resume
      // routinely ends in a blank one — and a blank entry shadows to itself, so
      // taking it at face value would switch the whole section's check off.
      ResumeData? last;
      var lastIndex = -1;
      for (var i = count - 1; i >= 0; i--) {
        last = shadowEntry(i);
        if (last != null) {
          lastIndex = i;
          break;
        }
      }
      if (last == null || await render(last) != full) return;
      lost.add(label);

      // The last entry is missing. One more render says whether anything from
      // this section survived at all, which is the difference between "some of
      // your skills does not fit" and a section that is simply not there.
      ResumeData? first;
      for (var i = 0; i < lastIndex; i++) {
        first = shadowEntry(i);
        if (first != null) break;
      }
      if (first == null || await render(first) == full) emptied.add(label);
    }

    await check('experience', data.experiences.length, (i) {
      final shadowed = _shadowExperience(data.experiences[i]);
      if (shadowed == data.experiences[i]) return null;
      return data.copyWith(
        experiences: _replace(data.experiences, i, shadowed),
      );
    });
    await check('education', data.education.length, (i) {
      final shadowed = _shadowEducation(data.education[i]);
      if (shadowed == data.education[i]) return null;
      return data.copyWith(education: _replace(data.education, i, shadowed));
    });
    await check('projects', data.projects.length, (i) {
      final shadowed = _shadowProject(data.projects[i]);
      if (shadowed == data.projects[i]) return null;
      return data.copyWith(projects: _replace(data.projects, i, shadowed));
    });
    await check('skills', data.skills.length, (i) {
      final shadowed = data.skills[i].copyWith(
        name: _shadow(data.skills[i].name),
      );
      if (shadowed == data.skills[i]) return null;
      return data.copyWith(skills: _replace(data.skills, i, shadowed));
    });

    // Certifications, publications, languages, volunteering: the escape hatch
    // the fixed schema does not model, and for a long time the one thing this
    // check never looked at. Each section is probed on its own and named by the
    // user's own title, because "some of your custom sections does not fit"
    // would not tell them which one.
    for (var s = 0; s < data.customSections.length; s++) {
      final section = data.customSections[s];
      final title = section.sectionTitle.trim();
      await check(
        title.isEmpty ? 'extra sections' : title,
        section.items.length,
        (i) {
          final shadowed = _shadowCustomItem(section.items[i]);
          if (shadowed == section.items[i]) return null;
          // Only the item is shadowed, never the section heading: a design that
          // draws the heading and drops every item under it — a labelled empty
          // band — must still read as a loss.
          return data.copyWith(
            customSections: _replace(
              data.customSections,
              s,
              section.copyWith(items: _replace(section.items, i, shadowed)),
            ),
          );
        },
      );
    }

    return TruncationReport(lost, emptied: emptied);
  }

  static List<T> _replace<T>(List<T> list, int i, T value) => [
    ...list.sublist(0, i),
    value,
    ...list.sublist(i + 1),
  ];

  /// Same length, same spaces, same punctuation, different glyphs.
  ///
  /// Rot-13 for letters, +5 for digits, everything else left alone: total on
  /// any input, and it cannot shorten or lengthen the string. That last part is
  /// the whole point — a shadow that changed the layout would change the bytes
  /// whether or not the text was ever drawn, and the check would report nothing
  /// wherever it mattered most.
  static String _shadow(String s) => String.fromCharCodes(
    s.runes.map((c) {
      if (c >= 0x61 && c <= 0x7A) return (c - 0x61 + 13) % 26 + 0x61;
      if (c >= 0x41 && c <= 0x5A) return (c - 0x41 + 13) % 26 + 0x41;
      if (c >= 0x30 && c <= 0x39) return (c - 0x30 + 5) % 10 + 0x30;
      return c;
    }),
  );

  static Experience _shadowExperience(Experience e) => e.copyWith(
    company: _shadow(e.company),
    position: _shadow(e.position),
    startDate: _shadow(e.startDate),
    endDate: _shadow(e.endDate),
    description: _shadow(e.description),
  );

  static Education _shadowEducation(Education e) => e.copyWith(
    institution: _shadow(e.institution),
    degree: _shadow(e.degree),
    field: _shadow(e.field),
    startDate: _shadow(e.startDate),
    endDate: _shadow(e.endDate),
    gpa: _shadow(e.gpa),
  );

  static Project _shadowProject(Project p) => p.copyWith(
    name: _shadow(p.name),
    description: _shadow(p.description),
    link: _shadow(p.link),
    technologies: _shadow(p.technologies),
  );

  static CustomItem _shadowCustomItem(CustomItem i) => i.copyWith(
    title: _shadow(i.title),
    subtitle: _shadow(i.subtitle),
    description: _shadow(i.description),
  );

  static final RegExp _creationDate = RegExp(r'/CreationDate\(D:[^)]*\)');
  static final RegExp _fileId = RegExp(r'/ID\[(<[0-9a-f]*>)+\]');

  /// A render with the two fields that change on every save removed.
  ///
  /// `dart_pdf` stamps `/CreationDate` and derives the file `/ID` from it.
  /// Everything else is a pure function of the content, so once these are gone
  /// two renders of the same resume are byte-identical.
  static String _canonical(Uint8List bytes) => latin1
      .decode(bytes, allowInvalid: true)
      .replaceAll(_creationDate, '')
      .replaceAll(_fileId, '');

  /// Test seam: the font map used for a template's renders.
  static Future<Map<FontFamily, LoadedFamily>> fontsFor(
    ResumeTemplate template,
  ) => PdfRenderer.ensureFonts(template);
}
