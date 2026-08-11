import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/templates/registry.dart';

/// Contract every design in the catalog must satisfy.
///
/// Runs against the registry rather than a hand-maintained list, so a template
/// added tomorrow is covered without touching this file.
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

  test('the catalog is not empty and has unique ids', () {
    expect(resumeTemplates, isNotEmpty);

    final ids = resumeTemplates.map((t) => t.id).toList();
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'a duplicate id would make templateById ambiguous',
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
    });
  }
}
