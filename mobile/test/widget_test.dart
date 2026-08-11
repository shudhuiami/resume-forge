import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/screens/resume_list_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

Widget harness(ResumeRepository repo) => ProviderScope(
  overrides: [repositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(theme: AppTheme.build(), home: const ResumeListScreen()),
);

void main() {
  testWidgets('shows the empty state when nothing is saved', (tester) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    expect(find.text('No resumes yet'), findsOneWidget);
    expect(find.text('Create your first resume'), findsOneWidget);
  });

  testWidgets('lists saved resumes newest first', (tester) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await repo.save(
      newResumeDocument(id: 'a').copyWith(updatedAt: DateTime(2026, 1, 1)),
    );
    await repo.save(
      newResumeDocument(id: 'b').copyWith(updatedAt: DateTime(2026, 6, 1)),
    );

    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    // Both render, and an untitled document still shows a usable label rather
    // than an empty row.
    expect(find.text('Untitled resume'), findsNWidgets(2));
    expect(find.text('No resumes yet'), findsNothing);
  });
}
