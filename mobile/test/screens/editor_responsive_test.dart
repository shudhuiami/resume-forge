import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/form_fields.dart';

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
    ResumeData data, {
    double textScale = 1.0,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: EditorScreen(
                document: newResumeDocument().copyWith(data: data),
              ),
            ),
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

      // Doubling the type size is where a header row that pairs a fixed icon
      // tile with a wrapping heading, or a card that pads on both edges, runs
      // out of width.
      testWidgets('${entry.key} — double text size', (tester) async {
        await pumpEditor(tester, entry.value, longContent(), textScale: 2);
        expect(find.text('About you'), findsOneWidget);
      });
    }

    testWidgets('landscape phone at double text size', (tester) async {
      await pumpEditor(
        tester,
        const Size(800, 360),
        longContent(),
        textScale: 2,
      );
      expect(find.text('About you'), findsOneWidget);
    });
  });

  group('editor form structure', () {
    testWidgets('every section is a card introduced by an icon tile', (
      tester,
    ) async {
      await pumpEditor(tester, const Size(430, 4000), const ResumeData());

      // Six sections, six panels, six marks. A form that renders its groups as
      // bare text headings between fields is the layout this replaced.
      expect(find.byType(FormSectionCard), findsNWidgets(6));
      expect(find.byType(SectionIconTile), findsNWidgets(6));
    });

    testWidgets('repeating entries are grouped and labelled', (tester) async {
      // Tall enough for a filled resume to build every entry: a ListView
      // stops short of the fold, and these counts are about content.
      await pumpEditor(tester, const Size(430, 12000), sampleResume);

      final expected =
          sampleResume.experiences.length +
          sampleResume.education.length +
          sampleResume.skills.length +
          sampleResume.projects.length +
          sampleResume.customSections.length;
      expect(find.byType(EntryGroup), findsNWidgets(expected));
      expect(find.text('ROLE 1'), findsOneWidget);
      expect(find.text('ROLE 2'), findsOneWidget);
    });

    testWidgets('the photo action sits with the photo, inside About you', (
      tester,
    ) async {
      await pumpEditor(tester, const Size(430, 4000), const ResumeData());

      final aboutYou = find.ancestor(
        of: find.text('About you'),
        matching: find.byType(FormSectionCard),
      );
      expect(
        find.descendant(of: aboutYou, matching: find.text('Add photo')),
        findsOneWidget,
        reason: 'the photo control belongs to the section it fills',
      );
    });
  });

  group('editor interactions', () {
    testWidgets('adding and removing a role both work', (tester) async {
      await pumpEditor(tester, const Size(430, 4000), const ResumeData());

      expect(find.text('No roles added yet'), findsOneWidget);

      await tester.tap(find.text('Add role'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('ROLE 1'), findsOneWidget);
      expect(find.text('Position'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove this role'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('ROLE 1'), findsNothing);
      expect(find.text('No roles added yet'), findsOneWidget);
    });
  });

  group('editor with the keyboard open', () {
    testWidgets('a focused field further down is scrolled clear of it', (
      tester,
    ) async {
      const viewport = Size(390, 844);
      const keyboard = 336.0;
      await pumpEditor(tester, viewport, sampleResume, keyboard: keyboard);

      // Website is the seventh field: below the fold before the keyboard
      // opens, and squarely under it afterwards if nothing scrolls.
      final website = find.widgetWithText(TextField, 'Website');
      await tester.showKeyboard(website);
      await tester.pumpAndSettle();

      final field = tester.getRect(website);
      expect(
        field.bottom,
        lessThanOrEqualTo(viewport.height - keyboard),
        reason: 'the field being typed into cannot sit under the keyboard',
      );
      expect(field.top, greaterThanOrEqualTo(0));
    });
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

  group('editor form width', () {
    testWidgets('does not stretch single-line fields across a tablet', (
      tester,
    ) async {
      await pumpEditor(tester, const Size(768, 1024), sampleResume);

      // Edge-to-edge fields at 736px read as an admin table rather than a
      // document editor, and drag the eye across empty space between a label
      // and its value. Matches the constraint the resume list applies.
      final field = tester.getSize(find.byType(TextField).first);
      expect(
        field.width,
        lessThanOrEqualTo(640),
        reason: 'the form must stop widening past a readable measure',
      );
    });

    testWidgets('still uses the full width on a phone', (tester) async {
      await pumpEditor(tester, const Size(390, 844), sampleResume);

      final field = tester.getSize(find.byType(TextField).first);
      expect(
        field.width,
        greaterThan(300),
        reason: 'the constraint must not shrink a phone form',
      );
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
