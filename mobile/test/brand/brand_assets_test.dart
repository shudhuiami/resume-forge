import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:resume_forge/theme/app_theme.dart';

/// The brand rasters cannot read `ColorScheme` at build time, so the palette is
/// copied into `assets/brand/generate_brand.py`, into the native splash config,
/// and into the Android window colour. These tests are what stop those copies
/// from rotting: change the theme without regenerating, and the first group
/// below fails naming the value that moved.
///
/// Everything after that group is asserted against the *baked* literals rather
/// than against `AppTheme`, so a palette change produces two precise failures
/// ("the icon is still the old colour") instead of twenty vague ones.

/// The two colours baked into the rasters. Copied by hand from the table at the
/// top of `assets/brand/generate_brand.py`; that file is the thing that
/// actually painted the pixels, this is the assertion that it painted the right
/// ones.
const _base = Color(0xFF0E0E10); // BASE — matte near-black
const _mark = Color(0xFFD8A657); // MARK — matte amber

/// A4, mirrored from the generator and from `lib/screens/splash_screen.dart`.
const _a4 = 1 / 1.4142135623730951;

/// Every generated image that carries the mark, with the page fraction
/// `assets/brand/generate_brand.py` drew it at.
const _sources = <({String path, int canvas, double page})>[
  (path: 'assets/brand/icon_foreground.png', canvas: 1024, page: 0.52),
  (path: 'assets/brand/icon_master.png', canvas: 1024, page: 0.60),
  (path: 'assets/brand/splash_logo.png', canvas: 640, page: 0.90),
  (path: 'assets/brand/splash_android12.png', canvas: 1152, page: 0.50),
];

/// The two native splash sources, which are the mark's *first frame*.
const _splashSources = <({String path, int canvas, double page})>[
  (path: 'assets/brand/splash_logo.png', canvas: 640, page: 0.90),
  (path: 'assets/brand/splash_android12.png', canvas: 1152, page: 0.50),
];

String _hex(Color color) {
  String part(double channel) =>
      (channel * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${part(color.r)}${part(color.g)}${part(color.b)}'.toUpperCase();
}

img.Image _load(String path) {
  final file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason: '$path is missing — run `python assets/brand/generate_brand.py`',
  );
  final decoded = img.decodePng(file.readAsBytesSync());
  expect(decoded, isNotNull, reason: '$path is not a readable PNG');
  return decoded!;
}

/// Pixel coordinates at ([fx], [fy]) of the mark's page box, for a page
/// [pageFraction] of a square [canvas] — the geometry every generated image
/// shares.
({int x, int y}) _onPage(
  int canvas,
  double pageFraction,
  double fx,
  double fy,
) {
  final h = canvas * pageFraction;
  final w = h * _a4;
  return (
    x: ((canvas - w) / 2 + w * fx).round(),
    y: ((canvas - h) / 2 + h * fy).round(),
  );
}

/// Points on the page that miss the fold and every piece of its content.
///
/// Six, spread into every band of the page the mark leaves clear: above the
/// portrait, right of it under the fold, between the shoulders and the lower
/// line, right of that line, between it and the arrow, and below the arrow's
/// tail. Every one was checked against the generated PNGs with a margin of 1.5%
/// of the page height in all directions, so an antialiased edge cannot be what
/// makes them pass — and they are spread widely enough that a gradient across
/// the page could not hold one value across all six.
const _pageGaps = <({double fx, double fy})>[
  (fx: 0.50, fy: 0.075),
  (fx: 0.75, fy: 0.300),
  (fx: 0.30, fy: 0.480),
  (fx: 0.94, fy: 0.480),
  (fx: 0.30, fy: 0.680),
  (fx: 0.30, fy: 0.965),
];

/// Dead centre of the portrait's head — the deepest point of the mark's
/// content, 39px clear of an edge on a 1024px layer.
const _portrait = (fx: 0.315, fy: 0.235);

/// Inside the arrow: one point on the shaft, one in the head.
const _arrowShaft = (fx: 0.50, fy: 0.808);
const _arrowHead = (fx: 0.86, fy: 0.72);

/// Inside the folded corner.
///
/// The crease runs 45 degrees from (0.66, 0) to (1.0, 0.24), so this sits well
/// beyond it. Unlike the content, the fold is part of the mark's *silhouette*,
/// so it is cut away on the native splash frames too.
const _foldCorner = (fx: 0.92, fy: 0.06);

