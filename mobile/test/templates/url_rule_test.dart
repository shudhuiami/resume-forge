import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/render/truncation_check.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// Guards the URL rule documented at the top of `lib/templates/template.dart`.
///
/// Every failure this file exists for was *silent*. Aurora never referenced
/// `pr.link` at all; six contact blocks joined the website onto the end of a
/// run clamped to two lines, where it fell off the third and vanished; and a
/// long link left as a non-flex `pw.Row` child starved the project name beside
/// it down to one clipped glyph. In all three the PDF was still one valid A4
/// page and every existing test stayed green — the content was simply gone.
///
/// So the assertions are differential, and deliberately sharper than "did the
/// bytes change at all": each URL is swapped for a *shadow* of the same length
/// with the same delimiters in the same places but different letters. A URL
/// that reaches the page changes the drawn glyphs; a URL that is clipped away
/// changes nothing, because dart_pdf never registers a glyph it did not paint.
/// Comparing whole documents rather than their lengths is what makes that
/// distinction visible — a clipped run and a drawn one often have identical
/// byte counts.
///
/// Everything is driven from the registry, so a design added tomorrow is
/// covered without editing this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Deliberately pathological: longer than any of the thirteen columns can
  // hold, with no whitespace anywhere for the engine to break on.
  const longProjectLink =
      'https://github.com/someuser/a-fairly-long-repository-name';
  const longLinkedin =
      'https://linkedin.com/in/alexandra-whitfield-morrison-8b4a12345';
  const longWebsite =
      'https://alexandra-whitfield-morrison.portfolio.example.com/work';

  /// Same length, same punctuation in the same places, different letters.
  ///
  /// Rot-13 past the scheme. Line breaking therefore lands identically, so a
  /// difference in the rendered bytes can only mean the letters themselves
  /// were drawn.
  String shadow(String url) {
    final at = url.indexOf('://');
    final head = at < 0 ? '' : url.substring(0, at + 3);
    final tail = at < 0 ? url : url.substring(at + 3);
    return head +
        tail.split('').map((c) {
          final code = c.codeUnitAt(0);
          if (code < 0x61 || code > 0x7A) return c;
          return String.fromCharCode((code - 0x61 + 13) % 26 + 0x61);
        }).join();
  }

  /// The sample resume with every URL replaced by an unreasonable one, plus a
  /// second project whose link the user left blank.
  ResumeData pathological() => sampleResume.copyWith(
    personalInfo: sampleResume.personalInfo.copyWith(
      linkedin: longLinkedin,
      website: longWebsite,
    ),
    projects: [
      sampleResume.projects.first.copyWith(link: longProjectLink),
      sampleResume.projects.last.copyWith(link: ''),
    ],
  );

  /// A render, with the two fields that change on every save removed.
  ///
  /// `dart_pdf` stamps `/CreationDate` and derives the file `/ID` from it, so
  /// two renders of identical content are otherwise byte-identical — verified
  /// across all thirteen designs.
  Future<String> render(ResumeTemplate template, ResumeData data) async {
    final bytes = await PdfRenderer.build(template: template, data: data);
    return latin1
        .decode(bytes, allowInvalid: true)
        .replaceAll(RegExp(r'/CreationDate\(D:[^)]*\)'), '')
        .replaceAll(RegExp(r'/ID\[(<[0-9a-f]*>)+\]'), '');
  }

  int pageCount(String pdf) =>
      RegExp(r'/Type\s*/Page(?![s])').allMatches(pdf).length;

  // ---------------------------------------------------------------------
  // Item 1 of the rule: the display form.
  // ---------------------------------------------------------------------
  group('urlDisplay', () {
    test('drops the scheme, a leading www., and a trailing slash', () {
      expect(urlDisplay('https://github.com/user'), 'github.com/user');
      expect(urlDisplay('http://example.com'), 'example.com');
      expect(urlDisplay('https://www.linkedin.com/in/x'), 'linkedin.com/in/x');
      expect(urlDisplay('https://example.com/'), 'example.com');
      expect(urlDisplay('https://example.com///'), 'example.com');
    });

    test('leaves everything else alone', () {
      expect(urlDisplay('github.com/user'), 'github.com/user');
      expect(urlDisplay('example.com/a?b=c#d'), 'example.com/a?b=c#d');
      // A host that merely starts with "www" has no "www." prefix to drop.
      expect(urlDisplay('wwwhatever.com'), 'wwwhatever.com');
    });

    test('is total and idempotent', () {
      for (final input in [
        '',
        '   ',
        '/',
        'https://',
        'not a url at all',
        longLinkedin,
      ]) {
        final once = urlDisplay(input);
        expect(urlDisplay(once), once, reason: 'not idempotent for "$input"');
      }
      expect(urlDisplay('  https://example.com/  '), 'example.com');
    });
  });

  // ---------------------------------------------------------------------
  // Items 3 and 4: how a URL that does not fit is broken or shortened.
  // Measurement is injected so the algorithm is pinned exactly rather than
  // through whatever one font happens to do at one size.
  // ---------------------------------------------------------------------
  group('fitUrlLines', () {
    // One unit per character: makes every expectation below arithmetic.
    double perChar(String s) => s.length.toDouble();

    List<String> fit(String s, double limit, int maxLines) =>
        fitUrlLines(s, limit: limit, maxLines: maxLines, width: perChar);

    test('returns the URL untouched when it already fits', () {
      expect(fit('github.com/user', 40, 1), ['github.com/user']);
    });

    test('never returns a line wider than the limit', () {
      const url = 'github.com/someuser/a-fairly-long-repository-name';
      for (var limit = 4.0; limit <= 60; limit += 1) {
        for (final maxLines in [1, 2, 3, 4]) {
          final lines = fit(url, limit, maxLines);
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

    test('breaks after a delimiter, never mid-token', () {
      const url = 'linkedin.com/in/alexandra-whitfield-morrison-8b4a12345';
      const delimiters = {
        '/',
        '.',
        '-',
        '_',
        '?',
        '#',
        '&',
        '=',
        '@',
        ':',
        ',',
      };

      for (var limit = 20.0; limit <= 50; limit += 1) {
        final lines = fit(url, limit, 4);
        // Every run between two delimiters in this URL is shorter than the
        // limit, so no character break is ever forced.
        for (final line in lines.take(lines.length - 1)) {
          expect(
            delimiters.contains(line[line.length - 1]),
            isTrue,
            reason: 'limit $limit broke mid-token at "$line"',
          );
        }
      }
    });

    test('wrapping is lossless', () {
      const url = 'linkedin.com/in/alexandra-whitfield-morrison-8b4a12345';
      expect(fit(url, 30, 4).join(), url);
    });

    test('marks a one-line shortening with an ellipsis and keeps the host', () {
      const url = 'github.com/someuser/a-fairly-long-repository-name';
      for (var limit = 12.0; limit < perChar(url); limit += 1) {
        final line = fit(url, limit, 1).single;
        expect(line, contains('…'), reason: 'limit $limit gave "$line"');
        expect(
          line.startsWith('github.com'),
          isTrue,
          reason: 'limit $limit lost the host: "$line"',
        );
      }
    });

    test('drops the middle of the path before the tail', () {
      const url = 'github.com/someuser/atlas-design-system';
      expect(fit(url, 34, 1).single, 'github.com/…/atlas-design-system');
    });

    test('character-breaks only a run that cannot fit any other way', () {
      // One 30-character token with no delimiter inside it.
      const url = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com';
      final lines = fit(url, 10, 4);
      for (final line in lines) {
        expect(perChar(line), lessThanOrEqualTo(10));
      }
      expect(lines.join(), startsWith('aaaaaaaaaa'));
    });

    test('survives degenerate input', () {
      expect(fit('', 20, 2), isEmpty);
      expect(fit('x', 0.5, 1), isNotEmpty);
      expect(fit('github.com/user', 1, 1), isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------
  // Every design in the catalog, against the pathological set.
  // ---------------------------------------------------------------------
  for (final template in resumeTemplates) {
    group('template "${template.id}" URL rule', () {
      test('keeps a pathological set of URLs on one page', () async {
        expect(pageCount(await render(template, pathological())), 1);
      });

      test('draws the LinkedIn URL', () async {
        final data = pathological();
        expect(
          await render(template, data),
          isNot(
            await render(
              template,
              data.copyWith(
                personalInfo: data.personalInfo.copyWith(
                  linkedin: shadow(longLinkedin),
                ),
              ),
            ),
          ),
          reason:
              'changing the LinkedIn URL changed nothing on the page, so '
              'none of it is drawn',
        );
      });

      test('draws the website URL', () async {
        final data = pathological();
        expect(
          await render(template, data),
          isNot(
            await render(
              template,
              data.copyWith(
                personalInfo: data.personalInfo.copyWith(
                  website: shadow(longWebsite),
                ),
              ),
            ),
          ),
          reason:
              'changing the website changed nothing on the page — QA-4, '
              'where it fell past a two-line clamp and disappeared',
        );
      });

      test('draws the project link, if it draws projects at all', () async {
        final data = pathological();
        final full = await render(template, data);
        final noProjects = await render(
          template,
          data.copyWith(projects: const []),
        );

        if (full == noProjects) {
          // A design with no projects section; a project link is not its job.
          return;
        }

        expect(
          await render(
            template,
            data.copyWith(projects: [data.projects.first]),
          ),
          isNot(
            await render(
              template,
              data.copyWith(
                projects: [
                  data.projects.first.copyWith(link: shadow(longProjectLink)),
                ],
              ),
            ),
          ),
          reason:
              'this design draws a projects section but ignores pr.link, '
              'so a URL the user typed never reaches the PDF — QA-1',
        );
      });

      test('a long URL costs the email not one character', () async {
        // Whatever a contact block gives up to fit a pathological URL, it must
        // not be somebody's email address: a shortened email is simply a wrong
        // email. Only the last three characters change, so if the tail of the
        // address is not on the page the two renders are identical.
        final data = pathological();
        final email = data.personalInfo.email;
        expect(
          await render(template, data),
          isNot(
            await render(
              template,
              data.copyWith(
                personalInfo: data.personalInfo.copyWith(
                  email: email.substring(0, email.length - 3) + shadow('com'),
                ),
              ),
            ),
          ),
          reason:
              'the end of the email is missing from the page — a long URL '
              'shortened a value that is not a URL',
        );
      });

      test('a long link does not starve the project name', () async {
        // The mechanism behind QA-2 and QA-3: a URL left as a non-flex Row
        // child is laid out unbounded, leaves its Expanded sibling zero width,
        // and the name collapses to one clipped glyph. Once that happens the
        // name's content stops affecting the page at all.
        final data = pathological();
        expect(
          await render(
            template,
            data.copyWith(
              projects: [data.projects.first.copyWith(name: 'Atlas')],
            ),
          ),
          isNot(
            await render(
              template,
              data.copyWith(
                projects: [
                  data.projects.first.copyWith(
                    name: 'Atlas Design System Platform',
                  ),
                ],
              ),
            ),
          ),
          reason:
              'the project name made no difference beside a long link, so '
              'the link had squeezed it out of the row',
        );
      });

      test('a blank link draws nothing at all', () async {
        final data = pathological();
        final blank = await render(
          template,
          data.copyWith(projects: [data.projects.first.copyWith(link: '')]),
        );

        expect(pageCount(blank), 1);
        expect(
          await render(
            template,
            data.copyWith(projects: [data.projects.first.copyWith(link: '  ')]),
          ),
          blank,
          reason:
              'a whitespace-only URL must draw nothing — not a stray '
              'separator, gap, or rule where a link would have been',
        );
      });

      test('long URLs do not push a section off the page', () async {
        // Shortening and wrapping are meant to absorb a long URL inside the
        // space the design already reserved. If they grew the block instead,
        // dart_pdf's Column would drop whatever no longer fit — and the user
        // would lose a whole job to a long profile URL.
        final plain = await TruncationCheck.run(
          template: template,
          data: sampleResume,
        );
        final long = await TruncationCheck.run(
          template: template,
          data: pathological(),
        );

        expect(
          long.sections,
          plain.sections,
          reason: 'pathological URLs cost this design a section',
        );
      });
    });
  }

  test('a URL never reaches the page with its scheme still on it', () async {
    // Item 1 of the rule, checked end to end rather than only on the helper:
    // the string handed to the page must already be in display form.
    for (final template in resumeTemplates) {
      final withScheme = await render(template, pathological());
      final withoutScheme = await render(
        template,
        pathological().copyWith(
          personalInfo: pathological().personalInfo.copyWith(
            linkedin: urlDisplay(longLinkedin),
            website: urlDisplay(longWebsite),
          ),
          projects: [
            sampleResume.projects.first.copyWith(
              link: urlDisplay(longProjectLink),
            ),
            sampleResume.projects.last.copyWith(link: ''),
          ],
        ),
      );

      expect(
        withScheme,
        withoutScheme,
        reason:
            '${template.id} renders "https://" differently from the same '
            'URL typed without it; the two must be indistinguishable',
      );
    }
  });

  test('every template renders identically for the same input', () async {
    // The differential assertions above are only meaningful if a render is a
    // pure function of its content once the timestamp is masked. Pinning that
    // here means a future change to the renderer cannot quietly turn the whole
    // group into a set of tests that pass for the wrong reason.
    for (final template in resumeTemplates) {
      final a = await render(template, pathological());
      final b = await render(template, pathological());
      expect(a, b, reason: '${template.id} is not deterministic');
    }
  });
}
