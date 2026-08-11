import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../templates/template.dart';

/// Rasterizes PDF bytes to a displayable PNG.
///
/// This is the step that makes the preview *be* the PDF rather than a
/// reimplementation of it. It cannot run in a background isolate — rasterizing
/// goes through PDFium on device and pdf.js on web, both platform-bound — so
/// the expensive document build is what gets moved off the main thread
/// instead, and this stays cheap by rendering a single page.
abstract final class PdfRaster {
  /// PDF user space is 72 units per inch.
  static const _pointsPerInch = 72.0;

  /// Upper bound on raster width. A phone preview never needs more, and
  /// unbounded DPI on a large tablet window is an easy way to allocate a
  /// hundred-megabyte bitmap.
  static const maxPixelWidth = 2400.0;
  static const minPixelWidth = 200.0;

  /// Width / height of the page these rasters come out of.
  ///
  /// Single source of truth for the preview frame's shape: derived from the
  /// real page format rather than from a rounded 1/1.4142, so the widget that
  /// holds the image and the image itself cannot disagree.
  static final pageAspect = a4.width / a4.height;

  /// DPI needed to rasterize an A4 page to [logicalWidth] * [pixelRatio]
  /// pixels wide.
  static double dpiForWidth(double logicalWidth, double pixelRatio) {
    final targetPx = (logicalWidth * pixelRatio).clamp(
      minPixelWidth,
      maxPixelWidth,
    );
    final pageInches = a4.width / _pointsPerInch;
    return targetPx / pageInches;
  }

  /// Renders page one of [pdfBytes] sized for a widget [logicalWidth] wide.
  ///
  /// Returns null when the document has no pages — the honest signal for
  /// "nothing to show" rather than a fabricated blank image.
  static Future<Uint8List?> firstPageToPng(
    Uint8List pdfBytes, {
    required double logicalWidth,
    double pixelRatio = 2,
  }) async {
    final dpi = dpiForWidth(logicalWidth, pixelRatio);
    await for (final page in Printing.raster(
      pdfBytes,
      pages: const [0],
      dpi: dpi,
    )) {
      return page.toPng();
    }
    return null;
  }
}
