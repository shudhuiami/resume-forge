import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/sample_resume.dart';
import '../render/pdf_raster.dart';
import '../render/pdf_renderer.dart';
import '../templates/registry.dart';
import '../templates/template.dart';
import '../theme/tokens.dart';

/// Aspect ratio of the page every thumbnail rasterizes: A4, the only shape a
/// resume is ever printed at. The thumbnail box is held to exactly this so the
/// grid cannot crop the design it is advertising.
const _pageAspect = 794 / 1123;

/// Card width the grid aims for before it adds another column, and the width
/// below which a card stops reading as a page at all.
const _targetTileWidth = 190.0;
const _minTileWidth = 140.0;

/// Line boxes reserved for the caption under each thumbnail, at text scale 1:
/// one line of `labelLarge` for the name and two of `bodySmall` for the
/// "best for" line. Scaled by the ambient text scaler so an accessibility
/// text size grows the cell instead of squeezing the page out of it.
const _nameLineHeight = 20.0;
const _bestForLineHeight = 16.0;

/// Template picker.
///
/// Thumbnails are rasterizations of each template rendered against the sample
/// resume — the real design, never a hand-drawn mock-up. A gallery that lies
/// about what you are choosing is worse than no gallery.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.title = 'Choose a design',
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Column maths runs on the width the cards actually get: the grid
            // padding and the gutters between cards are not theirs to use, and
            // counting them made every card narrower than intended.
            final usable = math.max(
              1.0,
              constraints.maxWidth - tokens.spaceLg * 2,
            );
            final fits =
                ((usable + tokens.spaceLg) /
                        (_targetTileWidth + tokens.spaceLg))
                    .floor();
            // Widen to more columns on tablets rather than stretching two
            // enormous cards across the screen; drop to one only when two
            // would be too narrow to read as pages.
            final columns = usable < _minTileWidth * 2 + tokens.spaceLg
                ? 1
                : fits.clamp(2, 4);
            final tileWidth = math.max(
              1.0,
              (usable - tokens.spaceLg * (columns - 1)) / columns,
            );
            final captionHeight =
                tokens.spaceSm +
                textScaler.scale(_nameLineHeight) +
                textScaler.scale(_bestForLineHeight) * 2;

            return GridView.builder(
              padding: EdgeInsets.all(tokens.spaceLg),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: tokens.spaceLg,
                mainAxisSpacing: tokens.spaceLg,
                // A full-width A4 page plus the caption beneath it, rather than
                // a fixed ratio that made the page box a different shape at
                // every viewport and cropped the design to fit.
                mainAxisExtent: tileWidth / _pageAspect + captionHeight,
              ),
              itemCount: resumeTemplates.length,
              itemBuilder: (context, index) {
                final template = resumeTemplates[index];
                return _TemplateCard(
                  template: template,
                  selected: template.id == selectedId,
                  onTap: () => onSelected(template.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final ResumeTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      label: '${template.name}. ${template.bestFor}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        // The caption repeats what the label above already says. Excluded here
        // rather than on the Semantics above, which would take the InkWell's
        // tap action with it and leave a button a screen reader cannot press.
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AspectRatio inside the flexible slot, so the framed page keeps
              // its A4 shape whatever height the cell ends up with — any slack
              // falls outside the border instead of stretching or cropping the
              // design.
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AspectRatio(
                    aspectRatio: _pageAspect,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _Thumbnail(template: template),
                    ),
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (selected) ...[
                    SizedBox(width: tokens.spaceXs),
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              // Two lines: at 360px the category list is wider than one line and
              // truncating it hid the only description a card carries.
              Text(
                template.bestFor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rasterized preview of one template, cached across rebuilds.
class _Thumbnail extends StatefulWidget {
  const _Thumbnail({required this.template});

  final ResumeTemplate template;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  /// Process-wide cache so scrolling the grid does not re-render a design that
  /// has already been drawn once.
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _png;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = _cache[widget.template.id];
    if (cached != null) {
      setState(() => _png = cached);
      return;
    }
    try {
      final pdf = await PdfRenderer.build(
        template: widget.template,
        data: sampleResume,
      );
      // Low DPI on purpose: a grid cell is a couple of hundred pixels wide.
      final png = await PdfRaster.firstPageToPng(
        pdf,
        logicalWidth: 200,
        pixelRatio: 2,
      );
      if (!mounted) return;
      if (png == null) {
        setState(() => _failed = true);
        return;
      }
      _cache[widget.template.id] = png;
      setState(() => _png = png);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Placeholder and failure states sit on app chrome, not on paper white: a
  /// white rectangle on the dark grid reads as a page that has finished
  /// loading and come out blank.
  Widget _failure(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceSm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: tokens.spaceXs),
            Text(
              'Preview unavailable',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_failed) return _failure(context);

    if (_png == null) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }
    // contain, not cover: the box is already A4, and a raster that is a pixel
    // off must letterbox rather than shave the edge off the design. A raster
    // that decodes to nothing falls back to the labelled failure state rather
    // than to an empty rectangle.
    return Image.memory(
      _png!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => _failure(context),
    );
  }
}
