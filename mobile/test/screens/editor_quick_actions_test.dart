import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// The editor's two whole-document actions: load the sample, and clear.
///
/// Both throw away whatever the user has typed, so the confirm-then-cancel path
/// matters as much as the happy one: a cancelled destructive action must leave
/// the form *and* storage exactly as they were.
void main() {
  /// Something the user could plausibly have typed themselves, with enough in
  /// it that "untouched" is a claim about real content.
  final ownWork = ResumeData(
    personalInfo: const PersonalInfo(
      fullName: 'Priya Raman',
      title: 'Backend Engineer',
      email: 'priya.raman@example.com',
      summary: 'Distributed systems, mostly payments.',
    ),
    experiences: const [
      Experience(
        id: 'own-1',
        company: 'Halden Systems',
        position: 'Staff Engineer',
        startDate: '2020-01',
        current: true,
      ),
    ],
  );

  late InMemoryResumeRepository repo;
  late ResumeDocument doc;

  /// A viewport tall enough to build the whole form at once, so assertions are
  /// about content rather than about how far a ListView has been scrolled.
  ///
  /// Deliberately generous. The form's height is not fixed — the phone field's
  /// country control drops below the number when the two cannot share a line,
  /// and under the test font (every glyph a full em box) that happens at widths
  /// where a device with Inter loaded still fits them side by side. A viewport
  /// sized to the form as it is today would fail the next time any field grows
  /// a line, rather than the next time this screen actually breaks.
  const tall = Size(430, 6000);

  Future<void> pumpEditor(
    WidgetTester tester,
    ResumeData data, {
    Size size = tall,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    doc = newResumeDocument().copyWith(data: data);
    // Mirrors the real flow: the list screen writes the document before it
    // pushes the editor, so storage has something to be left untouched.
    await repo.save(doc);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: EditorScreen(document: doc),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pumps without settling: the preview tab holds a progress indicator that
  /// never stops animating, so `pumpAndSettle` would spin forever.
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More actions'));
    await pumpFrames(tester);
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await pumpFrames(tester);
  }

  Future<void> tapDialogButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await pumpFrames(tester);
  }

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await pumpFrames(tester);
  }

  /// Scoped to the form, because the app bar title shows the same name.
  Finder inForm(Finder finder) => find.descendant(
    of: find.byKey(const Key('editor-form-list')),
    matching: finder,
  );

  /// Lets the autosave debounce fire and the snackbar expire, so no timer is
  /// left pending when the test ends.
  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
  }

  Future<ResumeData> stored() async => (await repo.byId(doc.id))!.data;

  group('load sample data', () {
    testWidgets('an empty resume is filled without stopping to ask', (
      tester,
    ) async {
      await pumpEditor(tester, const ResumeData());
      await openMenu(tester);
      await choose(tester, 'Load sample data');

      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'there was nothing to lose, so nothing to confirm',
      );
      expect(inForm(find.text('Amara Okonkwo')), findsOneWidget);
      expect(inForm(find.text('Senior Product Designer')), findsWidgets);
      expect(
        inForm(find.text('Northwind Analytics International')),
        findsOneWidget,
        reason: 'every section must fill, not just the contact block',
      );
      expect(
        inForm(find.text('Design systems')),
        findsOneWidget,
        reason: 'skills are part of the sample too',
      );

      await quiesce(tester);
      expect(
        await stored(),
        equals(sampleResume),
        reason: 'the edit must go through the controller, so autosave runs',
      );
    });

    testWidgets(
      'written content is confirmed first, and cancel changes nothing',
      (tester) async {
        await pumpEditor(tester, ownWork);
        await openMenu(tester);
        await choose(tester, 'Load sample data');

        expect(find.text('Replace what you have written?'), findsOneWidget);

        await tapCancel(tester);

        expect(inForm(find.text('Priya Raman')), findsOneWidget);
        expect(inForm(find.text('Halden Systems')), findsOneWidget);
        expect(
          find.text('Amara Okonkwo'),
          findsNothing,
          reason: 'a cancelled replace must not touch the form',
        );

        await quiesce(tester);
        expect(
          await stored(),
          equals(ownWork),
          reason: 'a cancelled replace must not touch storage either',
        );
      },
    );

    testWidgets('confirming replaces the whole document', (tester) async {
      await pumpEditor(tester, ownWork);
      await openMenu(tester);
      await choose(tester, 'Load sample data');
      await tapDialogButton(tester, 'Replace');

      expect(inForm(find.text('Amara Okonkwo')), findsOneWidget);
      expect(
        find.text('Priya Raman'),
        findsNothing,
        reason: 'stale text left in a field would be edited back into the PDF',
      );
      expect(find.text('Halden Systems'), findsNothing);
      expect(find.text('Sample resume loaded.'), findsOneWidget);

      await quiesce(tester);
      expect(await stored(), equals(sampleResume));
    });

    testWidgets('undo puts the replaced content back', (tester) async {
      await pumpEditor(tester, ownWork);
      await openMenu(tester);
      await choose(tester, 'Load sample data');
      await tapDialogButton(tester, 'Replace');

      await tester.tap(find.text('Undo'));
      await pumpFrames(tester);

      expect(inForm(find.text('Priya Raman')), findsOneWidget);
      expect(inForm(find.text('Halden Systems')), findsOneWidget);
      expect(find.text('Amara Okonkwo'), findsNothing);

      await quiesce(tester);
      expect(await stored(), equals(ownWork));
    });
  });

  group('clear', () {
    testWidgets('confirming empties every section', (tester) async {
      await pumpEditor(tester, sampleResume);
      await openMenu(tester);
      await choose(tester, 'Clear all fields');

      expect(find.text('Clear this resume?'), findsOneWidget);

      await tapDialogButton(tester, 'Clear');

      expect(find.text('Amara Okonkwo'), findsNothing);
      expect(find.text('Northwind Analytics International'), findsNothing);
      expect(find.text('Design systems'), findsNothing);
      expect(
        find.text('No roles added yet'),
        findsOneWidget,
        reason: 'the emptied sections must fall back to their empty state',
      );
      expect(find.text('Resume cleared.'), findsOneWidget);

      await quiesce(tester);
      expect(await stored(), equals(const ResumeData()));
    });

    testWidgets('cancelling leaves every field where it was', (tester) async {
      await pumpEditor(tester, sampleResume);
      await openMenu(tester);
      await choose(tester, 'Clear all fields');
      await tapCancel(tester);

      expect(inForm(find.text('Amara Okonkwo')), findsOneWidget);
      expect(
        inForm(find.text('Northwind Analytics International')),
        findsOneWidget,
      );

      await quiesce(tester);
      expect(
        await stored(),
        equals(sampleResume),
        reason: 'a cancelled clear must not write an emptied document',
      );
    });

    testWidgets('undo puts the cleared content back', (tester) async {
      await pumpEditor(tester, sampleResume);
      await openMenu(tester);
      await choose(tester, 'Clear all fields');
      await tapDialogButton(tester, 'Clear');

      await tester.tap(find.text('Undo'));
      await pumpFrames(tester);

      expect(inForm(find.text('Amara Okonkwo')), findsOneWidget);
      expect(
        inForm(find.text('Northwind Analytics International')),
        findsOneWidget,
      );

      await quiesce(tester);
      expect(await stored(), equals(sampleResume));
    });

    testWidgets('is offered as unavailable when there is nothing to clear', (
      tester,
    ) async {
      await pumpEditor(tester, const ResumeData());
      await openMenu(tester);

      final item =
          find
                  .ancestor(
                    of: find.text('Clear all fields'),
                    matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
                  )
                  .evaluate()
                  .single
                  .widget
              as PopupMenuItem;
      expect(
        item.enabled,
        isFalse,
        reason: 'clearing a blank resume would be a control that does nothing',
      );

      // And it behaves as it looks: the tap is inert rather than opening a
      // confirmation for an action with nothing to do.
      await tester.tap(find.text('Clear all fields'));
      await pumpFrames(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('placement', () {
    for (final entry in const {
      'phone small': Size(360, 800),
      'phone normal': Size(390, 844),
      'phone large': Size(430, 932),
      'tablet': Size(768, 1024),
    }.entries) {
      testWidgets('${entry.key} — the menu opens and the form keeps the fold', (
        tester,
      ) async {
        await pumpEditor(tester, sampleResume, size: entry.value);

        // The whole point of putting these in the app bar: the first thing the
        // user came to type is still on screen.
        final firstField = tester.getRect(find.text('Full name').first);
        expect(
          firstField.bottom,
          lessThan(entry.value.height),
          reason: 'a quick-action row must not push the form below the fold',
        );

        await openMenu(tester);
        expect(find.text('Load sample data'), findsOneWidget);
        expect(find.text('Clear all fields'), findsOneWidget);
      });
    }
  });
}
