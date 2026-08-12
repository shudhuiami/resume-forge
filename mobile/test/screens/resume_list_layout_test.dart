import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/about_screen.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/screens/resume_list_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/theme/tokens.dart';

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

  /// The one supporting line under the title. Spelled out here rather than read
  /// off the private widget, so a copy edit has to be a deliberate one.
  const greetingText = 'Welcome back. Pick up where you left off.';

  /// The empty state's hero: one solid disc, addressed by key.
  ///
  /// It used to be found by matching a Container painted with
  /// `AppTheme.heroGradient`, which is a finder that could only exist while
  /// exactly one thing on the screen carried a ramp. Nothing carries one now.
  final heroDisc = find.byKey(heroDiscKey);

  /// Every decoration painted anywhere in the current tree.
  ///
  /// `Container` folds its decoration into a `DecoratedBox`, but only once it
  /// is built — collecting from both is what makes this independent of how a
  /// given widget happens to be composed.
  Iterable<Decoration> decorationsIn(WidgetTester tester) sync* {
    for (final widget in tester.allWidgets) {
      if (widget is DecoratedBox) yield widget.decoration;
      if (widget is Container && widget.decoration != null) {
        yield widget.decoration!;
      }
      if (widget is Ink && widget.decoration != null) yield widget.decoration!;
    }
  }

  /// Fails if anything on screen is painted with a gradient.
  ///
  /// The palette is matte: solid fills only, no ramp, no gloss, no glow. This
  /// is asserted against the rendered tree rather than against the theme,
  /// because the theme was never where the gradients were — they were inlined
  /// in the widgets that wanted one.
  void expectNothingIsAGradient(WidgetTester tester, String where) {
    for (final decoration in decorationsIn(tester)) {
      final gradient = switch (decoration) {
        BoxDecoration(:final gradient) => gradient,
        ShapeDecoration(:final gradient) => gradient,
        _ => null,
      };
      expect(
        gradient,
        isNull,
        reason: '$where paints a $gradient; this palette is flat',
      );
    }
  }

  /// Brings [target] into view when the header has pushed it below the fold.
  /// A lazy list has not built an off-screen row, which is the point of one.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    if (target.evaluate().isNotEmpty) return;
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.byType(Scrollable).first,
    );
  }

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

    testWidgets('leads with a solid hero disc, not a ramp', (tester) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(heroDisc, findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(
        tester.getSize(heroDisc).width,
        160,
        reason: 'a phone has room for the full-size disc',
      );

      // One flat accent fill, which is also the colour the launcher icon's
      // page is filled with — the mark the user tapped to get here.
      final decoration =
          tester.widget<Container>(heroDisc).decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.colorScheme.primary);
      expect(decoration.gradient, isNull);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('the hero yields its space to the copy on a short screen', (
      tester,
    ) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);
      final onPhone = tester.getSize(heroDisc).width;

      // Landscape at double text size: the words and the button need every
      // pixel, so the disc must shrink rather than push them off the pane.
      await pumpList(tester, const Size(800, 360), repo: repo, textScale: 2);
      final squeezed = tester.getSize(heroDisc).width;

      expect(squeezed, lessThan(onPhone));
      expect(
        squeezed,
        greaterThanOrEqualTo(64),
        reason: 'below this the mark stops reading as a mark',
      );
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

    /// The one screen a first-run user sees. It used to show a hero, a heading
    /// and a button, and name the product nowhere at all — the app name had
    /// moved out of the removed `AppBar` and into a greeting that only renders
    /// once something has been saved.
    testWidgets('names the product before anything has been saved', (
      tester,
    ) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.text(Wordmark.text), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(Wordmark.text)).dy,
        lessThan(tester.getTopLeft(find.text('No resumes yet')).dy),
        reason:
            'it is the screen title above the hero, not a footnote under it',
      );
    });

    /// The title row costs height on the viewport that had least of it to give,
    /// so the orb has to pay for it rather than the copy.
    testWidgets('the wordmark survives a landscape phone at 2x text', (
      tester,
    ) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(800, 360), repo: repo, textScale: 2);

      expect(find.text(Wordmark.text), findsOneWidget);
      await tester.drag(find.text('No resumes yet'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('Create your first resume'), findsOneWidget);
    });
  });

  group('the populated list fits the viewport', () {
    for (final entry in viewports.entries) {
      testWidgets('long titles at ${entry.key} ${entry.value}', (tester) async {
        // Stamped rather than saved in sequence: the list is ordered by edit
        // time, and three documents created microseconds apart put the long
        // title in a different row on different runs — which decides whether
        // it is the row a short viewport builds. The hazard being tested is
        // the long title, so it is pinned to the top and the untitled one to
        // the bottom.
        final repo = await seeded(tester, [
          docNamed(
            'a',
            longName,
          ).copyWith(updatedAt: DateTime(2026, 8, 12, 12)),
          docNamed(
            'b',
            'Amara Okonkwo',
          ).copyWith(updatedAt: DateTime(2026, 8, 12, 11)),
          docNamed('c', '').copyWith(updatedAt: DateTime(2026, 8, 12, 10)),
        ]);
        await pumpList(tester, entry.value, repo: repo);

        expect(find.text(longName), findsOneWidget);
        // The header takes real height, so on a short viewport the last row
        // starts below the fold — a lazy list has not built it yet. Scrolling
        // to it is the assertion that it is reachable rather than lost.
        await scrollTo(tester, find.text('Untitled resume'));
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

      // The row itself, not the first Card on the screen — the quick actions
      // are cards too now.
      final card = tester.getSize(
        find
            .ancestor(
              of: find.text('Amara Okonkwo'),
              matching: find.byType(Card),
            )
            .first,
      );
      expect(
        card.width,
        lessThan(640),
        reason:
            'a full-width tablet row puts the title and its delete button half '
            'a screen apart',
      );
    });
  });

  /// The home screen is a title row, one line of greeting, one header action,
  /// and then the saved resumes — not a bare list under a bare bar. Every
  /// viewport here is pumped at normal and double text size, and a RenderFlex
  /// overflow anywhere in that header fails the test that provoked it.
  group('the home header', () {
    testWidgets('greets without inventing a user', (tester) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.text(greetingText), findsOneWidget);
      // There are no accounts, so nothing on this screen may address the user
      // by a name — including the name on the resume they happen to have saved.
      expect(find.textContaining('Amara', findRichText: true), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(Wordmark.text), findsOneWidget);
    });

    /// The header used to stack four lines of chrome above the first resume:
    /// the product name as a small eyebrow, a headline-sized "Welcome back",
    /// and two muted lines under that. The name is the title row's job now, and
    /// what is left of the greeting is one line.
    testWidgets('the greeting is one line, under one title', (tester) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final title = tester.getRect(find.text(Wordmark.text));
      final greeting = tester.getRect(find.text(greetingText));
      final firstCard = tester.getRect(
        find.ancestor(
          of: find.text('Amara Okonkwo'),
          matching: find.byType(Card),
        ),
      );

      expect(title.bottom, lessThanOrEqualTo(greeting.top));
      expect(
        find.text('Welcome back'),
        findsNothing,
        reason: 'the headline-sized greeting is now part of the one line',
      );
      expect(
        find.text(
          'Pick up where you left off. Everything stays on this device.',
        ),
        findsNothing,
        reason: 'the device claim is made on the about screen, not on relaunch',
      );
      // The whole header — title, greeting, browse action, section heading —
      // before the first resume: 244 here, where the four-line-plus-two-tiles
      // version measured about 330.
      expect(
        firstCard.top,
        lessThan(260),
        reason: 'header chrome must not fill the screen before the content',
      );
    });

    /// "New resume" used to be both a quick-action tile and the FAB — two
    /// controls, one destination, a hand's width apart, on the screen whose
    /// empty state goes out of its way to offer only one. The FAB is the one
    /// that survived: it is the only create action still on screen once the
    /// list has been scrolled.
    testWidgets('the create action exists exactly once', (tester) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.text('New resume'),
        findsNothing,
        reason:
            'the labelled tile was the duplicate; the FAB carries a tooltip',
      );
      expect(
        find.byIcon(Icons.add),
        findsOneWidget,
        reason: 'one plus on the screen, not two',
      );
    });

    /// The reason the FAB is the one that stayed. A tile scrolls away, and a
    /// long list is exactly when someone decides they want another resume.
    testWidgets('the create action outlives a scrolled list', (tester) async {
      final repo = await seeded(tester, [
        for (var i = 0; i < 12; i++) docNamed('r$i', 'Person $i'),
      ]);
      await pumpList(tester, const Size(360, 800), repo: repo);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(
        find.text(greetingText),
        findsNothing,
        reason: 'the header really has scrolled out of view',
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GalleryScreen), findsOneWidget);
    });

    testWidgets('the icon-only create action is still labelled and live', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(
        fab.tooltip,
        'New resume',
        reason: 'an icon-only control with no label is unusable by a reader',
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GalleryScreen), findsOneWidget);
    });

    /// A FAB is a fixed graphic; an extended one grows with its label. At 2x on
    /// a 360px phone the labelled version took two thirds of the width and
    /// parked itself across the first resume in the list.
    testWidgets('the create action does not grow with the text size', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      final fab = find.byType(FloatingActionButton);

      await pumpList(tester, const Size(360, 800), repo: repo);
      final normal = tester.getSize(fab);

      await pumpList(tester, const Size(360, 800), repo: repo, textScale: 2);
      final large = tester.getSize(fab);

      expect(large.width, normal.width);
      expect(
        large.width,
        lessThan(120),
        reason: 'the create action must not take a third of a small screen',
      );
      expect(large.width, greaterThanOrEqualTo(48));
    });

    testWidgets('the greeting belongs to the populated state only', (
      tester,
    ) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(
        find.text(greetingText),
        findsNothing,
        reason:
            'a first run has nothing to come back to, and the hero pane needs '
            'the height',
      );
      expect(find.text('Browse designs'), findsNothing);
    });

    for (final entry in viewports.entries) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('header and actions fit ${entry.key} at ${scale}x text', (
          tester,
        ) async {
          final repo = await seeded(tester, [docNamed('a', longName)]);
          await pumpList(tester, entry.value, repo: repo, textScale: scale);

          expect(find.text(Wordmark.text), findsOneWidget);
          expect(find.byIcon(Icons.info_outline), findsOneWidget);
          expect(find.text(greetingText), findsOneWidget);
          expect(find.text('Browse designs'), findsOneWidget);
        });
      }
    }

    /// A stacked header on a landscape phone filled the viewport on its own and
    /// left the first resume entirely below the fold. Past 560px of content the
    /// greeting and the browse action share the width instead.
    testWidgets('the browse action sits beside the greeting given width', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      final tile = find.byKey(quickActionKey('Browse designs'));
      final greeting = find.text(greetingText);

      await pumpList(tester, const Size(390, 844), repo: repo);
      expect(
        tester.getTopLeft(tile).dy,
        greaterThan(tester.getBottomLeft(greeting).dy),
        reason: 'a phone stacks them',
      );

      await pumpList(tester, const Size(800, 360), repo: repo);
      expect(
        tester.getTopLeft(tile).dx,
        greaterThan(tester.getBottomRight(greeting).dx),
        reason: 'a landscape phone puts them side by side',
      );
      expect(
        tester.getTopLeft(find.byType(Card).last).dy,
        lessThan(360),
        reason: 'the first resume must be visible without scrolling',
      );

      await pumpList(tester, const Size(768, 1024), repo: repo);
      expect(
        tester.getTopLeft(tile).dx,
        greaterThan(tester.getBottomRight(greeting).dx),
        reason: 'so does a tablet',
      );
    });

    testWidgets('the browse action stays a touch target as its label wraps', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      final tile = find.byKey(quickActionKey('Browse designs'));

      for (final scale in const [1.0, 2.0]) {
        await pumpList(
          tester,
          const Size(360, 800),
          repo: repo,
          textScale: scale,
        );

        expect(
          tester.getSize(tile).height,
          greaterThanOrEqualTo(48),
          reason: 'a header action is a touch target at ${scale}x',
        );
        expect(
          find.descendant(of: tile, matching: find.byIcon(Icons.chevron_right)),
          findsOneWidget,
          reason: 'the chevron is what says the card goes somewhere',
        );
      }
    });

    /// Not a stub: it opens the gallery, which is the only destination ahead of
    /// the editor. Asserted through the gallery's own framing so the scoping
    /// survives the gallery restyling its header.
    testWidgets('the browse action opens the gallery as "Browse designs"', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      await tester.tap(find.byKey(quickActionKey('Browse designs')));
      // Not pumpAndSettle: gallery thumbnails spin while they rasterize.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GalleryScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GalleryScreen),
          matching: find.text('Browse designs'),
        ),
        findsOneWidget,
      );
    });

    /// The quick actions used to be the one place on a populated home where the
    /// accent ramp appeared. What is left is one action, marked with the same
    /// recessed accent square the editor's sections carry — flat, and not a
    /// solid tint, because on this screen a tint means "this is a design".
    testWidgets('the browse action wears a recessed accent mark, not a ramp', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final tile = find.byKey(quickActionKey('Browse designs'));
      final mark = tester
          .widgetList<Container>(
            find.descendant(of: tile, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .first;

      expect(mark.color, AppTheme.colorScheme.surfaceContainerLowest);
      expect(mark.gradient, isNull);
      expect(
        tester.widget<Card>(tile).color,
        isNull,
        reason:
            'the card keeps the plain tier; a tint would claim it is a design',
      );
    });
  });

  /// The title row: the product's name, and the one route off this screen that
  /// is not a resume. It is outside the scroll view and above every state, so
  /// neither depends on having saved something or on where the list is
  /// scrolled to.
  group('the title row', () {
    testWidgets('names the product in every state', (tester) async {
      final populated = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: populated);
      expect(find.text(Wordmark.text), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      final empty = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: empty);
      expect(find.text(Wordmark.text), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await pumpList(tester, const Size(390, 844), repo: _BrokenRepository());
      expect(find.text(Wordmark.text), findsOneWidget);
      expect(
        find.byIcon(Icons.info_outline),
        findsOneWidget,
        reason: 'a broken list must not take the rest of the app with it',
      );
    });

    testWidgets('the information button is labelled and opens the screen', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.info_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        button.tooltip,
        'About ResumeForge',
        reason: 'an icon-only control with no label is unusable by a reader',
      );

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    testWidgets('it stays put while the list scrolls', (tester) async {
      final repo = await seeded(tester, [
        for (var i = 0; i < 12; i++) docNamed('r$i', 'Person $i'),
      ]);
      await pumpList(tester, const Size(360, 800), repo: repo);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text(Wordmark.text), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    /// The case most likely to break: one unbreakable word beside a
    /// fixed-size icon button on the narrowest phone at the largest text size.
    testWidgets('the title shares its row at 2x text on a small phone', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(360, 800), repo: repo, textScale: 2);

      final title = tester.widget<Text>(find.text(Wordmark.text));
      expect(
        title.textScaler?.scale(10),
        lessThanOrEqualTo(16),
        reason: 'past ~1.6x the product name can only ellipsize',
      );
      expect(title.maxLines, 1);

      final button = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.info_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.width, greaterThanOrEqualTo(48));
      expect(button.height, greaterThanOrEqualTo(48));

      // The row fits inside the screen rather than running off it: a Row that
      // overflows throws, but a title that pushed the button off the edge
      // would not.
      final row = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.info_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(row.right, lessThanOrEqualTo(360));
    });
  });

  /// The whole point of the re-tone: solid matte colour everywhere, and not one
  /// ramp left behind. Asserted on the rendered tree of both states of this
  /// screen rather than on the theme, because the ramps lived in the widgets.
  group('nothing is painted with a gradient', () {
    testWidgets('the empty state', (tester) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);
      expectNothingIsAGradient(tester, 'the empty state');
    });

    testWidgets('the populated home', (tester) async {
      final repo = await seeded(tester, [
        docNamed('a', 'Amara Okonkwo'),
        docNamed('b', longName),
      ]);
      await pumpList(tester, const Size(390, 844), repo: repo);
      expectNothingIsAGradient(tester, 'the populated home');
    });

    testWidgets('the failure state', (tester) async {
      await pumpList(tester, const Size(390, 844), repo: _BrokenRepository());
      expectNothingIsAGradient(tester, 'the failure state');
    });
  });

  group('a resume card says more than its title', () {
    ResumeDocument filled(String id) => newResumeDocument(id: id).copyWith(
      data: const ResumeData(
        personalInfo: PersonalInfo(fullName: 'Amara Okonkwo'),
        experiences: [
          Experience(id: 'e1'),
          Experience(id: 'e2'),
        ],
        education: [Education(id: 'd1')],
        skills: [
          Skill(id: 's1'),
          Skill(id: 's2'),
          Skill(id: 's3'),
        ],
      ),
    );

    testWidgets('names the design, the progress, and the edit time', (
      tester,
    ) async {
      final repo = await seeded(tester, [filled('a')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.text(defaultTemplate.name), findsOneWidget);
      expect(find.text('2 roles · 1 degree · 3 skills'), findsOneWidget);
      expect(find.text('Edited just now'), findsOneWidget);
      expect(
        find.text('AO'),
        findsOneWidget,
        reason: 'the plate carries the initials on the resume',
      );
    });

    testWidgets('an untouched document says so instead of looking broken', (
      tester,
    ) async {
      final repo = await seeded(tester, [newResumeDocument(id: 'a')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.text('Not started yet'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byIcon(Icons.description_outlined),
        ),
        findsOneWidget,
        reason: 'no name to draw initials from yet',
      );
    });

    /// The row used to fall back to `2026-07` past a month, so it read "Edited
    /// 2026-07" — a stamp rather than a phrase, and ambiguous about the day.
    /// A resume kept for a year of occasional applications is a real case, so
    /// the long tail gets a real date.
    test('the edit stamp is a phrase at every age', () {
      final now = DateTime(2026, 8, 12, 15, 30);
      String at(Duration ago) => relativeEditedAt(now.subtract(ago), now: now);

      expect(at(const Duration(seconds: 20)), 'just now');
      expect(at(const Duration(minutes: 5)), '5m ago');
      expect(at(const Duration(hours: 3)), '3h ago');
      expect(at(const Duration(days: 9)), '9d ago');
      expect(
        at(const Duration(days: 200)),
        'on 24 Jan 2026',
        reason: 'a bare year-month is a stamp, not something you can read out',
      );
    });

    testWidgets('an old resume says a date, not a stamp', (tester) async {
      final repo = await seeded(tester, [
        docNamed(
          'a',
          'Amara Okonkwo',
        ).copyWith(updatedAt: DateTime(2026, 1, 24, 9)),
      ]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.text('Edited on 24 Jan 2026'), findsOneWidget);
    });

    testWidgets('a name with no sections is described honestly', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      expect(find.text('Personal details only'), findsOneWidget);
    });

    testWidgets('the plate holds its page shape and its initials at 2x text', (
      tester,
    ) async {
      final repo = await seeded(tester, [filled('a')]);
      await pumpList(tester, const Size(360, 800), repo: repo, textScale: 2);

      final plate = tester.getSize(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(plate.width / plate.height, closeTo(794 / 1123, 0.02));
      expect(find.text('AO'), findsOneWidget);
    });
  });

  /// A row wears its design's category tint, so every word on it is read
  /// against whichever of the five that design happens to be — and the plate
  /// and chip inside it are recesses cut back to the well.
  group('card colour pairings clear WCAG AA', () {
    const cs = AppTheme.colorScheme;
    const tokens = AppTokens();

    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    void atLeast(String label, Color fg, Color bg, double threshold) {
      final measured = ratio(fg, bg);
      expect(
        measured,
        greaterThanOrEqualTo(threshold),
        reason: '$label is ${measured.toStringAsFixed(2)}:1, needs $threshold',
      );
    }

    test('card copy on every tint a row can take', () {
      for (final category in TemplateCategory.values) {
        final tint = categoryTint(category, tokens);
        atLeast('onSurface/${category.name}', cs.onSurface, tint, 4.5);
        atLeast(
          'onSurfaceVariant/${category.name}',
          cs.onSurfaceVariant,
          tint,
          4.5,
        );
      }
    });

    test('the plate and the chip are recesses that still read', () {
      // Both are punched back to the well and marked in the accent or in
      // muted ink, so neither has to be re-measured per tint — which is the
      // reason they are recesses rather than a second colour per design.
      atLeast(
        'primary/well (plate initials)',
        cs.primary,
        cs.surfaceContainerLowest,
        4.5,
      );
      atLeast(
        'onSurfaceVariant/well (chip label)',
        cs.onSurfaceVariant,
        cs.surfaceContainerLowest,
        4.5,
      );
      for (final category in TemplateCategory.values) {
        final tint = categoryTint(category, tokens);
        final step = ratio(cs.surfaceContainerLowest, tint);
        expect(
          step,
          greaterThanOrEqualTo(1.35),
          reason:
              'the plate is only ${step.toStringAsFixed(2)}:1 below a '
              '${category.name} row; it has to read as cut into the card',
        );
      }
    });

    /// The tint is only worth learning if it means the same thing in both
    /// places it appears, so the two screens call one function rather than
    /// keeping two tables in step by hand.
    testWidgets('a row is the same colour as that design in the gallery', (
      tester,
    ) async {
      final repo = await seeded(tester, [docNamed('a', 'Amara Okonkwo')]);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final row = tester.widget<Card>(
        find
            .ancestor(
              of: find.text('Amara Okonkwo'),
              matching: find.byType(Card),
            )
            .first,
      );
      expect(row.color, categoryTint(defaultTemplate.category, tokens));
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

      // Scoped to the row's own button: the title row carries one too.
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Delete Amara Okonkwo');
    });
  });

  /// What replaced the ramp maths.
  ///
  /// The hero used to be a five-stop pink/violet/blue gradient, and its glyph
  /// was white — the only colour that worked across all five stops, except that
  /// the warm end measured ~2.1:1 against it. That was solved by shading the
  /// core of the orb with the theme scrim and sampling the ramp at fifty points
  /// to prove the fix held, which is a lot of machinery for a decision the
  /// matte palette has now unmade.
  ///
  /// A solid fill has exactly one pair to check, and it is a pair the theme
  /// already guarantees everywhere else. `AppTheme.onHero`, `heroCoreShadeAlpha`
  /// and the sampler are deleted rather than left dormant — there is no ramp
  /// left for them to describe.
  group('the hero glyph is legible on the solid disc', () {
    double contrastRatio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    test('one fill, one pair, no sampling required', () {
      const cs = AppTheme.colorScheme;
      final ratio = contrastRatio(cs.onPrimary, cs.primary);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason:
            'the glyph measures ${ratio.toStringAsFixed(2)}:1 on the disc; '
            'a meaningful graphic needs 3:1',
      );
      // Comfortably past it, rather than resting on the threshold the way the
      // shaded ramp did at 3.30:1.
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    testWidgets('and the disc really is one flat colour', (tester) async {
      final repo = await seeded(tester, const []);
      await pumpList(tester, const Size(390, 844), repo: repo);

      final decoration =
          tester.widget<Container>(heroDisc).decoration! as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, isNotNull);
      // No glow either: the disc is its own box now, where it used to sit in
      // one 1.6x wider and 1.32x taller so a blurred halo had somewhere to
      // fall.
      expect(
        tester.getSize(heroDisc).width,
        tester.getSize(heroDisc).height,
        reason: 'the hero box is the disc, with no room reserved for a glow',
      );
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
