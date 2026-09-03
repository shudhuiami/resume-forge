import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/phone.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// Guards THE CONTACT LINK RULE at the top of `lib/templates/template.dart`:
/// the email address opens a `mailto:` and the phone number dials a `tel:`,
/// in every design, without a single glyph moving.
///
/// The failure mode is the same quiet one `link_target_test.dart` exists for. A
/// `/Link` annotation is invisible in a rasterized preview, invisible in
/// extracted text and invisible to `flutter analyze`, so a page with no contact
/// annotations renders pixel-for-pixel identically to one with two. And a
/// *wrong* target is worse than none: `tel:` carrying the digits of an
/// extension dials a different subscriber, and `mailto:on request` is a link a
/// reader cannot tell is broken until they follow it.
///
/// So the assertions read the annotation dictionaries out of the PDF itself.
/// `dart_pdf` writes them uncompressed next to the page, so the destination can
/// be recovered exactly rather than inferred. Everything is driven from the
/// registry, so a design added tomorrow is covered without editing this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One `/Link` annotation as the PDF actually carries it.
  ///
  /// Same parser as `link_target_test.dart`, extended with the rectangle: a
  /// contact link is the only kind whose hot area can silently land on the
  /// wrong words, because — unlike a URL — it is wrapped around a widget
  /// somebody else built.
  ({String uri, String border, List<double> rect}) parseAnnot(String object) {
    final uri = RegExp(r'/URI\(((?:\\.|[^\\()])*)\)').firstMatch(object);
    final border = RegExp(r'/Border\[([^\]]*)\]').firstMatch(object);
    final rect = RegExp(r'/Rect\[([^\]]*)\]').firstMatch(object);
    return (
      uri: uri == null
          ? ''
          : uri
                .group(1)!
                .replaceAll(r'\(', '(')
                .replaceAll(r'\)', ')')
                .replaceAll(r'\\', r'\'),
      border: border?.group(1) ?? '',
      rect: rect == null
          ? const <double>[]
          : rect
                .group(1)!
                .trim()
                .split(RegExp(r'\s+'))
                .map(double.parse)
                .toList(),
    );
  }

  List<({String uri, String border, List<double> rect})> linkAnnotations(
    List<int> bytes,
  ) {
    final pdf = latin1.decode(bytes, allowInvalid: true);
    return [
      for (final object in pdf.split('endobj'))
        if (object.contains('/Subtype/Link')) parseAnnot(object),
    ];
  }

  Future<List<({String uri, String border, List<double> rect})>> linksOf(
    ResumeTemplate template,
    ResumeData data,
  ) async =>
      linkAnnotations(await PdfRenderer.build(template: template, data: data));

  Future<List<String>> targetsOf(
    ResumeTemplate template,
    ResumeData data,
  ) async => (await linksOf(template, data)).map((a) => a.uri).toList();

  ResumeData withContact({required String email, required String phone}) =>
      sampleResume.copyWith(
        personalInfo: sampleResume.personalInfo.copyWith(
          email: email,
          phone: phone,
        ),
      );

  /// Every linkable field at once — the two contact values and the three URLs.
  ///
  /// A full resume otherwise, so this is a page with plenty of content on it,
  /// not the empty document. The distinction matters: an annotation left over
  /// from a field the user cleared would still be sitting on a busy page.
  ResumeData withEveryLinkable(String value) => sampleResume.copyWith(
    personalInfo: sampleResume.personalInfo.copyWith(
      email: value,
      phone: value,
      linkedin: value,
      website: value,
    ),
    projects: [
      for (final project in sampleResume.projects)
        project.copyWith(link: value),
    ],
  );

  // ---------------------------------------------------------------------
  // The mailto: gate. Rule item 4.
  // ---------------------------------------------------------------------
  group('emailTarget', () {
    test('links an address, verbatim and unescaped', () {
      expect(
        emailTarget('amara.okonkwo@example.com'),
        'mailto:amara.okonkwo@example.com',
      );
      expect(emailTarget('a@b.co'), 'mailto:a@b.co');
      expect(
        emailTarget('first+tag@mail.example.co.uk'),
        'mailto:first+tag@mail.example.co.uk',
      );
      expect(
        emailTarget("o'brien_1@sub-domain.example.museum"),
        "mailto:o'brien_1@sub-domain.example.museum",
      );
    });

    test('trims surrounding whitespace but changes nothing else', () {
      expect(emailTarget('  amara@example.com \t'), 'mailto:amara@example.com');
    });

    test('preserves case, because a local part is case-sensitive', () {
      // The domain half is case-insensitive; the mailbox half is not, and a
      // resume is the wrong place to normalise somebody's address on a guess.
      expect(emailTarget('Amara.O@Example.COM'), 'mailto:Amara.O@Example.COM');
    });

    test('refuses anything that is not an address', () {
      // The list is what people really type into an email field when they do
      // not want to publish one. `mailto:on request` is worse than plain ink.
      for (final input in [
        '',
        '   ',
        '\t\n',
        'on request',
        'available on request',
        'n/a',
        'N/A',
        'TBD',
        'ask me',
        'email me',
        'amara at example dot com',
        'amara@example',
        'amara@example.c',
        'amara@',
        '@example.com',
        'amara.okonkwo',
        'example.com',
        'amara@ example.com',
        'amara @example.com',
        'amara@exa mple.com',
        'amara@@example.com',
        'amara@example@com.co',
        '.amara@example.com',
        'amara.@example.com',
        'amara..o@example.com',
        'amara@.example.com',
        'amara@example..com',
        'amara@example.com.',
        'amara@-example.com',
        'amara@example-.com',
        'mailto:amara@example.com',
        'Amara Okonkwo <amara@example.com>',
        'amara@example.com, other@example.com',
        'amara@192.168.1.1',
      ]) {
        expect(
          emailTarget(input),
          isNull,
          reason: '"$input" is not an address but was turned into a link',
        );
      }
    });

    test('refuses the legal characters it cannot carry literally', () {
      // Rule item 4: the accepted set is narrower than RFC 5322 on purpose, so
      // there is no escaping step to get wrong. These are real, legal, rare
      // addresses — drawn as ink rather than encoded on a guess.
      for (final input in [
        'a&b@example.com',
        'a%b@example.com',
        'a/b@example.com',
        'a=b@example.com',
        'a!b@example.com',
        'a?b@example.com',
        'a#b@example.com',
        r'a\b@example.com',
        'amara@example.com?subject=Hi',
      ]) {
        expect(emailTarget(input), isNull, reason: '"$input" was linked');
      }
    });

    test('never emits a scheme other than mailto, and never a bare one', () {
      for (final input in [
        'amara@example.com',
        'a@b.co',
        'javascript@example.com',
        'data@example.com',
      ]) {
        expect(emailTarget(input), startsWith('mailto:'));
        expect(emailTarget(input), isNot('mailto:'));
      }
    });

    test('is total and stable', () {
      for (final input in [
        '',
        '   ',
        '@',
        '@@',
        '.',
        'a' * 4000,
        '${'a' * 300}@${'b' * 300}.com',
        'amara@example.com',
        '😀@example.com',
        'amara@exämple.com',
      ]) {
        final once = emailTarget(input);
        expect(emailTarget(input), once, reason: 'not stable for "$input"');
      }
    });
  });

  // ---------------------------------------------------------------------
  // The tel: rule. Rule item 5.
  // ---------------------------------------------------------------------
  group('telTarget', () {
    test('reduces a written number to the digits a dialler wants', () {
      // The brief's own example. Grouping is for the reader; the target is not.
      expect(telTarget('+1 (415) 555-0134'), 'tel:+14155550134');
      expect(telTarget('+44 20 7946 0958'), 'tel:+442079460958');
      expect(telTarget('+49 (0)30 901820'), 'tel:+49030901820');
      expect(telTarget('+1.415.555.0134'), 'tel:+14155550134');
      expect(telTarget('+33 1/23/45/67/89'), 'tel:+33123456789');
    });

    test('keeps a leading + and never invents one', () {
      // `lib/phone.dart` promises the editor it will not insert a country
      // code. Inventing one here would produce a confidently wrong number.
      expect(telTarget('415-555-0134'), 'tel:4155550134');
      expect(telTarget('(020) 7946 0958'), 'tel:02079460958');
      expect(telTarget('+1 415 555 0134'), 'tel:+14155550134');
    });

    test('treats the separators a paste can carry as separators', () {
      // Non-breaking space and en dash both arrive from web pages and from
      // phone keyboards; neither is a digit and neither is a defect.
      expect(telTarget('+1 415 555 0134'), 'tel:+14155550134');
      expect(telTarget('+1 415–555–0134'), 'tel:+14155550134');
    });

    test('trims surrounding whitespace', () {
      expect(telTarget('  +1 (415) 555-0134  '), 'tel:+14155550134');
    });

    test('refuses a number carrying an extension', () {
      // The reason [_dialable] exists. `checkPhoneNumber` accepts these — it is
      // right to, in the editor — but "every digit" of them dials `…0134210`,
      // which is somebody else's phone. Drawn in full, left unlinked.
      for (final input in [
        '+1 415 555 0134 x210',
        '+1 415 555 0134 ext. 210',
        '+1 415 555 0134 ext 210',
        '+1 415 555 0134 #210',
        '+1 415 555 0134,210',
        '+1 415 555 0134;210',
      ]) {
        expect(
          telTarget(input),
          isNull,
          reason: '"$input" would dial a different subscriber',
        );
      }
    });

    test('refuses anything that is not a number', () {
      for (final input in [
        '',
        '   ',
        '\t\n',
        'on request',
        'available on request',
        'n/a',
        'N/A',
        'ask me',
        'call me',
        'Phone: 415 555 0134',
        '415 555 0134 (mobile)',
        '+1 415 555 0134 or +44 20 7946 0958',
        'amara@example.com',
        'tel:+14155550134',
      ]) {
        expect(
          telTarget(input),
          isNull,
          reason: '"$input" is not a phone number but was turned into a link',
        );
      }
    });

    test('refuses what the app already calls implausible', () {
      // Reused rather than reinvented, so the exported PDF and the editor
      // cannot hold different opinions about the same string.
      for (final input in [
        '12', // tooShort
        '123',
        '+1234567890123456', // tooLong: 16 digits, E.164 caps at 15
        '415 555 0134 +1', // misplacedPlus
        '++14155550134',
        '()-.', // no digits at all
      ]) {
        expect(telTarget(input), isNull, reason: '"$input" was linked');
        expect(
          checkPhoneNumber(input),
          isNot(PhoneIssue.ok),
          reason: 'the shared plausibility check is not what refused "$input"',
        );
      }
    });

    test('never emits a scheme other than tel, and never a bare one', () {
      for (final input in [
        '+1 (415) 555-0134',
        '4155550134',
        '+442079460958',
      ]) {
        expect(telTarget(input), startsWith('tel:'));
        expect(telTarget(input), matches(RegExp(r'^tel:\+?[0-9]{4,15}$')));
      }
    });

    test('the target carries every digit the page shows, in order', () {
      // The counterpart of the URL rule's "never target the display form": the
      // display is the lossy one there, and here it is the target that drops
      // characters — so it may only ever drop *separators*.
      for (final input in [
        '+1 (415) 555-0134',
        '415.555.0134',
        '+44 20 7946 0958',
        '+81 3-1234-5678',
      ]) {
        final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
        expect(telTarget(input), endsWith(digits));
      }
    });

    test('is total and stable', () {
      for (final input in [
        '',
        '   ',
        '+',
        '++',
        '()',
        '-' * 4000,
        '9' * 4000,
        '+1 (415) 555-0134',
        '😀',
        '٤١٥', // Arabic-Indic digits: not ASCII digits, not separators
      ]) {
        final once = telTarget(input);
        expect(telTarget(input), once, reason: 'not stable for "$input"');
      }
    });
  });

  // ---------------------------------------------------------------------
  // The gate itself. Rule item 1: nothing may be routed through here that is
  // not known to be an address or a number.
  // ---------------------------------------------------------------------
  group('contactTarget', () {
    test('dispatches on the field, never on the value', () {
      // The same string, four kinds, four answers. A caller cannot ask for
      // "whatever scheme this looks like".
      const value = 'amara@example.com';
      expect(contactTarget(value, ContactKind.email), 'mailto:$value');
      expect(contactTarget(value, ContactKind.phone), isNull);
      expect(contactTarget(value, ContactKind.url), isNull);
      expect(contactTarget(value, ContactKind.plain), isNull);
    });

    test('plain is never linked, whatever it holds', () {
      for (final input in [
        'San Francisco, CA',
        'amara@example.com',
        '+1 (415) 555-0134',
        'https://amara.design',
        'javascript:alert(1)',
      ]) {
        expect(contactTarget(input, ContactKind.plain), isNull);
      }
    });

    test('an email field cannot smuggle another scheme through', () {
      // The whole reason [urlTarget] refuses non-http schemes. The email and
      // phone gates must be no weaker, or item 1 has been quietly undone.
      for (final input in [
        'javascript:alert(1)',
        'data:text/html,<script>1</script>',
        'file:///etc/passwd',
        'mailto:a@b.com',
        'tel:+14155550134',
        'https://amara.design',
      ]) {
        expect(
          contactTarget(input, ContactKind.email),
          isNull,
          reason: '"$input" passed the email gate',
        );
        expect(
          contactTarget(input, ContactKind.phone),
          isNull,
          reason: '"$input" passed the phone gate',
        );
      }
    });

    test('urlTarget is unchanged: still http(s) only', () {
      // Belt and braces. If a later pass "simplifies" these three gates into
      // one, this is what notices.
      expect(urlTarget('mailto:amara@example.com'), isNull);
      expect(urlTarget('tel:+14155550134'), isNull);
      expect(urlTarget('javascript:alert(1)'), isNull);
      expect(urlTarget('amara.design'), 'https://amara.design');
    });
  });

  // ---------------------------------------------------------------------
  // Rule item 2: the wrapper moves nothing.
  //
  // Proved against where the glyphs land, which is the claim, rather than
  // against the bytes, which is not. Two documents that draw an identical page
  // are never byte-identical once one of them carries an annotation: the extra
  // object renumbers everything after it and rewrites the xref. Nor are their
  // content streams identical, because `pw.UrlLink` paints its child inside a
  // `q … cm … Q`, so the child's own coordinates become relative to it.
  //
  // Neither of those is a layout change, and neither would be caught by
  // eyeballing a rendered page either. So the stream is interpreted instead —
  // the CTM stack is tracked and every glyph run is resolved to the absolute
  // point on the page where it is actually drawn. That is the strongest
  // statement available here: `Printing.raster` does not run under
  // `flutter_test`, so a pixel diff is not on the table.
  // ---------------------------------------------------------------------
  group('contactLink is layout-transparent', () {
    /// Every glyph run in a content stream, at its absolute page position.
    ///
    /// A deliberately small PDF interpreter: enough of the imaging model to
    /// resolve `q`/`Q`/`cm`/`BT`/`Td`/`Tm`/`Tf` and place each `Tj`/`TJ`, and
    /// nothing else. A matrix is `[a b c d e f]`, and a point lands at
    /// `(a·x + c·y + e, b·x + d·y + f)`.
    ///
    /// A font's PDF resource name comes from its object number, and an
    /// annotation is an object, so adding one renumbers `/F5` to `/F7` without
    /// moving anything. Only the size is kept, never the name.
    List<String> glyphRuns(String stream) {
      List<double> mul(List<double> m, List<double> n) => [
        m[0] * n[0] + m[1] * n[2],
        m[0] * n[1] + m[1] * n[3],
        m[2] * n[0] + m[3] * n[2],
        m[2] * n[1] + m[3] * n[3],
        m[4] * n[0] + m[5] * n[2] + n[4],
        m[4] * n[1] + m[5] * n[3] + n[5],
      ];
      const identity = <double>[1, 0, 0, 1, 0, 0];

      var ctm = identity;
      var textMatrix = identity;
      final stack = <List<double>>[];
      final operands = <String>[];
      final runs = <String>[];
      var size = 0.0;
      var text = '';

      double num(int fromEnd) =>
          double.parse(operands[operands.length - fromEnd]);

      final tokens = RegExp(r'\((?:\\.|[^\\()])*\)|[^\s\[\]]+');
      for (final match in tokens.allMatches(stream)) {
        final token = match[0]!;
        switch (token) {
          case 'q':
            stack.add(ctm);
          case 'Q':
            if (stack.isNotEmpty) ctm = stack.removeLast();
          case 'cm':
            ctm = mul([num(6), num(5), num(4), num(3), num(2), num(1)], ctm);
          case 'BT':
            textMatrix = identity;
          case 'Td':
            textMatrix = mul([1, 0, 0, 1, num(2), num(1)], textMatrix);
          case 'Tm':
            textMatrix = [num(6), num(5), num(4), num(3), num(2), num(1)];
          case 'Tf':
            size = num(1);
          case 'Tj':
          case 'TJ':
            final at = mul(textMatrix, ctm);
            // Two decimal places — a hundredth of a point, about a third of a
            // micron on paper. Not slack: the writer rounds every coordinate
            // it emits to five places, so `718.09994 + 2.025` and `720.12494`
            // are the same position expressed two ways and differ in the
            // fourth decimal. Comparing further than this compares the
            // writer's rounding, not the layout.
            runs.add(
              '$text @ ${at[4].toStringAsFixed(2)},${at[5].toStringAsFixed(2)}'
              ' size ${size.toStringAsFixed(2)}',
            );
          default:
            if (token.startsWith('(')) {
              text = token.substring(1, token.length - 1);
            }
        }
        if (token.startsWith('(') ||
            RegExp(r'^[-+.\d]').hasMatch(token) ||
            token.startsWith('/')) {
          operands.add(token);
        } else {
          operands.clear();
        }
      }
      return runs;
    }

    Future<List<String>> drawnPage(
      pw.Widget Function(pw.TextStyle) build,
    ) async {
      final doc = pw.Document(compress: false);
      doc.addPage(
        pw.Page(
          build: (context) => pw.Container(
            width: 200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                build(const pw.TextStyle(fontSize: 9)),
                build(const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
      final pdf = latin1.decode(await doc.save(), allowInvalid: true);
      final stream = RegExp(
        r'stream\n(.*?)\nendstream',
        dotAll: true,
      ).firstMatch(pdf);
      expect(stream, isNotNull, reason: 'no content stream in the document');
      final runs = glyphRuns(stream!.group(1)!);
      expect(runs, isNotEmpty, reason: 'the page drew no text at all');
      return runs;
    }

    Future<List<String>> annotationsOf(
      pw.Widget Function(pw.TextStyle) build,
    ) async {
      final doc = pw.Document(compress: false);
      doc.addPage(
        pw.Page(build: (context) => build(const pw.TextStyle(fontSize: 9))),
      );
      return linkAnnotations(await doc.save()).map((a) => a.uri).toList();
    }

    for (final (name, value, kind) in <(String, String, ContactKind)>[
      ('an email', 'amara.okonkwo@example.com', ContactKind.email),
      ('a phone number', '+1 (415) 555-0134', ContactKind.phone),
    ]) {
      test('draws $name exactly as the unwrapped widget does', () async {
        // Rule item 2, at the mechanism. `pw.UrlLink` passes its constraints
        // straight through and adopts the child's box, so wrapping a widget
        // may add an annotation and must add nothing else.
        expect(
          await drawnPage(
            (style) => contactLink(
              value,
              kind,
              child: clampedText(value, style: style),
            ),
          ),
          await drawnPage((style) => clampedText(value, style: style)),
          reason: 'the link wrapper moved something on the drawn page',
        );

        expect(
          await annotationsOf(
            (style) => contactLink(
              value,
              kind,
              child: clampedText(value, style: style),
            ),
          ),
          hasLength(1),
          reason: 'the wrapper drew the text but attached no annotation',
        );
        expect(
          await annotationsOf((style) => clampedText(value, style: style)),
          isEmpty,
        );
      });
    }

    test('returns the child untouched when there is no target', () async {
      // Not "an annotation to nowhere" and not a zero-area hot spot: the
      // wrapper is absent entirely, so a refused value costs the page nothing.
      expect(
        await drawnPage(
          (style) => contactLink(
            'on request',
            ContactKind.email,
            child: clampedText('on request', style: style),
          ),
        ),
        await drawnPage((style) => clampedText('on request', style: style)),
      );
      expect(
        await annotationsOf(
          (style) => contactLink(
            'on request',
            ContactKind.email,
            child: clampedText('on request', style: style),
          ),
        ),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------
  // Every design in the catalog.
  // ---------------------------------------------------------------------
  for (final template in resumeTemplates) {
    group('template "${template.id}" contact links', () {
      test('makes the email address open a mailto', () async {
        // The QA ask, stated as the user would: tapping the address in the
        // exported PDF starts an email to it.
        expect(
          await targetsOf(template, sampleResume),
          contains('mailto:amara.okonkwo@example.com'),
          reason: 'this design draws the email address but it is not tappable',
        );
      });

      test('makes the phone number dial the number as typed', () async {
        expect(
          await targetsOf(template, sampleResume),
          contains('tel:+14155550134'),
          reason: 'this design draws the phone number but it is not tappable',
        );
      });

      test('dials the digits, not the punctuation on the page', () async {
        // The one that would pass a screenshot review and fail a caller.
        for (final target in await targetsOf(template, sampleResume)) {
          if (!target.startsWith('tel:')) continue;
          expect(
            target,
            matches(RegExp(r'^tel:\+?[0-9]+$')),
            reason: 'a tel: target carrying separators: "$target"',
          );
        }
      });

      test('draws no annotation for a blank email or phone', () async {
        // Not "a link to the empty string" and not a zero-area hot spot —
        // nothing at all, exactly as a blank URL produces nothing today.
        final targets = await targetsOf(
          template,
          withContact(email: '', phone: '   '),
        );
        expect(targets.where((t) => t.startsWith('mailto:')), isEmpty);
        expect(targets.where((t) => t.startsWith('tel:')), isEmpty);
        // ...and the URLs are untouched by their absence.
        expect(targets, contains('https://amara.design'));
      });

      test('draws no annotation for a value that is not one', () async {
        // Still drawn as ink — nothing about the display changes — just not
        // linked, which is what a URL field does with prose today.
        final targets = await targetsOf(
          template,
          withContact(email: 'on request', phone: 'ask me'),
        );
        expect(targets.where((t) => t.startsWith('mailto:')), isEmpty);
        expect(targets.where((t) => t.startsWith('tel:')), isEmpty);
      });

      test('annotates nothing when every linkable field is blank', () async {
        // Not "a link to the empty string" and not "a link to the page it sits
        // on" — nothing at all, on a page that is otherwise full.
        for (final blank in ['', '   ', '\t ']) {
          expect(
            await linksOf(template, withEveryLinkable(blank)),
            isEmpty,
            reason: 'a blank field left an annotation behind',
          );
        }
      });

      test('annotates nothing when every linkable field is prose', () async {
        // Every one of these is still drawn as ink. None of them is a promise
        // this app can keep, so none of them is linked.
        for (final prose in ['available on request', 'n/a', 'ask me', 'TBD']) {
          expect(
            await linksOf(template, withEveryLinkable(prose)),
            isEmpty,
            reason: '"$prose" became a link to nonsense',
          );
        }
      });

      test('leaves a phone number with an extension unlinked', () async {
        final targets = await targetsOf(
          template,
          withContact(
            email: 'amara.okonkwo@example.com',
            phone: '+1 (415) 555-0134 x210',
          ),
        );
        expect(
          targets.where((t) => t.startsWith('tel:')),
          isEmpty,
          reason: 'the extension digits would have been dialled',
        );
        // The email beside it is unaffected: one refusal is not five.
        expect(targets, contains('mailto:amara.okonkwo@example.com'));
      });

      test('every annotation is borderless and over a real area', () async {
        // A border is a rectangle some viewers paint over the type, which
        // would be exactly the display change item 2 forbids. A zero-area or
        // off-page rect is a hot spot the reader can never hit.
        final links = await linksOf(template, sampleResume);
        expect(links, isNotEmpty);
        for (final link in links) {
          expect(
            link.border.split(RegExp(r'\s+')).where((s) => s.isNotEmpty),
            ['0', '0', '0'],
            reason: 'a visible link border would alter the drawn page',
          );
          expect(link.rect, hasLength(4), reason: 'no /Rect on ${link.uri}');
          final [x0, y0, x1, y1] = link.rect;
          expect(x1 - x0, greaterThan(1), reason: 'flat rect on ${link.uri}');
          expect(y1 - y0, greaterThan(1), reason: 'flat rect on ${link.uri}');
          expect(x0, greaterThanOrEqualTo(-0.5));
          expect(y0, greaterThanOrEqualTo(-0.5));
          expect(x1, lessThanOrEqualTo(596.0)); // A4 width in points
          expect(y1, lessThanOrEqualTo(843.0)); // A4 height in points
        }
      });

      test('every annotation names a scheme this catalog may emit', () async {
        // The superset of `link_target_test.dart`'s http(s)-only assertion.
        // A PDF viewer follows whatever scheme an annotation names, so this is
        // the line that keeps `javascript:` and `file:` off the page.
        for (final link in await linksOf(template, sampleResume)) {
          expect(
            RegExp(r'^(https?://|mailto:|tel:)').hasMatch(link.uri),
            isTrue,
            reason: 'annotation target "${link.uri}" names a forbidden scheme',
          );
        }
      });

      test('draws one annotation per value, never a duplicate', () async {
        // dart_pdf builds an annotation at paint time, so a subtree painted
        // twice would stack two identical hot areas — invisible, and it would
        // grow with every render.
        final targets = await targetsOf(template, sampleResume);
        expect(
          targets.toSet().length,
          targets.length,
          reason: 'duplicate link annotations: $targets',
        );
        // Six linkable fields in the sample: email, phone, LinkedIn, website
        // and two project links. No design may exceed that.
        expect(targets.length, lessThanOrEqualTo(6));
      });
    });
  }

  test('no design links anything the user did not type', () async {
    // A catch-all against a template hard-coding a contact of its own — a
    // designer's address, a placeholder left in during development. Every
    // target on every page must trace back to a field in the data.
    //
    // The superseding form of the same check in `link_target_test.dart`, which
    // predates email and phone being linkable and so allows only URL targets.
    final data = sampleResume;
    final allowed = {
      emailTarget(data.personalInfo.email),
      telTarget(data.personalInfo.phone),
      urlTarget(data.personalInfo.linkedin),
      urlTarget(data.personalInfo.website),
      for (final project in data.projects) urlTarget(project.link),
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

  test('an empty resume produces no annotation anywhere', () async {
    // The state a new user starts in. Every field blank must mean every
    // annotation absent, not thirteen zero-area hot spots at the origin.
    for (final template in resumeTemplates) {
      expect(
        await linksOf(template, const ResumeData()),
        isEmpty,
        reason: '${template.id} annotated an empty resume',
      );
    }
  });
}
