import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../models/resume.dart';

/// What happened when the user tried to export.
///
/// Cancellation is modelled separately from failure: the share sheet returning
/// false usually means the user backed out, and showing them an error for
/// changing their mind is worse than showing nothing.
enum ExportStatus { shared, dismissed, failed }

class ExportOutcome {
  const ExportOutcome(this.status, {this.message});

  const ExportOutcome.shared() : this(ExportStatus.shared);
  const ExportOutcome.dismissed() : this(ExportStatus.dismissed);
  const ExportOutcome.failed(String message)
    : this(ExportStatus.failed, message: message);

  final ExportStatus status;
  final String? message;

  bool get isFailure => status == ExportStatus.failed;
}

/// Hands finished PDF bytes to the platform share/save sheet.
abstract final class PdfExport {
  /// Filename for a resume belonging to [info].
  ///
  /// Kept ASCII, lowercase, and hyphenated because this string becomes a real
  /// file on the user's device and travels through mail clients and cloud
  /// drives that mishandle spaces and punctuation.
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
      return ExportOutcome.failed(_describe(error));
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
      return ExportOutcome.failed(_describe(error));
    }
  }

  /// Turns platform exceptions into something a user can act on.
  static String _describe(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission')) {
      return 'Storage permission is required to save the PDF. '
          'Grant it in Settings and try again.';
    }
    if (text.contains('space') || text.contains('enospc')) {
      return 'Not enough storage space to save the PDF.';
    }
    return 'Could not export the PDF. Please try again.';
  }
}