/// Exact-match assertion. Not approximate on purpose: the mark is one flat
/// colour over a flat backdrop, so every interior pixel is that colour to the
/// bit. Only the antialiased edges are blends, and nothing here samples one.
void _expectPixel(
  img.Image image,
  ({int x, int y}) at,
  Color want, {
  required String reason,
}) {
  final pixel = image.getPixel(at.x, at.y);
  String part(num channel) => channel.toInt().toRadixString(16).padLeft(2, '0');
  final got = '#${part(pixel.r)}${part(pixel.g)}${part(pixel.b)}'.toUpperCase();
  expect(
    got,
    _hex(want),
    reason: '$reason (at ${at.x},${at.y}; alpha ${pixel.a})',
  );
}

void main() {
  group('the baked palette still matches Dart', () {
    // The two assertions the whole file exists for. If either fails, the app
    // has been re-toned and `assets/brand/generate_brand.py` has not been:
    // update its table, rerun it, then rerun `dart run flutter_launcher_icons`
    // and `dart run flutter_native_splash:create`.
    test('the base is AppTheme.colorScheme.surface', () {
      expect(
        _hex(AppTheme.colorScheme.surface),
        _hex(_base),
        reason:
            'the icon backdrop, the native splash and the Android window are '
            'all baked at ${_hex(_base)}; a different Dart surface is a '
            'visible flash at launch',
      );
    });

    test('the mark fill is AppTheme.colorScheme.primary', () {
      expect(
        _hex(AppTheme.colorScheme.primary),
        _hex(_mark),
        reason:
            'the launcher icon and both native splash images are baked at '
            '${_hex(_mark)}; the Flutter splash paints the mark in '
            'colorScheme.primary, so the icon the user taps and the mark that '
            'animates in must be the same colour',
      );
    });
  });

  group('splash colour handoff', () {
    test('flutter_native_splash paints the matte base, everywhere', () {
      final config = File('flutter_native_splash.yaml').readAsStringSync();
      final colours = RegExp(
        r'^\s*(?:color|color_dark):\s*"([^"]+)"',
        multiLine: true,
      ).allMatches(config).map((m) => m.group(1)!.toUpperCase()).toList();

      expect(
        colours,
        hasLength(4),
        reason: 'light, dark, and the same pair again in the android_12 block',
      );
      for (final colour in colours) {
        expect(
          colour,
          _hex(_base),
          reason:
              'the native splash and the Flutter splash must be the same '
              'colour or the user sees a flash between them',
        );
      }
    });

    test('the Android window background matches too', () {
      // NormalTheme's windowBackground is what shows between the launch window
      // closing and Flutter's first frame. Left at ?android:colorBackground it
      // resolves to near-white in light mode.
      final colours = File(
        'android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();
      expect(
        RegExp(
          r'name="window_background">([^<]+)<',
        ).firstMatch(colours)?.group(1)?.toUpperCase(),
        _hex(_base),
      );

      for (final path in const [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('@color/window_background'),
          reason:
              '$path still falls back to the platform background colour — '
              'the splash generators rewrite LaunchTheme in these files and '
              'this line has to survive that',
        );
      }
    });
  });

  group('generated icon layers', () {
    test('the adaptive background is the matte base, flat to the edges', () {
      final background = _load('assets/brand/icon_background.png');
      expect(background.width, 1024);
      expect(background.height, 1024);

      // Corners, edge midpoints and the centre. Sampled this widely because
      // "flat" is the requirement: the backdrop used to lift toward a panel
      // tint in the middle and bloom the accent under the page, and a single
      // corner sample would not notice either coming back.
      for (final at in const [
        (x: 0, y: 0),
        (x: 1023, y: 0),
        (x: 0, y: 1023),
        (x: 1023, y: 1023),
        (x: 512, y: 4),
        (x: 4, y: 512),
        (x: 512, y: 512),
        (x: 300, y: 700),
      ]) {
        _expectPixel(
          background,
          at,
          _base,
          reason: 'the backdrop must be one flat matte colour, no gradient',
        );
      }
      expect(background.getPixel(0, 0).a, 255, reason: 'and opaque');
    });

    test('the master icon carries no alpha channel', () {
      // An iOS app icon with an alpha channel is rejected at submission.
      final master = _load('assets/brand/icon_master.png');
      expect(master.numChannels, 3);
      expect(master.width, 1024);
    });

    test('the mark is one solid colour, on every layer that is coloured', () {
      for (final source in _sources) {
        final image = _load(source.path);
        for (final gap in _pageGaps) {
          _expectPixel(
            image,
            _onPage(source.canvas, source.page, gap.fx, gap.fy),
            _mark,
            reason:
                '${source.path}: every point of the page is the same matte '
                'amber. Six points spread across it cannot all match if the '
                'fill has gone back to a ramp',
          );
        }
      }
    });

    test('the corner is folded away on every layer', () {
      // The fold is silhouette rather than content, so unlike the portrait and
      // the lines it is cut out of the native splash frames as well — the
      // Flutter splash opens on an already-folded page.
      for (final source in _sources) {
        final at = _onPage(
          source.canvas,
          source.page,
          _foldCorner.fx,
          _foldCorner.fy,
        );
        final pixel = _load(source.path).getPixel(at.x, at.y);
        if (source.path.endsWith('icon_master.png')) {
          _expectPixel(
            _load(source.path),
            at,
            _base,
            reason:
                'the flattened master must show the backdrop through the fold',
          );
        } else {
          expect(
            pixel.a,
            lessThan(16),
            reason:
                '${source.path} still has a square top-right corner — the '
                'reference logo\'s folded corner is the mark\'s most '
                'recognisable feature and the only one that survives at 36px',
          );
        }
      }
    });

    test(
      'the portrait and the arrow are punched through to the layer behind',
      () {
        // On the adaptive foreground the contents are holes, so the adaptive
        // background — and, under a themed icon, the system's own plate — shows
        // through.
        final foreground = _load('assets/brand/icon_foreground.png');
        final master = _load('assets/brand/icon_master.png');

        for (final spot in const [_portrait, _arrowShaft, _arrowHead]) {
          final at = _onPage(1024, 0.52, spot.fx, spot.fy);
          expect(
            foreground.getPixel(at.x, at.y).a,
            lessThan(16),
            reason:
                'the foreground contents must be transparent, not painted '
                '(${spot.fx},${spot.fy})',
          );

          // On the flattened master they resolve to the backdrop, which is what
          // makes the legacy icon legible: page and content are the same 8.7:1
          // apart as page and backdrop.
          _expectPixel(
            master,
            _onPage(1024, 0.60, spot.fx, spot.fy),
            _base,
            reason:
                'the master\'s contents must read as the backdrop showing '
                'through (${spot.fx},${spot.fy})',
          );
        }
      },
    );

    test(
      'the monochrome layer is a flat silhouette with its bars punched out',
      () {
        final mono = _load('assets/brand/icon_monochrome.png');

        // Flat white whatever the accent does: Android 13 reads only this
        // layer's alpha and recolours it to the user's wallpaper palette, so it
        // deliberately does *not* follow the palette.
        for (final gap in _pageGaps) {
          final at = _onPage(1024, 0.52, gap.fx, gap.fy);
          final ink = mono.getPixel(at.x, at.y);
          expect(ink.a, greaterThan(200), reason: 'the page is opaque');
          expect(
            ink.r,
            ink.g,
            reason: 'and flat white, for the system to tint',
          );
          expect(ink.g, ink.b);
          expect(ink.r, greaterThan(250));
        }

        for (final spot in const [
          _portrait,
          _arrowShaft,
          _arrowHead,
          _foldCorner,
        ]) {
          final at = _onPage(1024, 0.52, spot.fx, spot.fy);
          expect(
            mono.getPixel(at.x, at.y).a,
            lessThan(16),
            reason:
                'the contents and the fold are holes, so the theme shows '
                'through them (${spot.fx},${spot.fy})',
          );
        }
      },
    );

    test('the adaptive foreground keeps the mark inside the safe circle', () {
      final foreground = _load('assets/brand/icon_foreground.png');
      const size = 1024;
      // Android guarantees only the inner 66% circle survives masking.
      const safeRadius = size * 0.66 / 2;
      final centre = (size - 1) / 2;

      var painted = 0;
      var outside = 0;
      for (var y = 0; y < size; y += 2) {
        for (var x = 0; x < size; x += 2) {
          if (foreground.getPixel(x, y).a < 16) continue;
          painted++;
          final dx = x - centre;
          final dy = y - centre;
          if (dx * dx + dy * dy > safeRadius * safeRadius) outside++;
        }
      }

      expect(painted, greaterThan(0), reason: 'the layer must not be blank');
      expect(
        outside,
        0,
        reason:
            '$outside sampled pixels of the mark sit outside the 66% safe '
            'circle and would be clipped by a launcher mask',
      );
    });
  });

  group('native splash source images', () {
    test('they are the empty folded page — the splash\'s frame 0', () {
      // The animated splash opens on the empty page and places the portrait,
      // writes the lines in and draws the arrow out. A finished mark here would
      // mean the mark appears, loses its contents for a beat, then animates
      // them back in at the native-to-Flutter handoff.
      for (final source in _splashSources) {
        final image = _load(source.path);
        expect(image.width, source.canvas);

        for (final spot in const [_portrait, _arrowShaft, _arrowHead]) {
          _expectPixel(
            image,
            _onPage(source.canvas, source.page, spot.fx, spot.fy),
            _mark,
            reason:
                '${source.path} already has its contents punched out at '
                '(${spot.fx},${spot.fy}) — the mark would appear complete, '
                'then lose them at the handoff',
          );
        }
      }
    });

    test('the page lands at the same height the splash opens at', () {
      // lib/screens/splash_screen.dart draws a 164dp page on a 390dp phone and
      // opens it at 0.88 scale = 144dp. Both sources are treated as 4x assets
      // by their platforms, so both must carry a 144dp page.
      for (final source in _splashSources) {
        expect(
          source.canvas * source.page / 4,
          closeTo(144, 1),
          reason: '${source.path} would jump in size at the handoff',
        );
      }
    });
  });

  group('platform icon output', () {
    test('every Android density has all three adaptive layers', () {
      for (final density in const [
        'mdpi',
        'hdpi',
        'xhdpi',
        'xxhdpi',
        'xxxhdpi',
      ]) {
        for (final layer in const [
          'ic_launcher_background',
          'ic_launcher_foreground',
          'ic_launcher_monochrome',
        ]) {
          final path = 'android/app/src/main/res/drawable-$density/$layer.png';
          expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        }
        expect(
          File(
            'android/app/src/main/res/mipmap-$density/ic_launcher.png',
          ).existsSync(),
          isTrue,
        );
      }
    });

    test('the generated Android icon carries the current mark', () {
      // The end of the pipeline, not the start: this is the file the launcher
      // actually reads, so it catches a regenerate that was never run.
      final launcher = _load(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      );
      _expectPixel(
        launcher,
        (x: 2, y: 2),
        _base,
        reason: 'the shipped mipmap still has the old backdrop',
      );
      _expectPixel(
        launcher,
        _onPage(launcher.width, 0.60, 0.30, 0.680),
        _mark,
        reason: 'the shipped mipmap still has the old mark fill',
      );
      // Two shapes that only exist in the current mark, so a stale mipmap left
      // over from the previous drawing fails here rather than passing on the
      // colour alone.
      _expectPixel(
        launcher,
        _onPage(launcher.width, 0.60, _foldCorner.fx, _foldCorner.fy),
        _base,
        reason: 'the shipped mipmap has not been regenerated with the fold',
      );
      _expectPixel(
        launcher,
        _onPage(launcher.width, 0.60, _portrait.fx, _portrait.fy),
        _base,
        reason: 'the shipped mipmap has not been regenerated with the portrait',
      );
    });

    test('the adaptive icon xml wires the monochrome layer with no inset', () {
      final xml = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();

      expect(xml, contains('@drawable/ic_launcher_background'));
      expect(xml, contains('@drawable/ic_launcher_foreground'));
      expect(
        xml,
        contains('@drawable/ic_launcher_monochrome'),
        reason: 'Android 13 themed icons need a monochrome layer',
      );
      expect(
        xml,
        isNot(contains('android:inset="16%"')),
        reason:
            'the art already respects the safe zone; a second inset shrinks '
            'the mark to a third of the layer',
      );
    });

    test('the native splash images landed on both platforms', () {
      for (final path in const [
        'android/app/src/main/res/drawable-xxxhdpi/splash.png',
        'android/app/src/main/res/drawable-xxxhdpi/android12splash.png',
        'android/app/src/main/res/drawable-night-xxxhdpi/splash.png',
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });
  });
}
