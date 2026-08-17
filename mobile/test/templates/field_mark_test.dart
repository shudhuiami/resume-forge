import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/render/truncation_check.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// Guards THE FIELD MARK RULE at the top of `lib/templates/template.dart`.
///
/// QA-8 asked for field icons in every template; the answer was one design.
/// Two things can go wrong with that answer and both are quiet.
///
/// The first is **spread**: a later pass "makes the catalog consistent" and
/// puts marks on all thirteen, which is the gallery's differentiation being
/// spent rather than a gap being closed. Nothing in a screenshot review flags
/// that as a regression, so it is pinned here instead — the marks are counted
/// per design, and twelve of the thirteen must have none.
///
/// The second is **substitution**: a mark quietly standing in for the value it
/// labels. A resume is read by parsers as well as by people, and a drawn path
/// contributes nothing to extracted text, so a design that swapped "EMAIL" for
/// an envelope would look tidier and be worse. Every contact value is checked
/// to still reach the page.
///
/// A mark is one stroked path — `S` in the content stream — and the streams are
/// Flate-compressed, so they are inflated here rather than pattern-matched
/// through the compression.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Offset of [needle] in [bytes] at or after [from], or -1.
  int indexOf(Uint8List bytes, String needle, int from) {
    final n = needle.codeUnits;
    outer:
    for (var i = from; i <= bytes.length - n.length; i++) {
      for (var j = 0; j < n.length; j++) {
        if (bytes[i + j] != n[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  /// Every content stream in [bytes], inflated and concatenated.
  String contentStreams(Uint8List bytes) {
    final zlib = ZLibCodec();
    final out = StringBuffer();
    var i = 0;
    while (true) {
      final start = indexOf(bytes, 'stream', i);
      if (start < 0) break;
      var s = start + 'stream'.length;
      if (s < bytes.length && bytes[s] == 0x0D) s++;
      if (s < bytes.length && bytes[s] == 0x0A) s++;
      final end = indexOf(bytes, 'endstream', s);
      if (end < 0) break;
      try {
        out.write(String.fromCharCodes(zlib.decode(bytes.sublist(s, end))));
      } catch (_) {
        // A font file or an image: not a content stream, and not our business.
      }
      i = end + 'endstream'.length;
    }
    return out.toString();
  }

  final strokeOp = RegExp(r'(^|\s)S(\s|$)');

  Future<int> strokeCount(ResumeTemplate template, ResumeData data) async {
    final bytes = await PdfRenderer.build(template: template, data: data);
    return strokeOp.allMatches(contentStreams(bytes)).length;
  }

  Future<String> render(ResumeTemplate template, ResumeData data) async {
    final bytes = await PdfRenderer.build(template: template, data: data);
    return latin1
        .decode(bytes, allowInvalid: true)
        .replaceAll(RegExp(r'/CreationDate\(D:[^)]*\)'), '')
        .replaceAll(RegExp(r'/ID\[(<[0-9a-f]*>)+\]'), '');
  }

  ResumeData blankContact() => sampleResume.copyWith(
    personalInfo: sampleResume.personalInfo.copyWith(
      email: '',
      phone: '',
      location: '',
      linkedin: '',
      website: '',
    ),
  );

  /// The five fields a design may set a mark beside, in one place so the count
  /// below cannot drift from the enum.
  const contactFields = 5;

  // ---------------------------------------------------------------------
  // The rule's item 2: one design, and it is a decision rather than a gap.
  // ---------------------------------------------------------------------
  test('exactly one design in the catalog draws field marks', () async {
    // Emptying the contact block removes each design's contact text. Only a
    // design that also draws a mark per field loses stroked paths with it, so
    // this separates "draws marks" from "draws contact" without naming either.
    final marked = <String, int>{};
    for (final template in resumeTemplates) {
      final delta =
          await strokeCount(template, sampleResume) -
          await strokeCount(template, blankContact());
      if (delta != 0) marked[template.id] = delta;
    }

    expect(
      marked.keys,
      ['aurora'],
      reason:
          'field marks have spread beyond the one design that opted into '
          'them — see THE FIELD MARK RULE, item 2. Adding a mark to a design '
          'is a design decision, not a consistency fix.',
    );
    expect(
      marked['aurora'],
      contactFields,
      reason: 'aurora should draw exactly one mark per contact field',
    );
  });

  group('aurora field marks', () {
    final aurora = resumeTemplates.firstWhere((t) => t.id == 'aurora');

    test('draws one mark per field the user filled in, and no more', () async {
      final all = await strokeCount(aurora, sampleResume);
      for (final drop in [
        sampleResume.personalInfo.copyWith(email: ''),
        sampleResume.personalInfo.copyWith(phone: ''),
        sampleResume.personalInfo.copyWith(location: ''),
        sampleResume.personalInfo.copyWith(linkedin: ''),
        sampleResume.personalInfo.copyWith(website: ''),
      ]) {
        expect(
          await strokeCount(aurora, sampleResume.copyWith(personalInfo: drop)),
          all - 1,
          reason: 'removing one contact field must remove exactly one mark',
        );
      }
    });

    test('draws no mark for a blank or whitespace-only field', () async {
      // An icon with nothing beside it is worse than no icon: it reads as a
      // value that failed to render.
      final blank = await strokeCount(
        aurora,
        sampleResume.copyWith(
          personalInfo: sampleResume.personalInfo.copyWith(location: ''),
        ),
      );
      expect(
        await strokeCount(
          aurora,
          sampleResume.copyWith(
            personalInfo: sampleResume.personalInfo.copyWith(location: '   '),
          ),
        ),
        blank,
      );
      expect(
        await strokeCount(aurora, blankContact()),
        await strokeCount(aurora, sampleResume) - contactFields,
      );
    });

    test('never lets a mark stand in for the value beside it', () async {
      // Rule item 3. Each field is swapped for a same-shaped alternative; if
      // the value still reaches the page the drawn glyphs change, and if the
      // mark had replaced it the two renders would be identical.
      final info = sampleResume.personalInfo;
      final swaps = <String, PersonalInfo>{
        'email': info.copyWith(email: 'zzzzz.zzzzzzz@zzzzzzz.zzz'),
        'phone': info.copyWith(phone: '+9 (999) 999-9999'),
        'location': info.copyWith(location: 'Zzz Zzzzzzzzz, ZZ'),
        'linkedin': info.copyWith(linkedin: 'zzzxrqva.pbz/va/nznenbxbaxjb'),
        'website': info.copyWith(website: 'nznen.qrfvta'),
      };

      final base = await render(aurora, sampleResume);
      for (final entry in swaps.entries) {
        expect(
          await render(
            aurora,
            sampleResume.copyWith(personalInfo: entry.value),
          ),
          isNot(base),
          reason:
              'changing ${entry.key} changed nothing on the page — its mark '
              'is being drawn in place of the value, not beside it',
        );
      }
    });

    test('the marks cost the design no content', () async {
      // The marks narrow the rail's text column by 13pt. dart_pdf deletes a
      // Column child that no longer fits rather than clipping it, so the way
      // this would fail is a whole section vanishing (see the ENGINE HAZARD
      // note) — not a visibly cramped line.
      for (final data in [
        sampleResume,
        sampleResume.copyWith(
          personalInfo: sampleResume.personalInfo.copyWith(
            linkedin:
                'https://linkedin.com/in/alexandra-whitfield-morrison-8b4a12345',
            website:
                'https://alexandra-whitfield-morrison.portfolio.example.com/work',
          ),
        ),
      ]) {
        final report = await TruncationCheck.run(template: aurora, data: data);
        expect(report.sections, isEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------
  // The helper itself.
  // ---------------------------------------------------------------------
  group('fieldMark', () {
    Future<String> drawAlone(FieldMark mark, double size) async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => fieldMark(
            mark,
            size: size,
            color: const PdfColor.fromInt(0xFF000000),
          ),
        ),
      );
      return contentStreams(Uint8List.fromList(await doc.save()));
    }

    test('draws every mark in the enum', () async {
      // A mark that silently draws nothing is the failure a rasterized preview
      // hides best: an empty 7.6pt box beside a value looks like alignment.
      for (final mark in FieldMark.values) {
        final stream = await drawAlone(mark, 12);
        expect(
          strokeOp.allMatches(stream).length,
          1,
          reason: '$mark did not draw exactly one stroked path',
        );
      }
    });

    test('scales its stroke with its size', () async {
      // Rule item 4: a fixed point width would be a hairline beside 8pt type
      // and a slab beside 14pt.
      double lineWidth(String stream) =>
          double.parse(RegExp(r'([\d.]+)\s+w').firstMatch(stream)!.group(1)!);

      final small = lineWidth(await drawAlone(FieldMark.email, 12));
      final large = lineWidth(await drawAlone(FieldMark.email, 24));
      expect(large / small, closeTo(2, 0.01));
      // 24 grid units at 24pt is 1:1, so the default weight shows through.
      expect(large, closeTo(1.9, 0.01));
    });
  });
}
