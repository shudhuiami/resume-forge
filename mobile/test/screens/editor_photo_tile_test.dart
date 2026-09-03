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
import 'package:resume_forge/theme/tokens.dart';
import 'package:resume_forge/widgets/form_fields.dart';

/// What "About you" offers about a photo, on a design that prints one and on a
/// design that does not.
///
/// QA first reported this as "the image is not showing" on five designs. It is
/// not a bug — those five render no portrait on purpose, and three say so in
/// their own doc comments — and adding photos to them would erase a distinction
/// the gallery advertises. The first fix disclosed it in a note beside a picker
/// that still worked. The user's answer to that: *"if user selects a template
/// with no image then the form should not show a image picker. it's
/// confusing"*. They are right. A picker that invites a choose-crop-and-wait
/// for an image the design will discard is worse than the silence was, and a
/// note explaining a control that should never have been offered is not the
/// fix.
///
/// So there are three states, and this file pins all three:
///
///  1. photo-free design, nothing stored — no tile at all;
///  2. photo-free design, photo stored — no picker, but the photo, what
///     becomes of it, and Remove;
///  3. a design that prints one — the tile exactly as it was.
///
/// The second state is the one that must not be lost to a tidier rule. A photo
/// belongs to the resume, not to the design, so it survives a switch to a
/// photo-free design — and if the tile went with the picker, the only control
/// over a photo the user has already added would go with it.
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
  final otherPhotoShowing = resumeTemplates.lastWhere(
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

  /// Goes through the gallery the way the user does, and comes back to the
  /// form.
  ///
  /// Changing the design drops the user on the preview tab — the change is
  /// meant to be seen — so the form is off-screen and unbuilt until the Edit
  /// tab is chosen again. That round trip is the transition under test: the
  /// tile has to be right on the frame the form comes back.
  Future<void> switchDesign(WidgetTester tester, {required String to}) async {
    await tester.tap(find.byTooltip('Change design'));
    // Not pumpAndSettle: the gallery's thumbnails rasterize behind an
    // indeterminate progress indicator, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GalleryScreen), findsOneWidget);

    final card = find.byKey(templateCardKey(to));
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    // Three frames rather than pumpAndSettle: the pop animates, and until it
    // has finished the editor underneath is offstage and cannot be tapped.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GalleryScreen), findsNothing);

    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder tile() => find.byKey(photoTileKey);
  Finder note() => find.textContaining('prints no photo');
  Finder picker() => find.text('Add photo');
  Finder replace() => find.text('Replace photo');
  Finder remove() => find.text('Remove');

  group('a design that prints no photo', () {
    testWidgets('offers no picker, and no tile at all, with nothing stored', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: false, templateId: photoFree.id);

      expect(
        tile(),
        findsNothing,
        reason: 'nothing is being left out, so there is nothing to say',
      );
      expect(picker(), findsNothing);
      expect(replace(), findsNothing);
      expect(remove(), findsNothing);
      expect(
        note(),
        findsNothing,
        reason: 'a note about a control that is not there is worse than none',
      );
      // The section still has to read as a deliberate form.
      expect(find.text('Full name'), findsOneWidget);
      await quiesce(tester);
    });

    testWidgets('leaves no hole where the tile was', (tester) async {
      await pumpEditor(tester, withPhoto: false, templateId: photoFree.id);

      final tokens = tester.element(find.byType(FormSectionCard).first).tokens;
      final subtitle = tester.getRect(
        find.text('The header of every design is built from this.'),
      );
      final firstField = tester.getRect(
        find.ancestor(
          of: find.text('Full name'),
          matching: find.byType(ResumeTextField),
        ),
      );

      expect(
        firstField.top - subtitle.bottom,
        moreOrLessEquals(tokens.spaceLg, epsilon: 1),
        reason: 'the first field sits exactly where every section header ends',
      );
      await quiesce(tester);
    });

    testWidgets('keeps a stored photo, and says so by name, without a picker', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);

      expect(tile(), findsOneWidget);
      expect(
        picker(),
        findsNothing,
        reason: 'this is the fix: no invitation to crop a discarded image',
      );
      expect(replace(), findsNothing);

      expect(note(), findsOneWidget);
      expect(
        find.textContaining(photoFree.name),
        findsWidgets,
        reason: 'naming the design is what makes the disclosure actionable',
      );
      expect(
        find.textContaining('stays saved'),
        findsOneWidget,
        reason: 'the photo is not lost, and copy that implies it is lies',
      );
      await quiesce(tester);
    });

    testWidgets('still lets the user delete the photo they added', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);

      expect(
        remove(),
        findsOneWidget,
        reason: 'hiding the only control over stored data is the worse bug',
      );

      await tester.tap(remove());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // And with nothing stored, the tile goes with it.
      expect(tile(), findsNothing);
      expect(note(), findsNothing);
      await quiesce(tester);
    });

    testWidgets('offers the one action that changes the outcome', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);

      await tester.ensureVisible(find.text('Change design'));
      await tester.pump();
      await tester.tap(find.text('Change design'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(GalleryScreen),
        findsOneWidget,
        reason: 'the disclosure has to land where the choice is made',
      );
      // And the gallery says the same thing about the design in its own copy,
      // so the user is not choosing blind a second time.
      expect(find.text(templateCues[photoFree.id]!), findsWidgets);

      // Back out rather than leaving the route open under the tear-down.
      Navigator.of(tester.element(find.byType(GalleryScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await quiesce(tester);
    });

    testWidgets('names the photo for a screen reader', (tester) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);

      expect(
        find.bySemanticsLabel('Your photo'),
        findsOneWidget,
        reason: 'otherwise Remove is reached with no idea what it removes',
      );
      await quiesce(tester);
    });
  });

  group('a design that prints one', () {
    testWidgets('offers the picker, and says nothing about being left out', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: false, templateId: photoShowing.id);

      expect(tile(), findsOneWidget);
      expect(picker(), findsOneWidget);
      expect(remove(), findsNothing, reason: 'nothing to remove yet');
      expect(note(), findsNothing);
      await quiesce(tester);
    });

    testWidgets('offers replace and remove once a photo is stored', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoShowing.id);

      expect(replace(), findsOneWidget);
      expect(remove(), findsOneWidget);
      expect(note(), findsNothing);
      expect(find.bySemanticsLabel('Your photo'), findsOneWidget);
      await quiesce(tester);
    });
  });

  /// The transition is the whole point: the picker has to appear and disappear
  /// as the design changes under a document that never moves.
  group('switching design', () {
    testWidgets('to a photo-free design takes the picker away, not the photo', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoShowing.id);
      expect(replace(), findsOneWidget);

      await switchDesign(tester, to: photoFree.id);

      expect(replace(), findsNothing);
      expect(picker(), findsNothing);
      expect(note(), findsOneWidget);
      expect(
        remove(),
        findsOneWidget,
        reason: 'the photo survived the switch, so its Remove must too',
      );
      await quiesce(tester);
    });

    testWidgets('back to a design that prints one brings the picker back', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: true, templateId: photoFree.id);
      expect(note(), findsOneWidget);
      expect(replace(), findsNothing);

      await switchDesign(tester, to: otherPhotoShowing.id);

      expect(
        replace(),
        findsOneWidget,
        reason: 'the stored photo is still there and is printable again',
      );
      expect(note(), findsNothing);
      await quiesce(tester);
    });

    testWidgets('brings the whole tile back when nothing is stored', (
      tester,
    ) async {
      await pumpEditor(tester, withPhoto: false, templateId: photoFree.id);
      expect(tile(), findsNothing);

      await switchDesign(tester, to: otherPhotoShowing.id);

      expect(tile(), findsOneWidget);
      expect(picker(), findsOneWidget);
      await quiesce(tester);
    });
  });

  /// The kept-photo tile is a paragraph, an avatar and two buttons in the
  /// densest block on the screen — the one most likely to overflow. These pump
  /// real viewports: a RenderFlex overflow is a framework error, so it fails
  /// the test that provoked it.
  group('layout', () {
    const viewports = {
      'phone small': Size(360, 800),
      'phone normal': Size(390, 844),
      'phone large': Size(430, 932),
      'tablet': Size(768, 1024),
      'landscape phone': Size(844, 390),
    };

    for (final entry in viewports.entries) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('${entry.key} at ${scale}x', (tester) async {
          await pumpEditor(
            tester,
            withPhoto: true,
            templateId: photoFree.id,
            size: entry.value,
            textScale: scale,
          );

          await tester.ensureVisible(tile());
          await tester.pump();

          // Inside the card that hosts it, at every size — the failure this
          // catches is a row with a fixed-width part spilling past the card's
          // own edge, which is not something a pump reports on its own.
          final card = tester.getRect(find.byType(FormSectionCard).first);
          for (final part in [
            note(),
            find.text('Change design'),
            remove(),
            find.byKey(photoTileKey),
          ]) {
            final rect = tester.getRect(part);
            expect(rect.left, greaterThanOrEqualTo(card.left));
            expect(rect.right, lessThanOrEqualTo(card.right));
          }
          await quiesce(tester);
        });
      }
    }
  });
}
