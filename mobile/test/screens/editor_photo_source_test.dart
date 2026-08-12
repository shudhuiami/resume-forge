import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:resume_forge/data/photo_service.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/screens/editor_screen.dart';
import 'package:resume_forge/state/app_providers.dart';
import 'package:resume_forge/theme/app_theme.dart';

/// Stands in for the platform picker.
///
/// [supportsImageSource] is implemented rather than left to [noSuchMethod]
/// deliberately: `PhotoService.supportsCamera` reads it synchronously to decide
/// whether the camera row exists at all, and a bare fake throws there.
class _FakePicker implements ImagePicker {
  _FakePicker({this.result, this.error, this.cameraSupported = true});

  /// Mutable so one instance can play back a camera that fails and then a
  /// library that works — the platform changes its mind between requests, and
  /// the provider is only overridden once, at pump time.
  Uint8List? result;
  Object? error;
  final bool cameraSupported;

  /// Every source the editor actually asked the platform for, in order.
  final List<ImageSource> requested = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requested.add(source);
    if (error != null) throw error!;
    if (result == null) return null;
    return XFile.fromData(result!, name: 'portrait.png');
  }

  @override
  bool supportsImageSource(ImageSource source) =>
      source == ImageSource.camera ? cameraSupported : true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List portraitPng() {
  final image = img.Image(width: 120, height: 120);
  for (var y = 0; y < 120; y++) {
    for (var x = 0; x < 120; x++) {
      image.setPixelRgb(x, y, x * 2, y * 2, 90);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Choosing where a photo comes from, end to end through the UI.
void main() {
  late _FakePicker picker;

  /// A viewport tall enough to hold the About-you card without scrolling.
  const phone = Size(390, 844);

  Future<void> pumpEditor(
    WidgetTester tester, {
    Size size = phone,
    ResumeData data = const ResumeData(),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    final repo = InMemoryResumeRepository();
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          photoServiceProvider.overrideWithValue(PhotoService(picker: picker)),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: EditorScreen(
                document: newResumeDocument().copyWith(data: data),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Taps the photo tile's action and waits out the sheet's entrance.
  ///
  /// Scrolls to it first: on a landscape phone at double text size the section
  /// heading alone fills the viewport, so the control is in the tree but below
  /// the fold.
  Future<void> openSources(
    WidgetTester tester, {
    String label = 'Add photo',
  }) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Pumps with real async between frames, so the picker future and the
  /// downscale can actually complete.
  Future<void> settlePick(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await settlePick(tester);
  }

  /// A photo in the model flips the tile's own copy, which is the only thing
  /// on screen that says whether one landed.
  void expectHasPhoto(bool has) {
    expect(find.text(has ? 'Replace photo' : 'Add photo'), findsOneWidget);
    expect(find.text('Remove'), has ? findsOneWidget : findsNothing);
  }

  setUp(() => picker = _FakePicker(result: portraitPng()));

  group('photo source chooser', () {
    testWidgets('offers the camera and the library as peers', (tester) async {
      await pumpEditor(tester);
      await openSources(tester);

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Open the camera and capture one now.'), findsOneWidget);
      expect(find.text('Choose an existing photo'), findsOneWidget);
      expect(find.text('Pick one from your photo library.'), findsOneWidget);
      expect(
        picker.requested,
        isEmpty,
        reason: 'opening the chooser must not open a picker',
      );
    });

    testWidgets('the camera row asks the platform for the camera', (
      tester,
    ) async {
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Take a photo');

      expect(picker.requested, [ImageSource.camera]);
      expectHasPhoto(true);
    });

    testWidgets('the library row asks the platform for the library', (
      tester,
    ) async {
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Choose an existing photo');

      expect(picker.requested, [ImageSource.gallery]);
      expectHasPhoto(true);
    });

    testWidgets('backing out of the sheet changes nothing', (tester) async {
      await pumpEditor(tester);
      await openSources(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await settlePick(tester);

      expect(find.text('Take a photo'), findsNothing);
      expect(picker.requested, isEmpty, reason: 'no source was chosen');
      expectHasPhoto(false);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an existing photo is replaced through the same sheet', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        data: ResumeData(personalInfo: PersonalInfo(photo: portraitPng())),
      );
      expectHasPhoto(true);

      await openSources(tester, label: 'Replace photo');

      expect(
        find.text('Replace photo'),
        findsNWidgets(2),
        reason: 'the sheet heading names what the tap is about to do',
      );
      await choose(tester, 'Take a photo');

      expect(picker.requested, [ImageSource.camera]);
      expectHasPhoto(true);
    });

    testWidgets('removing a photo still works alongside the chooser', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        data: ResumeData(personalInfo: PersonalInfo(photo: portraitPng())),
      );

      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expectHasPhoto(false);
    });
  });

  group('a device with no camera', () {
    setUp(
      () => picker = _FakePicker(result: portraitPng(), cameraSupported: false),
    );

    testWidgets('is never offered one', (tester) async {
      await pumpEditor(tester);
      await openSources(tester);

      expect(
        find.text('Take a photo'),
        findsNothing,
        reason: 'a camera row that cannot work is worse than no row',
      );
      expect(
        find.byType(ListTile),
        findsNothing,
        reason: 'a sheet with a single row charges a tap for no choice',
      );
    });

    testWidgets('goes straight to the library instead', (tester) async {
      await pumpEditor(tester);
      await openSources(tester);
      await settlePick(tester);

      expect(picker.requested, [ImageSource.gallery]);
      expectHasPhoto(true);
    });
  });

  group('outcomes', () {
    testWidgets('backing out of the camera says nothing', (tester) async {
      picker = _FakePicker();
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Take a photo');

      expect(picker.requested, [ImageSource.camera]);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'a cancelled capture is not a problem to report',
      );
      expectHasPhoto(false);
    });

    testWidgets('a refused camera permission is explained in its own words', (
      tester,
    ) async {
      picker = _FakePicker(
        error: PlatformException(
          code: 'camera_access_denied',
          message: 'The user did not allow camera access.',
        ),
      );
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Take a photo');

      // The service's sentence, not one invented here: it names the camera
      // switch, which is the one that changes anything.
      expect(find.textContaining('Camera access'), findsOneWidget);
      expect(find.textContaining('Settings'), findsOneWidget);
      expect(find.textContaining('Photo access'), findsNothing);
      expectHasPhoto(false);

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a device that finds no camera is not sent to Settings', (
      tester,
    ) async {
      // What image_picker_android raises when ACTION_IMAGE_CAPTURE resolves to
      // nothing. Missing hardware is not a permission anyone can grant.
      picker = _FakePicker(
        error: PlatformException(
          code: 'no_available_camera',
          message: 'No cameras available for taking pictures.',
        ),
      );
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Take a photo');

      expect(find.textContaining('No camera is available'), findsOneWidget);
      expect(
        find.textContaining('Settings'),
        findsNothing,
        reason: 'there is no switch to go and find',
      );

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a failed capture offers the other source as a way out', (
      tester,
    ) async {
      picker = _FakePicker(
        error: PlatformException(
          code: 'no_available_camera',
          message: 'No cameras available for taking pictures.',
        ),
      );
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Take a photo');

      expect(find.text('Choose photo'), findsOneWidget);

      // The library works where the camera did not — which is exactly the
      // situation the message describes.
      picker.error = null;
      picker.result = portraitPng();

      // A snackbar ignores pointers until its entrance finishes.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      await settlePick(tester);

      expect(
        picker.requested,
        [ImageSource.camera, ImageSource.gallery],
        reason: 'the way out has to actually reach the other source',
      );
      expectHasPhoto(true);

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a refused library permission gets no dead-end action', (
      tester,
    ) async {
      picker = _FakePicker(
        error: PlatformException(
          code: 'photo_access_denied',
          message: 'The user did not allow photo access.',
        ),
      );
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Choose an existing photo');

      expect(find.textContaining('Photo access'), findsOneWidget);
      expect(
        find.text('Choose photo'),
        findsNothing,
        reason: 'offering the source that just failed leads nowhere',
      );

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('an unreadable image says so rather than blaming the library', (
      tester,
    ) async {
      picker = _FakePicker(result: Uint8List.fromList([1, 2, 3, 4, 5]));
      await pumpEditor(tester);
      await openSources(tester);
      await choose(tester, 'Choose an existing photo');

      // The service tells an unreadable file apart from an inaccessible
      // library, and the sentence the user sees has to keep that apart too.
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.textContaining('Could not open your photos'), findsNothing);
      expectHasPhoto(false);

      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('accessibility', () {
    testWidgets('each row is one labelled, tappable target', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester);
      await openSources(tester);

      for (final row in const {
        'Take a photo': 'Open the camera and capture one now.',
        'Choose an existing photo': 'Pick one from your photo library.',
      }.entries) {
        final tile = find.ancestor(
          of: find.text(row.key),
          matching: find.byType(ListTile),
        );

        expect(
          tester.getSize(tile).height,
          greaterThanOrEqualTo(48),
          reason: '${row.key} must be reachable by a thumb',
        );

        final node = tester.getSemantics(tile);
        expect(
          node.label,
          contains(row.key),
          reason: 'the label must not live only in a tooltip',
        );
        expect(
          node.label,
          contains(row.value),
          reason: 'the supporting line belongs to the same target',
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: '${row.key} must be activatable by a screen reader',
        );
      }

      handle.dispose();
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
      // with a fixed height overflows; a RenderFlex overflow fails the test
      // that provoked it.
      testWidgets('${entry.key} — at double text size', (tester) async {
        await pumpEditor(tester, size: entry.value, textScale: 2);
        await openSources(tester);

        expect(find.text('Take a photo'), findsOneWidget);
        expect(find.text('Choose an existing photo'), findsOneWidget);

        final sheet = tester.getRect(
          find.ancestor(
            of: find.text('Take a photo'),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(sheet.top, greaterThanOrEqualTo(0));
        expect(
          sheet.bottom,
          lessThanOrEqualTo(entry.value.height + precisionErrorTolerance),
          reason: 'the sheet must not run off the bottom of the screen',
        );
      });
    }
  });
}
