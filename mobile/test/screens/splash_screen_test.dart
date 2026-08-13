import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/screens/splash_screen.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// Points on the mark's page that miss the fold and every piece of its
/// content, and the points that land inside them.
///
/// Copied from `test/brand/brand_assets_test.dart`, which asks the same
/// questions of the baked PNGs. Duplicated rather than shared because the two
/// files are asserting that two independent drawings — one in Python, one in
/// Dart — agree, and a shared constant would let them agree by construction.
const _pageGaps = <({double fx, double fy})>[
  (fx: 0.50, fy: 0.075),
  (fx: 0.75, fy: 0.300),
  (fx: 0.30, fy: 0.480),
  (fx: 0.94, fy: 0.480),
  (fx: 0.30, fy: 0.680),
  (fx: 0.30, fy: 0.965),
];
const _portrait = (fx: 0.315, fy: 0.235);
const _arrowShaft = (fx: 0.50, fy: 0.808);
const _arrowHead = (fx: 0.86, fy: 0.72);
const _foldCorner = (fx: 0.92, fy: 0.06);

/// The viewports every screen in this app is reviewed at, plus a landscape
/// phone, which is the one that runs out of height first.
const _viewports = <String, Size>{
  'phone small': Size(360, 800),
  'phone normal': Size(390, 844),
  'phone large': Size(430, 932),
  'tablet': Size(768, 1024),
  'landscape phone': Size(800, 360),
};

Widget _harness(
  Widget child, {
  bool reducedMotion = false,
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: MaterialApp(theme: AppTheme.build(), home: child),
  );
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

double _markProgress(WidgetTester tester) =>
    tester.widget<ResivoMark>(find.byType(ResivoMark)).progress;

/// The mark, rasterised, so what it *paints* can be asserted rather than what
/// it was handed.
///
/// The mark is a `CustomPainter` with a private painter, so its colours are not
/// reachable through the widget tree at all. They are, however, the contract
/// with `assets/brand/generate_brand.py` — the launcher icon is baked from the
/// same two values — so they are worth rendering to check. The RepaintBoundary
/// this reads back is already in the tree for performance; this borrows it.
class _MarkPixels {
  const _MarkPixels(this._bytes, this._width, this.size);

  final ByteData _bytes;
  final int _width;

  /// Logical size of the mark's box.
  final Size size;

  Color at(Offset offset) {
    final index = (offset.dy.round() * _width + offset.dx.round()) * 4;
    return Color.fromARGB(
      _bytes.getUint8(index + 3),
      _bytes.getUint8(index),
      _bytes.getUint8(index + 1),
      _bytes.getUint8(index + 2),
    );
  }

  /// Pixel offset of a point given as fractions of the *page* — the same
  /// fractions `generate_brand.py` uses for the bars, so a coordinate can be
  /// copied between the two.
  ///
  /// [scale] is the page's entrance scale, which is 0.88 on frame zero.
  Offset onPage(double fx, double fy, {double scale = 1.0}) {
    // _boxHeightRatio and _pageAspect, mirrored — they are private to the
    // screen, and duplicating two numbers is better than widening its API for
    // a test.
    final pageHeight = size.height / 1.30;
    final pageWidth = pageHeight / 1.4142135623730951;
    return size.center(Offset.zero) +
        Offset(pageWidth * (fx - 0.5), pageHeight * (fy - 0.5)) * scale;
  }
}

Future<_MarkPixels> _rasterise(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(
      of: find.byType(ResivoMark),
      matching: find.byType(RepaintBoundary),
    ),
  );
  late final int width;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data;
  });
  return _MarkPixels(bytes!, width, boundary.size);
}

