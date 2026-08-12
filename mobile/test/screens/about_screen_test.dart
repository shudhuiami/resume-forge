import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

      expect(find.text(AboutScreen.title), findsOneWidget);
      expect(find.text(AboutScreen.tagline), findsOneWidget);
    });

    /// The one claim on this screen worth making, and the product's actual
    /// differentiator: there is no account, no server and no network call
    /// anywhere in the app.
    testWidgets('states the privacy property plainly', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      expect(find.text('Everything stays on this device'), findsOneWidget);
      expect(
        find.textContaining('No accounts, no backend, no network.'),
        findsOneWidget,
      );
    });

    testWidgets('credits the developer, spelled exactly once', (tester) async {
      await pumpAbout(tester, const Size(390, 844));

      expect(find.text('Developed by'), findsOneWidget);
      expect(find.text(developerName), findsOneWidget);
      expect(
        developerName,
        'codevioso',
        reason: 'lowercase, as given; not title-cased by a later edit',
      );
    });

    /// Nothing on this screen may be a control that goes nowhere. No URL,
    /// address or entity was supplied for the developer, so the credit is a
    /// statement rather than a link — a tappable-looking dead end would be
    /// worse than the plain text.
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
          expect(find.text(AboutScreen.title), findsOneWidget);
          await tester.scrollUntilVisible(find.text(developerName), 120);
          expect(find.text(developerName), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Version $appVersion'),
            120,
          );
          expect(find.text('Version $appVersion'), findsOneWidget);
        });
      }
    }

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
}
