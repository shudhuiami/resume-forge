import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/pdf_page_view.dart';

/// The export action, end to end through the UI.
///
/// The share plugin has no implementation under `flutter_test`, so every run
/// here takes the failure path — which is exactly the path that has to stay
/// recoverable.
void main() {
  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize =
        const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: EditorScreen(
            document: newResumeDocument().copyWith(data: sampleResume),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final exportFinder = find.ancestor(
    of: find.byTooltip('Export PDF'),
    matching: find.byType(IconButton),
  );

  IconButton exportButton(WidgetTester tester) =>
      tester.widget<IconButton>(exportFinder);

  /// Pumps, letting real async (the render isolate, the plugin call) run
  /// between frames, until [finder] matches or the budget runs out.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('export', () {
    testWidgets('progress is shown for as long as the work takes', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.tap(find.byTooltip('Export PDF'));
      await tester.pump();

      expect(find.text('Preparing PDF…'), findsOneWidget);

      // The old fixed one-second snackbar had already vanished by here,
      // leaving the app looking idle mid-export.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Preparing PDF…'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('the button is not a dead control while an export runs', (
      tester,
    ) async {
      await pumpEditor(tester);
      expect(exportButton(tester).onPressed, isNotNull);

      await tester.tap(find.byTooltip('Export PDF'));
      await tester.pump();

      expect(
        exportButton(tester).onPressed,
        isNull,
        reason: 'a second tap would build the document twice',
      );
      expect(
        find.descendant(
          of: exportFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a disabled button with no explanation reads as broken',
      );

      await pumpUntil(tester, find.text('Try again'));
      await tester.pump();
      expect(
        exportButton(tester).onPressed,
        isNotNull,
        reason: 'the action has to come back once the attempt is over',
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a failure is explained and offers a retry', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byTooltip('Export PDF'));
      await tester.pump();

      await pumpUntil(tester, find.text('Try again'));

      expect(find.text('Could not export the PDF.'), findsOneWidget);
      expect(
        find.text('Try again'),
        findsOneWidget,
        reason: 'a failed export must not end the road',
      );
      expect(
        find.text('Preparing PDF…'),
        findsNothing,
        reason: 'the progress snackbar must be closed before the outcome',
      );

      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('preview', () {
    testWidgets('the preview tab can ask for a failed render to be retried', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.tap(find.text('Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final view = tester.widget<PdfPageView>(
        find.byType(PdfPageView, skipOffstage: false),
      );

      // Left null, the preview's Retry affordance could never be drawn and a
      // render error was a dead end until the user typed something else.
      expect(view.onRetry, isNotNull);
    });
  });
}
