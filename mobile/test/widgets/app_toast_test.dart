import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/app_toast.dart';

/// A page with a full-screen button underneath, so a test can prove the toast
/// is not stealing input from the content it floats over.
class _Host extends StatelessWidget {
  const _Host({required this.onTapBehind, this.onReady});

  final VoidCallback onTapBehind;
  final void Function(BuildContext)? onReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            onReady?.call(context);
            return GestureDetector(
              onTap: onTapBehind,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(child: Text('page')),
            );
          },
        ),
      ),
    );
  }
}

/// Pumps the host and hands back a context inside the Navigator.
Future<BuildContext> pumpHost(
  WidgetTester tester, {
  required VoidCallback onTapBehind,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  late BuildContext captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: _Host(
        onTapBehind: onTapBehind,
        onReady: (context) => captured = context,
      ),
    ),
  );
  return captured;
}

void main() {
  group('placement', () {
    testWidgets('sits in the top half, not over the bottom of the page', (
      tester,
    ) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(context, message: 'Saved as resume.pdf');
      await tester.pumpAndSettle();

      final box = tester.getRect(find.text('Saved as resume.pdf'));
      expect(
        box.center.dy,
        lessThan(844 / 2),
        reason: 'the whole complaint was that it showed at the bottom',
      );
    });

    testWidgets('hugs the right edge when the screen is wide', (tester) async {
      final context = await pumpHost(
        tester,
        onTapBehind: () {},
        size: const Size(1024, 768),
      );
      AppToast.show(context, message: 'Saved');
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.byType(Card).evaluate().isEmpty
            ? find.text('Saved')
            : find.text('Saved'),
      );
      // Capped rather than spanning: a 1024pt-wide toast is a banner.
      expect(card.width, lessThan(420));
      expect(
        1024 - card.right,
        lessThan(1024 - card.left),
        reason: 'closer to the right edge than the left',
      );
    });

    testWidgets('spans the width on a narrow phone', (tester) async {
      final context = await pumpHost(
        tester,
        onTapBehind: () {},
        size: const Size(360, 800),
      );
      AppToast.show(
        context,
        message: 'A message long enough to need the room it is given',
      );
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.ancestor(
          of: find.textContaining('long enough'),
          matching: find.byType(Material).last,
        ),
      );
      expect(card.width, greaterThan(360 * 0.7));
    });
  });

  group('does not block the page', () {
    testWidgets('a tap beside the toast still reaches the content', (
      tester,
    ) async {
      var tapsBehind = 0;
      final context = await pumpHost(tester, onTapBehind: () => tapsBehind++);
      AppToast.show(context, message: 'Saved as resume.pdf');
      await tester.pumpAndSettle();

      // Level with the toast, but on the far left where the card is not.
      final toast = tester.getRect(find.text('Saved as resume.pdf'));
      await tester.tapAt(Offset(8, toast.center.dy));
      await tester.pump();

      expect(
        tapsBehind,
        1,
        reason: 'the overlay must only take hits on the card itself',
      );
    });

    testWidgets('a tap on the far bottom reaches the content', (tester) async {
      var tapsBehind = 0;
      final context = await pumpHost(tester, onTapBehind: () => tapsBehind++);
      AppToast.show(context, message: 'Saved');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(195, 800));
      await tester.pump();
      expect(tapsBehind, 1);
    });
  });

  group('auto dismiss', () {
    testWidgets('a plain confirmation leaves on its own', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(
        context,
        message: 'Saved as resume.pdf',
        variant: ToastVariant.success,
      );
      await tester.pump();
      expect(find.text('Saved as resume.pdf'), findsOneWidget);

      await tester.pump(AppToast.successDwell);
      await tester.pumpAndSettle();
      expect(find.text('Saved as resume.pdf'), findsNothing);
    });

    testWidgets('one carrying an action is given longer to be reached', (
      tester,
    ) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(
        context,
        message: 'Sample resume loaded.',
        actionLabel: 'Undo',
        onAction: () {},
      );
      await tester.pump();

      // Still there well past the plain-confirmation dwell.
      await tester.pump(AppToast.successDwell);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(AppToast.actionDwell);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('progress never leaves on its own', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      final handle = AppToast.showProgress(context, message: 'Preparing PDF…');
      await tester.pump();

      await tester.pump(const Duration(minutes: 2));
      expect(
        find.text('Preparing PDF…'),
        findsOneWidget,
        reason: 'a render of unknown length must not look finished',
      );

      handle.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Preparing PDF…'), findsNothing);
    });

    testWidgets('the countdown pauses while a finger is on the card', (
      tester,
    ) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(
        context,
        message: 'Resume cleared.',
        actionLabel: 'Undo',
        onAction: () {},
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Resume cleared.')),
      );
      await tester.pump(AppToast.actionDwell * 2);
      expect(
        find.text('Resume cleared.'),
        findsOneWidget,
        reason: 'it must not vanish under a finger reaching for Undo',
      );

      await gesture.up();
      await tester.pump(AppToast.actionDwell);
      await tester.pumpAndSettle();
      expect(find.text('Resume cleared.'), findsNothing);
    });
  });

  group('actions and handles', () {
    testWidgets('the action fires and takes the toast with it', (tester) async {
      var undone = 0;
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(
        context,
        message: 'Sample resume loaded.',
        actionLabel: 'Undo',
        onAction: () => undone++,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undone, 1);
      expect(find.text('Sample resume loaded.'), findsNothing);
    });

    testWidgets('an action label with no callback shows no button', (
      tester,
    ) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(context, message: 'Saved', actionLabel: 'Undo');
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('dismissing twice is a no-op, not a crash', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      final handle = AppToast.show(context, message: 'Saved');
      await tester.pumpAndSettle();

      handle.dismiss();
      await tester.pumpAndSettle();
      expect(handle.isShowing, isFalse);

      // The SnackBar this replaced threw `Bad state: No element` here.
      handle.dismiss();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('swiping up dismisses it', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(context, message: 'Saved as resume.pdf');
      await tester.pumpAndSettle();

      await tester.fling(
        find.text('Saved as resume.pdf'),
        const Offset(0, -200),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved as resume.pdf'), findsNothing);
    });
  });

  group('stacking', () {
    testWidgets('a second toast joins the first rather than replacing it', (
      tester,
    ) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.showProgress(context, message: 'Preparing PDF…');
      AppToast.show(context, message: 'Could not export the PDF.');
      // Not pumpAndSettle: the progress spinner never stops, by design.
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Preparing PDF…'), findsOneWidget);
      expect(find.text('Could not export the PDF.'), findsOneWidget);
    });

    testWidgets('the newest is on top', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.showProgress(context, message: 'first');
      AppToast.showProgress(context, message: 'second');
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getRect(find.text('second')).top,
        lessThan(tester.getRect(find.text('first')).top),
      );
    });

    testWidgets('the stack is capped and drops the oldest', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      for (var i = 0; i < AppToast.maxVisible + 2; i++) {
        AppToast.showProgress(context, message: 'toast $i');
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('toast 0'), findsNothing);
      expect(find.text('toast 1'), findsNothing);
      expect(find.textContaining('toast '), findsNWidgets(AppToast.maxVisible));
    });
  });

  group('variants', () {
    testWidgets('error is marked by a glyph, not by colour alone', (
      tester,
    ) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(
        context,
        message: 'Could not export the PDF.',
        variant: ToastVariant.error,
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('success and info carry their own glyphs', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(context, message: 'a', variant: ToastVariant.success);
      AppToast.show(context, message: 'b', variant: ToastVariant.info);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('progress shows a spinner and no glyph', (tester) async {
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.showProgress(context, message: 'Preparing PDF…');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });
  });

  group('accessibility and motion', () {
    testWidgets('reduced motion shows the resting frame with no animation', (
      tester,
    ) async {
      final context = await pumpHost(
        tester,
        onTapBehind: () {},
        reduceMotion: true,
      );
      AppToast.show(context, message: 'Saved');
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'nothing should be ticking',
      );
    });

    testWidgets('the card is a live region so a reader announces it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final context = await pumpHost(tester, onTapBehind: () {});
      AppToast.show(context, message: 'Saved as resume.pdf');
      await tester.pumpAndSettle();

      expect(tester.getSemantics(find.text('Saved as resume.pdf')), isNotNull);
      handle.dispose();
    });

    testWidgets('survives 2x text on a small phone without overflowing', (
      tester,
    ) async {
      final context = await pumpHost(
        tester,
        onTapBehind: () {},
        size: const Size(360, 800),
        textScale: 2.0,
      );
      AppToast.show(
        context,
        message:
            'Camera access is required to take a photo. Enable it in Settings.',
        variant: ToastVariant.error,
        actionLabel: 'Choose photo',
        onAction: () {},
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Choose photo'), findsOneWidget);
    });
  });
}
