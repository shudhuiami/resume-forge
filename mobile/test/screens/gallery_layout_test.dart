import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// Layout verification for the template picker.
///
/// A RenderFlex overflow is a framework error, which fails the test that
/// provoked it — so every pump here is an assertion that the grid survives the
/// viewport and text size it was pumped at.
void main() {
  const viewports = {
    'phone small': Size(360, 800),
    'phone normal': Size(390, 844),
    'phone large': Size(430, 932),
    'tablet': Size(768, 1024),
    'phone landscape': Size(800, 360),
    'very narrow': Size(320, 640),
  };

  /// A4 in logical pixels, the shape every thumbnail rasterizes at.
  const pageAspect = 794 / 1123;

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
            child: GalleryScreen(selectedId: selectedId, onSelected: (_) {}),
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
    final grid = tester.widget<GridView>(find.byType(GridView));
    return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  }

  group('the grid lays out without overflow', () {
    for (final entry in viewports.entries) {
      testWidgets('${entry.key} at ${entry.value}', (tester) async {
        await pumpGallery(tester, entry.value);
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text(defaultTemplate.name), findsOneWidget);
      });
    }

    testWidgets('at double text size on the smallest phone', (tester) async {
      await pumpGallery(tester, const Size(360, 800), textScale: 2);
      expect(find.byType(GridView), findsOneWidget);
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

    testWidgets('the cell reserves room for the caption', (tester) async {
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

  testWidgets('the selected design is marked and announced', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpGallery(
      tester,
      const Size(390, 844),
      selectedId: defaultTemplate.id,
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(InkWell).first),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        // Exactly this label: the caption below the thumbnail repeats the name
        // and the description, and must not be announced a second time.
        label: '${defaultTemplate.name}. ${defaultTemplate.bestFor}',
      ),
    );
    handle.dispose();
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
}
