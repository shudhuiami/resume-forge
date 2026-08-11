import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/resume_list_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// A repository that cannot read, so the list screen's error branch is
/// reachable from a test instead of only in theory.
class _BrokenRepository implements ResumeRepository {
  @override
  Future<List<ResumeDocument>> all() async => throw StateError('box is gone');

  @override
  Future<ResumeDocument?> byId(String id) async => null;

  @override
  Future<void> save(ResumeDocument doc) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Stream<List<ResumeDocument>> watch() => const Stream.empty();

  @override
  Future<void> close() async {}
}

void main() {
  const viewports = {
    'phone small': Size(360, 800),
    'phone normal': Size(390, 844),
    'phone large': Size(430, 932),
    'tablet': Size(768, 1024),
    'phone landscape': Size(800, 360),
  };

  /// A name long enough to break a row that does not constrain its title.
  const longName =
      'Wolfeschlegelsteinhausenbergerdorff-Featherstonehaugh Montgomery III';

  ResumeDocument docNamed(String id, String fullName) =>
      newResumeDocument(id: id).copyWith(
        data: ResumeData(personalInfo: PersonalInfo(fullName: fullName)),
      );

  Future<void> pumpList(
    WidgetTester tester,
    Size size, {
    required ResumeRepository repo,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

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
              child: const ResumeListScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<InMemoryResumeRepository> seeded(
    WidgetTester tester,
    List<ResumeDocument> docs,
  ) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);
    for (final doc in docs) {
      await repo.save(doc);
    }
    return repo;
  }

  group('the empty state fits the viewport', () {
    for (final entry in viewports.entries) {
      testWidgets('${entry.key} at ${entry.value}', (tester) async {
        final repo = await seeded(tester, const []);
        await pumpList(tester, entry.value, repo: repo);

        expect(find.text('No resumes yet'), findsOneWidget);
        expect(find.text('Create your first resume'), findsOneWidget);
      });
    }

    testWidgets('scrolls rather than overflowing when it cannot fit', (
      tester,
    ) async {
      final repo = await seeded(tester, const []);
      // Short landscape window plus double text size: the stack is taller than
      // the screen and must scroll instead of throwing an overflow.
      await pumpList(tester, const Size(800, 360), repo: repo, textScale: 2);

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(find.text('No resumes yet'), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.text('Create your first resume'), findsOneWidget);
    });

    testWidgets('offers one call to action, not two', (tester) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(
        find.byType(FloatingActionButton),
        findsNothing,
        reason: 'the empty state already carries the create action',
      );

      await repo.save(docNamed('a', 'Amara Okonkwo'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('the populated list fits the viewport', () {
    for (final entry in viewports.entries) {
      testWidgets('long titles at ${entry.key} ${entry.value}', (tester) async {
        final repo = await seeded(tester, [
          docNamed('a', longName),
          docNamed('b', 'Amara Okonkwo'),
          docNamed('c', ''),
        ]);
        await pumpList(tester, entry.value, repo: repo);

        expect(find.text(longName), findsOneWidget);
        expect(find.text('Untitled resume'), findsOneWidget);
      });
    }

    testWidgets('long titles at double text size', (tester) async {
      final repo = await seeded(tester, [docNamed('a', longName)]);
      await pumpList(tester, const Size(360, 800), repo: repo, textScale: 2);

      expect(find.text(longName), findsOneWidget);
    });

    testWidgets('rows stop widening on a tablet', (tester) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(768, 1024), repo: repo);

      final card = tester.getSize(find.byType(Card).first);
      expect(
        card.width,
        lessThan(640),
        reason:
            'a full-width tablet row puts the title and its delete button half '
            'a screen apart',
      );
    });
  });

  group('destructive action', () {
    testWidgets('the delete button confirms before removing anything', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Delete this resume?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repo.all(), hasLength(1));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await repo.all(), isEmpty);
      expect(find.text('No resumes yet'), findsOneWidget);
    });

    testWidgets('the icon-only delete control carries a label', (tester) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, 'Delete Amara Okonkwo');
    });
  });

  group('failure state', () {
    testWidgets('a repository that cannot read shows a retry, not a blank', (
      tester,
    ) async {
      await pumpList(tester, const Size(390, 844), repo: _BrokenRepository());

      expect(find.text('Could not load your saved resumes'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the failure state survives a landscape phone', (tester) async {
      await pumpList(tester, const Size(800, 360), repo: _BrokenRepository());

      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
