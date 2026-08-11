import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/render/pdf_raster.dart';

void main() {
  group('raster sizing', () {
    test('picks a DPI that fills the requested widget width', () {
      // A4 is 8.27in wide; 390 logical px at 2x is 780px => ~94 dpi.
      final dpi = PdfRaster.dpiForWidth(390, 2);
      expect(dpi, closeTo(780 / (595.276 / 72), 0.5));
    });

    test(
      'clamps absurdly large targets so a tablet cannot allocate a huge bitmap',
      () {
        final dpi = PdfRaster.dpiForWidth(4000, 3);
        final widthPx = dpi * (595.276 / 72);
        expect(widthPx, closeTo(PdfRaster.maxPixelWidth, 1));
      },
    );

    test('clamps tiny targets so a thumbnail is still legible', () {
      final dpi = PdfRaster.dpiForWidth(10, 1);
      final widthPx = dpi * (595.276 / 72);
      expect(widthPx, closeTo(PdfRaster.minPixelWidth, 1));
    });
  });
}
