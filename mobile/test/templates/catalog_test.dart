import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// Contract every design in the catalog must satisfy.
///
/// Runs against the registry rather than a hand-maintained list, so a template
/// added tomorrow is covered without touching this file.
///
/// ## Why one A4 page and a parseable PDF was not enough
///
/// Every defect the QA-5/QA-11 audit found was invisible to this file: Quill
/// and Linen dropped their entire Skills section on a four-role resume, Terminal
/// drew a labelled but empty `~/skills` band, and Ledger dropped Certifications
/// whole. In all of them the PDF was one valid A4 page with embedded fonts, so
/// every assertion here passed. **A blank page would have passed.**
///
/// So the assertions below are about ink, not about structure: for every design
/// in the registry, every entry and every field the fixture holds must actually
/// be painted.
///
/// ### How "present" is decided
///
/// The same trick `url_rule_test.dart` uses for URLs, because the problem is
/// the same one: a byte *count* cannot tell "drawn" from "drawn, then dropped".
/// Each probe swaps a piece of the user's content for a **shadow** — rot-13 for
/// letters, +5 for digits, everything else untouched — so the string keeps its
/// length, its spaces and its punctuation, and only the glyphs change. Two whole
/// documents are then compared with `/CreationDate` and the `/ID` derived from
/// it masked out. If they are identical, none of those glyphs were painted:
/// `dart_pdf` never registers a glyph it did not draw.
///
/// Shadowing rather than deleting is the load-bearing part. Deleting content
/// frees the space it wanted, the rest of the page reflows into it, and the
/// bytes change whether or not the deleted thing was ever on the page — which
/// is exactly how Terminal's empty skill band went unnoticed. A shadow changes
/// no layout at all, so the only thing it can change is ink.
///
/// ### Telling a design choice from content loss
///
/// Designs leave things out on purpose. Measured at the time of writing: five
/// draw no portrait, six ignore a skill's level, and eight never print a GPA.
/// Those are deliberate, and a test that failed on them would be deleted rather
/// than fixed — but neither those counts nor which design is in which group are
/// written down anywhere here, because a list like that goes stale the first
/// time a design changes its mind. The answer is derived, per design, by asking
/// it twice:
///
///   * not drawn in the full fixture, **and** not drawn in [sparse] — the same
///     resume with every string cut to its first few characters, which no
///     design can be short of room for — means this design never draws that
///     content at all. A design choice; the probe says nothing.
///   * not drawn in the full fixture but drawn in [sparse] means the design
///     does render it, and this particular page lost it. That is the failure
///     this file exists to catch.
///
/// [sparse] is a prefix of the fixture field by field, so it can never contain
/// something the fixture does not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int pageCount(Uint8List bytes) => RegExp(
    r'/Type\s*/Page(?![s])',
  ).allMatches(latin1.decode(bytes, allowInvalid: true)).length;

  /// Nine roles, 24 skills, and absurd strings — the shape that previously
  /// caused a Column to silently drop its children.
  ResumeData stressContent() {
    const long = 'Wolfeschlegelsteinhausenbergerdorff-Featherstonehaugh ';
    return sampleResume.copyWith(
      personalInfo: sampleResume.personalInfo.copyWith(
        fullName: long * 3,
        summary: long * 12,
      ),
      experiences: List.generate(
        9,
        (i) => sampleResume.experiences.first.copyWith(
          id: 'exp-$i',
          description: long * 8,
        ),
      ),
      skills: List.generate(
        24,
        (i) => Skill(id: 'sk-$i', name: 'Capability number $i', level: i % 6),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // The presence machinery.
  // -----------------------------------------------------------------------

  /// Same length, same spaces, same punctuation, different glyphs.
  String shadow(String s) => String.fromCharCodes(
    s.runes.map((c) {
      if (c >= 0x61 && c <= 0x7A) return (c - 0x61 + 13) % 26 + 0x61;
      if (c >= 0x41 && c <= 0x5A) return (c - 0x41 + 13) % 26 + 0x41;
      if (c >= 0x30 && c <= 0x39) return (c - 0x30 + 5) % 10 + 0x30;
      return c;
    }),
  );

  /// The first few characters of [s], never blank when [s] is not.
  String clip(String s) {
    if (s.length <= 8) return s;
    final head = s.substring(0, 8);
    return head.trim().isEmpty ? s : head;
  }

  /// The fixture with every string cut to a prefix: the same shape, the same
  /// number of entries, a fraction of the ink. The oracle for "does this design
  /// draw this at all", which is the only way to tell a deliberate omission
  /// from content that fell off the page.
  ResumeData sparse(ResumeData d) => d.copyWith(
    personalInfo: d.personalInfo.copyWith(
      fullName: clip(d.personalInfo.fullName),
      title: clip(d.personalInfo.title),
      email: clip(d.personalInfo.email),
      phone: clip(d.personalInfo.phone),
      location: clip(d.personalInfo.location),
      summary: clip(d.personalInfo.summary),
      linkedin: clip(d.personalInfo.linkedin),
      website: clip(d.personalInfo.website),
    ),
    experiences: [
      for (final e in d.experiences)
        e.copyWith(
          company: clip(e.company),
          position: clip(e.position),
          description: clip(e.description),
        ),
    ],
    education: [
      for (final e in d.education)
        e.copyWith(
          institution: clip(e.institution),
          degree: clip(e.degree),
          field: clip(e.field),
        ),
    ],
    skills: [for (final s in d.skills) s.copyWith(name: clip(s.name))],
    projects: [
      for (final p in d.projects)
        p.copyWith(
          name: clip(p.name),
          description: clip(p.description),
          link: clip(p.link),
          technologies: clip(p.technologies),
        ),
    ],
    customSections: [
      for (final s in d.customSections)
        s.copyWith(
          sectionTitle: clip(s.sectionTitle),
          items: [
            for (final i in s.items)
              i.copyWith(
                title: clip(i.title),
                subtitle: clip(i.subtitle),
                description: clip(i.description),
              ),
          ],
        ),
    ],
  );

  List<T> replace<T>(List<T> list, int i, T value) => [
    ...list.sublist(0, i),
    value,
    ...list.sublist(i + 1),
  ];

  /// The fixture's own portrait with every pixel inverted, re-encoded in the
  /// same format at the same size. Null in, null out, so a fixture with no
  /// photo makes the probe inert rather than making it lie.
  Uint8List? negative(PersonalInfo info) {
    final bytes = info.photo;
    if (bytes == null) return null;
    final decoded = img.decodeJpg(bytes);
    if (decoded == null) return null;
    return img.encodeJpg(img.invert(decoded), quality: 85);
  }

  final creationDate = RegExp(r'/CreationDate\(D:[^)]*\)');
  final fileId = RegExp(r'/ID\[(<[0-9a-f]*>)+\]');
  // `PdfRenderer` puts the full name in the document's /Author and /Title, so a
  // probe on the name would change the file without a single glyph reaching the
  // page. The whole info dictionary up to /Producer goes. Anchored on the `<<`
  // that opens the dictionary so it cannot match a coincidence inside a
  // compressed content stream and swallow a real difference with it.
  final docInfo = RegExp(r'<<(/Author\(|/Title\()[\s\S]*?/Producer');

  /// A render, reduced to what actually depends on the content.
  Future<String> render(ResumeTemplate template, ResumeData data) async {
    final bytes = await PdfRenderer.build(template: template, data: data);
    return latin1
        .decode(bytes, allowInvalid: true)
        .replaceAll(creationDate, '')
        .replaceAll(fileId, '')
        .replaceAll(docInfo, '<</Producer');
  }

  /// The app's own filler. It carries content in every section the model has,
  /// and it is what the gallery advertises every design with, so a design that
  /// cannot hold it is advertising a page it does not draw.
  ResumeData populated() => sampleResume;

  /// One probe: a name, and the fixture with that piece of it shadowed.
  final entryProbes = <String, ResumeData Function(ResumeData)>{};
  for (var n = 0; n < populated().experiences.length; n++) {
    final i = n;
    entryProbes['experience[$i]'] = (d) => d.copyWith(
      experiences: replace(
        d.experiences,
        i,
        d.experiences[i].copyWith(
          company: shadow(d.experiences[i].company),
          position: shadow(d.experiences[i].position),
          description: shadow(d.experiences[i].description),
        ),
      ),
    );
  }
  for (var n = 0; n < populated().education.length; n++) {
    final i = n;
    entryProbes['education[$i]'] = (d) => d.copyWith(
      education: replace(
        d.education,
        i,
        d.education[i].copyWith(
          institution: shadow(d.education[i].institution),
          degree: shadow(d.education[i].degree),
          field: shadow(d.education[i].field),
        ),
      ),
    );
  }
  for (var n = 0; n < populated().skills.length; n++) {
    final i = n;
    entryProbes['skill[$i]'] = (d) => d.copyWith(
      skills: replace(
        d.skills,
        i,
        d.skills[i].copyWith(name: shadow(d.skills[i].name)),
      ),
    );
  }
  for (var n = 0; n < populated().projects.length; n++) {
    final i = n;
    entryProbes['project[$i]'] = (d) => d.copyWith(
      projects: replace(
        d.projects,
        i,
        d.projects[i].copyWith(
          name: shadow(d.projects[i].name),
          description: shadow(d.projects[i].description),
        ),
      ),
    );
  }
  for (var n = 0; n < populated().customSections.length; n++) {
    final s = n;
    // The heading and the items are probed apart on purpose. A design that
    // draws "Certifications" and then drops every certification under it — the
    // labelled empty band Terminal drew for skills — must fail, and it only
    // fails if the two are not allowed to cover for each other.
    entryProbes['customSection[$s].title'] = (d) => d.copyWith(
      customSections: replace(
        d.customSections,
        s,
        d.customSections[s].copyWith(
          sectionTitle: shadow(d.customSections[s].sectionTitle),
        ),
      ),
    );
    for (var m = 0; m < populated().customSections[s].items.length; m++) {
      final i = m;
      entryProbes['customSection[$s].item[$i]'] = (d) => d.copyWith(
        customSections: replace(
          d.customSections,
          s,
          d.customSections[s].copyWith(
            items: replace(
              d.customSections[s].items,
              i,
              d.customSections[s].items[i].copyWith(
                title: shadow(d.customSections[s].items[i].title),
                subtitle: shadow(d.customSections[s].items[i].subtitle),
                description: shadow(d.customSections[s].items[i].description),
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Every field the model can hold, shadowed across every entry at once.
  ///
  /// Enumerated from [ResumeData]'s own shape rather than from what the designs
  /// happen to read: a field nobody draws is exactly the kind of thing that
  /// should show up here.
  final fieldProbes = <String, ResumeData Function(ResumeData)>{
    'PersonalInfo.fullName': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        fullName: shadow(d.personalInfo.fullName),
      ),
    ),
    'PersonalInfo.title': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        title: shadow(d.personalInfo.title),
      ),
    ),
    'PersonalInfo.email': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        email: shadow(d.personalInfo.email),
      ),
    ),
    'PersonalInfo.phone': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        phone: shadow(d.personalInfo.phone),
      ),
    ),
    'PersonalInfo.location': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        location: shadow(d.personalInfo.location),
      ),
    ),
    'PersonalInfo.summary': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        summary: shadow(d.personalInfo.summary),
      ),
    ),
    'PersonalInfo.linkedin': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        linkedin: shadow(d.personalInfo.linkedin),
      ),
    ),
    'PersonalInfo.website': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(
        website: shadow(d.personalInfo.website),
      ),
    ),
    // Not a string, so not rot-13, but the same idea: the sample portrait with
    // every pixel inverted. Same format, same dimensions, so the slot it lands
    // in is identical and only the ink differs — and it is derived from the
    // fixture's own photo rather than a second image, so it cannot drift.
    'PersonalInfo.photo': (d) => d.copyWith(
      personalInfo: d.personalInfo.copyWith(photo: negative(d.personalInfo)),
    ),
    'Experience.company': (d) => d.copyWith(
      experiences: [
        for (final e in d.experiences) e.copyWith(company: shadow(e.company)),
      ],
    ),
    'Experience.position': (d) => d.copyWith(
      experiences: [
        for (final e in d.experiences) e.copyWith(position: shadow(e.position)),
      ],
    ),
    'Experience.startDate': (d) => d.copyWith(
      experiences: [
        for (final e in d.experiences)
          e.copyWith(startDate: shadow(e.startDate)),
      ],
    ),
    'Experience.endDate': (d) => d.copyWith(
      experiences: [
        for (final e in d.experiences) e.copyWith(endDate: shadow(e.endDate)),
      ],
    ),
    // "Present" against a real end date: the one field whose rendering is a
    // branch rather than a string, and the subject of QA-11.
    'Experience.current': (d) => d.copyWith(
      experiences: [
        for (final e in d.experiences)
          e.copyWith(current: !e.current, endDate: e.current ? '2024-01' : ''),
      ],
    ),
    'Experience.description': (d) => d.copyWith(
      experiences: [
        for (final e in d.experiences)
          e.copyWith(description: shadow(e.description)),
      ],
    ),
    'Education.institution': (d) => d.copyWith(
      education: [
        for (final e in d.education)
          e.copyWith(institution: shadow(e.institution)),
      ],
    ),
    'Education.degree': (d) => d.copyWith(
      education: [
        for (final e in d.education) e.copyWith(degree: shadow(e.degree)),
      ],
    ),
    'Education.field': (d) => d.copyWith(
      education: [
        for (final e in d.education) e.copyWith(field: shadow(e.field)),
      ],
    ),
    'Education.startDate': (d) => d.copyWith(
      education: [
        for (final e in d.education) e.copyWith(startDate: shadow(e.startDate)),
      ],
    ),
    'Education.endDate': (d) => d.copyWith(
      education: [
        for (final e in d.education) e.copyWith(endDate: shadow(e.endDate)),
      ],
    ),
    'Education.gpa': (d) => d.copyWith(
      education: [for (final e in d.education) e.copyWith(gpa: shadow(e.gpa))],
    ),
    'Skill.name': (d) => d.copyWith(
      skills: [for (final s in d.skills) s.copyWith(name: shadow(s.name))],
    ),
    // Also not a string: 0..5 mirrored, so a meter that reads the level draws a
    // different length and one that ignores it draws the same page.
    'Skill.level': (d) => d.copyWith(
      skills: [for (final s in d.skills) s.copyWith(level: 5 - s.level)],
    ),
    'Project.name': (d) => d.copyWith(
      projects: [for (final p in d.projects) p.copyWith(name: shadow(p.name))],
    ),
    'Project.description': (d) => d.copyWith(
      projects: [
        for (final p in d.projects)
          p.copyWith(description: shadow(p.description)),
      ],
    ),
    'Project.link': (d) => d.copyWith(
      projects: [for (final p in d.projects) p.copyWith(link: shadow(p.link))],
    ),
    'Project.technologies': (d) => d.copyWith(
      projects: [
        for (final p in d.projects)
          p.copyWith(technologies: shadow(p.technologies)),
      ],
    ),
    'CustomSection.sectionTitle': (d) => d.copyWith(
      customSections: [
        for (final s in d.customSections)
          s.copyWith(sectionTitle: shadow(s.sectionTitle)),
      ],
    ),
    'CustomItem.title': (d) => d.copyWith(
      customSections: [
        for (final s in d.customSections)
          s.copyWith(
            items: [
              for (final i in s.items) i.copyWith(title: shadow(i.title)),
            ],
          ),
      ],
    ),
    'CustomItem.subtitle': (d) => d.copyWith(
      customSections: [
        for (final s in d.customSections)
          s.copyWith(
            items: [
              for (final i in s.items) i.copyWith(subtitle: shadow(i.subtitle)),
            ],
          ),
      ],
    ),
    'CustomItem.description': (d) => d.copyWith(
      customSections: [
        for (final s in d.customSections)
          s.copyWith(
            items: [
              for (final i in s.items)
                i.copyWith(description: shadow(i.description)),
            ],
          ),
      ],
    ),
  };

  /// Probes the fixture cannot answer, because it leaves the field blank and a
  /// shadow of nothing is nothing.
  Set<String> inert(ResumeData data) => {
    for (final p in fieldProbes.entries)
      if (p.value(data) == data) p.key,
  };

  test('the catalog is not empty and has unique ids', () {
    expect(resumeTemplates, isNotEmpty);

    final ids = resumeTemplates.map((t) => t.id).toList();
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'a duplicate id would make templateById ambiguous',
    );
  });

  test('the fixture has content in every section', () {
    // Everything below is derived from this fixture, so a section quietly
    // emptied out of it would quietly stop being covered.
    final data = populated();
    expect(data.experiences, isNotEmpty);
    expect(data.education, isNotEmpty);
    expect(data.skills, isNotEmpty);
    expect(data.projects, isNotEmpty);
    expect(data.customSections, isNotEmpty);
    expect(data.customSections.first.items, isNotEmpty);
    expect(data.personalInfo.photo, isNotNull);
  });

  test('the document metadata cannot stand in for ink', () async {
    // `PdfRenderer` copies the full name into /Author and /Title. If either
    // survived masking, the `PersonalInfo.fullName` probe below would pass on
    // every design in the catalog whether or not the name was ever painted —
    // including on the five that would have had to lay it out somewhere.
    final canonical = await render(resumeTemplates.first, populated());
    expect(canonical, isNot(contains('/Author(')));
    expect(canonical, isNot(contains('/Title(')));
  });

  test('and content in all but one of the fields the model can hold', () {
    // Not a gap that is being tolerated — a gap that cannot be closed here.
    // Quill has no headroom left on the app's own sample: five characters of
    // `CustomItem.description` and its entire Competencies section is evicted,
    // so a fixture carrying one would fail this file for a defect that belongs
    // to the template. If the sample ever gains a description, delete this.
    expect(
      inert(populated()),
      {'CustomItem.description'},
      reason:
          'a field the fixture leaves blank is a field nothing here checks; '
          'either fill it in the sample or record it as unreachable',
    );
  });

  for (final template in resumeTemplates) {
    group('template "${template.id}"', () {
      test('declares complete metadata', () {
        expect(template.id, isNotEmpty);
        expect(template.name, isNotEmpty);
        expect(template.description, isNotEmpty);
        expect(template.bestFor, isNotEmpty);
        expect(
          template.requiredFonts,
          isNotEmpty,
          reason: 'a template with no declared font cannot render text',
        );
      });

      test('renders the sample resume as one A4 page', () async {
        final bytes = await PdfRenderer.build(
          template: template,
          data: sampleResume,
        );

        expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(pageCount(bytes), 1);
        expect(
          latin1.decode(bytes, allowInvalid: true),
          contains('/FontFile2'),
          reason: 'exported text must be extractable for ATS parsers',
        );
      });

      test('keeps pathological content on one page', () async {
        final bytes = await PdfRenderer.build(
          template: template,
          data: stressContent(),
        );

        expect(pageCount(bytes), 1);
      });

      test('renders an empty resume without throwing', () async {
        final bytes = await PdfRenderer.build(
          template: template,
          data: const ResumeData(),
        );

        expect(pageCount(bytes), 1);
      });

      test('survives an undecodable photo', () async {
        final data = sampleResume.copyWith(
          personalInfo: sampleResume.personalInfo.copyWith(
            photo: Uint8List.fromList(List.filled(64, 0x7F)),
          ),
        );

        // One corrupt photo must cost the portrait, not the whole resume.
        final bytes = await PdfRenderer.build(template: template, data: data);
        expect(pageCount(bytes), 1);
      });

      test('draws every entry of every section', () async {
        final data = populated();
        final full = await render(template, data);
        final lean = sparse(data);
        final leanBase = await render(template, lean);

        final lost = <String>[];
        for (final probe in entryProbes.entries) {
          if (await render(template, probe.value(data)) != full) continue;
          // Nothing of this entry is on the page. Design, or loss?
          if (await render(template, probe.value(lean)) != leanBase) {
            lost.add(probe.key);
          }
        }

        expect(
          lost,
          isEmpty,
          reason:
              'this design draws these on a shorter resume but not on the '
              "app's own sample, so it is losing them to the page edge — the "
              'user is told nothing and the PDF is still one valid A4 page',
        );
      });

      test('draws every field it draws at all', () async {
        final data = populated();
        final full = await render(template, data);
        final lean = sparse(data);
        final leanBase = await render(template, lean);
        final skip = inert(data);

        final lost = <String>[];
        for (final probe in fieldProbes.entries) {
          if (skip.contains(probe.key)) continue;
          if (await render(template, probe.value(data)) != full) continue;
          if (await render(template, probe.value(lean)) != leanBase) {
            lost.add(probe.key);
          }
        }

        expect(
          lost,
          isEmpty,
          reason:
              'a field this design renders when there is room for it, and '
              'silently discards when there is not',
        );
      });

      test('and the probe can tell when something is missing', () async {
        // Everything above is an assertion that two renders *differ*, which
        // would also hold if the comparison were simply broken — an unmasked
        // timestamp, a render that is not a pure function of its content, a
        // shadow that changes the layout. So: a case where the answer is known
        // in advance. No design in the catalog fits twenty roles on one A4
        // page, so the twentieth cannot be drawn, and the probe has to say so.
        final flooded = populated().copyWith(
          experiences: List.generate(
            20,
            (i) => populated().experiences.first.copyWith(
              id: 'exp-$i',
              company: 'Company $i',
              position: 'Role $i',
            ),
          ),
        );
        final last = flooded.experiences.length - 1;

        expect(
          await render(
            template,
            flooded.copyWith(
              experiences: replace(
                flooded.experiences,
                last,
                flooded.experiences[last].copyWith(
                  company: shadow(flooded.experiences[last].company),
                  position: shadow(flooded.experiences[last].position),
                  description: shadow(flooded.experiences[last].description),
                ),
              ),
            ),
          ),
          await render(template, flooded),
          reason:
              'the twentieth role changed the page, which means either this '
              'design flows to a second page now or the comparison above is '
              'reporting a difference that has nothing to do with ink',
        );
      });
    });
  }
}
