import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/main.dart';
import 'package:resume_forge/screens/resume_list_screen.dart';
import 'package:resume_forge/screens/splash_screen.dart';

/// Long enough that the entrance finishes first, so the two halves of the
/// handoff condition can be exercised independently.
const _slowStorage = Duration(milliseconds: 900);

Widget _app(
  Future<ResumeRepository> Function() startup, {
  bool reducedMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: ResivoApp(startup: startup),
  );
}

void main() {
  testWidgets('splash holds until storage opens, then hands off to the list', (
    tester,
  ) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      _app(() => Future.delayed(_slowStorage, () => repo)),
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(ResumeListScreen), findsNothing);

    // Entrance over, storage still opening: the splash stays rather than
    // cutting to a screen that has nothing to show.
    await tester.pump(splashEntrance);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(ResumeListScreen), findsNothing);

    // pumpAndSettle only advances while frames are scheduled, and a splash
    // waiting on storage schedules none — so the pending open has to be waited
    // out explicitly before the handoff can settle.
    await tester.pump(_slowStorage);
    await tester.pumpAndSettle();
    expect(find.byType(ResumeListScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('No resumes yet'), findsOneWidget);
  });

  testWidgets('storage that opens instantly still gets the full entrance', (
    tester,
  ) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(_app(() async => repo));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    // Just short of the end of the entrance.
    await tester.pump(splashEntrance - const Duration(milliseconds: 50));
    expect(
      find.byType(ResumeListScreen),
      findsNothing,
      reason: 'the splash must not be cut off mid-animation',
    );

    await tester.pumpAndSettle();
    expect(find.byType(ResumeListScreen), findsOneWidget);
  });

  testWidgets('the resume list reads the repository that was opened', (
    tester,
  ) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);
    await repo.save(newResumeDocument(id: 'a'));

    await tester.pumpWidget(_app(() async => repo));
    await tester.pumpAndSettle();

    expect(find.text('Untitled resume'), findsOneWidget);
    expect(find.text('No resumes yet'), findsNothing);
  });

  testWidgets('reduced motion hands off without an animation', (tester) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(_app(() async => repo, reducedMotion: true));
    expect(
      find.byType(SplashScreen),
      findsOneWidget,
      reason: 'the brand frame is still shown, it just does not animate',
    );

    // No time advanced at all: one frame for the splash to report its (static)
    // entrance, one for the swap. Neither the 460ms entrance nor the 200ms
    // crossfade is waited out.
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    expect(find.byType(ResumeListScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('a failed start surfaces the error instead of spinning', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(() async => throw StateError('box is corrupt')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StartupFailureScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Could not open your saved resumes'), findsOneWidget);
    expect(find.textContaining('box is corrupt'), findsOneWidget);
  });

  testWidgets('storage that never answers times out rather than hanging', (
    tester,
  ) async {
    // Stands in for a platform channel that never replies — the one way an
    // offline, local-only startup can still leave the user on a spinner.
    final never = Completer<ResumeRepository>();
    addTearDown(() => never.complete(InMemoryResumeRepository()));

    await tester.pumpWidget(_app(() => never.future));
    await tester.pump(const Duration(seconds: 10));
    expect(
      find.byType(SplashScreen),
      findsOneWidget,
      reason: 'a slow start is still a start',
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(StartupFailureScreen), findsOneWidget);
    expect(find.text('Storage did not respond.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('retrying after a failure reaches the app', (tester) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    var attempts = 0;
    await tester.pumpWidget(
      _app(() async {
        attempts++;
        if (attempts == 1) throw StateError('box is corrupt');
        return repo;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StartupFailureScreen), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(
      find.byType(SplashScreen),
      findsOneWidget,
      reason: 'a retry goes back to starting up, not to a dead screen',
    );

    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(ResumeListScreen), findsOneWidget);
  });

  testWidgets('nothing reads the repository before the handoff', (
    tester,
  ) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      _app(() => Future.delayed(_slowStorage, () => repo)),
    );
    await tester.pump(splashEntrance);

    // The override throws while storage is opening. If any screen above the
    // resume list started reading it, that would surface here.
    expect(tester.takeException(), isNull);

    await tester.pump(_slowStorage);
    await tester.pumpAndSettle();
    expect(find.byType(ResumeListScreen), findsOneWidget);
  });
}
