import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:printing/printing.dart';

import '../models/resume.dart';

/// What happened when the user tried to export.
///
/// Cancellation is modelled separately from failure: the share sheet returning
/// false usually means the user backed out, and showing them an error for
/// changing their mind is worse than showing nothing. [ExportStatus.dismissed]
/// covers a backed-out save the same way it covers a backed-out share — one
/// user gesture, one status.
enum ExportStatus { shared, saved, dismissed, failed }

class ExportOutcome {
  const ExportOutcome(this.status, {this.message, this.location});

  const ExportOutcome.shared() : this(ExportStatus.shared);
  const ExportOutcome.saved({String? location})
    : this(ExportStatus.saved, location: location);
  const ExportOutcome.dismissed() : this(ExportStatus.dismissed);
  const ExportOutcome.failed(String message)
    : this(ExportStatus.failed, message: message);

  final ExportStatus status;
  final String? message;

  /// Where the platform says the saved file landed. Set only for
  /// [ExportStatus.saved].
  ///
  /// This is a `content://` URI on Android and a sandbox path on iOS — useful
  /// for logging or a later "open" action, and not fit to show a user. A
  /// snackbar wanting a name should use [PdfExport.fileNameFor], which is what
  /// the picker was seeded with.
  final String? location;

  bool get isFailure => status == ExportStatus.failed;
}

/// The platform boundary behind [PdfExport.save].
///
/// Returns wherever the file landed, or null when the user dismissed the
/// picker without choosing a destination; throws when the write genuinely
/// failed. Injectable so the saved / dismissed / failed paths can be tested
/// without a real file dialog on a real device.
typedef PdfFileSaver =
    Future<String?> Function({
      required Uint8List bytes,
      required String fileName,
    });

/// Hands finished PDF bytes to the platform: the share sheet, the print
/// dialog, or a save-to-disk destination the user picks.
abstract final class PdfExport {
  /// Filename for a resume belonging to [info].
  ///
  /// Kept ASCII, lowercase, and hyphenated because this string becomes a real
  /// file on the user's device and travels through mail clients and cloud
  /// drives that mishandle spaces and punctuation. The same name seeds the
  /// save dialog, where the stakes are higher still: `/` and `:` are illegal in
  /// a filename on the destinations this app can write to, and a trailing dot
  /// is silently dropped or outright rejected. Slugifying to `[a-z0-9-]` makes
  /// all three unrepresentable rather than merely unlikely.
  static String fileNameFor(PersonalInfo info) {
    final base = info.fullName.trim().isNotEmpty
        ? info.fullName
        : (info.title.trim().isNotEmpty ? info.title : 'resume');

    final slug = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final safe = slug.isEmpty ? 'resume' : slug;
    // Some filesystems and share targets choke well before PATH_MAX; a very
    // long name is also unreadable in a file picker.
    final trimmed = safe.length > 60 ? safe.substring(0, 60) : safe;
    return trimmed.endsWith('-resume') || trimmed == 'resume'
        ? '$trimmed.pdf'
        : '$trimmed-resume.pdf';
  }

