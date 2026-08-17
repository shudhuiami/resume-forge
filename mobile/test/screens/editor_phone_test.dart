import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/form_fields.dart';

/// The phone field, in the form it actually ships in.
///
/// `test/widgets/form_fields_test.dart` covers the control's own behaviour;
/// this is about what reaches the document — above all that opening a resume
/// saved before the country picker existed does not quietly rewrite the number
/// in it.
void main() {
  /// Tall enough to build the whole form, so these are assertions about
  /// content rather than about how far a list has been scrolled.
  const tall = Size(430, 4000);

  late InMemoryResumeRepository repo;

  Future<ResumeDocument> pumpEditor(
    WidgetTester tester, {
    required String phone,
    Size size = tall,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    final doc = newResumeDocument().copyWith(
      data: ResumeData(personalInfo: PersonalInfo(phone: phone)),
    );
    await repo.save(doc);

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
              child: EditorScreen(document: doc),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return doc;
  }

  /// Lets the autosave debounce and any toast expire, so nothing is left
  /// pending when the test ends.
  Future<void> quiesce(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));
  }

  Future<String> storedPhone() async =>
      (await repo.all()).single.data.personalInfo.phone;

  Finder numberField() => find.widgetWithText(TextField, 'Phone');

  group('the country code control', () {
    testWidgets('sits beside the phone field in About you', (tester) async {
      await pumpEditor(tester, phone: '');

      expect(find.byKey(PhoneField.codeButtonKey), findsOneWidget);
      expect(numberField(), findsOneWidget);
      await quiesce(tester);
    });

    /// The whole reason `splitPhoneNumber` returns a null country rather than
    /// a default: every resume saved before this field existed holds a number
    /// with no `+`, and putting a dial code in front of one would invent digits
    /// the user never typed.
    testWidgets('opening a resume saved without a code changes nothing', (
      tester,
    ) async {
      await pumpEditor(tester, phone: '(415) 555-0134');
      await quiesce(tester);

      expect(await storedPhone(), '(415) 555-0134');
      expect(find.text('(415) 555-0134'), findsOneWidget);
    });

    testWidgets('editing a number keeps its stored country code', (
      tester,
    ) async {
      await pumpEditor(tester, phone: '+880 1712-345678');

      await tester.enterText(numberField(), '1811 999888');
      await quiesce(tester);

      expect(await storedPhone(), '+880 1811 999888');
    });

    testWidgets('picking a country reaches the document', (tester) async {
      await pumpEditor(tester, phone: '01712 345678');

      await tester.tap(find.byKey(PhoneField.codeButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Search'), '880');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bangladesh'));
      await tester.pumpAndSettle();
      await quiesce(tester);

      expect(await storedPhone(), '+880 01712 345678');
    });

    /// The check is a plausibility check and says so; it is never a gate. A
    /// resume field that refuses somebody's real number is a worse defect than
    /// one that accepts an odd one.
    testWidgets('an implausible number is still saved', (tester) async {
      await pumpEditor(tester, phone: '');

      await tester.tap(numberField());
      await tester.pump();
      await tester.enterText(numberField(), '12');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await quiesce(tester);

      expect(find.textContaining('too short'), findsOneWidget);
      expect(await storedPhone(), '+1 12');
    });
  });

  /// The code control and the number cannot always share a line, and what runs
  /// out of room is a string at a text size rather than a screen — so the pair
  /// is measured, exactly as the start/end date pair is.
  ///
  /// **The threshold sits at a different width here than on a device.** The
  /// test font draws every glyph as a full em box, so a country's example
  /// number measures about twice what Inter renders it at and the pair gives up
  /// the shared row sooner. So these are assertions about the *property* —
  /// whichever arrangement is chosen, the number keeps the room and the two
  /// controls do not collide — with the two unambiguous ends pinned below.
  group('the code and the number', () {
    for (final size in const [
      Size(360, 4000),
      Size(390, 4000),
      Size(430, 4000),
      Size(768, 4000),
    ]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('lay out at ${size.width.toInt()}px, ${scale}x', (
          tester,
        ) async {
          await pumpEditor(
            tester,
            phone: '+880 1811-999888',
            size: size,
            textScale: scale,
          );

          final code = tester.getRect(find.byKey(PhoneField.codeButtonKey));
          final number = tester.getRect(numberField());

          if (code.top == number.top) {
            expect(
              number.width,
              greaterThan(code.width),
              reason: 'the number is the field being filled in, not the code',
            );
          } else {
            expect(
              number.top,
              greaterThanOrEqualTo(code.bottom),
              reason: 'the two controls must not overlap',
            );
            expect(
              number.width,
              closeTo(code.width, 1),
              reason: 'stacking is only worth it if the number gets the width',
            );
          }
          await quiesce(tester);
        });
      }
    }

    testWidgets('share a row where there is room for both', (tester) async {
      await pumpEditor(
        tester,
        phone: '+880 1811-999888',
        size: const Size(768, 4000),
      );

      expect(
        tester.getRect(find.byKey(PhoneField.codeButtonKey)).top,
        tester.getRect(numberField()).top,
        reason: 'a code and its number are one fact and read faster as a pair',
      );
      await quiesce(tester);
    });

    testWidgets('stack on a small phone at double text size', (tester) async {
      await pumpEditor(
        tester,
        phone: '+880 1811-999888',
        size: const Size(360, 4000),
        textScale: 2,
      );

      expect(
        tester.getRect(numberField()).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(PhoneField.codeButtonKey)).bottom,
        ),
        reason: 'half a row cannot hold a country and a number at this size',
      );
      await quiesce(tester);
    });
  });
}
