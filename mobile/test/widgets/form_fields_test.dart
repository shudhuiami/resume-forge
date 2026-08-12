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
