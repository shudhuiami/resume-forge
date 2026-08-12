import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// The keyboard must survive everything the editor does while you type.
///
/// Reported as "after typing a few words the keypad auto hides". The timing
/// pointed at the truncation check: it is armed when a preview render lands and
/// fires 900ms later, which is a beat after a typing pause — and when it
/// reports lost content a banner appears above the tabs, changing the shape of
/// the widget tree the focused field lives in.
void main() {
  /// Fourteen roles overflows every design in the catalog, so the check is
  /// guaranteed to report loss and the banner is guaranteed to appear.
  ResumeData overflowing() => sampleResume.copyWith(
    experiences: List.generate(
      14,
      (i) => sampleResume.experiences.first.copyWith(
        id: 'exp-$i',
        company: 'Company $i',
        position: 'Role $i',
      ),
    ),
  );

  Future<void> pumpEditor(
    WidgetTester tester,
    ResumeData data, {
    Size size = const Size(390, 844),
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    // A real IME takes a third of the screen and the Scaffold resizes the body
    // under it. Left at zero the test never sees the layout the bug was
    // reported in.
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: EditorScreen(
            document: newResumeDocument().copyWith(data: data),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pumps with real async between frames so the render isolate can actually
  /// produce a page and the truncation check can run.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  // Matches both wordings the report can produce: one section reads "does not
  // fit", several read "do not fit".
  final banner = find.textContaining('fit on the page');

  group('typing while the truncation banner appears', () {
    testWidgets('the field keeps focus and the keyboard stays up', (
      tester,
    ) async {
      await pumpEditor(tester, overflowing());

      final field = find.widgetWithText(TextField, 'Full name');
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, 'Amara Okonkwo');
      await tester.pump();

      final focused = tester.binding.focusManager.primaryFocus;
      expect(focused, isNotNull);
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'the keyboard has to be up before this test means anything',
      );
      expect(banner, findsNothing, reason: 'the check has not run yet');

      // The reported moment: the user pauses, the check lands, the banner
      // appears above the tabs.
      await pumpUntil(tester, banner);
      expect(banner, findsOneWidget, reason: 'the warning must still appear');

      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'the keyboard closed itself while the user was typing',
      );
      expect(
        tester.binding.focusManager.primaryFocus,
        same(focused),
        reason: 'the field being typed into lost focus',
      );
      expect(
        tester.testTextInput.hasAnyClients,
        isTrue,
        reason: 'the text input connection was dropped',
      );
      expect(
        find.widgetWithText(TextField, 'Amara Okonkwo'),
        findsOneWidget,
        reason: 'and what was typed has to still be there',
      );

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('and survives it with the keyboard actually taking the screen', (
      tester,
    ) async {
      // Same moment, but laid out the way a phone lays it out with the IME up:
      // the body is a third shorter, so the banner's arrival shrinks an
      // already-short viewport.
      await pumpEditor(tester, overflowing(), keyboard: 336);

      // Not the field's own hint text, which would match this finder twice.
      const typed = 'Principal Designer';
      final field = find.widgetWithText(TextField, 'Job title');
      await tester.ensureVisible(field);
      await tester.pump();
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, typed);
      await tester.pump();

      final focused = tester.binding.focusManager.primaryFocus;
      expect(tester.testTextInput.isVisible, isTrue);

      // Long enough for all three timers on this path: the render debounce,
      // the 800ms autosave, and the 900ms truncation check.
      await pumpUntil(tester, banner);
      expect(banner, findsOneWidget);

      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.binding.focusManager.primaryFocus, same(focused));
      expect(find.widgetWithText(TextField, typed), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('and the banner costs nothing when there is no loss', (
      tester,
    ) async {
      // The banner is now always in the column, so "absent" has to mean it
      // draws nothing at all rather than merely saying nothing.
      await pumpEditor(tester, sampleResume);
      await tester.pump(const Duration(seconds: 2));

      expect(banner, findsNothing);
      expect(
        tester.getRect(find.byType(TabBarView)).top,
        tester.getRect(find.byType(AppBar)).bottom,
        reason: 'an empty warning must take no height above the tabs',
      );

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the tab view is never rebuilt from scratch', (tester) async {
      // The mechanism, asserted directly rather than through its symptom: if
      // the banner's arrival remounts the subtree the form lives in, every
      // field's State and FocusNode goes with it.
      await pumpEditor(tester, overflowing());

      final before = tester.element(find.byType(TabBarView));
      final formBefore = tester.element(
        find.byKey(const Key('editor-form-list')),
      );

      await pumpUntil(tester, banner);
      expect(banner, findsOneWidget);

      expect(
        tester.element(find.byType(TabBarView)),
        same(before),
        reason: 'the tab view was unmounted and rebuilt',
      );
      expect(
        tester.element(find.byKey(const Key('editor-form-list'))),
        same(formBefore),
        reason: 'the form list was unmounted and rebuilt',
      );

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
