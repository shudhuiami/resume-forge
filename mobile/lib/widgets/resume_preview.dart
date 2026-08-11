import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Displays the rasterized resume page.
///
/// Deliberately keeps the previous frame on screen while a newer render is in
/// flight. Clearing to a spinner on every keystroke would make the preview
/// strobe while typing, which reads as broken even though it is technically
/// "correct" progress feedback.
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

  static const _aspect = 1 / 1.4142; // A4 portrait

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Center(
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Container(
          decoration: BoxDecoration(
            // The page itself is white regardless of app theme — it is a
            // document, not app chrome.
            color: Colors.white,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pngBytes != null)
                Image.memory(
                  pngBytes!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, _, _) => _Message(
                    icon: Icons.broken_image_outlined,
                    text: 'Could not display this page',
                  ),
                )
              else if (error == null)
                const _FirstRenderPlaceholder(),
              if (error != null && pngBytes == null)
                _Message(
                  icon: Icons.error_outline,
                  text: 'Preview failed to render',
                  action: onRetry == null
                      ? null
                      : TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                ),
              if (isRendering)
                Positioned(
                  top: tokens.spaceSm,
                  right: tokens.spaceSm,
                  child: _BusyDot(color: scheme.primary),
                ),
              if (error != null && pngBytes != null)
                Positioned(
                  left: tokens.spaceSm,
                  right: tokens.spaceSm,
                  bottom: tokens.spaceSm,
                  child: _StaleBanner(onRetry: onRetry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown only before the very first successful render.
class _FirstRenderPlaceholder extends StatelessWidget {
  const _FirstRenderPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black45, size: 32),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (action != null) ...[const SizedBox(height: 4), action!],
          ],
        ),
      ),
    );
  }
}

/// Small, non-blocking activity marker. Deliberately not a full-page overlay.
class _BusyDot extends StatelessWidget {
  const _BusyDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Updating preview',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      ),
    );
  }
}

/// Tells the user the page they are looking at is behind their edits, without
/// hiding it.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3B1D1D),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Color(0xFFFFD9D6),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Showing the last good preview',
                style: TextStyle(color: Color(0xFFFFD9D6), fontSize: 12),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
