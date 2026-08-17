import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/phone.dart';
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

  /// The phone field turns one stored string into two controls and back again.
  ///
  /// Everything here is about what it refuses to do: it does not put a dial
  /// code in front of a number that was saved without one, it does not name a
  /// country it only guessed at, it does not rewrite the separators the user
  /// typed, and it does not refuse a number the plausibility check dislikes.
  group('PhoneField', () {
    /// Every string the field has handed to `onChanged`, newest last. This is
    /// what would be stored, so it is what the assertions are about.
    late List<String> pushed;

    setUp(() => pushed = <String>[]);

    Future<void> pumpPhone(
      WidgetTester tester, {
      required String initial,
      Size size = const Size(430, 900),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: _Rebuildable(
                  initial: initial,
                  builder: (value, onChanged) => PhoneField(
                    value: value,
                    onChanged: (v) {
                      pushed.add(v);
                      onChanged(v);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder codeButton() => find.byKey(PhoneField.codeButtonKey);
    Finder numberField() => find.widgetWithText(TextField, 'Phone');

    /// The control's value, which is every string it draws except its own
    /// floating label.
    String codeText(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(of: codeButton(), matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .whereType<String>()
        .firstWhere((data) => data != 'Code');

    String? hintOf(WidgetTester tester) =>
        tester.widget<TextField>(numberField()).decoration?.hintText;

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(codeButton());
      await tester.pumpAndSettle();
    }

    testWidgets('splits a stored international number into its two parts', (
      tester,
    ) async {
      // Deliberately not the country's own example number: that string is also
      // the placeholder, which stays in the tree behind the text.
      await pumpPhone(tester, initial: '+880 1811-999888');

      expect(codeText(tester), '+880');
      expect(
        find.text('1811-999888'),
        findsOneWidget,
        reason: 'the number field holds the national part, code taken off',
      );
    });

    /// The case every resume saved before this field existed is in.
    /// `splitPhoneNumber` answers `country == null` there, which means "the
    /// whole string is the number" — not "use the default".
    testWidgets('a number saved without a code keeps every character', (
      tester,
    ) async {
      await pumpPhone(tester, initial: '(415) 555-0134');

      expect(codeText(tester), 'None');
      expect(find.text('(415) 555-0134'), findsOneWidget);
      expect(pushed, isEmpty, reason: 'reading a value must not write one');
    });

    testWidgets('typing into a code-less number prepends nothing', (
      tester,
    ) async {
      await pumpPhone(tester, initial: '020 7946 0018');
      await tester.enterText(numberField(), '020 7946 0019');
      await tester.pump();

      expect(pushed.last, '020 7946 0019');
    });

    testWidgets('picking a country is what puts a code in front of a number', (
      tester,
    ) async {
      await pumpPhone(tester, initial: '01712 345678');
      expect(codeText(tester), 'None');

      await openPicker(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search'),
        'Bangla',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bangladesh'));
      await tester.pumpAndSettle();

      expect(pushed.last, '+880 01712 345678');
      expect(
        find.text('01712 345678'),
        findsOneWidget,
        reason: 'the number itself is untouched — no trunk zero stripped',
      );
    });

    testWidgets('an untouched field stores nothing when a country is picked', (
      tester,
    ) async {
      await pumpPhone(tester, initial: '');

      await openPicker(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search'),
        'Bangla',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bangladesh'));
      await tester.pumpAndSettle();

      expect(
        pushed.every((v) => v.isEmpty),
        isTrue,
        reason: 'a bare "+880" would print as a broken number on the PDF',
      );
      expect(codeText(tester), '+880');
    });

    /// QA's actual request: the placeholder shows the shape a number is written
    /// in wherever the user is.
    testWidgets('the placeholder follows the country', (tester) async {
      await pumpPhone(tester, initial: '');
      final before = hintOf(tester);

      await openPicker(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search'),
        'Bangla',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bangladesh'));
      await tester.pumpAndSettle();

      expect(hintOf(tester), '1712-345678');
      expect(hintOf(tester), isNot(before));
    });

    testWidgets('the picker takes a code back off again', (tester) async {
      await pumpPhone(tester, initial: '+880 1712-345678');

      await openPicker(tester);
      await tester.tap(find.text('No country code'));
      await tester.pumpAndSettle();

      expect(pushed.last, '1712-345678');
      expect(codeText(tester), 'None');
    });

    /// `+1` covers 25 countries. The dial code is a fact — it is in the user's
    /// own text — but which country it belongs to is not, so the field shows
    /// the one and never claims the other.
    group('a shared dial code', () {
      testWidgets('is shown without naming a country', (tester) async {
        await pumpPhone(tester, initial: '+1 415 555 0134');

        expect(codeText(tester), '+1');
        expect(find.textContaining('United States'), findsNothing);
      });

      testWidgets('leaves every row in the picker unticked', (tester) async {
        await pumpPhone(tester, initial: '+1 415 555 0134');
        await openPicker(tester);

        expect(
          find.byIcon(Icons.check),
          findsNothing,
          reason:
              'a guess ticked as a selection is a finding the app cannot make',
        );
        expect(
          find.textContaining('use +1'),
          findsOneWidget,
          reason: 'the unticked list needs to say why it is unticked',
        );
      });

      testWidgets('resolves for real when the number says which country', (
        tester,
      ) async {
        // 204 is a Manitoba area code, which the table carries — so this one
        // is a finding rather than a fallback, and the picker may say so.
        await pumpPhone(tester, initial: '+1 204 555 0134');
        await openPicker(tester);

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.text('Canada'), findsWidgets);
        expect(find.text('Currently in use'), findsOneWidget);
      });
    });

    group('the plausibility check', () {
      testWidgets('says nothing while the number is still being typed', (
        tester,
      ) async {
        await pumpPhone(tester, initial: '');
        await tester.tap(numberField());
        await tester.pump();
        await tester.enterText(numberField(), '12');
        await tester.pump();

        expect(
          find.textContaining('too short'),
          findsNothing,
          reason: 'scolding someone mid-number is not help',
        );
      });

      testWidgets('shows a note once the user has moved on, and still saves', (
        tester,
      ) async {
        await pumpPhone(tester, initial: '');
        await tester.tap(numberField());
        await tester.pump();
        await tester.enterText(numberField(), '12');
        await tester.pump();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(find.textContaining('too short'), findsOneWidget);
        expect(
          pushed.last,
          '+1 12',
          reason: 'the check never withholds what the user typed',
        );
      });

      testWidgets('has nothing to say about an empty field', (tester) async {
        await pumpPhone(tester, initial: '');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.info_outline), findsNothing);
      });
    });

    /// The control shows a dial code and a chevron and nothing else, so
    /// everything a screen reader needs has to be stated: what it is, what it
    /// currently holds, and that it can be pressed.
    group('the code control for a screen reader', () {
      testWidgets('is a pressable button that names itself and its value', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpPhone(tester, initial: '+880 1811-999888');

        final node = tester.getSemantics(codeButton());
        expect(node.label, contains('Country code'));
        expect(
          node.value,
          contains('Bangladesh'),
          reason: 'the name is not on screen; it has to be spoken',
        );
        expect(
          node,
          isSemantics(isButton: true, hasTapAction: true),
          reason: 'it opens a picker, and has to announce that it can be',
        );
        // Released inside the body: the framework checks for live handles
        // before tear-downs run.
        handle.dispose();
      });

      testWidgets('does not speak a country it only guessed at', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpPhone(tester, initial: '+1 415 555 0134');

        final node = tester.getSemantics(codeButton());
        expect(node.value, '+1');
        expect(node.value, isNot(contains('United States')));
        handle.dispose();
      });
    });

    /// The reason this field does not use `_ModelBackedField`: re-deriving the
    /// national part from the stored string on every keystroke hands the text
    /// back through `splitPhoneNumber`, which drops the separators between the
    /// dial code and the first digit. Typing `(` would erase it again.
    testWidgets('separators the user types survive the round trip', (
      tester,
    ) async {
      await pumpPhone(tester, initial: '+1 5550134');
      await tester.enterText(numberField(), '(415');
      await tester.pump();

      expect(find.text('(415'), findsOneWidget);
      expect(pushed.last, '+1 (415');
    });

    /// The number most people have to hand is a whole international one, and
    /// the number field is where it gets pasted. Joining a dial code onto the
    /// front of that would store a number that dials nowhere.
    group('a whole international number typed into the number field', () {
      testWidgets('moves its code into the control instead of doubling up', (
        tester,
      ) async {
        await pumpPhone(tester, initial: '');
        expect(codeText(tester), '+1');

        await tester.enterText(numberField(), '+44 20 7946 0018');
        await tester.pump();

        expect(pushed.last, '+44 20 7946 0018');
        expect(codeText(tester), '+44');
        expect(find.text('20 7946 0018'), findsOneWidget);
      });

      testWidgets('leaves half a dial code alone while it is being typed', (
        tester,
      ) async {
        await pumpPhone(tester, initial: '');

        await tester.enterText(numberField(), '+4');
        await tester.pump();

        expect(pushed.last, '+4');
        expect(
          find.text('+4'),
          findsOneWidget,
          reason: 'a code that has not resolved is still the user\'s text',
        );
        expect(codeText(tester), 'None');
      });
    });

    /// Load sample, undo and clear all replace the document under the field.
    testWidgets('follows the document when it is replaced from outside', (
      tester,
    ) async {
      await pumpPhone(tester, initial: '');
      tester
          .state<_RebuildableState>(find.byType(_Rebuildable))
          .push('+44 20 7946 0018');
      await tester.pump();

      expect(codeText(tester), '+44');
      expect(find.text('20 7946 0018'), findsOneWidget);

      tester.state<_RebuildableState>(find.byType(_Rebuildable)).push('');
      await tester.pump();

      expect(find.text('20 7946 0018'), findsNothing);
    });

    group('the country picker', () {
      testWidgets('finds a country by name, code, or dial code', (
        tester,
      ) async {
        await pumpPhone(tester, initial: '');
        await openPicker(tester);

        final search = find.widgetWithText(TextField, 'Search');
        for (final query in ['Bangla', 'BD', '880']) {
          await tester.enterText(search, query);
          await tester.pumpAndSettle();
          expect(find.text('Bangladesh'), findsOneWidget, reason: query);
        }
      });

      testWidgets('says so when a search matches nothing', (tester) async {
        await pumpPhone(tester, initial: '');
        await openPicker(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Search'),
          'zzzzz',
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('No country matches'), findsOneWidget);
        expect(
          find.text('No country code'),
          findsOneWidget,
          reason: 'the way back to a code-less number stays reachable',
        );
      });

      testWidgets('dismissing it changes nothing', (tester) async {
        await pumpPhone(tester, initial: '+880 1712-345678');
        await openPicker(tester);
        Navigator.of(tester.element(find.text('No country code'))).pop();
        await tester.pumpAndSettle();

        expect(pushed, isEmpty);
        expect(codeText(tester), '+880');
      });

      /// The sheet shipped overflowing here by 14px: a heading, a search
      /// field and two two-line rows are taller than the 258px a landscape
      /// sheet has to give, and the `Flexible` list could shrink to nothing
      /// while its fixed siblings could not. Everything below the search now
      /// rides in the one scrollable.
      for (final (size, scale) in const [
        (Size(800, 360), 1.0),
        (Size(800, 360), 2.0),
        (Size(360, 800), 2.0),
        (Size(768, 1024), 2.0),
      ]) {
        testWidgets(
          'opens at ${size.width.toInt()}x${size.height.toInt()}, ${scale}x',
          (tester) async {
            // The sheet is a route above the widget under test, so it does not
            // inherit a MediaQuery pushed in around it — the text size has to
            // come from the platform for this to be an assertion about the
            // sheet at all.
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            await pumpPhone(
              tester,
              initial: '+880 1811-999888',
              size: size,
              textScale: scale,
            );
            await openPicker(tester);

            expect(find.text('No country code'), findsOneWidget);
            expect(
              find.byType(ListView),
              findsOneWidget,
              reason: 'a short viewport has to scroll, not clip',
            );
          },
        );
      }

      testWidgets('builds its rows lazily rather than all 246 at once', (
        tester,
      ) async {
        await pumpPhone(tester, initial: '');
        await openPicker(tester);

        expect(find.byType(ListView), findsOneWidget);
        expect(
          find.byType(ListTile).evaluate().length,
          lessThan(phoneCountries.length),
        );
      });
    });

    group('layout', () {
      /// A code control beside a number field is the pair most likely to run
      /// out of room, and the answer is the one the date pair already uses:
      /// measure the content, then stack rather than clip.
      ///
      /// Only the two ends are pinned. The test font draws every glyph as a
      /// full em box, so the width where the pair gives up the shared row is
      /// not the width a device with Inter loaded arrives at — asserting a
      /// threshold here would be asserting the test font.
      for (final (size, scale, sameRow) in const [
        (Size(430, 900), 1.0, true),
        (Size(360, 900), 2.0, false),
      ]) {
        testWidgets('${size.width.toInt()}px at ${scale}x '
            '${sameRow ? 'shares a row' : 'stacks'}', (tester) async {
          await pumpPhone(
            tester,
            initial: '+880 1712-345678',
            size: size,
            textScale: scale,
          );

          final code = tester.getRect(codeButton());
          final number = tester.getRect(numberField());
          if (sameRow) {
            expect(code.top, number.top);
          } else {
            expect(number.top, greaterThanOrEqualTo(code.bottom));
          }
        });
      }

      /// A format the user cannot finish reading is not a format. At double
      /// text size on a small phone even a full-width field is narrower than
      /// `(201) 555-0123`, so the hint is allowed a second line rather than
      /// being cut off mid-number.
      for (final (size, scale) in const [
        (Size(360, 900), 1.0),
        (Size(360, 900), 2.0),
        (Size(430, 900), 2.0),
      ]) {
        testWidgets(
          'the whole placeholder fits at ${size.width.toInt()}px, ${scale}x',
          (tester) async {
            await pumpPhone(tester, initial: '', size: size, textScale: scale);

            final field = tester.widget<TextField>(numberField());
            final painter =
                TextPainter(
                  text: TextSpan(
                    text: field.decoration!.hintText,
                    style: AppTheme.build().textTheme.bodyLarge,
                  ),
                  textScaler: TextScaler.linear(scale),
                  maxLines: field.decoration!.hintMaxLines,
                  textDirection: TextDirection.ltr,
                )..layout(
                  // The decoration's own horizontal padding is not the hint's to
                  // use.
                  maxWidth: tester.getSize(numberField()).width - 32,
                );
            addTearDown(painter.dispose);

            expect(
              painter.didExceedMaxLines,
              isFalse,
              reason: 'a format hint cut in half is worse than no hint',
            );
          },
        );
      }
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
