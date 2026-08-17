import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// The editor autosaves, and QA asked for a Save button.
///
/// The request is the finding: a user who cannot see the saving happen has no
/// way to tell a working autosave from a broken one, so they ask for a lever
/// to be sure. The answer is both halves — say what is happening, and give the
/// job an end — and neither half may lie about the other. These tests are what
/// stop the indicator drifting into a decoration that always reads "Saved".
class _GatedRepository extends InMemoryResumeRepository {
  /// When set, the next write blocks on this — so a test can hold storage open
  /// and watch what the screen does meanwhile.
  Completer<void>? gate;

  bool failSaves = false;
  int attempts = 0;

  @override
  Future<void> save(ResumeDocument doc) async {
    attempts++;
    final held = gate;
    if (held != null) {
      gate = null;
      await held.future;
    }
    if (failSaves) throw StateError('storage unavailable');
    await super.save(doc);
  }
}

void main() {
  late _GatedRepository repo;

  /// Pushes the editor the way the resume list does, so it has the back arrow
  /// and a route to pop back to.
  Future<void> pumpEditor(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ResumeData data = const ResumeData(),
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    repo = _GatedRepository();
    addTearDown(repo.close);

    final doc = newResumeDocument().copyWith(data: data);
    await repo.save(doc);
    repo.attempts = 0;

    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          navigatorKey: nav,
          theme: AppTheme.build(),
          home: const Scaffold(body: Center(child: Text('the resume list'))),
        ),
      ),
    );
    unawaited(
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => EditorScreen(document: doc)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextField, label), text);
    await tester.pump();
  }

  /// Lets the autosave debounce and any toast expire, so nothing is left
  /// pending when the test ends.
  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
  }

  group('the save indicator', () {
    testWidgets('says the work is safe before anything is typed', (
      tester,
    ) async {
      await pumpEditor(tester);

      expect(
        find.text('Saved'),
        findsOneWidget,
        reason: 'the document was written before the editor opened',
      );
      await quiesce(tester);
    });

    testWidgets('follows the write, not a timer', (tester) async {
      await pumpEditor(tester);
      await type(tester, 'Full name', 'Priya Raman');

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);

      // Past the 800ms debounce and the write behind it.
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Saved'), findsOneWidget);
      expect(
        (await repo.byId(
          (await repo.all()).single.id,
        ))!.data.personalInfo.fullName,
        'Priya Raman',
        reason: '"Saved" has to mean the bytes are actually on disk',
      );
      await quiesce(tester);
    });

    testWidgets('stays on "Saving…" while the write is in flight', (
      tester,
    ) async {
      await pumpEditor(tester);
      final gate = Completer<void>();
      repo.gate = gate;

      await type(tester, 'Full name', 'Priya Raman');
      await tester.pump(const Duration(seconds: 1));

      expect(repo.attempts, 1, reason: 'the write is in flight');
      expect(find.text('Saving…'), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      await quiesce(tester);
    });

    /// The failure the two-state version could not tell the truth about: a
    /// write that gave up leaves an indicator reading "Saving…" forever, which
    /// is a reassurance nothing is backing.
    testWidgets('says so when storage refuses the write', (tester) async {
      await pumpEditor(tester);
      repo.failSaves = true;

      await type(tester, 'Full name', 'Priya Raman');
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text('Saving…'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      await quiesce(tester);
    });

    testWidgets('goes back to trying when storage comes back', (tester) async {
      await pumpEditor(tester);
      repo.failSaves = true;
      await type(tester, 'Full name', 'Priya');
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Not saved'), findsOneWidget);

      repo.failSaves = false;
      await type(tester, 'Full name', 'Priya Raman');
      await tester.pump();
      expect(
        find.text('Saving…'),
        findsOneWidget,
        reason: 'a new edit is a new attempt, and reports its own outcome',
      );

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Saved'), findsOneWidget);
      await quiesce(tester);
    });

    testWidgets('is one screen-reader stop, not two, and never shouts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester);

      // The app bar merges its title into one node, so a screen reader reads
      // the document and its state together — "Untitled resume, Saved" — with
      // the glyph adding nothing of its own.
      final node = tester.getSemantics(find.text('Saved'));
      expect(node.label, 'Untitled resume\nSaved');
      expect(
        node.flagsCollection.isLiveRegion,
        isFalse,
        reason:
            'this changes on every keystroke; announcing each one would be an '
            'alarm wired to the space bar',
      );
      handle.dispose();
      await quiesce(tester);
    });
  });

  group('Done', () {
    testWidgets('goes back to the list', (tester) async {
      await pumpEditor(tester);

      expect(find.byTooltip('Done'), findsOneWidget);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(EditorScreen), findsNothing);
      expect(find.text('the resume list'), findsOneWidget);
    });

    /// The point of the button. Leaving inside the 800ms debounce used to
    /// depend on a fire-and-forget write in `dispose`, which is a race the
    /// list can lose.
    testWidgets('flushes what is pending before the list can be seen', (
      tester,
    ) async {
      await pumpEditor(tester);
      await type(tester, 'Full name', 'Priya Raman');

      final gate = Completer<void>();
      repo.gate = gate;
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      expect(
        find.byType(EditorScreen),
        findsOneWidget,
        reason: 'the editor may not leave while its write is still in flight',
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('the resume list'), findsOneWidget);
      expect(
        (await repo.all()).single.data.personalInfo.fullName,
        'Priya Raman',
      );
      await quiesce(tester);
    });

    testWidgets('says nothing on the way out', (tester) async {
      await pumpEditor(tester);
      await type(tester, 'Full name', 'Priya Raman');
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      for (final noise in const ['Saved', 'Saving…', 'Resume saved']) {
        expect(
          find.text(noise),
          findsNothing,
          reason:
              'a toast on every exit repeats what the indicator already said',
        );
      }
      await quiesce(tester);
    });

    testWidgets('a double tap does not pop the list too', (tester) async {
      await pumpEditor(tester);

      final gate = Completer<void>();
      repo.gate = gate;
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('the resume list'),
        findsOneWidget,
        reason: 'the second tap must not take the list off the stack as well',
      );
    });

    /// Leaving would drop the edits with the controller, so this is the one
    /// exit worth interrupting.
    testWidgets('a failed flush keeps the user and their work here', (
      tester,
    ) async {
      await pumpEditor(tester);
      await type(tester, 'Full name', 'Priya Raman');
      repo.failSaves = true;

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(EditorScreen), findsOneWidget);
      expect(
        find.textContaining('Could not save'),
        findsOneWidget,
        reason: 'silently staying put would read as a dead button',
      );
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Priya Raman'), findsOneWidget);

      // And the offered retry actually works once storage is back.
      repo.failSaves = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('the resume list'), findsOneWidget);
      expect(
        (await repo.all()).single.data.personalInfo.fullName,
        'Priya Raman',
      );
      await quiesce(tester);
    });
  });
}
