import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// Guards item 7 of the URL rule at the top of `lib/templates/template.dart`:
/// every URL this catalog draws is also tappable, and the thing it opens is the
/// URL the user typed rather than the shortened thing on the page.
///
/// The failure mode this file exists for is the quiet one. A `/Link` annotation
/// is invisible in a rasterized preview, invisible in extracted text, and
/// invisible to `flutter analyze`; a resume with no annotations at all renders
/// pixel-for-pixel identically to one with thirteen. Worse, a *wrong* target —
/// `https://github.com/…/atlas`, the display form with its ellipsis still in it
/// — also renders identically and is worse than no link, because the reader
/// cannot tell it is broken until they follow it.
///
/// So the assertions read the annotation objects out of the PDF itself.
/// `dart_pdf` writes them as uncompressed dictionaries next to the page, so the
/// destination can be recovered exactly rather than inferred. Everything is
/// driven from the registry, so a design added tomorrow is covered without
/// editing this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Long enough that every one of the thirteen columns has to shorten it, so
  // the display form and the target cannot possibly be the same string.
  const longProjectLink =
      'https://github.com/example/some-quite-long-repository-name'
      '/tree/main/packages/design-tokens';

  /// One `/Link` annotation as the PDF actually carries it.
  ({String uri, String border}) parseAnnot(String object) {
    final uri = RegExp(r'/URI\(((?:\\.|[^\\()])*)\)').firstMatch(object);
    final border = RegExp(r'/Border\[([^\]]*)\]').firstMatch(object);
    return (
      uri: uri == null
          ? ''
          : uri
                .group(1)!
                .replaceAll(r'\(', '(')
                .replaceAll(r'\)', ')')
                .replaceAll(r'\\', r'\'),
      border: border?.group(1) ?? '',
    );
  }

  /// Every link annotation in [bytes], in document order.
  ///
  /// Annotation dictionaries are plain objects — only content streams are
  /// deflated — so this reads what a PDF viewer would, not a proxy for it.
  List<({String uri, String border})> linkAnnotations(List<int> bytes) {
    final pdf = latin1.decode(bytes, allowInvalid: true);
    return [
      for (final object in pdf.split('endobj'))
        if (object.contains('/Subtype/Link')) parseAnnot(object),
    ];
  }

  Future<List<int>> render(ResumeTemplate template, ResumeData data) =>
      PdfRenderer.build(template: template, data: data);

  Future<List<({String uri, String border})>> linksOf(
    ResumeTemplate template,
    ResumeData data,
  ) async => linkAnnotations(await render(template, data));

  Future<List<String>> targetsOf(
    ResumeTemplate template,
    ResumeData data,
  ) async => (await linksOf(template, data)).map((a) => a.uri).toList();

  /// The URL annotations only.
  ///
  /// Contact details carry `mailto:` and `tel:` annotations of their own now.
  /// Every assertion in this file was written when a URL was the only thing on
  /// a page that could be linked, so the ones about *absence* have to say which
  /// kind of absence they mean. `contact_link_test.dart` covers the other two.
  Future<List<({String uri, String border})>> urlLinksOf(
    ResumeTemplate template,
    ResumeData data,
  ) async => (await linksOf(template, data))
      .where((a) => !a.uri.startsWith('mailto:') && !a.uri.startsWith('tel:'))
      .toList();

  ResumeData withUrls({
    required String linkedin,
    required String website,
    required String projectLink,
  }) => sampleResume.copyWith(
    personalInfo: sampleResume.personalInfo.copyWith(
      linkedin: linkedin,
      website: website,
    ),
    projects: [
      sampleResume.projects.first.copyWith(link: projectLink),
      sampleResume.projects.last.copyWith(link: ''),
    ],
  );

  /// A render with the two fields that change on every save masked out, so two
  /// documents of the same content compare equal. Same technique as
  /// `url_rule_test.dart`, and for the same reason.
  Future<String> stable(ResumeTemplate template, ResumeData data) async {
    return latin1
        .decode(await render(template, data), allowInvalid: true)
        .replaceAll(RegExp(r'/CreationDate\(D:[^)]*\)'), '')
        .replaceAll(RegExp(r'/ID\[(<[0-9a-f]*>)+\]'), '');
  }

  /// Whether [template] draws the project link at all, established without
  /// looking at a single annotation.
  ///
  /// Both strings are prose — no dot-and-TLD, so [urlTarget] refuses both and
  /// neither produces an annotation. They are the same length with the same
  /// delimiters in the same places, so line breaking lands identically. The
  /// only thing that can differ between the two renders is the drawn glyphs.
  /// Deriving this from the page rather than asserting "all thirteen draw
  /// projects" keeps the group honest if a later design chooses not to.
  Future<bool> drawsProjectLink(ResumeTemplate template) async {
    final a = await stable(
      template,
      withUrls(linkedin: '', website: '', projectLink: 'ask-me-later'),
    );
    final b = await stable(
      template,
      withUrls(linkedin: '', website: '', projectLink: 'nfx-zr-yngre'),
    );
    return a != b;
  }

  // ---------------------------------------------------------------------
  // The rule itself: what a typed string becomes, and what it must not.
  // ---------------------------------------------------------------------
  group('urlTarget', () {
    test('infers https for a scheme-less host, which is what users type', () {
      // Every URL in the app's own sample resume is scheme-less. If this did
      // not work, QA-12 would ship linking almost nothing.
      expect(urlTarget('amara.design'), 'https://amara.design');
      expect(
        urlTarget('linkedin.com/in/amaraokonkwo'),
        'https://linkedin.com/in/amaraokonkwo',
      );
      expect(
        urlTarget('www.example.co.uk/cv?ref=1#top'),
        'https://www.example.co.uk/cv?ref=1#top',
      );
    });

    test('keeps a scheme the user typed rather than upgrading it', () {
      // http may be the only thing their host answers on. Guessing https for
      // them would be a broken link chosen on their behalf.
      expect(urlTarget('http://amara.design'), 'http://amara.design');
      expect(urlTarget('https://amara.design'), 'https://amara.design');
    });

    test('lower-cases the scheme so one address has one target', () {
      expect(urlTarget('HTTPS://Amara.design'), 'https://Amara.design');
      expect(urlTarget('HtTp://amara.design'), 'http://amara.design');
    });

    test('refuses anything that is not an address', () {
      // A resume field is free text. This is the list of things people
      // actually put in it, and `https://` in front of any of them is a link
      // to nonsense — worse than plain ink, because it looks like it works.
      for (final input in [
        '',
        '   ',
        'n/a',
        'N/A',
        'TBD',
        'available on request',
        'ask me',
        'LinkedIn: amaraokonkwo',
        'portfolio',
        'Ph.D',
        'e.g',
        'etc.',
        '@amaraokonkwo',
        '/in/amaraokonkwo',
        '//amara.design',
        'amara.design/my page',
        '192.168.1.1',
        'localhost:3000',
      ]) {
        expect(
          urlTarget(input),
          isNull,
          reason: '"$input" is not a URL but was turned into a link',
        );
      }
    });

    test('refuses a scheme a resume has no business carrying', () {
      // A PDF viewer follows whatever scheme the annotation names.
      for (final input in [
        'javascript:alert(1)',
        'javascript://amara.design',
        'data:text/html,<script>1</script>',
        'data://amara.design',
        'file:///etc/passwd',
        'ftp://files.example.com',
        'mailto:amara.okonkwo@example.com',
        'https://',
        'https://n/a',
        'http://localhost',
      ]) {
        expect(
          urlTarget(input),
          isNull,
          reason: '"$input" produced a link target',
        );
      }
    });

    test('always returns an absolute http(s) URL when it returns one', () {
      for (final input in [
        'amara.design',
        'https://amara.design',
        'HTTP://amara.design/x',
        'github.com/example/atlas',
        'a.co',
        'sub.domain.example.museum/deep/path?q=1&r=2#f',
      ]) {
        final target = urlTarget(input)!;
        expect(
          RegExp(r'^https?://[^/]').hasMatch(target),
          isTrue,
          reason: '"$input" gave a target that is not absolute: "$target"',
        );
      }
    });

    test('keeps everything the display form throws away', () {
      // urlDisplay drops the scheme, a leading www., and a trailing slash —
      // all three of which a browser needs or a host may distinguish.
      const raw = 'https://www.linkedin.com/in/amaraokonkwo/';
      expect(urlDisplay(raw), 'linkedin.com/in/amaraokonkwo');
      expect(urlTarget(raw), raw);
    });

    test('escapes what a URI may not carry literally', () {
      expect(urlTarget('amara.design/café'), 'https://amara.design/caf%C3%A9');
      expect(urlTarget('amara.design/a<b>c'), 'https://amara.design/a%3Cb%3Ec');
      // Already-escaped input is not escaped twice.
      expect(
        urlTarget('amara.design/caf%C3%A9'),
        'https://amara.design/caf%C3%A9',
      );
    });

    test('is total and stable', () {
      for (final input in [
        '',
        '   ',
        '.',
        '..',
        '://',
        'https://',
        'a' * 4000,
        ' ',
        '😀.com',
        'amara.design',
      ]) {
        final once = urlTarget(input);
        expect(urlTarget(input), once, reason: 'not stable for "$input"');
      }
    });
  });

  // ---------------------------------------------------------------------
  // Every design in the catalog.
  // ---------------------------------------------------------------------
  for (final template in resumeTemplates) {
    group('template "${template.id}" link annotations', () {
      test('links the LinkedIn and website URLs it draws', () async {
        // The QA-12 ask, stated as the user would: the two profile URLs in the
        // contact block open when tapped.
        final targets = await targetsOf(template, sampleResume);
        expect(
          targets,
          containsAll(<String>[
            'https://linkedin.com/in/amaraokonkwo',
            'https://amara.design',
          ]),
          reason:
              'the contact block draws these two URLs but they are not '
              'tappable — QA-12',
        );
      });

      test('links the project link, if it draws one', () async {
        if (!await drawsProjectLink(template)) return;
        expect(
          await targetsOf(template, sampleResume),
          contains('https://github.com/example/atlas'),
          reason:
              'this design draws a project link as text but attaches no '
              'annotation to it',
        );
      });

      test('targets the whole URL, not the shortened display form', () async {
        // The one that would pass a screenshot review and fail a reader. The
        // page necessarily shortens this link — it is far wider than any of the
        // thirteen columns — and the ellipsis must not reach the destination.
        if (!await drawsProjectLink(template)) return;
        final targets = await targetsOf(
          template,
          withUrls(linkedin: '', website: '', projectLink: longProjectLink),
        );
        expect(targets, contains(longProjectLink));
        for (final target in targets) {
          expect(
            target,
            isNot(contains('…')),
            reason: 'a shortened URL reached the annotation: "$target"',
          );
        }
      });

      test('draws no annotation for a blank or whitespace URL', () async {
        // Not "a link to the empty string" and not "a link to the page it sits
        // on" — nothing at all.
        expect(
          await urlLinksOf(
            template,
            withUrls(linkedin: '', website: '   ', projectLink: '\t '),
          ),
          isEmpty,
        );
      });

      test('draws no annotation for text that is not a URL', () async {
        // Still drawn as ink — the display rule is unchanged — just not linked.
        expect(
          await urlLinksOf(
            template,
            withUrls(
              linkedin: 'available on request',
              website: 'n/a',
              projectLink: 'ask me',
            ),
          ),
          isEmpty,
          reason: 'prose in a URL field became a link to nonsense',
        );
      });

      test('every annotation is a borderless http(s) link', () async {
        // Item 7 promises the drawn page does not change. A border on a link
        // annotation is a rectangle some viewers paint over the type, which
        // would be exactly that change.
        final links = await linksOf(template, sampleResume);
        expect(links, isNotEmpty);
        for (final link in links) {
          // Scoped to the URL annotations this file is about. Email and phone
          // are linked too now (mailto:, tel:) and are covered by
          // contact_link_test.dart; this assertion was written when a URL was
          // the only thing on a page that could carry an annotation.
          if (!link.uri.startsWith('mailto:') && !link.uri.startsWith('tel:')) {
            expect(
              RegExp(r'^https?://').hasMatch(link.uri),
              isTrue,
              reason: 'annotation target "${link.uri}" is not an http(s) URL',
            );
          }
          expect(
            link.border.split(RegExp(r'\s+')).where((s) => s.isNotEmpty),
            ['0', '0', '0'],
            reason: 'a visible link border would alter the drawn page',
          );
        }
      });

      test('draws one annotation per URL, never a duplicate', () async {
        // dart_pdf builds an annotation at paint time, so a subtree painted
        // twice would stack two identical hot areas — invisible, and it would
        // grow with every render.
        final targets = await targetsOf(template, sampleResume);
        expect(
          targets.toSet().length,
          targets.length,
          reason: 'duplicate link annotations: $targets',
        );
        // Six linkable fields on the sample now, not four: LinkedIn, website,
        // one project link, plus email and phone since contact details became
        // tappable.
        expect(targets.length, lessThanOrEqualTo(6));
      });

      test('the annotations are the only thing the scheme changes', () async {
        // The display rule strips the scheme, so typing it must not move a
        // single glyph. Everything outside the annotation dictionaries has to
        // be byte-identical between the two spellings.
        String withoutAnnots(String pdf) => pdf
            .split('endobj')
            .where((o) => !o.contains('/Subtype/Link'))
            .join();

        final typed = await stable(
          template,
          withUrls(
            linkedin: 'https://linkedin.com/in/amaraokonkwo',
            website: 'https://amara.design',
            projectLink: 'https://github.com/example/atlas',
          ),
        );
        final bare = await stable(
          template,
          withUrls(
            linkedin: 'linkedin.com/in/amaraokonkwo',
            website: 'amara.design',
            projectLink: 'github.com/example/atlas',
          ),
        );
        expect(withoutAnnots(typed), withoutAnnots(bare));
        // ...and the targets agree too, because the scheme was inferred.
        expect(
          linkAnnotations(latin1.encode(typed)).map((a) => a.uri),
          linkAnnotations(latin1.encode(bare)).map((a) => a.uri),
        );
      });
    });
  }

  test('no design links anything the user did not type', () async {
    // A catch-all against a template hard-coding a URL of its own — a
    // designer's portfolio, a placeholder left in during development. Every
    // target on every page must trace back to a field in the data.
    final data = sampleResume;
    final allowed = {
      urlTarget(data.personalInfo.linkedin),
      urlTarget(data.personalInfo.website),
      for (final project in data.projects) urlTarget(project.link),
      // Contact details carry their own schemes; the point of this test is
      // that nothing is linked which the user did not type, not that every
      // target is an http URL.
      emailTarget(data.personalInfo.email),
      telTarget(data.personalInfo.phone),
    }.whereType<String>().toSet();

    for (final template in resumeTemplates) {
      for (final target in await targetsOf(template, data)) {
        expect(
          allowed,
          contains(target),
          reason: '${template.id} links "$target", which is not in the resume',
        );
      }
    }
  });
}
