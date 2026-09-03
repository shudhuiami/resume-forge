import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_portrait.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/form_fields.dart';

/// Telling the user when their design will not print their photo.
///
/// QA reported this as "the image is not showing" on five designs. It is not a
/// bug — those five render no portrait on purpose, and three say so in their own
/// doc comments — and adding photos to them would erase a distinction the
/// gallery advertises. The defect is that the app never said so: a photo was
/// added, a design was chosen, and the portrait quietly did not appear.
///
/// So the note is a disclosure with one condition on it: the user has actually
/// added a photo, and this design will not print it. A permanent label on five
/// designs would be read once and never again.
void main() {
  /// Tall enough to build the whole form, so these are assertions about content
  /// rather than about how far a list has been scrolled.
  const tall = Size(430, 4000);

  final photoFree = resumeTemplates.firstWhere(
    (t) => !templateShowsPhoto(t.id),
  );
  final photoShowing = resumeTemplates.firstWhere(
    (t) => templateShowsPhoto(t.id),
  );

  Future<void> pumpEditor(
    WidgetTester tester, {
    required bool withPhoto,
    required String templateId,
    Size size = tall,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    final doc = newResumeDocument().copyWith(
      templateId: templateId,
      data: ResumeData(
        personalInfo: PersonalInfo(
          fullName: 'Amara Okonkwo',
          photo: withPhoto ? samplePortraitJpeg : null,
        ),
      ),
    );
    await repo.save(doc);

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
              child: EditorScreen(document: doc),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
  }

  Finder note() => find.textContaining('prints no photo');

  testWidgets('a photo on a photo-free design is disclosed, by name', (
    tester,
  ) async {
    await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);

    expect(note(), findsOneWidget);
    expect(
      find.textContaining(photoFree.name),
      findsWidgets,
      reason: 'naming the design is what makes the note actionable',
    );
    expect(
      find.textContaining('stays saved'),
      findsOneWidget,
      reason: 'the photo is not lost, and a warning that implies it is lies',
    );
    await quiesce(tester);
  });

  testWidgets('a design that does print one says nothing', (tester) async {
    await pumpEditor(tester, withPhoto: true, templateId: photoShowing.id);

    expect(note(), findsNothing);
    await quiesce(tester);
  });

  testWidgets('no photo, no note — there is nothing being left out yet', (
    tester,
  ) async {
    await pumpEditor(tester, withPhoto: false, templateId: photoFree.id);

    expect(note(), findsNothing);
    expect(
      find.text('Add photo'),
      findsOneWidget,
      reason: 'the tile is otherwise unchanged',
    );
    await quiesce(tester);
  });

  testWidgets('it offers the one action that changes the outcome', (
    tester,
  ) async {
    await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);

    await tester.ensureVisible(find.text('Change design'));
    await tester.pump();
    await tester.tap(find.text('Change design'));
    // Not pumpAndSettle: the gallery's thumbnails rasterize behind an
    // indeterminate progress indicator, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(GalleryScreen),
      findsOneWidget,
      reason: 'the note has to land where the choice is made',
    );
    // And the gallery says the same thing about the design in its own copy, so
    // the user is not choosing blind a second time.
    expect(find.text(templateCues[photoFree.id]!), findsWidgets);

    // Back out rather than leaving the route open under the tear-down.
    Navigator.of(tester.element(find.byType(GalleryScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await quiesce(tester);
  });

  testWidgets('removing the photo takes the note away with it', (tester) async {
    await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);
    expect(note(), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(note(), findsNothing);
    await quiesce(tester);
  });

  /// The note is a paragraph and a button inside a tile that already holds an
  /// avatar, two lines of copy and two more buttons — the densest block on the
  /// screen, and the one most likely to overflow.
  for (final size in const [
    Size(360, 4000),
    Size(390, 4000),
    Size(430, 4000),
    Size(768, 4000),
  ]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('lays out at ${size.width.toInt()}px, ${scale}x', (
        tester,
      ) async {
        await pumpEditor(
          tester,
          withPhoto: true,
          templateId: photoFree.id,
          size: size,
          textScale: scale,
        );

        expect(note(), findsOneWidget);
        // Inside the card that hosts it, at every size — the failure this
        // catches is a row with a fixed-width part spilling past the card's
        // own edge, which is not something a pump reports on its own.
        final card = tester.getRect(find.byType(FormSectionCard).first);
        final message = tester.getRect(note());
        expect(message.left, greaterThanOrEqualTo(card.left));
        expect(message.right, lessThanOrEqualTo(card.right));

        final action = tester.getRect(find.text('Change design'));
        expect(action.left, greaterThanOrEqualTo(card.left));
        expect(action.right, lessThanOrEqualTo(card.right));
        await quiesce(tester);
      });
    }
  }
}