void main() {
  group('SplashScreen', () {
    testWidgets('renders the mark and the wordmark', (tester) async {
      await tester.pumpWidget(_harness(const SplashScreen()));
      await tester.pump();

      expect(find.byType(ResivoMark), findsOneWidget);
      expect(find.byKey(resivoMarkKey), findsOneWidget);
      expect(find.text('Resivo'), findsOneWidget);
      expect(find.text('Everything stays on this device'), findsOneWidget);
    });

    testWidgets('paints the colour the native splash hands off on', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const SplashScreen()));
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        AppTheme.colorScheme.surface,
        reason:
            'flutter_native_splash.yaml and values/colors.xml both paint the '
            'matte base; a different Flutter background is a visible flash. '
            'test/brand/brand_assets_test.dart checks the other three copies',
      );
    });

    testWidgets('paints the mark in flat colour, not a ramp', (tester) async {
      await tester.pumpWidget(_harness(const SplashScreen()));
      await tester.pumpAndSettle();

      final pixels = await _rasterise(tester);
      const scheme = AppTheme.colorScheme;

      // Points spread over the page, all clear of the fold and of every piece
      // of content. A gradient could not hold one value across all of them —
      // which is the property `assets/brand/generate_brand.py` bakes into the
      // icon, and this is the Dart end of that agreement. Same coordinates as
      // `_pageGaps` in test/brand/brand_assets_test.dart, so the two ends are
      // being asked the same question.
      for (final gap in _pageGaps) {
        expect(
          pixels.at(pixels.onPage(gap.fx, gap.fy)),
          scheme.primary,
          reason: 'the page is one solid accent; ${gap.fx},${gap.fy} is not it',
        );
      }

      // The portrait and the arrow read as holes punched back to the background
      // behind the page.
      for (final spot in const [_portrait, _arrowShaft, _arrowHead]) {
        expect(
          pixels.at(pixels.onPage(spot.fx, spot.fy)),
          scheme.surface,
          reason:
              'the mark\'s contents are the surface colour showing through; '
              '${spot.fx},${spot.fy} is not',
        );
      }

      // The folded corner is cut out of the page's silhouette, so by the
      // resting frame the mat behind it shows through.
      expect(
        pixels.at(pixels.onPage(_foldCorner.fx, _foldCorner.fy)),
        scheme.surfaceContainerHigh,
        reason:
            'the top-right corner must be folded away, showing the mat behind '
            'it — a square corner here means the Flutter mark and the launcher '
            'icon have drifted apart',
      );

      // The mat: opaque, flat, and outside the page's own width.
      expect(
        pixels.at(pixels.onPage(1.07, 0.50)),
        scheme.surfaceContainerHigh,
        reason: 'the mat under the page is a solid raised surface',
      );
    });

    testWidgets('frame zero is the bare page the native splash hands over', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const SplashScreen()));
      await tester.pump();
      expect(_markProgress(tester), 0.0);

      final pixels = await _rasterise(tester);
      const scheme = AppTheme.colorScheme;
      // The page opens at 0.88 scale, so frame zero's geometry is scaled too.
      const scale = 0.88;

      for (final spot in const [_portrait, _arrowShaft, _arrowHead]) {
        expect(
          pixels.at(pixels.onPage(spot.fx, spot.fy, scale: scale)),
          scheme.primary,
          reason:
              'nothing written on the page yet: assets/brand/splash_logo.png '
              'is the empty folded page, and anything already drawn at '
              '${spot.fx},${spot.fy} would flicker at the handoff',
        );
      }

      // The fold, though, *is* in the native image — it is silhouette rather
      // than content — so it has to be here on frame zero too.
      expect(
        pixels
            .at(pixels.onPage(_foldCorner.fx, _foldCorner.fy, scale: scale))
            .a,
        0,
        reason:
            'the corner must already be folded on frame zero: '
            'assets/brand/splash_logo.png is folded, so a square corner here '
            'is a shape change at the handoff',
      );
      expect(
        pixels.at(pixels.onPage(1.07, 0.50, scale: scale)).a,
        0,
        reason:
            'no mat yet either — it grows in after the handoff, which is the '
            'only reason it is allowed to exist at all',
      );
    });

    testWidgets('animates from nothing to the resting mark', (tester) async {
      await tester.pumpWidget(_harness(const SplashScreen()));
      await tester.pump();

      expect(_markProgress(tester), 0.0, reason: 'nothing drawn on frame one');

      await tester.pump(splashEntrance ~/ 2);
      final midway = _markProgress(tester);
      expect(midway, greaterThan(0.0));
      expect(midway, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(_markProgress(tester), 1.0);
    });

    testWidgets('reports its entrance exactly once, when it finishes', (
      tester,
    ) async {
      var completions = 0;
      await tester.pumpWidget(
        _harness(SplashScreen(onEntranceComplete: () => completions++)),
      );
      await tester.pump();
      expect(completions, 0);

      await tester.pump(splashEntrance ~/ 2);
      expect(completions, 0, reason: 'it must not leave mid-beat');

      await tester.pumpAndSettle();
      expect(completions, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
    });

    testWidgets('respects reduced motion: static frame, no ticking', (
      tester,
    ) async {
      var completions = 0;
      await tester.pumpWidget(
        _harness(
          SplashScreen(onEntranceComplete: () => completions++),
          reducedMotion: true,
        ),
      );
      await tester.pump();

      expect(
        _markProgress(tester),
        1.0,
        reason: 'the very first frame is the resting mark, not frame zero',
      );
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        0,
        reason: 'no controller may be ticking when animations are disabled',
      );
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'a static frame schedules no more frames',
      );
      expect(
        completions,
        1,
        reason: 'it hands off after one frame rather than after 460ms',
      );
    });

    testWidgets('disposes its controller when it leaves the tree', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const SplashScreen()));
      // Mid-animation, which is the case that leaks: a completed controller is
      // not ticking, a running one is.
      await tester.pump(splashEntrance ~/ 3);
      expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(_harness(const SizedBox.shrink()));
      await tester.pump();

      expect(find.byType(ResivoMark), findsNothing);
      expect(
        SchedulerBinding.instance.transientCallbackCount,
        0,
        reason: 'the ticker must stop when the splash is gone',
      );
      // flutter_test asserts at teardown that no ticker outlived its state, so
      // a missing dispose() fails this test even without the check above.
    });

    for (final entry in _viewports.entries) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('${entry.key} at ${scale}x text does not overflow', (
          tester,
        ) async {
          await _resize(tester, entry.value);
          await tester.pumpWidget(
            _harness(const SplashScreen(), textScale: scale),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Resivo'), findsOneWidget);

          final mark = tester.getSize(find.byKey(resivoMarkKey));
          expect(mark.height, greaterThan(0));
          expect(
            mark.width,
            lessThanOrEqualTo(entry.value.width),
            reason: 'the mark must never be wider than the screen',
          );
        });
      }
    }

    testWidgets('the mark keeps A4 proportions as it is resized', (
      tester,
    ) async {
      for (final size in const [Size(360, 800), Size(768, 1024)]) {
        await _resize(tester, size);
        await tester.pumpWidget(_harness(const SplashScreen()));
        await tester.pumpAndSettle();

        final box = tester.getSize(find.byKey(resivoMarkKey));
        final expected = ResivoMark.boxSizeFor(box.height / 1.30);
        expect(box.width, closeTo(expected.width, 0.5));
      }
    });
  });

  group('StartupFailureScreen', () {
    testWidgets('says what happened and offers a way out', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _harness(
          StartupFailureScreen(
            error: StateError('box is locked'),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not open your saved resumes'), findsOneWidget);
      expect(find.textContaining('box is locked'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('renders a timeout in words rather than in exception text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          StartupFailureScreen(
            error: TimeoutException('Future not completed'),
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Storage did not respond.'), findsOneWidget);
      expect(find.textContaining('TimeoutException'), findsNothing);
    });

    for (final entry in _viewports.entries) {
      testWidgets('${entry.key} at 2x text does not overflow', (tester) async {
        await _resize(tester, entry.value);
        await tester.pumpWidget(
          _harness(
            StartupFailureScreen(
              error: StateError(
                'a rather long failure message that keeps '
                'going well past any reasonable width, as real exception '
                'text tends to',
              ),
              onRetry: () {},
            ),
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Try again'), findsOneWidget);
      });
    }
  });
}
