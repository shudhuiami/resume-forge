import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/form_fields.dart';

/// Fields have to show whatever the model currently holds.
///
/// Every field in this form used to be an uncontrolled `TextFormField` seeded
/// with `initialValue`, which Flutter reads exactly once — `FormFieldState`
/// does not re-seed it in `didUpdateWidget`. Typing was unaffected, so the
/// defect only appeared when something *other than the keyboard* changed the
/// value: the model, storage and the PDF moved on while the text on screen did
/// not. The editor papered over the three known cases by rebuilding the whole
/// form from a revision key, and the fourth case — the "I currently work here"
/// switch clearing the end date — was shipped broken.
///
/// These are the tests that could not pass before the fields owned their
/// controllers, so they are what stops the trap being re-armed.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.build(),
    home: Scaffold(body: child),
  );

  /// A parent that can push a new value down, exactly as the editor form does
  /// when the document is replaced under it.
  Future<void> pumpField(
    WidgetTester tester,
    Widget Function(String value, ValueChanged<String> onChanged) build, {
    required String initial,
  }) async {
    await tester.pumpWidget(
      host(
        _Rebuildable(
          initial: initial,
          builder: (value, onChanged) => build(value, onChanged),
        ),
      ),
    );
  }

  void push(WidgetTester tester, String value) {
    tester.state<_RebuildableState>(find.byType(_Rebuildable)).push(value);
  }

  group('ResumeTextField follows the model', () {
    testWidgets('shows the value it is given', (tester) async {
      await pumpField(
        tester,
        (value, onChanged) => ResumeTextField(
          label: 'Full name',
          value: value,
          onChanged: onChanged,
        ),
        initial: 'Priya Raman',
      );

      expect(find.text('Priya Raman'), findsOneWidget);
    });

    testWidgets('a value replaced from outside reaches the screen', (
      tester,
    ) async {
      await pumpField(
        tester,
        (value, onChanged) => ResumeTextField(
          label: 'Full name',
          value: value,
          onChanged: onChanged,
        ),
        initial: 'Priya Raman',
      );

      push(tester, 'Amara Okonkwo');
      await tester.pump();

      expect(
        find.text('Amara Okonkwo'),
        findsOneWidget,
        reason: 'this is the assertion an initialValue-seeded field fails',
      );
      expect(find.text('Priya Raman'), findsNothing);
    });

    testWidgets('clearing the model clears the field', (tester) async {
      await pumpField(
        tester,
        (value, onChanged) => ResumeTextField(
          label: 'Full name',
          value: value,
          onChanged: onChanged,
        ),
        initial: 'Priya Raman',
      );

      push(tester, '');
      await tester.pump();

      expect(find.text('Priya Raman'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('typing reports every keystroke and keeps the caret', (
      tester,
    ) async {
      final seen = <String>[];
      await pumpField(
        tester,
        (value, onChanged) => ResumeTextField(
          label: 'Full name',
          value: value,
          onChanged: (v) {
            seen.add(v);
            onChanged(v);
          },
        ),
        initial: '',
      );

      await tester.enterText(find.byType(TextField), 'Ama');
      await tester.pump();

      expect(seen.last, 'Ama');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.text, 'Ama');
      expect(
        controller.selection.baseOffset,
        3,
        reason:
            'the round trip through the model must not move the caret, or '
            'every keystroke would jump the cursor to the end of the field',
      );
    });
  });

  group('MonthYearField', () {
    testWidgets('a date cleared by the current-role switch disappears', (
      tester,
    ) async {
      await pumpField(
        tester,
        (value, onChanged) =>
            MonthYearField(label: 'End', value: value, onChanged: onChanged),
        initial: '2021-06',
      );

      expect(find.text('2021-06'), findsOneWidget);

      // What `Experience.copyWith(current: true, endDate: '')` does to the
      // model. This is the case that shipped broken: the PDF printed
      // "Present" while the field still showed a date the user could not
      // remove without retyping it.
      push(tester, '');
      await tester.pump();

      expect(find.text('2021-06'), findsNothing);
    });

    testWidgets('switched off, it says what the PDF will print instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const MonthYearField(
            label: 'End',
            value: '',
            enabled: false,
            disabledHelper: 'Shows “Present”',
            onChanged: _ignore,
          ),
        ),
      );

      expect(find.text('Shows “Present”'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('while it is live it explains nothing it does not need to', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const MonthYearField(
            label: 'End',
            value: '',
            disabledHelper: 'Shows “Present”',
            onChanged: _ignore,
          ),
        ),
      );

      expect(find.text('Shows “Present”'), findsNothing);
    });
  });

  /// Dates used to be typed and nothing else, which is a lot of transcription
  /// to ask of someone holding a phone. The picker is month-and-year only —
  /// resumes carry no day, and a day-precision picker would collect a number
  /// no template can print — and it sits *beside* the keyboard rather than in
  /// front of it.
  group('MonthYearField picker', () {
    Finder pickerButton() => find.byTooltip('Pick month and year');

    testWidgets('offers a picker without taking the keyboard away', (
      tester,
    ) async {
      await pumpField(
        tester,
        (value, onChanged) =>
            MonthYearField(label: 'Start', value: value, onChanged: onChanged),
        initial: '',
      );

      expect(pickerButton(), findsOneWidget);

      // The field is still a field: typing a partial date the picker cannot
      // express has to keep working, because resumes carry them.
      await tester.enterText(find.byType(TextField), '2019');
      await tester.pump();
      expect(find.text('2019'), findsOneWidget);
    });

    testWidgets('a switched-off field offers nothing to pick', (tester) async {
      await tester.pumpWidget(
        host(
          const MonthYearField(
            label: 'End',
            value: '',
            enabled: false,
            disabledHelper: 'Shows “Present”',
            onChanged: _ignore,
          ),
        ),
      );

      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
        reason:
            'a current role has no end date, so the picker must not offer to '
            'set one',
      );
    });

    testWidgets('choosing a month writes YYYY-MM through the model', (
      tester,
    ) async {
      final reported = <String>[];
      await pumpField(
        tester,
        (value, onChanged) => MonthYearField(
          label: 'Start',
          value: value,
          onChanged: (v) {
            reported.add(v);
            onChanged(v);
          },
        ),
        initial: '',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();
      expect(find.text('Start date'), findsOneWidget);

      // Off the current year, so the answer proves both halves were read.
      await tester.tap(find.byTooltip('Previous year'));
      await tester.pump();
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      final year = DateTime.now().year - 1;
      expect(reported.single, '$year-03');
      expect(
        find.text('$year-03'),
        findsOneWidget,
        reason:
            'the picked date has to arrive through the model, which is the '
            'path an initialValue-seeded field could not follow',
      );
    });

    testWidgets('it opens on the date the field already holds', (tester) async {
      await pumpField(
        tester,
        (value, onChanged) =>
            MonthYearField(label: 'Start', value: value, onChanged: onChanged),
        initial: '1998-07',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();

      expect(find.text('1998'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Jul'),
      );
      expect(
        chip.selected,
        isTrue,
        reason: 'a picker that forgets the current answer makes you find it',
      );
    });

    testWidgets('a typed value the picker cannot read still opens it', (
      tester,
    ) async {
      await pumpField(
        tester,
        (value, onChanged) =>
            MonthYearField(label: 'Start', value: value, onChanged: onChanged),
        initial: 'Summer 2020',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();

      expect(
        find.text('${DateTime.now().year}'),
        findsOneWidget,
        reason: 'an unparseable date is not an error, it just has no month',
      );
    });

    testWidgets('the year list reaches a date decades back', (tester) async {
      final reported = <String>[];
      await pumpField(
        tester,
        (value, onChanged) => MonthYearField(
          label: 'Start',
          value: value,
          onChanged: (v) {
            reported.add(v);
            onChanged(v);
          },
        ),
        initial: '',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('${DateTime.now().year}'));
      await tester.pumpAndSettle();

      // The sheet's own scroll view, not the field's route behind it.
      await tester.scrollUntilVisible(
        find.text('1987'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('1987'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sep'));
      await tester.pumpAndSettle();

      expect(reported.single, '1987-09');
    });

    testWidgets('dismissing it leaves the date exactly as it was', (
      tester,
    ) async {
      final reported = <String>[];
      await pumpField(
        tester,
        (value, onChanged) => MonthYearField(
          label: 'Start',
          value: value,
          onChanged: (v) {
            reported.add(v);
            onChanged(v);
          },
        ),
        initial: '2019-04',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();
      // The barrier: the same answer as the drag handle or the back gesture.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(reported, isEmpty);
      expect(find.text('2019-04'), findsOneWidget);
    });

    testWidgets('it can also take a date away', (tester) async {
      final reported = <String>[];
      await pumpField(
        tester,
        (value, onChanged) => MonthYearField(
          label: 'Start',
          value: value,
          onChanged: (v) {
            reported.add(v);
            onChanged(v);
          },
        ),
        initial: '2019-04',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear date'));
      await tester.pumpAndSettle();

      expect(reported.single, isEmpty);
      expect(find.text('2019-04'), findsNothing);
    });

    testWidgets('an empty field is not offered a way to clear it', (
      tester,
    ) async {
      await pumpField(
        tester,
        (value, onChanged) =>
            MonthYearField(label: 'Start', value: value, onChanged: onChanged),
        initial: '',
      );

      await tester.tap(pickerButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Clear date'),
        findsNothing,
        reason: 'a control that does nothing is worse than no control',
      );
    });

    /// The case most likely to break: a full month grid, a sheet, and twice
    /// the type size on the smallest phone in the matrix. A RenderFlex
    /// overflow is a test failure, so these pumps are the assertion.
    testWidgets('it lays out on a small phone at double text size', (
      tester,
    ) async {
      tester.view.physicalSize =
          const Size(360, 800) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: const Scaffold(
                body: MonthYearField(
                  label: 'Start',
                  value: '2019-04',
                  onChanged: _ignore,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Pick month and year'));
      await tester.pumpAndSettle();

      for (final month in ['Jan', 'Jun', 'Dec']) {
        expect(find.text(month), findsOneWidget, reason: month);
      }
      expect(find.text('Clear date'), findsOneWidget);

      // And the months are still something a thumb can land on.
      expect(
        tester.getSize(find.widgetWithText(ChoiceChip, 'Jun')).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('MonthYear', () {
    test('reads the format the field writes, and nothing looser', () {
      expect(MonthYear.tryParse('2019-04'), const MonthYear(2019, 4));
      expect(MonthYear.tryParse('2019-4'), const MonthYear(2019, 4));
      expect(MonthYear.tryParse(' 2019-04 '), const MonthYear(2019, 4));
      for (final loose in ['', '2019', 'Summer 2020', '2019-13', '2019-00']) {
        expect(MonthYear.tryParse(loose), isNull, reason: loose);
      }
    });

    test('writes a padded month, which is what sorts and renders', () {
      expect(const MonthYear(2019, 4).format(), '2019-04');
      expect(const MonthYear(2019, 11).format(), '2019-11');
    });
  });
}

void _ignore(String _) {}

class _Rebuildable extends StatefulWidget {
  const _Rebuildable({required this.initial, required this.builder});

  final String initial;
  final Widget Function(String value, ValueChanged<String> onChanged) builder;

  @override
  State<_Rebuildable> createState() => _RebuildableState();
}

class _RebuildableState extends State<_Rebuildable> {
  late String _value = widget.initial;

  /// Replaces the value the way the editor's controller does: from outside the
  /// field, with no keyboard involved.
  void push(String value) => setState(() => _value = value);

  @override
  Widget build(BuildContext context) =>
      widget.builder(_value, (v) => setState(() => _value = v));
}
