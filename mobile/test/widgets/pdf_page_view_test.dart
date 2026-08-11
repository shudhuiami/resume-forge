import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/render/pdf_raster.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/pdf_page_view.dart';
import 'package:resume_forge/widgets/resume_preview.dart';

/// Rasterization sizing and frame retention.
///
/// `Printing.raster` is platform-bound and cannot run here, so these tests
/// cover the two things that are pure widget behaviour: what width the raster
/// is asked for, and whether the finished page survives a tab switch.
void main() {
  int? widthFor(double w, double h, {double pixelRatio = 2}) =>
      PdfPageView.rasterWidthFor(
        BoxConstraints(maxWidth: w, maxHeight: h),
        pixelRatio,
      );

  group('raster target width', () {
    test('follows the width when the page is width-limited', () {
      // 390 logical at 2x is 780 device px, snapped up to the next multiple of
      // the quantum.
      expect(widthFor(390, 700), 832);
    });

    test('follows the height when the page is height-limited', () {
      // Landscape phone: the A4 page is ~212 logical px wide inside an 812px
      // box. Keying off the box width would rasterize ~4x too many pixels.
      final actual = widthFor(812, 300)!;
      final naive = widthFor(812, 4000)!;

      expect(actual, 448);
      // Bitmap cost is quadratic in the width key, so a 3.7x width mistake is
      // a ~14x memory mistake.
      expect(
        (naive / actual) * (naive / actual),
        greaterThan(10),
        reason: 'a landscape page must not be rasterized at box width',
      );
    });

    test('a taller box does not grow the raster past the page width', () {
      expect(widthFor(390, 4000), widthFor(390, 700));
    });

    test('quantizes so a drag-resize does not re-render every frame', () {
      // A 100px drag reports ~100 distinct widths. Snapping collapses them to
      // a handful of keys, and so to a handful of rasterizations.
      final widths = [for (var w = 320.0; w < 420; w += 1) w];
      final keys = {for (final w in widths) widthFor(w, 4000)};

      expect(widths.length, 100);
      expect(keys.length, lessThanOrEqualTo(5));
    });

    test('stops making new keys past the rasterizer ceiling', () {
      expect(widthFor(4000, 8000), PdfRaster.maxPixelWidth.round());
      expect(widthFor(6000, 12000), PdfRaster.maxPixelWidth.round());
    });

    test(
      'an unbounded box asks for nothing rather than an infinite bitmap',
      () {
        expect(widthFor(double.infinity, double.infinity), isNull);
        expect(widthFor(0, 0), isNull);
      },
    );

    test('respects the device pixel ratio', () {
      expect(
        widthFor(390, 4000, pixelRatio: 1),
        lessThan(widthFor(390, 4000)!),
      );
      expect(
        widthFor(390, 4000, pixelRatio: 3),
        greaterThan(widthFor(390, 4000)!),
      );
    });
  });

  group('frame retention across tabs', () {
    /// The preview lives in a TabBarView. Its PageView drops off-screen
    /// children unless they opt out, which used to throw away the rasterized
    /// page every time the user went back to the form.
    Future<void> pumpTabs(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: const TabBar(
                tabs: [
                  Tab(text: 'Edit'),
                  Tab(text: 'Preview'),
                ],
              ),
              body: TabBarView(
                children: [
                  const Center(child: Text('form')),
                  PdfPageView(
                    // A build error rather than bytes: it puts the widget in a
                    // settled state with no rasterization and no animation,
                    // which is what makes this test deterministic.
                    pdfBytes: null,
                    buildError: StateError('boom'),
                    onRetry: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('the preview state is not rebuilt when the tab changes', (
      tester,
    ) async {
      await pumpTabs(tester);
      await tapTab(tester, 'Preview');

      final finder = find.byType(PdfPageView, skipOffstage: false);
      final before = tester.state(finder);

      await tapTab(tester, 'Edit');
      await tapTab(tester, 'Preview');

      expect(
        identical(tester.state(finder), before),
        isTrue,
        reason: 'a fresh state would show a blank page and re-rasterize',
      );
    });

    testWidgets('a build error routes retry to the parent, not the raster', (
      tester,
    ) async {
      await pumpTabs(tester);
      await tapTab(tester, 'Preview');

      final preview = tester.widget<ResumePreview>(find.byType(ResumePreview));
      expect(preview.error, isA<StateError>());
      expect(preview.onRetry, isNotNull);
      expect(find.text('Preview failed to render'), findsOneWidget);
    });
  });
}
