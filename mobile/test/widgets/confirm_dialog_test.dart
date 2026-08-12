import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/confirm_dialog.dart';

/// One confirmation, used by all three destructive actions.
///
/// It was hand-built in three places — delete a resume, replace everything with
/// the sample, clear every field — which matched only because each was copied
/// from the last. These are the properties that have to hold wherever it is
/// used, tested once rather than three times.
void main() {
  Future<bool?> open(
    WidgetTester tester, {
    String title = 'Clear this resume?',
    String confirmLabel = 'Clear',
  }) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await confirmDestructive(
                  context,
                  title: title,
                  message: 'Everything in this resume is thrown away.',
                  confirmLabel: confirmLabel,
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('asks before it does anything', (tester) async {
    await open(tester);

    expect(find.text('Clear this resume?'), findsOneWidget);
    expect(
      find.text('Everything in this resume is thrown away.'),
      findsOneWidget,
      reason: 'a question with no stated consequence is not a confirmation',
    );
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Clear'), findsOneWidget);
  });

  testWidgets('the destructive answer cannot be mistaken for the safe one', (
    tester,
  ) async {
    await open(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clear'),
    );
    final states = <WidgetState>{};
    expect(
      button.style?.backgroundColor?.resolve(states),
      AppTheme.colorScheme.error,
    );
    expect(
      button.style?.foregroundColor?.resolve(states),
      AppTheme.colorScheme.onError,
    );
  });

  testWidgets('confirming answers yes, cancelling answers no', (tester) async {
    var result = await open(tester);
    expect(result, isNull, reason: 'nothing answered yet');

    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    result = await open(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  /// Tapping outside is not consent. A dismissed dialog has to answer no, or a
  /// stray tap would delete somebody's resume.
  testWidgets('dismissing without answering means no', (tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answers.add(
                await confirmDestructive(
                  context,
                  title: 'Delete this resume?',
                  message: 'It will be removed from this device.',
                  confirmLabel: 'Delete',
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // The barrier: anywhere outside the dialog's own box.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(answers, [isFalse]);
  });
}
