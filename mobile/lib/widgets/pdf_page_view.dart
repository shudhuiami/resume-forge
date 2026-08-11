import 'dart:math' as math;
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

  /// Retries the *document build*. Raster failures are retried internally —
  /// this widget owns that step, so it does not need to ask its parent.
  final VoidCallback? onRetry;

  /// Target widths are snapped up to a multiple of this many device pixels.
  ///
  /// A drag-resize on desktop web reports a new width every frame; without
  /// quantizing, each one would key a fresh rasterization. Snapping *up* means
  /// the raster is never smaller than the page it fills, so this trades a few
  /// wasted pixels for not re-rendering sixty times a second.
  static const widthQuantum = 64;

  /// Device-pixel width to rasterize at, given the box the page is laid out in.
  ///
  /// [ResumePreview] letterboxes the page to A4 inside these constraints, so on
  /// a short, wide viewport — landscape, or a tablet split view — the page is
  /// far narrower than the box. Keying off `maxWidth` alone rasterized a
  /// landscape phone page at roughly five times the pixels it displays at.
  ///
  /// Returns null when the box gives nothing to size against, which is the
  /// signal to skip the render rather than guess.
  static int? rasterWidthFor(BoxConstraints constraints, double pixelRatio) {
    final byHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight * ResumePreview.pageAspect
        : double.infinity;
    final logical = math.min(constraints.maxWidth, byHeight);
    if (!logical.isFinite || logical <= 0) return null;

    final snapped =
        ((logical * pixelRatio) / widthQuantum).ceil() * widthQuantum;
    // Past the rasterizer's own ceiling every larger key renders the same
    // bitmap, so stop making new ones.
    return math.min(snapped, PdfRaster.maxPixelWidth.round());
  }

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView>
    with AutomaticKeepAliveClientMixin {
  // The preview lives in a TabBarView, whose PageView disposes off-screen
  // children by default. Without this, every trip to the Edit tab and back
  // threw away the rasterized page and the user came back to a blank sheet —
  // the exact strobe the "keep the last good frame" rule exists to prevent.
  @override
  bool get wantKeepAlive => true;

  Uint8List? _png;
  Object? _error;
  bool _busy = false;

  /// Guards against a slow rasterization landing after a newer one.
  int _generation = 0;

  Uint8List? _rasterizedBytes;
  int _rasterizedWidth = 0;

  Future<void> _rasterize(
    Uint8List bytes,
    int widthPx,
    double pixelRatio,
  ) async {
    // Skip when neither the document nor the target size changed — otherwise
    // every parent rebuild would kick off a redundant rasterization.
    if (identical(_rasterizedBytes, bytes) && _rasterizedWidth == widthPx) {
      return;
    }
    _rasterizedBytes = bytes;
    _rasterizedWidth = widthPx;

    final generation = ++_generation;
    setState(() => _busy = true);

    try {
      final png = await PdfRaster.firstPageToPng(
        bytes,
        logicalWidth: widthPx / pixelRatio,
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
      // Forget the attempt, so a retry — or any later rebuild — is allowed to
      // try again instead of being skipped as "already rasterized".
      _rasterizedBytes = null;
      _rasterizedWidth = 0;
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  void _retryRaster() {
    setState(() {
      _error = null;
      _rasterizedBytes = null;
      _rasterizedWidth = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bytes = widget.pdfBytes;
        final widthPx = PdfPageView.rasterWidthFor(constraints, pixelRatio);
        if (bytes != null && widthPx != null) {
          // Scheduled rather than awaited: rasterizing during build would be a
          // setState-in-build error.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _rasterize(bytes, widthPx, pixelRatio);
          });
        }

        final buildError = widget.buildError;
        return ResumePreview(
          pngBytes: _png,
          isRendering: widget.isRendering || _busy,
          error: buildError ?? _error,
          onRetry: buildError != null
              ? widget.onRetry
              : (_error != null ? _retryRaster : null),
        );
      },
    );
  }
}
