import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/truncation_check.dart';
import 'package:resume_forge/templates/registry.dart';

/// Guards the one thing a resume builder must never do quietly: leave a job off
/// the resume.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ResumeData withRoles(int n) => sampleResume.copyWith(
    experiences: List.generate(
      n,
      (i) => sampleResume.experiences.first.copyWith(
        id: 'exp-$i',
        company: 'Company $i',
        position: 'Role $i',
      ),
    ),
  );

  test('a resume that fits reports no loss', () async {
    final report = await TruncationCheck.run(
      template: templateById('aurora'),
      data: withRoles(2),
    );

    expect(report.hasLoss, isFalse);
    expect(report.sections, isEmpty);
    expect(report.describe(), isEmpty);
  });

  test('a resume that overflows reports the section that was cut', () async {
    // Measured capacity is 4-7 roles depending on the design; 14 overflows all
    // of them.
    final report = await TruncationCheck.run(
      template: templateById('circuit'),
      data: withRoles(14),
    );

    expect(report.hasLoss, isTrue);
    expect(report.sections, contains('experience'));
    expect(report.describe(), contains('experience'));
  });

  test('every template in the catalog drops content at some size', () async {
    // Not an aspiration — a record of current behaviour. If a template later
    // flows to a second page, this test should be revisited rather than
    // silently kept passing.
    for (final template in resumeTemplates) {
      final report = await TruncationCheck.run(
        template: template,
        data: withRoles(20),
      );

      expect(
        report.hasLoss,
        isTrue,
        reason:
            '${template.id} claims to fit 20 roles on one A4 page, which would '
            'mean the check is broken rather than the template being roomy',
      );
    }
  });

  test('an empty resume is not reported as truncated', () async {
    final report = await TruncationCheck.run(
      template: templateById('aurora'),
      data: const ResumeData(),
    );

    expect(report.hasLoss, isFalse);
  });

  test('describe() reads as a sentence for one and for several sections', () {
    expect(
      const TruncationReport(['experience']).describe(),
      'Some of your experience does not fit on the page and will not appear '
      'in the PDF.',
    );
    expect(
      const TruncationReport(['experience', 'projects']).describe(),
      contains('experience and projects'),
    );
    expect(
      const TruncationReport([
        'experience',
        'education',
        'projects',
      ]).describe(),
      contains('experience, education and projects'),
    );
  });
}
