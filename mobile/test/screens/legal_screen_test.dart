import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/brand.dart';
import 'package:resume_forge/legal.dart';
import 'package:resume_forge/screens/legal_screen.dart';
import 'package:resume_forge/theme/app_theme.dart';

Future<void> pumpDocument(
  WidgetTester tester,
  LegalDocument document, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: LegalScreen(document: document),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('both documents', () {
    for (final document in [privacyPolicy, termsOfUse]) {
      testWidgets('${document.title} shows its title, date and summary', (
        tester,
      ) async {
        await pumpDocument(tester, document);
        expect(find.text(document.title), findsOneWidget);
        expect(
          find.textContaining(legalEffectiveDate),
          findsOneWidget,
          reason: 'a policy with no effective date is unciteable',
        );
        expect(find.text(document.summary), findsOneWidget);
      });

      testWidgets('${document.title} renders every heading', (tester) async {
        await pumpDocument(tester, document, size: const Size(390, 4000));
        for (final section in document.sections) {
          expect(
            find.text(section.heading),
            findsOneWidget,
            reason: 'missing heading: ${section.heading}',
          );
        }
      });

      testWidgets('${document.title} survives 2x text on a small phone', (
        tester,
      ) async {
        await pumpDocument(
          tester,
          document,
          size: const Size(360, 800),
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('${document.title} can be read to the end', (tester) async {
        await pumpDocument(tester, document);
        final last = document.sections.last;
        await tester.scrollUntilVisible(
          find.text(last.heading),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(last.heading), findsOneWidget);
      });
    }
  });

  group('what the documents claim', () {
    test('the privacy policy names the product, not a placeholder', () {
      expect(privacyPolicy.summary, contains(appName));
      expect(termsOfUse.summary, contains(appName));
    });

    test('the contact address is carried by both documents', () {
      for (final document in [privacyPolicy, termsOfUse]) {
        final body = document.sections
            .expand((section) => section.paragraphs)
            .join(' ');
        expect(
          body,
          contains(legalContactEmail),
          reason: '${document.title} must say how to reach a human',
        );
      }
    });

    test('the terms credit the developer by the one agreed spelling', () {
      final body = termsOfUse.sections
          .expand((section) => section.paragraphs)
          .join(' ');
      expect(body, contains(developerName));
    });

    /// The claim that the app is offline is the product's whole pitch, so the
    /// policy has to state the qualification too: a device backup can put a
    /// copy in the user's own cloud account. Saying "nothing ever leaves the
    /// device" without that would be inaccurate.
    test('the privacy policy discloses device backups', () {
      final headings = privacyPolicy.sections.map((s) => s.heading);
      expect(headings, contains('Device backups'));
    });

    /// UI-016 is a real, shipped limitation. A user who loses a job from a
    /// silently dropped role should have been told here.
    test('the terms disclose that content can be dropped from a PDF', () {
      final body = termsOfUse.sections
          .expand((section) => section.paragraphs)
          .join(' ');
      expect(body, contains('will not appear in the exported'));
    });

    test('no document is empty or unheaded', () {
      for (final document in [privacyPolicy, termsOfUse]) {
        expect(document.sections, isNotEmpty);
        for (final section in document.sections) {
          expect(section.heading, isNotEmpty);
          expect(section.paragraphs, isNotEmpty);
          for (final paragraph in section.paragraphs) {
            expect(paragraph.trim(), isNotEmpty);
          }
        }
      }
    });
  });
}
