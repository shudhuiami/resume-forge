import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/theme/tokens.dart';

/// Layout, filtering, and selection verification for the template picker.
///
/// A RenderFlex overflow is a framework error, which fails the test that
/// provoked it — so every pump here is an assertion that the screen survives
/// the viewport and text size it was pumped at.
void main() {
  const viewports = {
    'phone small': Size(360, 800),
    'phone normal': Size(390, 844),
    'phone large': Size(430, 932),
    'tablet': Size(768, 1024),
    'phone landscape': Size(800, 360),
    'tablet landscape': Size(1024, 768),
    'very narrow': Size(320, 640),
  };

  /// A4 in logical pixels, the shape every thumbnail rasterizes at.
  const pageAspect = 794 / 1123;

  /// WCAG 2.1 relative-contrast ratio between two opaque colours.
  double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  final selections = <String>[];

  setUp(selections.clear);

  Future<void> pumpGallery(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    String? selectedId,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: GalleryScreen(
              selectedId: selectedId,
              onSelected: selections.add,
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: thumbnails show an indeterminate progress indicator
    // while they rasterize, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  SliverGridDelegateWithFixedCrossAxisCount delegateOf(WidgetTester tester) {
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  }

  int countIn(TemplateCategory category) =>
      resumeTemplates.where((t) => t.category == category).length;

  group('the screen lays out without overflow', () {
    for (final entry in viewports.entries) {
      testWidgets('${entry.key} at ${entry.value}', (tester) async {
        await pumpGallery(tester, entry.value);
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.text(defaultTemplate.name), findsOneWidget);
        // The header carries the title, so the app bar must not repeat it.
        expect(find.text('Choose a design'), findsOneWidget);
      });
    }

    testWidgets('at double text size on the smallest phone', (tester) async {
      await pumpGallery(
        tester,
        const Size(360, 800),
        textScale: 2,
        // With a selection so the badge — the widest thing that can sit on a
        // thumbnail — is laid out too.
        selectedId: defaultTemplate.id,
      );
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
    });

    testWidgets('at double text size in landscape', (tester) async {
      await pumpGallery(tester, const Size(800, 360), textScale: 2);
      expect(find.byType(SliverGrid), findsOneWidget);
    });
  });

  group('column count follows the width the cards actually get', () {
    // The old maths divided the full viewport width by a target tile width,
    // counting the grid padding and the gutters as usable space, so every card
    // came out narrower than intended.
    const expected = <(Size, int)>[
      (Size(360, 800), 2),
      (Size(390, 844), 2),
      (Size(430, 932), 2),
      (Size(768, 1024), 3),
      // Too narrow for two readable pages side by side.
      (Size(320, 640), 1),
    ];

    for (final (size, columns) in expected) {
      testWidgets('$columns column(s) at $size', (tester) async {
        await pumpGallery(tester, size);
        expect(delegateOf(tester).crossAxisCount, columns);
      });
    }

    testWidgets('a phone collapses to one column at double text size', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(390, 844), textScale: 2);
      expect(
        delegateOf(tester).crossAxisCount,
        1,
        reason:
            'two columns at 2x truncated every name and left the cue as pure '
            'ellipsis',
      );
    });

    testWidgets('a tablet keeps more than one column at double text size', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(768, 1024), textScale: 2);
      expect(delegateOf(tester).crossAxisCount, greaterThan(1));
    });

    testWidgets('a modest text bump does not cost a column', (tester) async {
      await pumpGallery(tester, const Size(390, 844), textScale: 1.3);
      expect(delegateOf(tester).crossAxisCount, 2);
    });
  });

  group('the thumbnail keeps the page shape', () {
    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
    ]) {
      testWidgets('A4 aspect at $size', (tester) async {
        await pumpGallery(tester, size);

        final box = tester.getSize(find.byType(AspectRatio).first);
        expect(
          box.width / box.height,
          closeTo(pageAspect, 0.01),
          reason:
              'a thumbnail box that is not A4 crops or letterboxes the design '
              'it is advertising',
        );
      });
    }

    testWidgets('the cell reserves room for the card around the page', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(390, 844));

      final extent = delegateOf(tester).mainAxisExtent!;
      final page = tester.getSize(find.byType(AspectRatio).first);
      expect(
        extent,
        greaterThan(page.height),
        reason: 'the caption must not be squeezed out of the cell',
      );
    });

    testWidgets('a larger text size grows the cell, not the page', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(390, 844));
      final normal = delegateOf(tester).mainAxisExtent!;

      await pumpGallery(tester, const Size(390, 844), textScale: 2);
      final scaled = delegateOf(tester).mainAxisExtent!;

      expect(scaled, greaterThan(normal));
    });
  });

  group('every design is identifiable before it is tapped', () {
    test('the cue table covers the registry exactly', () {
      expect(
        templateCues.keys.toSet(),
        resumeTemplates.map((t) => t.id).toSet(),
        reason:
            'a design without a cue ships as an unlabelled white rectangle, '
            'and a stale cue describes a design that no longer exists',
      );
    });

    test('cues are short enough to read under a thumbnail', () {
      for (final entry in templateCues.entries) {
        expect(
          entry.value.length,
          lessThanOrEqualTo(40),
          reason: '${entry.key} would ellipsize away to nothing',
        );
      }
    });

    testWidgets('a card shows its name, its structure, and its roles', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(390, 844));

      expect(find.text(defaultTemplate.name), findsOneWidget);
      expect(find.text(templateCues[defaultTemplate.id]!), findsOneWidget);
      expect(find.text(defaultTemplate.bestFor), findsOneWidget);
    });

    testWidgets('the cue gets the two lines a phone column needs', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(360, 800));

      final text = tester.widget<Text>(
        find.text(templateCues[defaultTemplate.id]!),
      );
      expect(
        text.maxLines,
        2,
        reason:
            'on one line every two-column design truncated to the identical '
            '"Two column · Photo · …", which is the wall this screen exists '
            'to break up',
      );
    });

    testWidgets('the full "best for" line survives the smallest phone', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(360, 800));

      final text = tester.widget<Text>(find.text(defaultTemplate.bestFor));
      expect(
        text.maxLines,
        2,
        reason: 'one line truncated the only description a card carries',
      );
    });
  });

  group('the category filter', () {
    testWidgets('offers All plus exactly the categories in the registry', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(768, 1024));

      expect(find.byKey(categoryChipKey(null)), findsOneWidget);
      for (final category in TemplateCategory.values) {
        expect(
          find.byKey(categoryChipKey(category)),
          countIn(category) > 0 ? findsOneWidget : findsNothing,
          reason: 'a chip that filters to nothing is a dead control',
        );
      }
    });

    testWidgets('narrows the grid and says how many are left', (tester) async {
      await pumpGallery(tester, const Size(390, 844));
      expect(
        find.textContaining('${resumeTemplates.length} designs.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(categoryChipKey(TemplateCategory.creative)));
      await tester.pump();

      final creative = countIn(TemplateCategory.creative);
      expect(
        find.textContaining('$creative of ${resumeTemplates.length} designs.'),
        findsOneWidget,
      );
      // Aurora is creative and stays; Beacon is corporate and goes.
      expect(find.byKey(templateCardKey('aurora')), findsOneWidget);
      expect(find.byKey(templateCardKey('beacon')), findsNothing);
    });

    testWidgets('All restores the whole catalog', (tester) async {
      await pumpGallery(tester, const Size(390, 844));

      await tester.tap(find.byKey(categoryChipKey(TemplateCategory.corporate)));
      await tester.pump();
      expect(find.byKey(templateCardKey('aurora')), findsNothing);

      await tester.tap(find.byKey(categoryChipKey(null)));
      await tester.pump();
      expect(find.byKey(templateCardKey('aurora')), findsOneWidget);
    });

    testWidgets('filtering never picks a design', (tester) async {
      await pumpGallery(
        tester,
        const Size(390, 844),
        selectedId: defaultTemplate.id,
      );

      await tester.tap(find.byKey(categoryChipKey(TemplateCategory.corporate)));
      await tester.pump();

      expect(
        selections,
        isEmpty,
        reason: 'a filter must not change the document the user is editing',
      );
    });

    testWidgets('chips past the right edge can be scrolled to', (tester) async {
      await pumpGallery(tester, const Size(360, 800));

      // Every chip is built, so the row has to be scrolled by position rather
      // than until a finder resolves.
      await tester.ensureVisible(
        find.byKey(categoryChipKey(TemplateCategory.values.last)),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(categoryChipKey(TemplateCategory.values.last)),
      );
      await tester.pump();

      expect(
        find.textContaining(
          '${countIn(TemplateCategory.values.last)} of '
          '${resumeTemplates.length} designs.',
        ),
        findsOneWidget,
      );
    });

    /// Filtering to a category the chosen design is not in used to scroll it
    /// off the screen with nothing left saying what was chosen: the header
    /// counted "2 of 13 designs" but never mentioned that yours was one of the
    /// eleven it had just hidden.
    group('when a filter hides the design in use', () {
      /// Aurora is creative; Corporate is a category it is not in.
      Future<void> filterAway(WidgetTester tester, {Size? size}) async {
        await pumpGallery(
          tester,
          size ?? const Size(390, 844),
          selectedId: defaultTemplate.id,
        );
        await tester.tap(
          find.byKey(categoryChipKey(TemplateCategory.corporate)),
        );
        await tester.pump();
      }

      testWidgets('it says so, by name and by category', (tester) async {
        await filterAway(tester);

        expect(find.byKey(templateCardKey(defaultTemplate.id)), findsNothing);
        expect(
          find.textContaining('${defaultTemplate.name} is your current design'),
          findsOneWidget,
          reason: 'a hidden selection with nothing said about it is a trap',
        );
        expect(find.textContaining('Creative'), findsWidgets);
      });

      testWidgets('and offers to bring it back without clearing the filter', (
        tester,
      ) async {
        await filterAway(tester);

        await tester.tap(find.text('Show it'));
        await tester.pump();

        expect(find.byKey(templateCardKey(defaultTemplate.id)), findsOneWidget);
        expect(
          find.text('Show it'),
          findsNothing,
          reason: 'the note has nothing left to say once the card is back',
        );
        expect(
          selections,
          isEmpty,
          reason: 'revealing a design must not choose it',
        );
      });

      testWidgets('it stays out of the way while the design is on screen', (
        tester,
      ) async {
        await pumpGallery(
          tester,
          const Size(390, 844),
          selectedId: defaultTemplate.id,
        );
        expect(find.text('Show it'), findsNothing);

        await tester.tap(
          find.byKey(categoryChipKey(TemplateCategory.creative)),
        );
        await tester.pump();
        expect(
          find.text('Show it'),
          findsNothing,
          reason: 'Aurora is creative, so this filter hides nothing',
        );
      });

      testWidgets('nothing selected means nothing to lose track of', (
        tester,
      ) async {
        await pumpGallery(tester, const Size(390, 844));
        await tester.tap(
          find.byKey(categoryChipKey(TemplateCategory.corporate)),
        );
        await tester.pump();

        expect(find.text('Show it'), findsNothing);
      });

      for (final entry in const {
        'phone small at 2x': (Size(360, 800), 2.0),
        'phone landscape': (Size(800, 360), 1.0),
        'tablet': (Size(768, 1024), 1.0),
      }.entries) {
        testWidgets('the note fits ${entry.key}', (tester) async {
          await pumpGallery(
            tester,
            entry.value.$1,
            textScale: entry.value.$2,
            selectedId: defaultTemplate.id,
          );
          await tester.tap(
            find.byKey(categoryChipKey(TemplateCategory.corporate)),
          );
          await tester.pump();

          expect(find.text('Show it'), findsOneWidget);
        });
      }
    });

    testWidgets('the selected chip is filled with the accent', (tester) async {
      await pumpGallery(tester, const Size(390, 844));

      final all = tester.widget<ChoiceChip>(find.byKey(categoryChipKey(null)));
      expect(all.selected, isTrue);
      expect(all.selectedColor, AppTheme.colorScheme.primary);
      expect(
        (all.labelStyle as TextStyle).color,
        AppTheme.colorScheme.onPrimary,
      );
    });
  });

  group('the selected design is unmistakable', () {
    testWidgets('a word, an icon, and a doubled accent ring', (tester) async {
      await pumpGallery(
        tester,
        const Size(390, 844),
        selectedId: defaultTemplate.id,
      );

      final card = find.byKey(templateCardKey(defaultTemplate.id));

      // 1. A word, not just a colour.
      expect(find.text('Selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // 2. An accent ring on the card — not on the page, where it would read
      //    as part of the template's own design — and twice the width of the
      //    resting hairline, so the cue is not carried by colour alone.
      final material = tester.widget<Material>(
        find.descendant(of: card, matching: find.byType(Material)).first,
      );
      final side = (material.shape as RoundedRectangleBorder).side;
      expect(side.color, AppTheme.colorScheme.primary);
      expect(side.width, 2);

      // 3. The fill stays the design's category tint. It used to step to a
      //    brighter neutral tier, which is where the luminance cue lived; the
      //    fill carries the category now, so the ring carries the cue — and
      //    carries it harder, see the measurement below.
      expect(
        material.color,
        categoryTint(defaultTemplate.category, const AppTokens()),
      );
    });

    /// The selection cue has to survive a colour-vision deficiency, which is
    /// why it was a luminance step and not a hue in the first place. Moving it
    /// from the fill to the ring keeps that property and strengthens it: the
    /// old step measured 1.08:1 between two neutral tiers, the ring measures
    /// 5.20:1 or better against every tint it can be drawn on.
    test('the ring is a luminance cue on every tint it can land on', () {
      const cs = AppTheme.colorScheme;
      const tokens = AppTokens();
      var worst = double.infinity;

      for (final category in TemplateCategory.values) {
        final tint = categoryTint(category, tokens);
        final ratio = contrastRatio(cs.primary, tint);
        worst = math.min(worst, ratio);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason:
              'the ring is ${ratio.toStringAsFixed(2)}:1 on a ${category.name} '
              'card; a selection nobody can see is not a selection',
        );
      }
      expect(
        worst,
        greaterThan(1.08),
        reason:
            'the cue this replaced measured 1.08:1; this one measures '
            '${worst.toStringAsFixed(2)}:1 at worst',
      );
    });

    /// The page placeholder sits inside a card that is now tinted, so "a tier
    /// above the card" is no longer what keeps it visible — the mat ring is.
    /// What it must still never be is mistakable for a rendered page, and two
    /// of the thirteen designs are deliberately dark ones.
    test('the placeholder is neither paper nor a dark template page', () {
      const cs = AppTheme.colorScheme;
      final placeholder = cs.surfaceContainerHighest;

      expect(
        contrastRatio(placeholder, const Color(0xFFFFFFFF)),
        greaterThanOrEqualTo(3.0),
        reason: 'a placeholder that reads as paper reads as a blank design',
      );
      for (final template in resumeTemplates) {
        final paper = Color(template.palette.paper.toInt());
        expect(
          contrastRatio(cs.outline, paper),
          greaterThanOrEqualTo(3.0),
          reason:
              'the mat ring is what delimits the page area on ${template.id}, '
              'now that the card behind it carries a tint',
        );
      }
    });

    testWidgets('an unselected card keeps the hairline and its category tint', (
      tester,
    ) async {
      await pumpGallery(
        tester,
        const Size(390, 844),
        selectedId: defaultTemplate.id,
      );

      final meridian = resumeTemplates.firstWhere((t) => t.id == 'meridian');
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(templateCardKey('meridian')),
              matching: find.byType(Material),
            )
            .first,
      );
      final side = (material.shape as RoundedRectangleBorder).side;
      expect(side.color, AppTheme.colorScheme.outlineVariant);
      expect(side.width, 1);
      expect(
        material.color,
        categoryTint(meridian.category, const AppTokens()),
      );
    });

    /// Same design, same colour, wherever it is shown. The two screens call one
    /// function; this is the assertion that the mapping is worth learning.
    testWidgets('cards in one category share a tint, and categories differ', (
      tester,
    ) async {
      await pumpGallery(tester, const Size(768, 1024));

      Color fillOf(String id) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(templateCardKey(id)),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;

      // Meridian and Beacon are both corporate; Aurora is creative.
      expect(fillOf('meridian'), fillOf('beacon'));
      expect(fillOf('aurora'), isNot(fillOf('meridian')));

      const tokens = AppTokens();
      final used = {
        for (final c in TemplateCategory.values) categoryTint(c, tokens),
      };
      expect(
        used,
        hasLength(TemplateCategory.values.length),
        reason: 'two categories sharing a tint makes the colour meaningless',
      );
      expect(
        used.length,
        lessThan(tokens.cardTints.length),
        reason:
            'thirteen cards in a two-column grid wearing all eight tints is '
            'confetti, not structure',
      );
    });

    testWidgets('no card on this screen is painted with a gradient', (
      tester,
    ) async {
      await pumpGallery(
        tester,
        const Size(390, 844),
        selectedId: defaultTemplate.id,
      );

      for (final widget in tester.allWidgets) {
        final decoration = switch (widget) {
          DecoratedBox(:final decoration) => decoration,
          Container(:final decoration?) => decoration,
          _ => null,
        };
        final gradient = switch (decoration) {
          BoxDecoration(:final gradient) => gradient,
          ShapeDecoration(:final gradient) => gradient,
          _ => null,
        };
        expect(gradient, isNull, reason: 'this palette is flat');
      }
    });

    testWidgets('nothing is marked when nothing is selected', (tester) async {
      await pumpGallery(tester, const Size(390, 844));
      expect(find.text('Selected'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('the page frame stays neutral whether or not it is chosen', (
      tester,
    ) async {
      await pumpGallery(
        tester,
        const Size(390, 844),
        selectedId: defaultTemplate.id,
      );

      final frame = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(templateCardKey(defaultTemplate.id)),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = frame.decoration as BoxDecoration;
      expect(
        decoration.border,
        Border.all(color: AppTheme.colorScheme.outline),
        reason:
            'the mid-tone mat ring is what steps a white page down to a dark '
            'panel; the decorative hairline is invisible against paper',
      );
      expect(
        decoration.boxShadow,
        isNull,
        reason:
            'a shadow under white paper on a dark panel does nothing — the '
            'page is already the brightest thing on the screen',
      );
    });

    testWidgets('the card is announced with everything it shows', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGallery(
        tester,
        const Size(390, 844),
        selectedId: defaultTemplate.id,
      );

      expect(
        tester.getSemantics(find.byKey(templateCardKey(defaultTemplate.id))),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          // Exactly this label: the caption below the thumbnail repeats the
          // name, the cue and the roles, and must not be announced twice.
          label:
              '${defaultTemplate.name}. '
              '${templateCues[defaultTemplate.id]}. '
              '${defaultTemplate.bestFor}',
        ),
      );
      handle.dispose();
    });

    testWidgets('tapping a card reports that design', (tester) async {
      await pumpGallery(tester, const Size(390, 844));

      await tester.tap(find.text(defaultTemplate.name));
      await tester.pump();

      expect(selections, [defaultTemplate.id]);
    });
  });

  group('badge contrast', () {
    const cs = AppTheme.colorScheme;

    test('its label clears AA on the accent fill', () {
      expect(
        contrastRatio(cs.onPrimary, cs.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    /// The badge floats on a rasterized document, and two designs in the
    /// catalog are deliberately dark pages. A pill that vanishes into the
    /// thumbnail it sits on is not a selection marker, so it is checked
    /// against every paper in the catalog rather than against white only.
    ///
    /// Either edge of the pill may do the separating, and which one does has
    /// swapped with the palette. The accent is now a light violet, so the fill
    /// is what holds up against Ember's charcoal and Terminal's near-black; on
    /// white paper the fill drops to 1.61:1 and the dark `onPrimary` ring
    /// carries it instead. Delete either one and this test fails on half the
    /// catalog.
    test('the pill holds 3:1 against every paper in the catalog', () {
      for (final template in resumeTemplates) {
        final paper = Color(template.palette.paper.toInt());
        final edge = math.max(
          contrastRatio(cs.primary, paper),
          contrastRatio(cs.onPrimary, paper),
        );
        expect(
          edge,
          greaterThanOrEqualTo(3.0),
          reason: '${template.id} would swallow the Selected badge',
        );
      }
    });
  });
}
