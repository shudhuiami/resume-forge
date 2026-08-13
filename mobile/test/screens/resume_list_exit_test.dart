import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/brand.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/screens/about_screen.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/screens/resume_list_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// A system back, the way the engine delivers one.
///
/// The same platform message Android sends for a back gesture or a back
/// button — not `Navigator.maybePop`, which would skip the part of the path
/// this screen is actually guarding. Copied from Flutter's own
/// `test/widgets/navigator_utils.dart`, which is not exported by
/// `flutter_test`.
Future<void> simulateSystemBack() {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'flutter/navigation',
        const JSONMessageCodec().encodeMessage(<String, dynamic>{
          'method': 'popRoute',
        }),
        (ByteData? _) {},
      );
}

void main() {
  const leaveTitle = 'Leave $appName?';
  const leaveBody =
      'Your resumes are saved on this device and will be here when you '
      'come back.';

  /// Every request the app makes to close itself.
  ///
  /// `SystemNavigator.pop()` is a platform channel call, so "did the app
  /// actually try to exit?" is a question only the channel can answer. The
  /// handler has to swallow everything else on `flutter/platform` too — the
  /// screen publishes its status bar style through the same channel.
  List<MethodCall> captureExits() {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return calls;
  }

  Future<InMemoryResumeRepository> pumpHome(
    WidgetTester tester, {
    bool seeded = true,
  }) async {
    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);
    if (seeded) await repo.save(newResumeDocument(id: 'a'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const ResumeListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('leaving the app', () {
    testWidgets('a back press on the home screen asks first', (tester) async {
      final exits = captureExits();
      await pumpHome(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(leaveTitle), findsOneWidget);
      expect(exits, isEmpty, reason: 'nothing may close before the answer');
    });

    /// Nothing is at risk here: every edit autosaves and everything is on the
    /// device. Copy that hinted otherwise would be a lie told to make a prompt
    /// feel more urgent.
    testWidgets('the copy does not imply anything is at risk', (tester) async {
      captureExits();
      await pumpHome(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(leaveBody), findsOneWidget);
      for (final alarm in const ['lose', 'lost', 'unsaved', 'discard']) {
        expect(
          find.textContaining(alarm, findRichText: true),
          findsNothing,
          reason: '"$alarm" says work is at stake, and none is',
        );
      }
    });

    /// The delete dialog wears the error colour on its confirm button because
    /// it destroys something. Closing an app that has saved everything does
    /// not, and a red button here would teach the user to distrust the red one
    /// that matters.
    testWidgets('the confirm button is not the destructive one', (
      tester,
    ) async {
      captureExits();
      await pumpHome(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      final leave = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Leave'),
      );
      expect(
        leave.style?.backgroundColor?.resolve(<WidgetState>{}),
        isNot(AppTheme.colorScheme.error),
      );
      expect(find.widgetWithText(TextButton, 'Stay'), findsOneWidget);
    });

    testWidgets('staying keeps the app open', (tester) async {
      final exits = captureExits();
      await pumpHome(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(find.text(leaveTitle), findsNothing);
      expect(exits, isEmpty);
      expect(find.byType(ResumeListScreen), findsOneWidget);
    });

    /// Dismissing the prompt — back again, or a tap outside it — is an answer,
    /// and the answer is no.
    testWidgets('backing out of the prompt is treated as staying', (
      tester,
    ) async {
      final exits = captureExits();
      await pumpHome(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();
      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(leaveTitle), findsNothing);
      expect(exits, isEmpty);
    });

    testWidgets('confirming closes the app', (tester) async {
      final exits = captureExits();
      await pumpHome(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(exits, hasLength(1));
      expect(exits.single.method, 'SystemNavigator.pop');
    });

    testWidgets('the prompt is there on a first run too', (tester) async {
      final exits = captureExits();
      await pumpHome(tester, seeded: false);

      expect(find.text('No resumes yet'), findsOneWidget);
      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(leaveTitle), findsOneWidget);
      expect(exits, isEmpty);
    });
  });

  /// The guard is the *root* route's, and only the root route's. A back press
  /// aimed at anything pushed on top of the home screen has to keep behaving
  /// exactly as it did.
  group('the prompt is scoped to the root route', () {
    testWidgets('backing out of the about screen just pops it', (tester) async {
      final exits = captureExits();
      await pumpHome(tester);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.byType(AboutScreen), findsNothing);
      expect(
        find.text(leaveTitle),
        findsNothing,
        reason: 'going back one screen is not leaving the app',
      );
      expect(exits, isEmpty);
      expect(find.byType(ResumeListScreen), findsOneWidget);
    });

    testWidgets('backing out of the gallery just pops it', (tester) async {
      final exits = captureExits();
      await pumpHome(tester);

      await tester.tap(find.byType(FloatingActionButton));
      // Not pumpAndSettle: gallery thumbnails spin while they rasterize.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GalleryScreen), findsOneWidget);

      // Three frames rather than pumpAndSettle: the pop is dispatched through
      // the platform channel and lands a frame later, then the route animates
      // out — and the gallery's thumbnail spinners mean this tree never
      // settles on its own.
      await simulateSystemBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GalleryScreen), findsNothing);
      expect(find.text(leaveTitle), findsNothing);
      expect(exits, isEmpty);
    });

    /// And once back on the home screen, the guard is armed again — a pushed
    /// route must not leave it disabled behind itself.
    testWidgets('the guard is still armed after a round trip', (tester) async {
      final exits = captureExits();
      await pumpHome(tester);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      await simulateSystemBack();
      await tester.pumpAndSettle();

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(leaveTitle), findsOneWidget);
      expect(exits, isEmpty);
    });

    /// The delete confirmation is a route too, and back has always dismissed
    /// it. It must keep dismissing only itself.
    testWidgets('backing out of a dialog does not ask about leaving', (
      tester,
    ) async {
      final exits = captureExits();
      final repo = await pumpHome(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Delete this resume?'), findsOneWidget);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text('Delete this resume?'), findsNothing);
      expect(find.text(leaveTitle), findsNothing);
      expect(exits, isEmpty);
      expect(await repo.all(), hasLength(1), reason: 'and nothing was deleted');
    });
  });
}
