import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/screens/resume_list_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/theme/app_theme.dart';

void main() {
  Widget harness(ResumeRepository repo) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: AppTheme.build(), home: const ResumeListScreen()),
  );

  testWidgets('creating a resume goes list -> gallery -> saved document', (
    tester,
  ) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create your first resume'));
    // Not pumpAndSettle: the gallery shows an indeterminate progress indicator
    // while thumbnails rasterize, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(GalleryScreen),
      findsOneWidget,
      reason: 'picking a design comes before the editor',
    );
    expect(find.text('Start with a design'), findsOneWidget);

    // Choose the design by its card, the way a user would.
    await tester.tap(find.text(defaultTemplate.name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await repo.all();
    expect(
      saved,
      hasLength(1),
      reason: 'choosing a design must persist a document',
    );
    expect(saved.single.templateId, defaultTemplate.id);
  });

  testWidgets('the gallery marks the current selection', (tester) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: GalleryScreen(
            selectedId: defaultTemplate.id,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text(defaultTemplate.name), findsOneWidget);
    expect(find.text(defaultTemplate.bestFor), findsOneWidget);
  });
}
