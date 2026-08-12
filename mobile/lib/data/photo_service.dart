import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Result of asking the user for a photo.
///
/// Deliberately four values and no more. A device with no camera is a
/// [PhotoPickStatus.failed] carrying its own explanation rather than a fifth
/// status: callers already switch exhaustively over this enum, and a new value
/// would break every one of them to say something the message already says.
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

  /// Whether this platform can capture a photo at all.
  ///
  /// Answers "is the camera affordance worth showing", not "does this handset
  /// have a working lens" — no platform reports the latter without launching
  /// the camera first, which is why [pick] still has to handle a capture that
  /// finds no camera to hand off to.
  bool get supportsCamera => _picker.supportsImageSource(ImageSource.camera);

  /// Takes a portrait with the camera.
  Future<PhotoPickResult> pickFromCamera() => pick(source: ImageSource.camera);

  /// Chooses an existing portrait from the photo library.
  Future<PhotoPickResult> pickFromGallery() =>
      pick(source: ImageSource.gallery);

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
      return _describeFailure(error, source);
    }
  }

  /// Turns a picker exception into a result the UI can render.
  ///
  /// Nothing here rethrows. Every path out of the camera — no hardware, no
  /// camera app installed, a refused permission, a second tap while the first
  /// sheet is still up — is a normal thing for a user to run into, and each one
  /// needs a sentence that says what happened and what to do instead.
  static PhotoPickResult _describeFailure(Object error, ImageSource source) {
    final code = error is PlatformException ? error.code : '';
    final text = '$code $error'.toLowerCase();
    final fromCamera = source == ImageSource.camera;

    // No camera app to hand the capture to (image_picker's `no_available_camera`
    // from an ActivityNotFoundException), or a platform whose image_picker
    // implementation has no camera delegate at all. Neither is retryable and
    // neither is about permissions, so the message must point at the gallery
    // rather than at Settings.
    if (text.contains('no_available_camera') ||
        text.contains('cameradelegate')) {
      return const PhotoPickResult(
        PhotoPickStatus.failed,
        message:
            'No camera is available on this device. Choose an existing photo '
            'instead.',
      );
    }

    // The picker is single-flight; a second request while a sheet is open is a
    // double tap, not a broken app.
    if (text.contains('already_active')) {
      return const PhotoPickResult(
        PhotoPickStatus.failed,
        message:
            'A photo request is already open. Finish with it, then try '
            'again.',
      );
    }

    // Refused, or blocked by parental controls (`*_access_restricted`). Both
    // land the user in the same place, and the wording has to name the right
    // switch — telling someone to grant photo access when they refused the
    // camera sends them to a setting that changes nothing.
    if (text.contains('permission') ||
        text.contains('denied') ||
        text.contains('restricted')) {
      return PhotoPickResult(
        PhotoPickStatus.denied,
        message: fromCamera
            ? 'Camera access is required. Grant it in Settings to take a '
                  'portrait.'
            : 'Photo access is required. Grant it in Settings to add a '
                  'portrait.',
      );
    }

    return PhotoPickResult(
      PhotoPickStatus.failed,
      message: fromCamera
          ? 'Could not open the camera. Please try again.'
          : 'Could not open your photos. Please try again.',
    );
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
    // package:image does not merely return null on bad input — its format
    // probes index past the end of a short or truncated buffer and throw
    // RangeError. Without this catch the null branch below is dead for exactly
    // the corrupt input it exists to handle, and a half-written photo file
    // escapes as an uncaught exception to every caller.
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(raw);
    } catch (_) {
      return null;
    }
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
