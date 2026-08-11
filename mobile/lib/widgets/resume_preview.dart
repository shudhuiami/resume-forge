import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../render/pdf_raster.dart';
import '../theme/tokens.dart';

/// Displays the rasterized resume page.
///
/// Deliberately keeps the previous frame on screen while a newer render is in
/// flight. Clearing to a spinner on every keystroke would make the preview
/// strobe while typing, which reads as broken even though it is technically
/// "correct" progress feedback.
///
/// The page is white because it is a document, not app chrome. Everything
/// drawn *on top* of it — progress, errors, the stale warning — is app chrome
/// and therefore takes its colours from the theme, which keeps those overlays
/// legible on white without inventing a second palette.
class ResumePreview extends StatelessWidget {
  const ResumePreview({
    super.key,
    required this.pngBytes,
    this.isRendering = false,
    this.error,
    this.onRetry,
  });

  /// Most recent successfully rendered page, or null before the first render.
  final Uint8List? pngBytes;

  /// True while a newer render is running.
  final bool isRendering;

  /// Set when the last render failed. The previous frame, if any, stays
  /// visible underneath so the user does not lose their place.
  final Object? error;

  final VoidCallback? onRetry;

  /// A4 portrait, taken from the page format the PDF is actually built at.
  static final pageAspect = PdfRaster.pageAspect;

  /// Below this page width the overlays go icon-only. Measured against the
  /// widest label plus a touch target — a landscape phone lands well under it,
  /// the smallest supported portrait phone comfortably over.
  static const compactPageWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final hasFrame = pngBytes != null;

    return Center(
      child: AspectRatio(
        aspectRatio: pageAspect,
        child: Container(
          decoration: BoxDecoration(
            // The page itself is white regardless of app theme — it is a
            // document, not app chrome.
            color: Colors.white,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.4),
                blurRadius: tokens.spaceXl,
                offset: Offset(0, tokens.spaceSm),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, page) {
              // In landscape the whole A4 page is only ~160dp wide. Full-text
              // chrome on a page that size wraps a warning strip into six
              // lines and swallows the document, so both overlays drop their
              // labels below this width and keep them as tooltips.
              final compact = page.maxWidth < compactPageWidth;

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (hasFrame)
                    Image.memory(
                      pngBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: 'Resume preview, page 1',
                      errorBuilder: (context, _, _) => const _PageOverlay(
                        icon: Icons.broken_image_outlined,
                        text: 'Could not display this page',
                      ),
                    )
                  else if (error == null)
                    const _PageOverlay(
                      text: 'Building your preview…',
                      busy: true,
                    ),
                  if (error != null && !hasFrame)
                    _PageOverlay(
                      icon: Icons.error_outline,
                      text: 'Preview failed to render',
                      onRetry: onRetry,
                    ),
                  if (isRendering)
                    Positioned(
                      top: tokens.spaceSm,
                      left: tokens.spaceSm,
                      right: tokens.spaceSm,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _BusyPill(compact: compact),
                      ),
                    ),
                  if (error != null && hasFrame)
                    Positioned(
                      left: tokens.spaceSm,
                      right: tokens.spaceSm,
                      bottom: tokens.spaceSm,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: _StaleBanner(onRetry: onRetry, compact: compact),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A themed card floated on the white page.
///
/// Everything here is app chrome sitting on a document, so it uses the app's
/// dark surfaces: ink-on-paper greys would either fail contrast or force a
/// second, light palette into a dark design system.
class _PageOverlay extends StatelessWidget {
  const _PageOverlay({
    required this.text,
    this.icon,
    this.busy = false,
    this.onRetry,
  });

  final IconData? icon;
  final String text;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Center(
      // The page can be very short in landscape; scrolling rather than
      // overflowing keeps the message readable instead of clipped.
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceLg,
                vertical: tokens.spaceMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: tokens.spaceXl,
                      height: tokens.spaceXl,
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else if (icon != null)
                    Icon(
                      icon,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: tokens.spaceXl,
                    ),
                  SizedBox(height: tokens.spaceSm),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (onRetry != null) ...[
                    SizedBox(height: tokens.spaceXs),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small, non-blocking activity marker. Deliberately not a full-page overlay.
///
/// It has to sit on white paper, so it carries its own dark surface — a
/// white-on-white chip was invisible in practice.
class _BusyPill extends StatelessWidget {
  const _BusyPill({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Semantics(
      container: true,
      liveRegion: true,
      label: compact ? 'Updating preview' : null,
      child: Tooltip(
        message: 'Updating preview',
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spaceSm,
              vertical: tokens.spaceXs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: tokens.spaceMd,
                  height: tokens.spaceMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (!compact) ...[
                  SizedBox(width: tokens.spaceSm),
                  Flexible(
                    child: Text(
                      'Updating',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the user the page they are looking at is behind their edits, without
/// hiding it.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.compact, this.onRetry});

  final bool compact;
  final VoidCallback? onRetry;

  static const message = 'Showing the last good preview';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ink = theme.colorScheme.onErrorContainer;

    return Semantics(
      container: true,
      label: compact ? message : null,
      child: Material(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? tokens.spaceXs : tokens.spaceMd,
            vertical: tokens.spaceXs,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Tooltip(
                message: message,
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: tokens.spaceLg,
                  color: ink,
                ),
              ),
              if (!compact) ...[
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: ink),
                  ),
                ),
              ],
              if (onRetry != null)
                if (compact)
                  IconButton(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    iconSize: tokens.spaceLg,
                    color: ink,
                    tooltip: 'Retry',
                    visualDensity: VisualDensity.compact,
                  )
                else
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      minimumSize: Size(0, tokens.minTouchTarget),
                      padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
                    ),
                    child: const Text('Retry'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
