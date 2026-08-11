import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/templates/aurora/aurora_template.dart';

void main() {
  // rootBundle needs the binding to load font assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  const template = AuroraTemplate();

  Future<Uint8List> render(ResumeData data) =>
      PdfRenderer.build(template: template, data: data);

  /// Counts page objects in the PDF.
  ///
  /// The negative lookahead matters: `/Type /Pages` is the page-*tree* node and
  /// would otherwise be counted as a page, making every document look like it
  /// had one more page than it does.
  int pageCount(Uint8List bytes) {
    final body = latin1.decode(bytes, allowInvalid: true);
    return RegExp(r'/Type\s*/Page(?![s])').allMatches(body).length;
  }

  group('Aurora fidelity probe', () {
    test('renders the sample resume to a valid single-page PDF', () async {
      final bytes = await render(sampleResume);

      expect(bytes.length, greaterThan(1000));
      expect(
        latin1.decode(bytes.sublist(0, 5)),
        '%PDF-',
        reason: 'output must be a real PDF, not an error payload',
      );

      expect(pageCount(bytes), 1, reason: 'the design is a one-page resume');
    });

    test('embeds real fonts so exported text is machine-extractable', () async {
      final bytes = await render(sampleResume);
      final body = latin1.decode(bytes, allowInvalid: true);

      // An embedded font program plus a font object is what separates a text
      // PDF from a rasterized one. ATS parsers cannot read the latter, so this
      // is a product requirement, not a nicety.
      expect(body, contains('/FontFile2'));
      expect(body, contains('/Font'));
    });

    test('renders without a photo', () async {
      final bytes = await render(sampleResume);
      expect(bytes.length, greaterThan(1000));
    });

    test('renders with a photo in the overlapping circular frame', () async {
      // 8x8 solid PNG — exercises the real decode + ClipOval path.
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGMQ2bEMK2IYWhIAAGRcgXCff0gAAAAASUVORK5CYII=',
      );
      final withPhoto = sampleResume.copyWith(
        personalInfo: sampleResume.personalInfo.copyWith(photo: png),
      );

      final bytes = await render(withPhoto);
      expect(bytes.length, greaterThan(1000));
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test(
      'a corrupt photo degrades to no portrait instead of failing the render',
      () async {
        final data = sampleResume.copyWith(
          personalInfo: sampleResume.personalInfo.copyWith(
            photo: Uint8List.fromList(List.filled(64, 0x7F)),
          ),
        );

        // pw.MemoryImage throws on undecodable bytes and that propagates out of
        // Document.save(), so without a guard one bad photo loses the whole resume.
        final bytes = await render(data);
        expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(pageCount(bytes), 1);
      },
    );

    test('renders an entirely empty resume without throwing', () async {
      final bytes = await render(const ResumeData());

      expect(bytes.length, greaterThan(500));
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('survives pathologically long user content', () async {
      final long = 'Wolfeschlegelsteinhausenbergerdorff ' * 40;
      final data = sampleResume.copyWith(
        personalInfo: sampleResume.personalInfo.copyWith(
          fullName: long,
          title: long,
          summary: long * 3,
        ),
        experiences: [
          sampleResume.experiences.first.copyWith(
            company: long,
            position: long,
            description: long * 2,
          ),
          ...sampleResume.experiences.skip(1),
        ],
      );

      final bytes = await render(data);
      expect(
        bytes.length,
        greaterThan(1000),
        reason: 'long content must clip, not throw or overflow the page',
      );

      expect(
        pageCount(bytes),
        1,
        reason: 'clipping must keep the resume on one page',
      );
    });

    test(
      'handles many skills and sections without spilling to page two',
      () async {
        final data = sampleResume.copyWith(
          skills: List.generate(
            20,
            (i) => Skill(id: 'sk-$i', name: 'Skill number $i', level: i % 6),
          ),
        );

        final bytes = await render(data);
        expect(pageCount(bytes), 1);
      },
    );
  });
}
