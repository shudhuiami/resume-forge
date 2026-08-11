import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/render/pdf_raster.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/resume_preview.dart';

/// State and layout verification for the preview page.
///
/// The preview is a flat image of the real PDF, so what is under test here is
/// everything drawn *around* that image: what the user sees before the first
/// render, while a newer one runs, and when one fails — with and without a
/// good frame to fall back on.
void main() {
  /// Smallest valid PNG. Enough for `Image.memory` to be a real image rather
  /// than an error, which is all these tests need.
  final onePixelPng = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
      'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );

  Future<void> pumpPreview(
    WidgetTester tester, {
    Uint8List? png,
    bool isRendering = false,
    Object? error,
    VoidCallback? onRetry,
    Size size = const Size(390, 844),
    double textScale = 1.0,
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
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ResumePreview(
                  pngBytes: png,
                  isRendering: isRendering,
                  error: error,
                  onRetry: onRetry,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the busy and placeholder states own an indeterminate
    // progress indicator, which never settles.
    await tester.pump();
  }

  group('preview states', () {
    testWidgets(
      'before any render it explains itself instead of sitting blank',
      (tester) async {
        await pumpPreview(tester);

        expect(find.text('Building your preview…'), findsOneWidget);
        expect(find.text('Preview failed to render'), findsNothing);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('a rendered page shows the page and no chrome', (tester) async {
      await pumpPreview(tester, png: onePixelPng);

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Building your preview…'), findsNothing);
      expect(find.text('Updating'), findsNothing);
      expect(find.text('Showing the last good preview'), findsNothing);
    });

    testWidgets('the page image carries a screen-reader label', (tester) async {
      await pumpPreview(tester, png: onePixelPng);

      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Resume preview, page 1',
        reason: 'the preview is a flat image; without a label it is silent',
      );
    });

    testWidgets('a failure with no previous frame offers a way out', (
      tester,
    ) async {
      var retries = 0;
      await pumpPreview(
        tester,
        error: StateError('boom'),
        onRetry: () => retries++,
      );

      expect(find.text('Preview failed to render'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1, reason: 'the error state must not be a dead end');
    });

    testWidgets('no retry handler means no retry button', (tester) async {
      await pumpPreview(tester, error: StateError('boom'));

      expect(find.text('Preview failed to render'), findsOneWidget);
      expect(
        find.text('Retry'),
        findsNothing,
        reason: 'a button that cannot do anything must not be drawn',
      );
    });

    testWidgets('a failure keeps the last good page visible', (tester) async {
      var retries = 0;
      await pumpPreview(
        tester,
        png: onePixelPng,
        error: StateError('boom'),
        onRetry: () => retries++,
      );

      expect(
        find.byType(Image),
        findsOneWidget,
        reason: 'losing your place on a failed re-render is worse than stale',
      );
      expect(find.text('Showing the last good preview'), findsOneWidget);
      expect(find.text('Preview failed to render'), findsNothing);

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('the busy marker is visible and does not hide the page', (
      tester,
    ) async {
      await pumpPreview(tester, png: onePixelPng, isRendering: true);

      expect(find.text('Updating'), findsOneWidget);
      expect(
        find.byType(Image),
        findsOneWidget,
        reason: 'clearing the page on every keystroke made the preview strobe',
      );
    });
  });

  group('a page too small for labels', () {
    // Landscape phone: the A4 page is about 250dp wide. A full-width warning
    // strip with an inline text button wrapped "Showing the last good
    // preview" into six one-word lines and buried the document under it.
    const landscape = Size(844, 390);

    testWidgets('the warning collapses to an icon instead of wrapping', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        png: onePixelPng,
        error: StateError('boom'),
        onRetry: () {},
        size: landscape,
      );

      expect(find.text('Showing the last good preview'), findsNothing);
      expect(
        find.byTooltip('Showing the last good preview'),
        findsOneWidget,
        reason: 'the meaning has to survive dropping the label',
      );
    });

    testWidgets('retry survives as a labelled icon control', (tester) async {
      var retries = 0;
      await pumpPreview(
        tester,
        png: onePixelPng,
        error: StateError('boom'),
        onRetry: () => retries++,
        size: landscape,
      );

      await tester.tap(find.byTooltip('Retry'));
      expect(retries, 1);
    });

    testWidgets('the busy pill drops its label but stays visible', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        png: onePixelPng,
        isRendering: true,
        size: landscape,
      );

      expect(find.text('Updating'), findsNothing);
      expect(find.byTooltip('Updating preview'), findsOneWidget);
    });

    testWidgets('a roomy page keeps the full labels', (tester) async {
      await pumpPreview(
        tester,
        png: onePixelPng,
        isRendering: true,
        error: StateError('boom'),
        onRetry: () {},
        size: const Size(390, 844),
      );

      expect(find.text('Showing the last good preview'), findsOneWidget);
      expect(find.text('Updating'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('page geometry', () {
    testWidgets('the frame is A4, matching the page the PDF is built at', (
      tester,
    ) async {
      await pumpPreview(tester, png: onePixelPng);

      final ratio = tester
          .widget<AspectRatio>(find.byType(AspectRatio).first)
          .aspectRatio;

      expect(ratio, closeTo(210 / 297, 0.0005));
      expect(ratio, PdfRaster.pageAspect);
    });

    testWidgets('the page is letterboxed, never stretched', (tester) async {
      await pumpPreview(tester, png: onePixelPng, size: const Size(768, 1024));

      final box = tester.getSize(find.byType(AspectRatio).first);
      expect(box.width / box.height, closeTo(210 / 297, 0.01));
    });
  });

  group('the preview survives every viewport it can be shown at', () {
    const viewports = {
      'phone small': Size(360, 800),
      'phone normal': Size(390, 844),
      'phone large': Size(430, 932),
      'tablet': Size(768, 1024),
      'phone landscape': Size(844, 390),
      'tablet landscape': Size(1024, 768),
    };

    for (final entry in viewports.entries) {
      // The stale state is the busiest: page, busy pill and warning banner all
      // on screen at once. A RenderFlex overflow fails the test that caused it.
      //
      // Asserted by tooltip rather than by text: below `compactPageWidth` both
      // overlays shed their labels, and the tooltip is what carries the
      // meaning in that form.
      testWidgets('${entry.key} — stale, busy and warning at once', (
        tester,
      ) async {
        await pumpPreview(
          tester,
          png: onePixelPng,
          isRendering: true,
          error: StateError('boom'),
          onRetry: () {},
          size: entry.value,
        );

        expect(find.byTooltip('Showing the last good preview'), findsOneWidget);
        expect(find.byTooltip('Updating preview'), findsOneWidget);
      });

      testWidgets('${entry.key} — error at double text size', (tester) async {
        await pumpPreview(
          tester,
          error: StateError('boom'),
          onRetry: () {},
          size: entry.value,
          textScale: 2.0,
        );

        expect(find.text('Preview failed to render'), findsOneWidget);
      });
    }
  });
}
