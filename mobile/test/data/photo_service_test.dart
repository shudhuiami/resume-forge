import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:resume_forge/data/photo_service.dart';

/// Stands in for the platform picker. Only [pickImage] is used; everything else
/// on the interface is forwarded to [noSuchMethod] and never called.
class _FakePicker implements ImagePicker {
  _FakePicker({this.result, this.error});

  /// Bytes the picker "returns", or null to simulate the user cancelling.
  final Uint8List? result;

  /// Thrown instead of returning, to simulate a platform failure.
  final Object? error;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (error != null) throw error!;
    if (result == null) return null;
    return XFile.fromData(result!, name: 'portrait.png');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a PNG of [width] x [height], coloured by [colorAt].
///
/// Fixtures are generated rather than committed so the test says exactly what
/// pixels it depends on.
Uint8List pngOf(
  int width,
  int height,
  List<int> Function(int x, int y) colorAt,
) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rgb = colorAt(x, y);
      image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List solidPng(int width, int height, List<int> rgb) =>
    pngOf(width, height, (_, _) => rgb);

img.Image decode(Uint8List? bytes) {
  expect(bytes, isNotNull, reason: 'expected decodable output');
  final image = img.decodeImage(bytes!);
  expect(image, isNotNull, reason: 'output must itself be a readable image');
  return image!;
}

void main() {
  group('PhotoService.downscale', () {
    test('caps the longest edge at 512px', () {
      final raw = pngOf(1200, 900, (x, y) => [x % 256, y % 256, (x + y) % 256]);

      final image = decode(PhotoService.downscale(raw));

      expect(image.width, PhotoService.maxEdge);
      expect(image.height, PhotoService.maxEdge);
      expect(max(image.width, image.height), lessThanOrEqualTo(512));
    });

    test('honours a caller-supplied cap', () {
      final raw = solidPng(400, 400, [10, 120, 200]);

      final image = decode(PhotoService.downscale(raw, maxEdge: 64));

      expect(image.width, 64);
      expect(image.height, 64);
    });

    test('centre-crops a wide image to a square', () {
      // Three vertical bands. A centred 100x100 crop of a 300x100 image lands
      // exactly on the green band, so an off-centre crop shows up as red/blue.
      final raw = pngOf(300, 100, (x, _) {
        if (x < 100) return [255, 0, 0];
        if (x < 200) return [0, 255, 0];
        return [0, 0, 255];
      });

      final image = decode(PhotoService.downscale(raw));

      expect(image.width, image.height, reason: 'output must be square');
      expect(image.width, 100, reason: 'crop takes the shorter edge');
      for (final point in <List<int>>[
        [0, 0],
        [99, 0],
        [50, 50],
        [0, 99],
        [99, 99],
      ]) {
        final pixel = image.getPixel(point[0], point[1]);
        expect(
          pixel.g,
          greaterThan(180),
          reason: 'centre band is green at ${point[0]},${point[1]}',
        );
        expect(pixel.r, lessThan(80));
        expect(pixel.b, lessThan(80));
      }
    });

    test('centre-crops a tall image to a square', () {
      final raw = pngOf(100, 300, (_, y) {
        if (y < 100) return [255, 0, 0];
        if (y < 200) return [0, 255, 0];
        return [0, 0, 255];
      });

      final image = decode(PhotoService.downscale(raw));

      expect(image.width, 100);
      expect(image.height, 100);
      final pixel = image.getPixel(50, 50);
      expect(pixel.g, greaterThan(180));
      expect(pixel.r, lessThan(80));
      expect(pixel.b, lessThan(80));
    });

    test('does not upscale an image already under the cap', () {
      final raw = solidPng(200, 200, [200, 100, 50]);

      final image = decode(PhotoService.downscale(raw));

      expect(
        image.width,
        200,
        reason: 'upscaling would add bytes and no detail',
      );
      expect(image.height, 200);
    });

    test('shrinks a large photo', () {
      // Noise resists PNG compression, so the input is genuinely large and the
      // comparison is not an artefact of an easily compressed gradient.
      final rng = Random(7);
      final raw = pngOf(
        900,
        900,
        (_, _) => [rng.nextInt(256), rng.nextInt(256), rng.nextInt(256)],
      );

      final out = PhotoService.downscale(raw);

      expect(out, isNotNull);
      expect(
        out!.length,
        lessThan(raw.length),
        reason: 'a photo stored in every autosave must get smaller on import',
      );
    });

    test('emits a JPEG', () {
      final raw = solidPng(300, 300, [12, 34, 56]);

      final out = PhotoService.downscale(raw)!;

      expect(out.sublist(0, 3), [
        0xFF,
        0xD8,
        0xFF,
      ], reason: 'stored portraits are JPEG, per the encode step');
    });

    test('returns null for bytes of an unrecognised format', () {
      // A long enough buffer that no decoder claims: every `isValidFile` probe
      // reads its header safely and declines, so `decodeImage` returns null and
      // the documented null contract holds.
      final unknown = Uint8List.fromList(List<int>.filled(4096, 0x5A));

      expect(PhotoService.downscale(unknown), isNull);
    });

    // Regression: `img.decodeImage` THROWS on short or truncated input rather
    // than returning null — the format probes in package:image index past the
    // end of the buffer. `downscale` catches that, so the documented "returns
    // null if undecodable" contract holds for the corrupt input it exists to
    // handle. Before the fix these threw RangeError and the null branch below
    // the decode was dead code.
    test('returns null for short garbage', () {
      expect(
        PhotoService.downscale(Uint8List.fromList([1, 2, 3, 4, 5])),
        isNull,
      );
    });

    test('returns null for empty bytes', () {
      expect(PhotoService.downscale(Uint8List(0)), isNull);
    });

    test('returns null for a truncated PNG', () {
      // A valid PNG signature followed by nothing: what a half-written file or
      // an interrupted download actually looks like.
      final raw = solidPng(64, 64, [1, 2, 3]);

      expect(PhotoService.downscale(raw.sublist(0, 16)), isNull);
    });

    test('a lower quality setting produces a smaller file', () {
      final raw = pngOf(
        400,
        400,
        (x, y) => [(x * 3) % 256, (y * 5) % 256, (x * y) % 256],
      );

      final high = PhotoService.downscale(raw, quality: 95)!;
      final low = PhotoService.downscale(raw, quality: 40)!;

      expect(low.length, lessThan(high.length));
    });
  });

  group('PhotoService.pick', () {
    test('returns downscaled bytes when the user picks a photo', () async {
      final raw = pngOf(800, 600, (x, y) => [x % 256, y % 256, (x * y) % 256]);
      final service = PhotoService(picker: _FakePicker(result: raw));

      final result = await service.pick();

      expect(result.status, PhotoPickStatus.picked);
      final image = decode(result.bytes);
      expect(image.width, PhotoService.maxEdge);
      expect(image.height, PhotoService.maxEdge);
    });

    test('reports cancellation when the picker returns nothing', () async {
      final service = PhotoService(picker: _FakePicker());

      final result = await service.pick();

      expect(result.status, PhotoPickStatus.cancelled);
      expect(result.bytes, isNull);
    });

    test('maps a permission error to a denied result with guidance', () async {
      final service = PhotoService(
        picker: _FakePicker(error: StateError('photo permission denied')),
      );

      final result = await service.pick();

      expect(result.status, PhotoPickStatus.denied);
      expect(result.message, contains('Settings'));
    });

    test('maps an unrelated platform error to failed', () async {
      final service = PhotoService(
        picker: _FakePicker(error: StateError('picker already in use')),
      );

      final result = await service.pick();

      expect(result.status, PhotoPickStatus.failed);
      expect(result.message, isNotNull);
    });

    // Consequence of the downscale defect above: a corrupt file still fails
    // safely (no crash reaches the caller), but it takes the generic "could
    // not open your photos" path because the decode throws before the null
    // check runs. The precise "that image could not be read" message is
    // therefore unreachable for a truncated file.
    test('a corrupt image reports the accurate message', () async {
      final service = PhotoService(
        picker: _FakePicker(result: Uint8List.fromList([1, 2, 3, 4, 5])),
      );

      final result = await service.pick();

      expect(result.status, PhotoPickStatus.failed);
      expect(
        result.message,
        contains('could not be read'),
        reason:
            'an unreadable image is a different problem from an '
            'inaccessible photo library, and the message should say which',
      );
    });
  });
}
