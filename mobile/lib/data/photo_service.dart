import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Result of asking the user for a photo.
enum PhotoPickStatus { picked, cancelled, denied, failed }

class PhotoPickResult {
  const PhotoPickResult(this.status, {this.bytes, this.message});

  const PhotoPickResult.cancelled() : this(PhotoPickStatus.cancelled);

  final PhotoPickStatus status;
  final Uint8List? bytes;
  final String? message;
}

/// Picks and downscales a portrait for the resume.
///
/// Camera output is routinely several megabytes, and the photo lives inside
/// the resume document that gets rewritten on every autosave. Downscaling on
/// import — once — keeps documents small instead of paying that cost on every
/// keystroke-triggered write.
class PhotoService {
  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Longest edge of the stored image. A resume portrait is printed at roughly
  /// 92pt; 512px covers 3x density with room to spare.
  static const maxEdge = 512;

  /// JPEG quality for the stored portrait. 85 is visually indistinguishable
  /// here and roughly halves the payload versus 95.
  static const jpegQuality = 85;

  Future<PhotoPickResult> pick({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        // Let the platform do the first downscale where it can — it avoids
        // decoding a 12MP original into memory on a low-end device.
        maxWidth: maxEdge * 2,
        maxHeight: maxEdge * 2,
        imageQuality: 90,
      );
      if (file == null) return const PhotoPickResult.cancelled();

      final raw = await file.readAsBytes();
      final processed = downscale(raw);
      if (processed == null) {
        return const PhotoPickResult(
          PhotoPickStatus.failed,
          message: 'That image could not be read. Try a different photo.',
        );
      }
      return PhotoPickResult(PhotoPickStatus.picked, bytes: processed);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('permission') || text.contains('denied')) {
        return const PhotoPickResult(
          PhotoPickStatus.denied,
          message:
              'Photo access is required. Grant it in Settings to add a '
              'portrait.',
        );
      }
      return const PhotoPickResult(
        PhotoPickStatus.failed,
        message: 'Could not open your photos. Please try again.',
      );
    }
  }

  /// Decodes, squares, and downscales [raw]; returns null if undecodable.
  ///
  /// Pure and synchronous so it can be unit-tested without a picker or a
  /// platform channel.
  static Uint8List? downscale(
    Uint8List raw, {
    int maxEdge = maxEdge,
    int quality = jpegQuality,
  }) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;

    // Centre-crop to a square first. Templates render the portrait in a circle
    // or square frame, and cropping here means the resume never has to letterbox
    // or distort it later.
    final edge = decoded.width < decoded.height
        ? decoded.width
        : decoded.height;
    final square = img.copyCrop(
      decoded,
      x: (decoded.width - edge) ~/ 2,
      y: (decoded.height - edge) ~/ 2,
      width: edge,
      height: edge,
    );

    final resized = edge > maxEdge
        ? img.copyResize(
            square,
            width: maxEdge,
            height: maxEdge,
            interpolation: img.Interpolation.average,
          )
        : square;

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
}
