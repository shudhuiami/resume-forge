import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/brand.dart';
import 'package:resume_forge/screens/about_screen.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/theme/tokens.dart';

void main() {
  const viewports = {
    'phone small': Size(360, 800),
    'phone normal': Size(390, 844),
    'phone large': Size(430, 932),
    'tablet': Size(768, 1024),
    'phone landscape': Size(800, 360),
  };

  /// The wordmark is rich text — one span of it is the accent letter — so it is
  /// addressed the way rich text has to be.
  final wordmark = find.text(appName, findRichText: true);
  final logo = find.byKey(developerLogoKey);

  /// Every decoration painted anywhere in the current tree, from both the
  /// widgets that declare one and the boxes a `Container` folds one into.
  Iterable<Decoration> decorationsIn(WidgetTester tester) sync* {
    for (final widget in tester.allWidgets) {
      if (widget is DecoratedBox) yield widget.decoration;
      if (widget is Container && widget.decoration != null) {
        yield widget.decoration!;
      }
      if (widget is Ink && widget.decoration != null) yield widget.decoration!;
    }
  }

  /// The `Text` the brand wordmark builds, spans and all.
  Text wordmarkText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(
      of: find.byType(BrandWordmark),
      matching: find.byType(Text),
    ),
  );

  Future<void> pumpAbout(
    WidgetTester tester,
    Size size, {
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
            child: const AboutScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('what the screen says', () {
    testWidgets('names the product and what it does', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      expect(wordmark, findsOneWidget);
      expect(find.text(AboutScreen.tagline), findsOneWidget);
    });

    /// The name is sliced into spans so one letter can carry the brand's
    /// accent. This is what stops the slicing from ever spelling the product
    /// wrong, and what keeps a screen reader hearing one word rather than
    /// three.
    testWidgets('the wordmark reads back as the product name', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      final text = wordmarkText(tester);
      expect(text.textSpan?.toPlainText(), appName);
      expect(text.semanticsLabel, appName);
    });

    /// The Resivo logo's only colour is the gold dot on its "i", and the app's
    /// amber is that gold. It comes from the scheme rather than from a literal.
    testWidgets('one letter carries the brand accent, from the theme', (
      tester,
    ) async {
      await pumpAbout(tester, const Size(390, 844));

      final spans = (wordmarkText(tester).textSpan! as TextSpan).children!
          .cast<TextSpan>();
      final accented = spans.where((s) => s.style?.color != null);

      expect(accented, hasLength(1), reason: 'one accent letter, not a word');
      expect(accented.single.text, 'i');
      expect(accented.single.style!.color, AppTheme.colorScheme.primary);
    });

    /// The one claim on this screen worth making, and the product's actual
    /// differentiator: there is no account, no server and no network call
    /// anywhere in the app. It is three separate guarantees rather than one
    /// sentence, because the sentence was skimmable.
    testWidgets('states the privacy property plainly', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      expect(find.text('Everything stays on this device'), findsOneWidget);
      for (final guarantee in _PrivacyCopy.guarantees) {
        expect(find.text(guarantee), findsOneWidget);
      }
      expect(find.text(_PrivacyCopy.storageLine), findsOneWidget);
    });

    testWidgets('credits the developer with their own mark', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      expect(find.text('Developed by'), findsOneWidget);
      expect(logo, findsOneWidget);
      expect(
        developerName,
        'codevioso',
        reason: 'lowercase, as given; not title-cased by a later edit',
      );
    });

    /// A logo is a graphic, and an unlabelled graphic where a name belongs is
    /// silence to a screen reader. Merged with its heading so the credit is one
    /// stop — "Developed by codevioso" — rather than two halves that mean
    /// nothing apart.
    testWidgets('the mark is announced, once, with its heading', (
      tester,
    ) async {
      // Disposed inside the body rather than in a teardown: the end-of-test
      // verification runs first and fails on a handle that is still open.
      final handle = tester.ensureSemantics();
      await pumpAbout(tester, const Size(390, 844));

      expect(tester.widget<Image>(logo).semanticLabel, developerName);

      // The merged node's own label is empty by construction — what a reader
      // is handed is the merged data.
      final merged = tester.getSemantics(logo).getSemanticsData();
      expect(merged.label, contains('Developed by'));
      expect(merged.label, contains(developerName));

      handle.dispose();
    });

    /// It is somebody else's mark. Not tinted, not blended, not stretched.
    testWidgets('the mark is drawn as supplied', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      final image = tester.widget<Image>(logo);
      expect(image.color, isNull, reason: 'a vendor mark is not recoloured');
      expect(image.colorBlendMode, isNull);
      expect(image.fit, BoxFit.contain);

      final size = tester.getSize(logo);
      expect(
        size.width / size.height,
        closeTo(800 / 152, 0.01),
        reason: 'the supplied proportion, whatever the viewport',
      );
    });

    /// The credit degrades to the name rather than to a hole in the card: an
    /// asset that will not decode must not take the developer's credit with it.
    testWidgets('a mark that cannot be drawn still credits them', (
      tester,
    ) async {
      await pumpAbout(tester, const Size(390, 844));

      final image = tester.widget<Image>(logo);
      expect(image.errorBuilder, isNotNull);

      final fallback = image.errorBuilder!(
        tester.element(logo),
        'missing',
        null,
      );
      expect(fallback, isA<Text>());
      expect((fallback as Text).data, developerName);
    });

    /// `assets/vendor/` is listed in the pubspec, which this test cannot edit
    /// and which the logo is useless without. If the entry is ever dropped, or
    /// the file renamed, this is what says so.
    testWidgets('the mark is actually bundled', (tester) async {
      final bytes = await rootBundle.load(developerLogoAsset);
      expect(
        bytes.lengthInBytes,
        greaterThan(0),
        reason: '$developerLogoAsset is not in the asset bundle',
      );
    });

    /// Nothing on this screen may be a control that goes nowhere. No URL,
    /// address or entity was supplied for the developer, so the credit is a
    /// mark rather than a link — a tappable-looking dead end would be worse
    /// than the plain image.
    testWidgets('has no dead links or stub controls', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      // The back button is the only interactive thing here.
      final buttons = find.byWidgetPredicate(
        (w) =>
            w is ButtonStyleButton ||
            (w is InkWell && w.onTap != null) ||
            (w is GestureDetector && w.onTap != null),
      );
      for (final element in buttons.evaluate()) {
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byWidget(element.widget),
          ),
          findsOneWidget,
          reason: '${element.widget} is a control outside the app bar',
        );
      }
    });

    testWidgets('states the version', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      expect(find.text('Version $appVersion'), findsOneWidget);
    });

    /// `package_info_plus` is not a dependency, so the version is a const — and
    /// a const can drift from the pubspec that ships it. This is the thing that
    /// stops it: `flutter test` runs from the package root, so the manifest is
    /// right there to read.
    test('the version const matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared = RegExp(
        r'^version:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(declared, isNotNull, reason: 'pubspec must declare a version');
      // `1.0.0+1` — the build number is not shown to the user.
      final name = declared!.group(1)!.split('+').first;
      expect(
        appVersion,
        name,
        reason:
            'about_screen.dart says $appVersion, pubspec.yaml says $name; '
            'change them together',
      );
    });
  });

  group('the screen fits', () {
    for (final entry in viewports.entries) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('${entry.key} at ${scale}x text', (tester) async {
          await pumpAbout(tester, entry.value, textScale: scale);

          // A RenderFlex overflow anywhere in here fails the pump above. What
          // is left to prove is that the content is reachable rather than
          // clipped off the bottom of a short viewport.
          expect(wordmark, findsOneWidget);
          await tester.scrollUntilVisible(logo, 120);
          expect(logo, findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Version $appVersion'),
            120,
          );
          expect(find.text('Version $appVersion'), findsOneWidget);
        });
      }
    }

    /// The case the wide mark is most likely to break: the narrowest phone at
    /// the largest text size, where the card has 296px of inner width to give.
    testWidgets('the mark stays inside its card on a small phone at 2x', (
      tester,
    ) async {
      await pumpAbout(tester, const Size(360, 800), textScale: 2);
      await tester.scrollUntilVisible(logo, 120);

      final card = tester.getRect(
        find.ancestor(of: logo, matching: find.byType(Card)),
      );
      final mark = tester.getRect(logo);

      expect(mark.left, greaterThanOrEqualTo(card.left));
      expect(mark.right, lessThanOrEqualTo(card.right));
      expect(
        mark.width / mark.height,
        closeTo(800 / 152, 0.01),
        reason: 'capping the width may not squash the mark',
      );
    });

    /// It is a name, so it grows with the type — up to the point where it would
    /// stop fitting.
    testWidgets('the mark grows with the text size, then stops', (
      tester,
    ) async {
      Future<double> widthAt(double scale) async {
        await pumpAbout(tester, const Size(390, 844), textScale: scale);
        // A larger text size pushes the credit below the fold, and a lazy list
        // has not built what is off screen.
        await tester.scrollUntilVisible(logo, 120);
        return tester.getSize(logo).width;
      }

      final atOne = await widthAt(1);
      final atOnePointThree = await widthAt(1.3);
      final atTwo = await widthAt(2);

      expect(atOnePointThree, greaterThan(atOne));
      expect(
        atTwo,
        closeTo(atOnePointThree * (1.6 / 1.3), 0.01),
        reason: 'capped at 1.6x, not left to run',
      );
    });

    testWidgets('the column stops widening on a tablet', (tester) async {
      await pumpAbout(tester, const Size(768, 1024));

      final card = tester.getSize(find.byType(Card).first);
      expect(
        card.width,
        lessThan(640),
        reason: 'a paragraph run across a full tablet is a reading problem',
      );
    });
  });

  group('the screen matches the app', () {
    /// The palette is matte: solid fills only, no ramp, no gloss, no glow.
    testWidgets('nothing is painted with a gradient', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      for (final decoration in decorationsIn(tester)) {
        final gradient = switch (decoration) {
          BoxDecoration(:final gradient) => gradient,
          ShapeDecoration(:final gradient) => gradient,
          _ => null,
        };
        expect(gradient, isNull, reason: 'this palette is flat');
      }
    });

    /// The cards are the app's own solid-tinted section cards, not a second
    /// card style invented for one screen.
    testWidgets('the cards take authored tints, never a mixed colour', (
      tester,
    ) async {
      await pumpAbout(tester, const Size(390, 844));

      const tints = AppTokens();
      final colours = tester
          .widgetList<Card>(find.byType(Card))
          .map((c) => c.color)
          .toList();

      expect(colours, hasLength(2));
      for (final colour in colours) {
        expect(
          tints.cardTints,
          contains(colour),
          reason: '$colour is not one of the eight authored card tints',
        );
      }
      expect(colours.toSet(), hasLength(2), reason: 'two cards, two tints');
    });

    testWidgets('it is reached and left through the back affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  /// The privacy card's copy, spelled out here rather than read off the private
  /// widget: this is the product's one claim, and a copy edit to it has to be a
  /// deliberate one.
  group('contrast of the new pairings', () {
    /// The accent tick on the slate card, measured rather than eyeballed. The
    /// rest of the screen's pairings are already covered against every tint by
    /// `test/theme/contrast_test.dart`.
    test('the guarantee tick reads on the card it is drawn on', () {
      const cs = AppTheme.colorScheme;
      const tokens = AppTokens();

      final fg = cs.primary.computeLuminance();
      final bg = tokens.tintSlate.computeLuminance();
      final ratio = (fg + 0.05) / (bg + 0.05);

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the tick measures ${ratio.toStringAsFixed(2)}:1 on slate; it '
            'carries meaning, so it is held to the text bar rather than 3:1',
      );
    });
  });
}

/// The privacy copy, duplicated deliberately so an edit to the screen's one
/// real claim has to be made twice — once in the product, once in the test that
/// says what the product promises.
abstract final class _PrivacyCopy {
  static const guarantees = [
    'No account to create',
    'No backend, nothing uploaded',
    'Works with nothing connected',
  ];

  static const storageLine = 'Your resumes are saved on this device only.';
}
