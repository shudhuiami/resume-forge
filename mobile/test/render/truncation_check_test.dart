import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/truncation_check.dart';
import 'package:resume_forge/templates/registry.dart';

/// Guards the one thing a resume builder must never do quietly: leave a job off
/// the resume.
///
/// The check is the app's only defence against that, so a hole in it is worse
/// than not having it: the absence of a warning reads as "everything fitted".
/// Two such holes are pinned below — custom sections, which it never looked at
/// at all, and a blank trailing row, which used to switch a whole section's
/// check off.
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

  /// The shipped sample with [n] certifications instead of one.
  ///
  /// No design in the catalog reserves room for more than five items in a
  /// custom section — several cap at three — so at twelve the tail is beyond
  /// every one of them and the loss is not a judgement call.
  ResumeData withCertifications(int n, {String title = 'Certifications'}) =>
      sampleResume.copyWith(
        customSections: [
          sampleResume.customSections.first.copyWith(
            sectionTitle: title,
            items: List.generate(
              n,
              (i) => CustomItem(
                id: 'ci-$i',
                title: 'Certified Professional in Accessibility Core $i',
                subtitle: 'IAAP · 202$i',
              ),
            ),
          ),
        ],
      );

  List<Skill> longSkills(int n) => List.generate(
    n,
    (i) => Skill(
      id: 'sk-$i',
      name: 'Capability number $i in the catalogue of things',
      level: i % 6,
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

  test('a custom section that overflows is reported, by its own name', () async {
    // QA-13. Certifications, publications and languages all live here, and for
    // a long time this was the one part of the model the check never looked at:
    // Ledger and Linen dropped the whole Certifications block off a four-role
    // resume and the report came back empty.
    for (final template in resumeTemplates) {
      final report = await TruncationCheck.run(
        template: template,
        data: withCertifications(12),
      );

      expect(
        report.sections,
        contains('Certifications'),
        reason:
            '${template.id} silently dropped certifications the user typed; '
            'no design in the catalog holds twelve of them',
      );
      expect(
        report.describe(),
        contains('Certifications'),
        reason: 'the warning has to name the section the user recognises',
      );
    }
  });

  test('an untitled custom section still has something to call it', () async {
    final report = await TruncationCheck.run(
      template: templateById('ledger'),
      data: withCertifications(12, title: '   '),
    );

    expect(report.sections, contains('extra sections'));
    expect(report.describe(), isNot(contains('  ')));
  });

  test('a blank row at the end does not switch a section off', () async {
    // The editor adds an empty row the moment you tap "add", so a resume in
    // progress routinely ends in one. A blank entry shadows to itself, and
    // taking that at face value used to mean the section was never checked —
    // the resume with *more* rows in it would report *less* loss.
    for (final template in resumeTemplates) {
      final plain = await TruncationCheck.run(
        template: template,
        data: sampleResume.copyWith(skills: longSkills(24)),
      );
      final trailingBlank = await TruncationCheck.run(
        template: template,
        data: sampleResume.copyWith(
          skills: [
            ...longSkills(24),
            const Skill(id: 'sk-blank', name: ''),
          ],
        ),
      );

      expect(
        trailingBlank.sections,
        plain.sections,
        reason:
            'adding an empty row to ${template.id} changed what the check '
            'reports about the twenty-four rows in front of it',
      );
    }
  });

  test('a section with nothing on the page is reported as such', () async {
    final data = withCertifications(
      12,
    ).copyWith(experiences: withRoles(20).experiences);

    var reportedEntirelyGone = 0;
    for (final template in resumeTemplates) {
      final report = await TruncationCheck.run(template: template, data: data);

      expect(
        report.emptied.every(report.sections.contains),
        isTrue,
        reason:
            '${template.id} reported a section as entirely missing without '
            'reporting it as missing at all',
      );
      if (report.emptied.isNotEmpty) reportedEntirelyGone++;
    }

    expect(
      reportedEntirelyGone,
      greaterThan(0),
      reason:
          'twenty roles and twelve certifications leave no design in the '
          'catalog room for everything, so if not one of them lost a whole '
          'section the distinction is never being drawn and the warning is '
          'back to under-stating what happened',
    );
  });

  test('an empty resume is not reported as truncated', () async {
    final report = await TruncationCheck.run(
      template: templateById('aurora'),
      data: const ResumeData(),
    );

    expect(report.hasLoss, isFalse);
  });

  group('mightOverflow gate', () {
    test('skips a resume too small to be at risk', () {
      // Cheapest possible answer for the common case: no renders at all.
      expect(TruncationCheck.mightOverflow(const ResumeData()), isFalse);
      expect(TruncationCheck.mightOverflow(withRoles(1)), isFalse);
    });

    test('opens the gate before the tightest measured capacity', () {
      // The tightest design holds 4 roles, so the gate must already be open at
      // 3 or it would miss a real loss.
      expect(TruncationCheck.mightOverflow(withRoles(3)), isTrue);
    });

    test('opens the gate on sheer length even with few entries', () {
      final wordy = sampleResume.copyWith(
        experiences: [
          sampleResume.experiences.first.copyWith(description: 'x' * 2000),
        ],
        education: const [],
        projects: const [],
        skills: const [],
        customSections: const [],
      );

      expect(TruncationCheck.mightOverflow(wordy), isTrue);
    });

    test('counts education, which it used to be blind to', () {
      // Two degrees is under the entry-count threshold, and the length estimate
      // did not look at education at all — so a page's worth of institution
      // names went through the gate as a resume too small to be at risk.
      final degrees = const ResumeData().copyWith(
        education: List.generate(
          2,
          (i) => Education(id: 'edu-$i', institution: 'Institute ' * 120),
        ),
      );

      expect(TruncationCheck.mightOverflow(degrees), isTrue);
    });

    test('counts skill names, which it used to be blind to', () {
      // Nine skills is under the entry-count threshold, and their names were
      // not counted either.
      final skills = const ResumeData().copyWith(
        skills: List.generate(
          9,
          (i) => Skill(id: 'sk-$i', name: 'Enterprise capability $i ' * 12),
        ),
      );

      expect(TruncationCheck.mightOverflow(skills), isTrue);
    });

    test('opens the gate on one custom section with several items', () {
      // "Publications" is one section by the section count, and four more
      // entries than any design in the catalog reserves room for.
      final publications = const ResumeData().copyWith(
        customSections: [
          CustomSection(
            id: 'cs-1',
            sectionTitle: 'Publications',
            items: List.generate(
              6,
              (i) => CustomItem(id: 'ci-$i', title: 'Paper $i'),
            ),
          ),
        ],
      );

      expect(TruncationCheck.mightOverflow(publications), isTrue);
    });
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

  test('describe() does not say "some" when the answer is "none"', () {
    // The wording used to be the same either way, so a design that dropped the
    // whole Skills block told the user that "some" of it did not fit — which
    // reads as a trim, and is the one reading that makes them send it anyway.
    expect(
      const TruncationReport(
        ['Certifications'],
        emptied: ['Certifications'],
      ).describe(),
      'None of your Certifications will fit on the page, so it will not '
      'appear in the PDF at all.',
    );
    expect(
      const TruncationReport(
        ['skills', 'projects'],
        emptied: ['skills', 'projects'],
      ).describe(),
      contains('None of your skills and projects will fit'),
    );
    final mixed = const TruncationReport(
      ['experience', 'Certifications'],
      emptied: ['Certifications'],
    ).describe();
    expect(mixed, contains('None of your Certifications will fit'));
    expect(mixed, contains('some of your experience does not fit either'));
  });

  test('describe() stays readable to the banner that renders it', () {
    // `_TruncationBanner` and the export dialog both look for this phrasing,
    // and a screen reader stops on whatever it finds there.
    for (final report in [
      const TruncationReport(['experience']),
      const TruncationReport(['skills'], emptied: ['skills']),
      const TruncationReport(['experience', 'skills'], emptied: ['skills']),
    ]) {
      expect(report.describe(), contains('fit on the page'));
      expect(report.describe(), endsWith('.'));
    }
    expect(const TruncationReport.none().describe(), isEmpty);
    expect(const TruncationReport.none().emptied, isEmpty);
  });
}
