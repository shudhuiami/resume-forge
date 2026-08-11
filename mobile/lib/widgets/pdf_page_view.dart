import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../render/pdf_raster.dart';
import 'resume_preview.dart';

/// Rasterizes PDF bytes and shows page one.
///
/// Rasterization is deliberately separate from the document build: resizing the
/// window or rotating the device should re-rasterize at the new width without
/// rebuilding the PDF, and the export path needs the bytes rather than pixels.
class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.pdfBytes,
    this.isRendering = false,
    this.buildError,
    this.onRetry,
  });

  final Uint8List? pdfBytes;
  final bool isRendering;
  final Object? buildError;
  final VoidCallback? onRetry;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  Uint8List? _png;
  Object? _error;
  bool _busy = false;

  /// Guards against a slow rasterization landing after a newer one.
  int _generation = 0;

  Uint8List? _rasterizedBytes;
  int _rasterizedWidth = 0;

  Future<void> _rasterize(Uint8List bytes, double logicalWidth) async {
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final widthKey = (logicalWidth * pixelRatio).round();

    // Skip when neither the document nor the target size changed — otherwise
    // every parent rebuild would kick off a redundant rasterization.
    if (identical(_rasterizedBytes, bytes) && _rasterizedWidth == widthKey) {
      return;
    }
    _rasterizedBytes = bytes;
    _rasterizedWidth = widthKey;

    final generation = ++_generation;
    setState(() => _busy = true);

    try {
      final png = await PdfRaster.firstPageToPng(
        bytes,
        logicalWidth: logicalWidth,
        pixelRatio: pixelRatio,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (png != null) _png = png;
        _error = png == null ? StateError('Document has no pages') : null;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bytes = widget.pdfBytes;
        if (bytes != null && constraints.maxWidth.isFinite) {
          // Scheduled rather than awaited: rasterizing during build would be a
          // setState-in-build error.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _rasterize(bytes, constraints.maxWidth);
          });
        }

        return ResumePreview(
          pngBytes: _png,
          isRendering: widget.isRendering || _busy,
          error: widget.buildError ?? _error,
          onRetry: widget.onRetry,
        );
      },
    );
  }
}