  /// Whether this platform can show a save-to-disk destination picker.
  ///
  /// The underlying plugin ships Android and iOS implementations only; anywhere
  /// else the method channel has no handler and the call fails at the moment
  /// the user commits. Gate the Save affordance on this rather than offering a
  /// button whose only possible answer is an apology — Share and Print still
  /// work everywhere.
  static bool get canSaveToDisk =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Opens the platform share sheet for [pdfBytes].
  ///
  /// Never throws: a failure here should surface as a message in the UI, not
  /// as an unhandled exception that loses the user's export attempt.
  static Future<ExportOutcome> share({
    required Uint8List pdfBytes,
    required PersonalInfo info,
  }) async {
    if (pdfBytes.isEmpty) {
      return const ExportOutcome.failed('Nothing to export yet.');
    }

    try {
      final shared = await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileNameFor(info),
      );
      return shared
          ? const ExportOutcome.shared()
          : const ExportOutcome.dismissed();
    } catch (error) {
      return ExportOutcome.failed(describeFailure(error));
    }
  }

  /// Writes [pdfBytes] to a destination the user picks.
  ///
  /// The destination comes from the platform's own save UI — the Storage
  /// Access Framework's create-document flow on Android, the document picker
  /// on iOS. Nothing is written anywhere until the user names a location, so
  /// this path needs no storage permission and cannot drop a file into a
  /// directory they did not ask for.
  ///
  /// Never throws. A null return from the picker is the user backing out, and
  /// comes back as [ExportStatus.dismissed] rather than an error, exactly as a
  /// dismissed share sheet does.
  static Future<ExportOutcome> save({
    required Uint8List pdfBytes,
    required PersonalInfo info,
    PdfFileSaver? saver,
  }) async {
    if (pdfBytes.isEmpty) {
      return const ExportOutcome.failed('Nothing to save yet.');
    }
    // Checked before the call, not after it fails: on a platform with no
    // implementation the channel error is a MissingPluginException whose text
    // means nothing to a user.
    if (saver == null && !canSaveToDisk) {
      return const ExportOutcome.failed(_unsupportedMessage);
    }

    try {
      final location = await (saver ?? _saveViaFileDialog)(
        bytes: pdfBytes,
        fileName: fileNameFor(info),
      );
      return location == null
          ? const ExportOutcome.dismissed()
          : ExportOutcome.saved(location: location);
    } catch (error) {
      // Handled here rather than in describeFailure: "use Share instead" is
      // advice only the save path can give, and it would be nonsense coming
      // back from a failed share.
      if (error is MissingPluginException) {
        return const ExportOutcome.failed(_unsupportedMessage);
      }
      return ExportOutcome.failed(
        describeFailure(error, fallback: 'Could not save the PDF.'),
      );
    }
  }

  /// Opens the system print / save-as-PDF dialog.
  static Future<ExportOutcome> printDocument({
    required Uint8List pdfBytes,
    required PersonalInfo info,
  }) async {
    if (pdfBytes.isEmpty) {
      return const ExportOutcome.failed('Nothing to print yet.');
    }

    try {
      final done = await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: fileNameFor(info),
      );
      return done
          ? const ExportOutcome.shared()
          : const ExportOutcome.dismissed();
    } catch (error) {
      return ExportOutcome.failed(describeFailure(error));
    }
  }

  /// Turns platform exceptions into something a user can act on.
  ///
  /// Every branch names the obstacle and the move that clears it; "an error
  /// occurred" leaves the user with a dead end and a PDF they still want.
  static String describeFailure(
    Object error, {
    String fallback = 'Could not export the PDF.',
  }) {
    final text = error.toString().toLowerCase();
    if (text.contains('already_active')) {
      return 'A file dialog is already open. Finish with it, then try again.';
    }
    // A SecurityException from the Storage Access Framework means the grant on
    // the chosen document is gone, not that the app is missing a permission it
    // could ask for — so it must not send the user hunting through Settings.
    if (text.contains('security_exception')) {
      return 'That location is no longer available to write to. '
          'Choose a different folder and try again.';
    }
    if (text.contains('save_file_failed') ||
        text.contains('file_copy_failed')) {
      return 'Could not write the PDF to that location. '
          'Choose a different folder and try again.';
    }
    if (text.contains('permission')) {
      return 'Storage permission is required to save the PDF. '
          'Grant it in Settings, then try again.';
    }
    if (text.contains('space') || text.contains('enospc')) {
      return 'Not enough storage space to save the PDF. '
          'Free up some space and try again.';
    }
    // Anything else is genuinely undiagnosable from here. Say so plainly and
    // let the caller offer a retry rather than inventing a cause.
    return fallback;
  }

  static const _unsupportedMessage =
      'Saving to a file is not supported on this device. '
      'Use Share instead.';

  static Future<String?> _saveViaFileDialog({
    required Uint8List bytes,
    required String fileName,
  }) => FlutterFileDialog.saveFile(
    params: SaveFileDialogParams(
      data: bytes,
      fileName: fileName,
      // Narrows the Android picker to PDF destinations, and tags the created
      // document so the file opens in a reader rather than as octet-stream.
      mimeTypesFilter: const ['application/pdf'],
    ),
  );
}
