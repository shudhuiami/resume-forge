import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/sample_resume.dart';
import '../render/pdf_raster.dart';
import '../render/pdf_renderer.dart';
import '../templates/registry.dart';
import '../templates/template.dart';
import '../theme/tokens.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Widen to more columns on tablets rather than stretching two
            // enormous cards across the screen.
            final columns = constraints.maxWidth ~/ 200 == 0
                ? 1
                : (constraints.maxWidth ~/ 200).clamp(2, 4);

            return GridView.builder(
              padding: EdgeInsets.all(tokens.spaceLg),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: tokens.spaceLg,
                mainAxisSpacing: tokens.spaceLg,
                // Page aspect plus room for the caption beneath it.
                childAspectRatio: 0.56,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                if (selected)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            Text(
              template.bestFor,
              maxLines: 1,
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

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.black26,
          ),
        ),
      );
    }
    if (_png == null) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return Image.memory(
      _png!,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
    );
  }
}
