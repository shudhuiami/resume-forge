import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';

void main() {
  group('ResumeData serialization', () {
    test('round-trips the sample resume without loss', () {
      final json = sampleResume.toJson();
      final restored = ResumeData.fromJson(json);

      expect(restored, equals(sampleResume));
    });

    test('survives an encode/decode cycle through a JSON string', () {
      final encoded = jsonEncode(sampleResume.toJson());
      final restored = ResumeData.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored, equals(sampleResume));
      expect(restored.experiences.length, 3);
      expect(restored.experiences.first.current, isTrue);
      final cert = restored.customSections.first.items.first;
      expect(cert.title, contains('Accessibility'));
      expect(cert.subtitle, contains('IAAP'));
    });

    test('round-trips photo bytes through base64', () {
      final bytes = Uint8List.fromList(List<int>.generate(256, (i) => i));
      final withPhoto = sampleResume.copyWith(
        personalInfo: sampleResume.personalInfo.copyWith(photo: bytes),
      );

      final restored = ResumeData.fromJson(
        jsonDecode(jsonEncode(withPhoto.toJson())) as Map<String, dynamic>,
      );

      expect(restored.personalInfo.photo, equals(bytes));
    });

    test('treats a corrupt photo payload as absent rather than throwing', () {
      final json = sampleResume.toJson();
      (json['personalInfo'] as Map<String, dynamic>)['photo'] = 'not-base64!!!';

      expect(
        () => ResumeData.fromJson(json),
        returnsNormally,
        reason: 'a corrupt photo must not take the whole resume down',
      );
      expect(ResumeData.fromJson(json).personalInfo.photo, isNull);
    });

    test('defaults produce a usable empty document', () {
      const empty = ResumeData();

      expect(empty.isEmpty, isTrue);
      expect(empty.experiences, isEmpty);
      expect(empty.personalInfo.fullName, '');
      expect(ResumeData.fromJson(empty.toJson()), equals(empty));
    });

    test('sample resume is not considered empty', () {
      expect(sampleResume.isEmpty, isFalse);
    });
  });

  group('ResumeDocument', () {
    ResumeDocument doc(ResumeData data) => ResumeDocument(
      id: 'doc-1',
      templateId: 'aurora',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      data: data,
    );

    test('round-trips including timestamps', () {
      final original = doc(sampleResume);
      final restored = ResumeDocument.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored, equals(original));
      expect(restored.updatedAt, DateTime.utc(2026, 1, 2));
    });

    test('displayTitle falls back through name, title, then placeholder', () {
      expect(doc(sampleResume).displayTitle, 'Amara Okonkwo');

      final titleOnly = doc(
        const ResumeData(personalInfo: PersonalInfo(title: 'Data Engineer')),
      );
      expect(titleOnly.displayTitle, 'Data Engineer');

      expect(doc(const ResumeData()).displayTitle, 'Untitled resume');
    });

    test('displayTitle ignores whitespace-only names', () {
      final blank = doc(
        const ResumeData(personalInfo: PersonalInfo(fullName: '   ')),
      );

      expect(blank.displayTitle, 'Untitled resume');
    });
  });
}
