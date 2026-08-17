import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/templates/fonts.dart';
import 'package:resume_forge/templates/prism/prism_template.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// Guards the skills rule documented at the top of `lib/templates/template.dart`.
///
/// Every defect this file exists for was *silent*. Quill and Linen deleted the
/// entire Skills section the moment a resume reached four roles — an ordinary
/// resume — on a page that still showed white space. Terminal drew `~/skills`
/// and its rule over an empty band, advertising a section it did not contain.
/// Aurora, alone in the catalog, capped nothing and let twenty-four skills
/// evict Education from its sidebar. In every case the PDF was one valid A4
/// page, `catalog_test.dart` was green, and the content was simply gone.
///
/// So the assertions here are differential, in the same shape as
/// `url_rule_test.dart`: a skill name is swapped for a *shadow* of the same
/// length and the two renders are compared whole. A name that reaches the page
/// changes the drawn glyphs; a name that was dropped changes nothing, because
/// dart_pdf never registers a glyph it did not paint. Comparing lengths would
/// not do — a dropped run and a drawn one often have identical byte counts.
///
/// Everything is driven from the registry, so a design added tomorrow is held
/// to the same rule without editing this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Fixtures
  // -------------------------------------------------------------------------

  /// A 62-character name. Three designs print it in full, so it *fits* a
  /// resume; the rest have to shorten it, and item 3 says visibly.
  const longSkill =
      'Enterprise Resource Planning Systems Integration and Migration';

  /// Same length, different letters. Rot-13, so word lengths and therefore
  /// line breaking land identically and a difference in the rendered bytes can
  /// only mean the letters themselves were drawn.
  String shadow(String s) => s.split('').map((c) {
    final code = c.codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7A) {
      return String.fromCharCode((code - 0x61 + 13) % 26 + 0x61);
    }
    if (code >= 0x41 && code <= 0x5A) {
      return String.fromCharCode((code - 0x41 + 13) % 26 + 0x41);
    }
    return c;
  }).join();

  /// The cheapest reproducer for the section that vanished: the shipped sample
  /// with one more role. Nothing else about it is unusual.
  ResumeData fourRoles([List<Skill>? skills]) => sampleResume.copyWith(
    experiences: [
      ...sampleResume.experiences,
      sampleResume.experiences.first.copyWith(
        id: 'exp-4',
        company: 'Atlas Interactive',
        position: 'Design Lead',
      ),
    ],
    skills: skills ?? sampleResume.skills,
  );

  List<Skill> skillsOfLevel(int count, int level) => List.generate(
    count,
    (i) => Skill(id: 'sk-$i', name: 'Capability $i', level: level),
  );

  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  final fontCache = <String, Map<FontFamily, LoadedFamily>>{};

  Future<Uint8List> bytes(ResumeTemplate template, ResumeData data) async {
    final families = fontCache[template.id] ??= await PdfRenderer.ensureFonts(
      template,
    );
    return PdfRenderer.renderWith(
      template: template,
      data: data,
      families: families,
    );
  }

  /// A render with the two fields that change on every save masked out, so two
  /// renders of identical content compare equal.
  Future<String> render(ResumeTemplate template, ResumeData data) async =>
      latin1
          .decode(await bytes(template, data), allowInvalid: true)
          .replaceAll(RegExp(r'/CreationDate\(D:[^)]*\)'), '')
          .replaceAll(RegExp(r'/ID\[(<[0-9a-f]*>)+\]'), '');

  /// Filled paths on the page.
  ///
  /// A skill meter is drawn geometry, not text, so "was a meter drawn" cannot
  /// be answered by comparing glyphs — it needs the content stream, which
  /// dart_pdf writes Flate-compressed. Every filled shape, rectangular or
  /// rounded, ends in an `f` operator, so counting those counts the boxes.
  int filledPaths(Uint8List pdf) {
    final text = latin1.decode(pdf, allowInvalid: true);
    var total = 0;
    for (final match in RegExp(r'stream\r?\n').allMatches(text)) {
      final end = text.indexOf('endstream', match.end);
      if (end < 0) continue;
      List<int> inflated;
      try {
        inflated = ZLibCodec().decode(pdf.sublist(match.end, end));
      } catch (_) {
        continue; // Not a compressed content stream; a font file, say.
      }
      total += RegExp(
        r'(?:^|\s)f\*?(?=\s)',
      ).allMatches(latin1.decode(inflated, allowInvalid: true)).length;
    }
    return total;
  }

  /// WCAG 2.1 relative luminance and contrast, computed here rather than
  /// imported: `test/theme/contrast_test.dart` guards the app's dark chrome,
  /// and a template carries its own ink-on-paper palette that has nothing to do
  /// with it. The two must not share a threshold or a helper.
  double luminance(PdfColor c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(c.red) +
        0.7152 * channel(c.green) +
        0.0722 * channel(c.blue);
  }

  double contrast(PdfColor a, PdfColor b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  // -------------------------------------------------------------------------
  // Item 3: how a name too long for its column is shortened.
  // Measurement is injected so the algorithm is pinned exactly rather than
  // through whatever one font happens to do at one size.
  // -------------------------------------------------------------------------
  group('fitTextLines', () {
    // One unit per character: makes every expectation below arithmetic.
    double perChar(String s) => s.length.toDouble();

    List<String> fit(String s, double limit, int maxLines) =>
        fitTextLines(s, limit: limit, maxLines: maxLines, width: perChar);

    test('returns the name untouched when it already fits', () {
      expect(fit('Design systems', 40, 1), ['Design systems']);
    });

    test('never returns more lines, or a wider line, than allowed', () {
      for (var limit = 6.0; limit <= 70; limit += 1) {
        for (final maxLines in [1, 2, 3, 4]) {
          final lines = fit(longSkill, limit, maxLines);
          expect(lines.length, lessThanOrEqualTo(maxLines));
          for (final line in lines) {
            expect(
              perChar(line),
              lessThanOrEqualTo(limit),
              reason: 'limit $limit, maxLines $maxLines produced "$line"',
            );
          }
        }
      }
    });

    test('marks a shortening with an ellipsis, always', () {
      // This is the whole of item 3: 29 characters or 62 is the design's
      // business, but the reader must be able to see that something went.
      for (var limit = 8.0; limit < perChar(longSkill); limit += 1) {
        final line = fit(longSkill, limit, 1).single;
        expect(
          line,
          endsWith('…'),
          reason: 'limit $limit cut without a mark: "$line"',
        );
      }
    });

    test('adds no mark when nothing was dropped', () {
      // Two lines are enough for this name at width 34, so an ellipsis here
      // would be a lie about content that is on the page.
      final lines = fit(longSkill, 34, 3);
      expect(lines.join(' '), longSkill);
      expect(lines.last, isNot(endsWith('…')));
    });

    test('breaks on whitespace, not mid-word, while a break exists', () {
      for (var limit = 20.0; limit <= 60; limit += 1) {
        final lines = fit(longSkill, limit, 4);
        for (final line in lines.take(lines.length - 1)) {
          expect(
            line,
            isNot(endsWith('-')),
            reason: 'limit $limit broke inside a word: "$line"',
          );
          // Every word in this name is shorter than 20, so a rebuilt line must
          // always end on a whole one.
          expect(
            longSkill.split(' '),
            contains(line.split(' ').last),
            reason: 'limit $limit ended a line mid-word: "$line"',
          );
        }
      }
    });

    test('character-breaks only a word that cannot fit any other way', () {
      const word = 'Supercalifragilisticexpialidocious';
      final lines = fit(word, 10, 4);
      for (final line in lines) {
        expect(perChar(line), lessThanOrEqualTo(10));
      }
      expect(lines.first, 'Supercalif');
    });

    test('preserves the run\'s own whitespace', () {
      // Linen sets its skills with a wide `   ·   ` separator. Splitting on
      // `\s+` and rejoining with one space quietly retyped it as a narrow one —
      // a typographic change smuggled in by a line breaker.
      const run = 'Alpha   ·   Beta   ·   Gamma';
      expect(fit(run, 100, 1), [run]);
      expect(fit(run, 18, 3).first, 'Alpha   ·   Beta');
    });

    test('survives degenerate input', () {
      expect(fit('', 20, 2), isEmpty);
      expect(fit('   ', 20, 2), isEmpty);
      expect(fit('x', 0.5, 1), isNotEmpty);
      expect(fit('Design systems', 0, 1), ['Design systems']);
      expect(fit('Design systems', double.infinity, 1), ['Design systems']);
    });
  });

  // -------------------------------------------------------------------------
  // Item 5: what level 0 means.
  // -------------------------------------------------------------------------
  group('skillRating', () {
    test('level 0 is "not rated", so there is nothing to draw', () {
      expect(skillRating(const Skill(id: 'a', name: 'x', level: 0)), isNull);
    });

    test('levels 1 to 5 are themselves', () {
      for (var level = 1; level <= 5; level++) {
        expect(
          skillRating(Skill(id: 'a', name: 'x', level: level)),
          level,
          reason: 'level $level',
        );
      }
    });

    test('a stored value outside 0..5 costs the meter, not the render', () {
      expect(skillRating(const Skill(id: 'a', name: 'x', level: 9)), 5);
      expect(skillRating(const Skill(id: 'a', name: 'x', level: -3)), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Item 4: the marker a continuous run closes with.
  // -------------------------------------------------------------------------
  group('skillsHiddenLabel', () {
    test('counts what is missing rather than hinting at it', () {
      expect(skillsHiddenLabel(1), '+1 more');
      expect(skillsHiddenLabel(19), '+19 more');
    });
  });

  // -------------------------------------------------------------------------
  // Item 5, on the page: a filled skill chip that is not legible.
  // -------------------------------------------------------------------------
  group('contrast of a filled skill treatment', () {
    // 4.5 : 1 is the WCAG AA threshold for normal-size text. All three of
    // these set their label between 7.8 and 8.2 pt, which is nowhere near the
    // large-text exemption, so none of them may use the 3 : 1 bound.
    const aa = 4.5;

    test('prism draws white on a violet that clears AA', () {
      final ratio = contrast(
        const PdfColor.fromInt(0xFFFFFFFF),
        PrismTemplate.strongChipFill,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(aa),
        reason:
            'the filled chip is back under AA — it was 4.23 : 1 on #8B5CF6, '
            'which is what this test exists to stop returning',
      );
      // Pins the figure quoted in the template's own doc comment.
      expect(ratio, closeTo(5.70, 0.01));
    });

    test('the other designs that fill with primary clear it too', () {
      for (final id in ['circuit', 'terminal']) {
        final p = templateById(id).palette;
        expect(
          contrast(p.onPrimary, p.primary),
          greaterThanOrEqualTo(aa),
          reason: '$id sets a skill label in onPrimary on primary',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Every design in the catalog.
  // -------------------------------------------------------------------------
  for (final template in resumeTemplates) {
    group('template "${template.id}" skills', () {
      test('draws every skill on an ordinary four-role resume', () async {
        // Item 1. Four roles is not a stress case, and the five skills are the
        // shipped sample's own. Quill and Linen dropped all five here.
        final data = fourRoles();
        final full = await render(template, data);

        for (var i = 0; i < data.skills.length; i++) {
          final swapped = [...data.skills];
          swapped[i] = swapped[i].copyWith(name: shadow(swapped[i].name));
          expect(
            await render(template, data.copyWith(skills: swapped)),
            isNot(full),
            reason:
                'skill ${i + 1} of ${data.skills.length} '
                '("${data.skills[i].name}") made no difference to the page, '
                'so it is not on it',
          );
        }
      });

      test('never draws a skills heading over an empty band', () async {
        // Item 2. Terminal printed `~/skills` and its rule with the whole token
        // cloud missing beneath — a page advertising a section it did not
        // contain, which is worse than no section at all. The shape of that
        // failure is: removing skills changes the page (so a heading is being
        // drawn) while changing a skill name does not (so no name is).
        final skills = [
          const Skill(id: 'sk-1', name: 'Design systems', level: 5),
          const Skill(id: 'sk-2', name: longSkill, level: 3),
          const Skill(id: 'sk-3', name: 'C', level: 0),
          const Skill(id: 'sk-4', name: 'Prototyping', level: 1),
          const Skill(id: 'sk-5', name: 'User research', level: 2),
          const Skill(id: 'sk-6', name: 'Accessibility', level: 4),
          const Skill(id: 'sk-7', name: 'Figma', level: 5),
          const Skill(id: 'sk-8', name: 'Data visualisation', level: 0),
        ];
        final data = fourRoles(skills);

        final full = await render(template, data);
        final none = await render(template, data.copyWith(skills: const []));
        if (full == none) {
          // A design that draws no skills section at all would be a different
          // defect, and `draws every skill` above already rules it out.
          fail('${template.id} drew nothing at all for eight skills');
        }

        expect(
          await render(
            template,
            data.copyWith(
              skills: [
                skills.first.copyWith(name: shadow(skills.first.name)),
                ...skills.skip(1),
              ],
            ),
          ),
          isNot(full),
          reason:
              'this design put something on the page for the skills section '
              'but the first skill name is not part of it — a heading over an '
              'empty band',
        );
      });

      test('a long skill name still reaches the page', () async {
        // Item 3. How many of the 62 characters survive is the design's own
        // business — a 148pt slate rail and a 460pt ledger row cannot share one
        // budget — but the name must be drawn, and shortening it must not cost
        // the page its shape.
        final data = fourRoles([
          const Skill(id: 'sk-1', name: longSkill, level: 3),
          ...sampleResume.skills,
        ]);

        expect(
          RegExp(
            r'/Type\s*/Page(?![s])',
          ).allMatches(await render(template, data)).length,
          1,
        );

        expect(
          await render(
            template,
            data.copyWith(
              skills: [
                data.skills.first.copyWith(name: shadow(longSkill)),
                ...data.skills.skip(1),
              ],
            ),
          ),
          isNot(await render(template, data)),
          reason: 'a 62-character skill name draws nothing at all',
        );
      });

      test('a long list of skills does not evict education', () async {
        // Item 1, the other way round. Aurora was the one design with no cap:
        // twenty-four meters ran to the foot of its sidebar and dart_pdf
        // deleted the Education block underneath them outright.
        //
        // The role count is held at the shipped sample's three, so the only
        // thing varying is the length of the skills list. Orchid drops
        // education on any four-role resume for a reason that has nothing to do
        // with skills (docs/ui/FLUTTER_UI_ISSUES.md), and this test must not
        // quietly absorb that.
        final data = sampleResume.copyWith(skills: skillsOfLevel(24, 3));

        expect(
          await render(template, data),
          isNot(await render(template, data.copyWith(education: const []))),
          reason:
              'removing education changed nothing, so twenty-four skills had '
              'already pushed it off the page',
        );
      });

      test('an unrated skill draws no rating', () async {
        // Item 5. A rating is drawn geometry, so this counts filled paths
        // rather than glyphs: one more unrated skill must add none.
        //
        // Only the four designs that draw a 0–5 meter are asked. In a chip
        // design the chip *is* a filled path, so "one more skill costs no
        // geometry" is not a claim that can be made about them — and they read
        // `level` as a two-way split where 0 and 3 already look the same.
        const meterDesigns = {'aurora', 'meridian', 'ember', 'ledger'};
        if (!meterDesigns.contains(template.id)) return;

        final three = filledPaths(
          await bytes(template, fourRoles(skillsOfLevel(3, 0))),
        );
        final four = filledPaths(
          await bytes(template, fourRoles(skillsOfLevel(4, 0))),
        );
        final fourRated = filledPaths(
          await bytes(template, fourRoles(skillsOfLevel(4, 3))),
        );

        expect(
          four,
          three,
          reason:
              'a fourth unrated skill drew ${four - three} more filled '
              'shape(s) — an empty meter, which reports a rating the user '
              'never gave and looks exactly like a meter that failed',
        );
        expect(
          fourRated,
          greaterThan(four),
          reason:
              'a rated skill drew no more geometry than an unrated one, so '
              'this design is not drawing its meter at all',
        );
      });

      test('the shipped sample is unaffected by any of it', () async {
        // The guard against fixing truncation by changing what a page that
        // never truncated looks like. Every one of these renders is compared
        // whole against itself, so the check is only as strong as the renderer
        // being deterministic — which the next test pins.
        final a = await render(template, sampleResume);
        final b = await render(template, sampleResume);
        expect(a, b, reason: '${template.id} is not deterministic');
        expect(RegExp(r'/Type\s*/Page(?![s])').allMatches(a).length, 1);
      });
    });
  }
}
