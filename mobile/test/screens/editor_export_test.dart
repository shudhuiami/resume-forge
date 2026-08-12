import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/widgets/pdf_page_view.dart';

/// Stands in for the platform save dialog.
///
/// The real one is a Storage Access Framework activity: nothing about it can be
/// answered from a widget test, so the editor takes a `fileSaver` seam and this
/// plays back each of the three things a save can do — a chosen destination, a
/// dismissed picker, a failed write.
class _FakeSaver {
  _FakeSaver({this.location, this.error});

  final String? location;
  final Object? error;

  int calls = 0;
  String? receivedName;
  Uint8List? receivedBytes;

  Future<String?> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls++;
    receivedName = fileName;
    receivedBytes = bytes;
    if (error != null) throw error!;
    return location;
  }
}

/// The export action, end to end through the UI.
///
/// The share plugin has no implementation under `flutter_test`, so every run of
/// the share path here takes the failure branch — which is exactly the branch
/// that has to stay recoverable. The save path is driven through the seam
/// instead, so its three outcomes are real rather than all-failures.
void main() {
  late _FakeSaver saver;

  Future<void> pumpEditor(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ResumeData? data,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

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
              child: EditorScreen(
                document: newResumeDocument().copyWith(
                  data: data ?? sampleResume,
                ),
                fileSaver: saver.call,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final exportFinder = find.ancestor(
    of: find.byTooltip('Export PDF'),
    matching: find.byType(IconButton),
  );

  IconButton exportButton(WidgetTester tester) =>
      tester.widget<IconButton>(exportFinder);

  /// Opens the destination chooser and waits out its entrance.
  Future<void> openDestinations(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Taps through the chooser to [label], the way a user reaches an export.
  Future<void> exportTo(WidgetTester tester, String label) async {
    await openDestinations(tester);
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Pumps, letting real async (the render isolate, the plugin call) run
  /// between frames, until [finder] matches or the budget runs out.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Lets an export finish when nothing is expected to appear at the end of it.
  Future<void> pumpOutExport(WidgetTester tester) async {
    for (var i = 0; i < 120; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUp(() => saver = _FakeSaver(location: 'content://downloads/42'));

  group('export destination chooser', () {
    testWidgets('offers saving and sharing as peers', (tester) async {
      await pumpEditor(tester);
      await openDestinations(tester);

      expect(find.text('Export PDF'), findsWidgets);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Save to device'), findsOneWidget);
      expect(
        find.text('Send the PDF through another app.'),
        findsOneWidget,
        reason: 'each row says what picking it does',
      );
      expect(find.text('Choose where to keep the file.'), findsOneWidget);
      expect(
        find.text('Preparing PDF…'),
        findsNothing,
        reason: 'the question is asked before the work, not during it',
      );
      expect(saver.calls, 0);
    });

    testWidgets('backing out of the sheet exports nothing', (tester) async {
      await pumpEditor(tester);
      await openDestinations(tester);

      // The barrier above the sheet: what a user taps to change their mind.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Share'), findsNothing);
      expect(find.text('Save to device'), findsNothing);
      expect(find.text('Preparing PDF…'), findsNothing);
      expect(saver.calls, 0, reason: 'no destination was chosen');
      expect(
        exportButton(tester).onPressed,
        isNotNull,
        reason: 'a dismissed chooser must not leave the action stuck disabled',
      );
    });

    testWidgets('every row is a real target, not a caption', (tester) async {
      await pumpEditor(tester);
      await openDestinations(tester);

      for (final label in ['Share', 'Save to device']) {
        final row = find.ancestor(
          of: find.text(label),
          matching: find.byType(ListTile),
        );
        expect(row, findsOneWidget, reason: label);
        expect(
          tester.widget<ListTile>(row).onTap,
          isNotNull,
          reason: '$label must do something',
        );
        expect(
          tester.getSize(row).height,
          greaterThanOrEqualTo(48),
          reason: '$label must be reachable by a thumb',
        );
      }
    });

    testWidgets('the sheet does not stretch across a tablet', (tester) async {
      await pumpEditor(tester, size: const Size(768, 1024));
      await openDestinations(tester);

      final sheet = tester.getSize(
        find.ancestor(
          of: find.text('Save to device'),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(
        sheet.width,
        lessThanOrEqualTo(640),
        reason: 'a 768-wide row strands its copy beside empty space',
      );
    });
  });

  group('share', () {
    testWidgets('progress is shown for as long as the work takes', (
      tester,
    ) async {
      await pumpEditor(tester);
      await exportTo(tester, 'Share');

      expect(find.text('Preparing PDF…'), findsOneWidget);

      // The old fixed one-second snackbar had already vanished by here,
      // leaving the app looking idle mid-export.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Preparing PDF…'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('the button is not a dead control while an export runs', (
      tester,
    ) async {
      await pumpEditor(tester);
      expect(exportButton(tester).onPressed, isNotNull);

      await exportTo(tester, 'Share');

      expect(
        exportButton(tester).onPressed,
        isNull,
        reason: 'a second tap would build the document twice',
      );
      expect(
        find.descendant(
          of: exportFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a disabled button with no explanation reads as broken',
      );

      await pumpUntil(tester, find.text('Try again'));
      await tester.pump();
      expect(
        exportButton(tester).onPressed,
        isNotNull,
        reason: 'the action has to come back once the attempt is over',
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a failure is explained and offers a retry', (tester) async {
      await pumpEditor(tester);
      await exportTo(tester, 'Share');

      await pumpUntil(tester, find.text('Try again'));

      expect(find.text('Could not export the PDF.'), findsOneWidget);
      expect(
        find.text('Try again'),
        findsOneWidget,
        reason: 'a failed export must not end the road',
      );
      expect(
        find.text('Preparing PDF…'),
        findsNothing,
        reason: 'the progress snackbar must be closed before the outcome',
      );
      expect(
        saver.calls,
        0,
        reason: 'choosing Share must not touch the save path',
      );

      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('save to device', () {
    testWidgets('a chosen destination is confirmed by name', (tester) async {
      await pumpEditor(tester);
      await exportTo(tester, 'Save to device');

      await pumpUntil(tester, find.textContaining('Saved as'));

      expect(saver.calls, 1);
      expect(saver.receivedName, 'amara-okonkwo-resume.pdf');
      expect(saver.receivedBytes, isNotNull);
      expect(saver.receivedBytes, isNotEmpty);
      expect(find.text('Saved as amara-okonkwo-resume.pdf'), findsOneWidget);
      expect(
        find.textContaining('content://'),
        findsNothing,
        reason: 'the returned location is a URI, documented as unfit to show',
      );
      expect(
        find.text('Try again'),
        findsNothing,
        reason: 'a successful save is not a failure',
      );

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a dismissed picker says nothing at all', (tester) async {
      saver = _FakeSaver();
      await pumpEditor(tester);
      await exportTo(tester, 'Save to device');

      await pumpOutExport(tester);

      expect(saver.calls, 1, reason: 'the picker did open; the user declined');
      expect(
        find.textContaining('Saved as'),
        findsNothing,
        reason: 'nothing was saved',
      );
      expect(
        find.text('Try again'),
        findsNothing,
        reason: 'changing your mind is not an error to apologise for',
      );
      expect(find.text('Preparing PDF…'), findsNothing);
      expect(
        exportButton(tester).onPressed,
        isNotNull,
        reason: 'the action has to come back',
      );

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a failed write says what to do next, and retries', (
      tester,
    ) async {
      saver = _FakeSaver(
        error: PlatformException(
          code: 'save_file_failed',
          message: 'Failed to write to the selected document',
        ),
      );
      await pumpEditor(tester);
      await exportTo(tester, 'Save to device');

      await pumpUntil(tester, find.text('Try again'));

      expect(find.textContaining('different folder'), findsOneWidget);
      expect(saver.calls, 1);

      // A snackbar ignores pointers until its entrance finishes, so the tap
      // has to wait for the bar to actually arrive.
      await tester.pump(const Duration(milliseconds: 500));

      // Retry goes back to the destination already chosen rather than asking
      // the same question twice.
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Save to device'),
        findsNothing,
        reason: 'the chooser must not reopen on retry',
      );
      await pumpUntil(tester, find.text('Preparing PDF…'));
      expect(find.text('Preparing PDF…'), findsOneWidget);

      await pumpUntil(tester, find.text('Try again'));
      expect(saver.calls, 2, reason: 'the retry reached the save path again');

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('an unreachable location does not send anyone to Settings', (
      tester,
    ) async {
      // A lost SAF grant. The advice has to be "pick somewhere else", not
      // "grant a permission", because there is no permission to grant.
      saver = _FakeSaver(
        error: PlatformException(
          code: 'security_exception',
          message: 'Permission Denial: opening provider',
        ),
      );
      await pumpEditor(tester);
      await exportTo(tester, 'Save to device');

      await pumpUntil(tester, find.text('Try again'));

      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.textContaining('Settings'), findsNothing);

      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('content that will not fit', () {
    /// Fourteen roles overflows every design in the catalog.
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

    testWidgets('is still warned about before a save leaves the app', (
      tester,
    ) async {
      await pumpEditor(tester, data: overflowing());
      await exportTo(tester, 'Save to device');

      await pumpUntil(tester, find.text('Some content will be left out'));

      expect(
        find.text('Some content will be left out'),
        findsOneWidget,
        reason: 'the new destination step must not bypass the warning',
      );
      expect(
        saver.calls,
        0,
        reason: 'nothing may reach the picker before the user has decided',
      );

      await tester.tap(find.text('Go back and edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(saver.calls, 0, reason: 'the user went back to edit');
      expect(exportButton(tester).onPressed, isNotNull);

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('can be accepted, and the save then runs', (tester) async {
      await pumpEditor(tester, data: overflowing());
      await exportTo(tester, 'Save to device');

      await pumpUntil(tester, find.text('Export anyway'));
      await tester.tap(find.text('Export anyway'));
      await tester.pump();

      await pumpUntil(tester, find.textContaining('Saved as'));

      expect(saver.calls, 1);
      expect(find.textContaining('Saved as'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('chooser layout', () {
    for (final entry in const {
      'phone small': Size(360, 800),
      'phone normal': Size(390, 844),
      'phone large': Size(430, 932),
      'tablet': Size(768, 1024),
      'landscape phone': Size(800, 360),
    }.entries) {
      // Two rows of supporting text at double the type size is where a sheet
      // with a fixed height overflows. A RenderFlex overflow is a framework
      // error, so these pumps are assertions.
      testWidgets('${entry.key} — at double text size', (tester) async {
        await pumpEditor(tester, size: entry.value, textScale: 2);
        await openDestinations(tester);

        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Save to device'), findsOneWidget);

        final sheet = tester.getRect(
          find.ancestor(
            of: find.text('Share'),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(
          sheet.bottom,
          lessThanOrEqualTo(entry.value.height + precisionErrorTolerance),
          reason: 'the sheet must not run off the bottom of the screen',
        );
      });
    }
  });

  group('preview', () {
    testWidgets('the preview tab can ask for a failed render to be retried', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.tap(find.text('Preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final view = tester.widget<PdfPageView>(
        find.byType(PdfPageView, skipOffstage: false),
      );

      // Left null, the preview's Retry affordance could never be drawn and a
      // render error was a dead end until the user typed something else.
      expect(view.onRetry, isNotNull);
    });
  });

  group('a platform with no save picker', () {
    // `canSaveToDisk` is false on web and desktop: the plugin has no
    // implementation there, so the only possible answer is an apology.
    testWidgets('goes straight to sharing rather than offering one row', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await pumpEditor(tester);

      await tester.tap(find.byTooltip('Export PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Save to device'),
        findsNothing,
        reason: 'a destination that cannot work must not be offered',
      );
      expect(
        find.byType(ListTile),
        findsNothing,
        reason: 'a sheet with a single row charges a tap for no choice',
      );
      expect(
        find.text('Preparing PDF…'),
        findsOneWidget,
        reason: 'the export starts immediately, as it did before the chooser',
      );

      // Restored inside the body: the framework asserts every foundation debug
      // variable is unset the moment the body returns, before any tearDown.
      debugDefaultTargetPlatformOverride = null;

      await pumpUntil(tester, find.text('Try again'));
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
