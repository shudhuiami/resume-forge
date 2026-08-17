import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/form_fields.dart';

/// The form has to agree with the document it is editing.
///
/// Every field used to be seeded once with `initialValue`, so anything that
/// changed the model without the keyboard left the screen behind. The editor
/// worked around the three whole-document actions by rebuilding the form from a
/// revision key; this is about the case that had no workaround, and about the
/// end-to-end behaviour now that the fields own their controllers.
void main() {
  /// Tall enough to build the whole form, so these are assertions about content
  /// rather than about how far a list has been scrolled.
  const tall = Size(430, 4000);

  late InMemoryResumeRepository repo;

  Future<ResumeDocument> pumpEditor(
    WidgetTester tester,
    ResumeData data,
  ) async {
    tester.view.physicalSize = tall * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    final doc = newResumeDocument().copyWith(data: data);
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
    return doc;
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lets the autosave debounce and any snackbar expire, so nothing is left
  /// pending when the test ends.
  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
  }

  ResumeData roleEnding(String end) => ResumeData(
    personalInfo: const PersonalInfo(fullName: 'Priya Raman'),
    experiences: [
      Experience(
        id: 'e1',
        position: 'Staff Engineer',
        company: 'Halden Systems',
        startDate: '2019-04',
        endDate: end,
      ),
    ],
  );

  group('the current-role switch and the end date', () {
    /// This one shipped broken. Switching "I currently work here" on clears
    /// `endDate` in the model — the PDF starts printing "Present" — but the
    /// seeded field kept showing the old date, so the form disagreed with the
    /// document and with the export, and the only way to clear the visible
    /// value was to select it and delete it by hand.
    testWidgets('turning it on clears the date the user can see', (
      tester,
    ) async {
      await pumpEditor(tester, roleEnding('2021-06'));

      expect(find.text('2021-06'), findsOneWidget);

      await tester.tap(find.text('I currently work here'));
      await pumpFrames(tester);

      expect(
        find.text('2021-06'),
        findsNothing,
        reason: 'a date left on screen contradicts the "Present" in the PDF',
      );
      await quiesce(tester);
    });

    testWidgets('turning it on switches the field off and says why', (
      tester,
    ) async {
      await pumpEditor(tester, roleEnding('2021-06'));

      final endField = find.widgetWithText(TextField, 'End');
      expect(tester.widget<TextField>(endField).enabled, isTrue);
      expect(find.text('Shows “Present”'), findsNothing);

      await tester.tap(find.text('I currently work here'));
      await pumpFrames(tester);

      expect(
        tester.widget<TextField>(endField).enabled,
        isFalse,
        reason: 'an end date is meaningless while the role is current',
      );
      expect(
        find.text('Shows “Present”'),
        findsOneWidget,
        reason: 'a field that has gone quiet with no reason reads as broken',
      );
      await quiesce(tester);
    });

    testWidgets('turning it back off returns a usable, empty field', (
      tester,
    ) async {
      await pumpEditor(tester, roleEnding('2021-06'));

      await tester.tap(find.text('I currently work here'));
      await pumpFrames(tester);
      await tester.tap(find.text('I currently work here'));
      await pumpFrames(tester);

      final endField = find.widgetWithText(TextField, 'End');
      expect(tester.widget<TextField>(endField).enabled, isTrue);
      expect(find.text('Shows “Present”'), findsNothing);
      expect(
        find.text('2021-06'),
        findsNothing,
        reason: 'the date was cleared on the way in and must not come back',
      );
      await quiesce(tester);
    });
  });

  /// The rating word beside a skill slider had a flat 68px box — a fixed
  /// graphic's worth of space handed to a line of copy. At double text size
  /// "Strong" did not fit, and being one word it could not wrap either: it
  /// broke mid-word into "Stron / g" and the second line rode up over the
  /// slider above it. No overflow was thrown, so nothing in the suite noticed.
  group('the skill rating label', () {
    testWidgets('stays on one line at double text size', (tester) async {
      tester.view.physicalSize =
          const Size(360, 4000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      repo = InMemoryResumeRepository();
      addTearDown(repo.close);
      final doc = newResumeDocument().copyWith(
        data: const ResumeData(
          skills: [Skill(id: 's1', name: 'Research', level: 4)],
        ),
      );
      await repo.save(doc);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.build(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: EditorScreen(document: doc),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final label = find.text('Strong');
      expect(label, findsOneWidget);

      // The height the same word takes with all the room in the world: if the
      // laid-out label is taller than that, it wrapped.
      final painter = TextPainter(
        text: TextSpan(text: 'Strong', style: tester.widget<Text>(label).style),
        textScaler: const TextScaler.linear(2),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);

      expect(
        tester.getSize(label).height,
        lessThanOrEqualTo(painter.height + 1),
        reason: 'the rating word wrapped, which for one word means mid-word',
      );

      // And the slider it labels is still something a thumb can aim at.
      expect(tester.getSize(find.byType(Slider)).width, greaterThan(120));
      await quiesce(tester);
    });
  });

  /// QA asked for "a date picker in every template", which is a misreading of
  /// where the field lives: there is one editor and thirteen designs, so the
  /// picker lands once and applies everywhere a date is typed. These are the
  /// end-to-end assertions — the field's own behaviour is covered in
  /// `test/widgets/form_fields_test.dart`.
  group('the date picker in the editor', () {
    testWidgets('a picked month reaches the role it was picked for', (
      tester,
    ) async {
      await pumpEditor(tester, roleEnding(''));

      // The start date's picker: first of the pair, and the only enabled one
      // that matters here.
      await tester.tap(find.byTooltip('Pick month and year').first);
      await pumpFrames(tester);
      expect(find.text('Start date'), findsOneWidget);

      await tester.tap(find.text('2019'));
      await pumpFrames(tester);
      await tester.tap(find.text('2021'));
      await pumpFrames(tester);
      await tester.tap(find.text('Nov'));
      await pumpFrames(tester);

      expect(
        find.text('2021-11'),
        findsOneWidget,
        reason:
            'the picked date has to travel model → field, not be pasted '
            'straight into the controller',
      );
      await quiesce(tester);
      expect(
        (await repo.all()).single.data.experiences.single.startDate,
        '2021-11',
      );
    });

    testWidgets('a current role is not offered an end date to pick', (
      tester,
    ) async {
      await pumpEditor(tester, roleEnding('2021-06'));

      await tester.tap(find.text('I currently work here'));
      await pumpFrames(tester);

      IconButton pickerOn(String label) => tester.widget<IconButton>(
        find.descendant(
          of: find.ancestor(
            of: find.widgetWithText(TextField, label),
            matching: find.byType(MonthYearField),
          ),
          matching: find.byType(IconButton),
        ),
      );

      expect(
        pickerOn('End').onPressed,
        isNull,
        reason: 'the PDF prints "Present"; there is no end date to choose',
      );
      expect(
        pickerOn('Start').onPressed,
        isNotNull,
        reason: 'the start date is still very much editable',
      );
      await quiesce(tester);
    });

    testWidgets('education dates get the same picker', (tester) async {
      await pumpEditor(
        tester,
        const ResumeData(
          education: [Education(id: 'ed1', institution: 'Bristol')],
        ),
      );

      expect(find.byTooltip('Pick month and year'), findsNWidgets(2));
      await quiesce(tester);
    });
  });

  /// The picker button takes a 48px touch target out of each date column. At
  /// double text size on a 360px phone that leaves less room than `2019-04`
  /// needs, and the user's own date is clipped inside its own field — so the
  /// pair stops sharing a row.
  group('the start/end pair', () {
    Future<void> pumpDates(
      WidgetTester tester, {
      required Size size,
      required double textScale,
    }) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      repo = InMemoryResumeRepository();
      addTearDown(repo.close);
      final doc = newResumeDocument().copyWith(data: roleEnding('2021-06'));
      await repo.save(doc);

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
                child: EditorScreen(document: doc),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Rect rectOf(WidgetTester tester, String label) =>
        tester.getRect(find.widgetWithText(TextField, label));

    /// Room a date needs, and the room the field's decoration does not leave
    /// for it: the leading content padding plus the picker's touch target.
    double valueWidth(double scale) {
      final painter = TextPainter(
        text: TextSpan(
          text: '2019-04',
          style: AppTheme.build().textTheme.bodyLarge,
        ),
        textScaler: TextScaler.linear(scale),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    const chrome = 16.0 + 48.0;

    /// The property that actually matters, and the one that holds whichever
    /// font is in use: however the pair is laid out, the date the user typed
    /// has room to be read inside its own field.
    for (final scale in [1.0, 2.0]) {
      for (final size in [const Size(360, 4000), const Size(768, 4000)]) {
        testWidgets(
          'a date is never clipped — ${size.width.toInt()}px at ${scale}x',
          (tester) async {
            await pumpDates(tester, size: size, textScale: scale);

            for (final label in ['Start', 'End']) {
              expect(
                rectOf(tester, label).width - chrome,
                greaterThanOrEqualTo(valueWidth(scale)),
                reason: '$label has less room than the date it holds',
              );
            }
            await quiesce(tester);
          },
        );
      }
    }

    testWidgets('shares a row where there is room for both', (tester) async {
      await pumpDates(tester, size: const Size(768, 4000), textScale: 1);

      expect(
        rectOf(tester, 'Start').top,
        rectOf(tester, 'End').top,
        reason: "a role's dates are one fact and read faster as a pair",
      );
      await quiesce(tester);
    });

    testWidgets('stacks on a small phone at double text size', (tester) async {
      await pumpDates(tester, size: const Size(360, 4000), textScale: 2);

      final start = rectOf(tester, 'Start');
      expect(
        rectOf(tester, 'End').top,
        greaterThanOrEqualTo(start.bottom),
        reason: 'half a row cannot hold a date at this size',
      );
      await quiesce(tester);
    });
  });

  group('removing an entry', () {
    /// Entries are keyed by id, so the surviving row must keep its own text
    /// rather than inheriting the removed row's controller.
    testWidgets('the remaining role keeps its own values', (tester) async {
      await pumpEditor(
        tester,
        const ResumeData(
          experiences: [
            Experience(id: 'e1', position: 'First role', company: 'Alpha'),
            Experience(id: 'e2', position: 'Second role', company: 'Beta'),
          ],
        ),
      );

      expect(find.text('First role'), findsOneWidget);
      expect(find.text('Second role'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove this role').first);
      await pumpFrames(tester);

      expect(find.text('First role'), findsNothing);
      expect(
        find.text('Second role'),
        findsOneWidget,
        reason: 'the surviving entry must not take the deleted one\'s text',
      );
      expect(find.text('Beta'), findsOneWidget);
      await quiesce(tester);
    });
  });
}
