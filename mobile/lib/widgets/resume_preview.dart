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
/// legible on white without inventing a second palette. On a dark palette that
/// means the overlays reach for the theme's *deepest* surface. Not
/// `inverseSurface`: in a dark scheme that slot is a light surface, so carrying
/// the old inverted treatment across would have painted a pale chip on pale
/// paper, which is not an overlay but a disappearance.
///
/// Re-measured for matte black rather than assumed to carry over, because this
/// is the widest colour jump in the app and it got wider: base to paper is
/// 19.4:1 here against the indigo palette's 13.4:1. The overlays gained from it
/// — the busy pill now sits at 20.01:1 on the page and the stale banner at
/// 15.43:1 — and the page's own edge is what needed the attention. See the mat
/// ring below.
///
/// The page is a **square-cornered rectangle**, and deliberately the only
/// surface in the app that is. Everything else here is app chrome and takes
/// `radiusSm`; this is a sheet of A4, and paper does not have rounded corners.
/// Rounding it was not only wrong as a picture of the printout — the clip
/// *removed* what the templates draw there. Measured off the rendered pages:
/// nine of the thirteen designs ink at least one page corner with a banner,
/// sidebar or full-bleed surface, and three of those — Terminal, Prism, Ember —
/// fill all four, so the arc was cutting a wedge out of the design at the one
/// place in the app whose whole promise is that what you see is what prints.
/// On Terminal, whose page is near-black, that wedge was the app's own
/// background showing through the paper.
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final hasFrame = pngBytes != null;

    return Center(
      child: AspectRatio(
        aspectRatio: pageAspect,
        child: Container(
          decoration: BoxDecoration(
            // The page itself is white regardless of app theme — it is a
            // document, not app chrome. The one hard-coded colour outside
            // `theme/`, and the only one there is a reason for.
            color: Colors.white,
            // No `borderRadius`. See the note on the class: the page is a
            // sheet of paper, and the arc was cutting the corners off the
            // document it exists to show.
            //
            // A mat, not a shadow, and it is what carries the separation now
            // that the corners are square — the radius never did. On the light
            // palette the page needed a lift to read as a sheet at all; on a
            // dark one it is the brightest object on the screen and needs no
            // help separating — a shadow under it would do nothing. What it
            // needs is the opposite: an edge, so 19.4:1 of white does not cut
            // straight into a near-black base. The mid-tone ring is that step
            // down — 3.40:1 from the paper it contains and 5.68:1 from the
            // surface behind it, so it reads from both sides — and it is the
            // same ring the gallery frames its thumbnails with, so a document
            // is matted the same way everywhere in the app.
            border: Border.all(color: theme.colorScheme.outline),
          ),
          // Rectangular now, so there is no curve to antialias — but still a
          // clip. It is the guarantee that app chrome cannot paint off the
          // paper and onto the matte base: at large text scales the stale
          // banner grows upward from the bottom edge, and a warning strip
          // hanging off the sheet reads as a broken layout.
          clipBehavior: Clip.hardEdge,
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
                  // Both overlays sit `spaceMd` in from the paper's edge.
                  //
                  // That number used to be doing two jobs. It was picked to
                  // clear the page's 12dp corner arc — at `spaceSm` the pill's
                  // outer corner fell inside the curve and `Clip.antiAlias`
                  // shaved it flat, a rounded pill with one square corner
                  // (UI-033) — and `spaceMd` only happened to equal
                  // `radiusSm`. With the corners square there is no arc to
                  // clear and nothing couples the two, so this is now what it
                  // looks like: a margin, off the standard spacing scale,
                  // chosen so chrome floating on a document does not crowd the
                  // mat ring. It is free to move without anything being
                  // clipped.
                  if (isRendering)
                    Positioned(
                      top: tokens.spaceMd,
                      left: tokens.spaceMd,
                      right: tokens.spaceMd,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _BusyPill(compact: compact),
                      ),
                    ),
                  if (error != null && hasFrame)
                    Positioned(
                      left: tokens.spaceMd,
                      right: tokens.spaceMd,
                      bottom: tokens.spaceMd,
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
/// Everything here is app chrome sitting on a document. The card takes the
/// theme's deepest surface rather than a panel tint, so at 19:1 against the
/// paper it cannot be mistaken for something the resume itself prints.
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
            color: theme.colorScheme.surfaceContainerLowest,
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
/// It has to be *noticed* on white paper at pill size, which a pale tint at
/// this scale is not, so it takes the theme's deepest surface: 19:1 against the
/// page. It used to take `inverseSurface` and cannot any more — inverted
/// semantics flip with the palette, and on a dark scheme that slot is the light
/// snackbar surface, which on white paper would be nearly invisible. The pill
/// is not "inverted chrome", it is "chrome on a document", and those were only
/// ever the same colour by coincidence.
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
          color: theme.colorScheme.surfaceContainerLowest,
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
                        color: theme.colorScheme.onSurface,
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
