import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// Responsive and overflow verification for the editor.
///
/// Flutter surfaces a RenderFlex overflow as a framework error, which fails the
/// test that provoked it. That makes these pumps real assertions: if any of
/// these viewport/content combinations overflows, this file goes red.
void main() {
  const viewports = {
    'phone small': Size(360, 800),
    'phone normal': Size(390, 844),
    'phone large': Size(430, 932),
    'tablet': Size(768, 1024),
  };

  /// Content chosen to break naive layouts: an unbroken 66-character company
  /// name, a long job title, and a skill label longer than any column.
  ResumeData longContent() {
    const long =
        'Wolfeschlegelsteinhausenbergerdorff-Featherstonehaugh International';
    return sampleResume.copyWith(
      personalInfo: sampleResume.personalInfo.copyWith(
        fullName: long,
        title:
            'Principal Staff Product Designer, Platform and Design Systems Group',
      ),
      experiences: [
        sampleResume.experiences.first.copyWith(
          company: long,
          position: 'Principal Staff Product Designer, Platform Experience',
        ),
        ...sampleResume.experiences.skip(1),
      ],
      skills: [
        ...sampleResume.skills,
        const Skill(
          id: 'sk-long',
          name: 'An Extremely Long Skill Name That Must Truncate Gracefully',
          level: 4,
        ),
      ],
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester,
    Size size,
    ResumeData data,
  ) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: EditorScreen(
            document: newResumeDocument().copyWith(data: data),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('editor lays out without overflow', () {
    for (final entry in viewports.entries) {
      testWidgets('${entry.key} — realistic content', (tester) async {
        await pumpEditor(tester, entry.value, sampleResume);
        // Only assert what is on screen: a ListView does not build children
        // below the fold, so a deeper section is checked by the scroll test.
        expect(find.text('About you'), findsOneWidget);
      });

      testWidgets('${entry.key} — pathological content', (tester) async {
        await pumpEditor(tester, entry.value, longContent());
        expect(find.text('About you'), findsOneWidget);
      });

      testWidgets('${entry.key} — empty resume', (tester) async {
        await pumpEditor(tester, entry.value, const ResumeData());
        expect(find.text('About you'), findsOneWidget);
      });
    }
  });

  group('editor exposes every section and add action', () {
    // A tall viewport renders the whole form at once, so these assertions test
    // the form's content rather than scroll mechanics inside a TabBarView.
    testWidgets('all sections and their add actions are present', (
      tester,
    ) async {
      await pumpEditor(tester, const Size(430, 4000), const ResumeData());

      for (final section in [
        'About you',
        'Experience',
        'Education',
        'Skills',
        'Projects',
        'Custom sections',
      ]) {
        expect(find.text(section), findsOneWidget, reason: 'section $section');
      }

      for (final action in [
        'Add role',
        'Add education',
        'Add skill',
        'Add project',
        'Add section',
      ]) {
        expect(find.text(action), findsOneWidget, reason: 'action $action');
      }

      // Empty repeating sections must explain themselves rather than
      // rendering as an unlabelled gap.
      expect(find.text('No roles added yet'), findsOneWidget);
      expect(find.text('No education added yet'), findsOneWidget);
    });
  });

  group('editor exposes its actions', () {
    testWidgets('design switch and export are both reachable', (tester) async {
      await pumpEditor(tester, const Size(390, 844), sampleResume);

      expect(
        find.byTooltip('Change design'),
        findsOneWidget,
        reason: 'switching design is the product premise; it cannot be hidden',
      );
      expect(find.byTooltip('Export PDF'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
    });
  });
}
