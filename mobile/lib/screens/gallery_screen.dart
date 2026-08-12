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

/// Line boxes reserved for the caption inside each card, at text scale 1: one
/// line of `titleSmall` for the name, one of `bodySmall` for the structure cue
/// (or the "Selected" pill, which is taller than a bare line), and two of
/// `bodySmall` for the roles line. Scaled by the ambient text scaler so an
/// accessibility text size grows the cell instead of squeezing the page out of
/// it.
const _nameLineHeight = 20.0;
const _cueLineHeight = 18.0;
const _bestForLineHeight = 16.0;

/// One-line structural cue per design, in registry order.
///
/// These describe what the eye can actually check against the thumbnail —
/// column count, whether the design has a place for a photo, the typographic
/// or structural signature — and each one was read off the template's own
/// `build` rather than invented as a marketing line. A gallery that mislabels
/// a design is worse than one that labels nothing, so `gallery_layout_test`
/// asserts this map covers the registry exactly: a new template cannot ship
/// without a cue, and a deleted one cannot leave a stale entry behind.
///
/// It lives here, not in `templates/`, because it is presentation copy for the
/// picker. The templates own their `description` and `bestFor`; this is the
/// shorter thing that fits under a 130px-wide thumbnail.
@visibleForTesting
const templateCues = <String, String>{
  'aurora': 'Two column · Photo · Skill meters',
  'meridian': 'Two column · Photo · Slate sidebar',
  'beacon': 'One column · Photo · Date gutter',
  'ledger': 'One column · Ruled rows · No photo',
  'compass': 'Two column · Photo · Skill chips',
  'circuit': 'Two column · Photo · Monospace data',
  'terminal': 'One column · Dark page · Monospace',
  'quill': 'One column · Serif · No photo',
  'linen': 'One column · Minimal · No photo',
  'coral': 'Two column · Photo · Centred name',
  'orchid': 'One column · Serif · Side rail',
  'prism': 'Two column · Photo · Card blocks',
  'ember': 'Two column · Photo · Dark page',
};

/// Display name for a category chip and its section copy.
@visibleForTesting
String categoryLabel(TemplateCategory category) => switch (category) {
  TemplateCategory.corporate => 'Corporate',
  TemplateCategory.creative => 'Creative',
  TemplateCategory.tech => 'Tech',
  TemplateCategory.academic => 'Academic',
  TemplateCategory.minimal => 'Minimal',
};

/// The solid card tint a design's category is drawn in.
///
/// The mapping is fixed, so a design is the same colour every time it is seen
/// and in every place it is seen: this is what paints the card in the gallery
/// *and* the card of a saved resume in the list, from the same function. Learn
/// that Tech is teal once and the list rewards you for it.
///
/// Five of the eight tints, one per category — not eight — because thirteen
/// cards in a two-column grid wearing eight colours is confetti rather than
/// structure. They are chosen so that no two are close in hue, and so the pair
/// that *are* nearly identical in the token set (clay and rust, 1.01:1 apart in
/// brightness) can never appear on the same screen: rust belongs to the editor
/// form, clay to the gallery.
///
/// Lives here rather than in `theme/` on purpose. The theme is app chrome and
/// knows nothing about resume templates; this is presentation copy for the
/// picker, exactly like [categoryLabel] beside it. Public rather than
/// `@visibleForTesting` because the resume list paints its rows from it too —
/// that shared call *is* the guarantee that the two screens cannot drift.
Color categoryTint(TemplateCategory category, AppTokens tokens) =>
    switch (category) {
      TemplateCategory.corporate => tokens.tintSlate,
      TemplateCategory.creative => tokens.tintClay,
      TemplateCategory.tech => tokens.tintTeal,
      TemplateCategory.academic => tokens.tintPlum,
      TemplateCategory.minimal => tokens.tintOlive,
    };

/// Finder handle for one design card.
@visibleForTesting
Key templateCardKey(String id) => ValueKey('template-card-$id');

/// Finder handle for a filter chip. `null` is the "All" chip.
@visibleForTesting
Key categoryChipKey(TemplateCategory? category) =>
    ValueKey('category-chip-${category?.name ?? 'all'}');

/// Template picker.
///
/// Thumbnails are rasterizations of each template rendered against the sample
/// resume — the real design, never a hand-drawn mock-up. A gallery that lies
/// about what you are choosing is worse than no gallery.
///
/// Thirteen A4 pages side by side are thirteen near-identical white rectangles,
/// so the screen leans on everything *around* the page to tell them apart: a
/// category filter derived from the registry's own `TemplateCategory`, a name
/// and a structural cue under each page, and a card that visibly contains the
/// page rather than a bare thumbnail floating on the background.
class GalleryScreen extends StatefulWidget {
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
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  /// Active category, or null for "All". Purely view state: filtering never
  /// touches the selection, so the design the user arrived on stays chosen
  /// whether or not it is currently on screen.
  TemplateCategory? _filter;

  /// Categories the catalog actually contains, in the enum's declared order.
  /// Derived rather than hard-coded so a chip can never point at an empty
  /// result — the filter has no empty state because it cannot produce one.
  static final List<TemplateCategory> _categories = TemplateCategory.values
      .where((c) => resumeTemplates.any((t) => t.category == c))
      .toList(growable: false);

  List<ResumeTemplate> get _visible => _filter == null
      ? resumeTemplates
      : resumeTemplates.where((t) => t.category == _filter).toList();

  /// The design the document is currently on, if the caller named one that the
  /// catalog actually holds.
  ResumeTemplate? get _selected {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final template in resumeTemplates) {
      if (template.id == id) return template;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textScaler = MediaQuery.textScalerOf(context);
    final visible = _visible;
    // Filtering to a category the chosen design is not in used to scroll it
    // off the screen with nothing left saying what was chosen — the header
    // counted "2 of 13 designs" but never mentioned that yours was among the
    // eleven it had hidden. Auto-switching the filter to the selection's own
    // category on open would fix that by hiding the rest of the catalog, on a
    // screen whose whole job is browsing it. This says so instead, and offers
    // the jump rather than making it.
    final selected = _selected;
    final hiddenSelection = selected != null && !visible.contains(selected)
        ? selected
        : null;

    return Scaffold(
      // Deliberately untitled: the screen title is the large heading in the
      // body below, and repeating it in the bar would say the same thing twice
      // in two sizes. The bar is here for the back affordance.
      appBar: AppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _GridMetrics.forWidth(
              constraints.maxWidth,
              tokens,
              textScaler,
            );

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _GalleryHeader(
                    title: widget.title,
                    shown: visible.length,
                    total: resumeTemplates.length,
                    // A landscape phone has about 300px of body height. A
                    // display-sized heading there pushes the first row of
                    // designs off the screen entirely, so the heading steps
                    // down a size rather than the grid losing its place.
                    compact: constraints.maxHeight < 500,
                  ),
                ),
                // Full-bleed so the row can scroll past the screen edge; its
                // own padding keeps the first chip on the grid's left margin.
                SliverToBoxAdapter(
                  child: _CategoryFilterBar(
                    categories: _categories,
                    selected: _filter,
                    onChanged: (c) => setState(() => _filter = c),
                  ),
                ),
                if (hiddenSelection != null)
                  SliverToBoxAdapter(
                    child: _HiddenSelectionNote(
                      template: hiddenSelection,
                      onShow: () =>
                          setState(() => _filter = hiddenSelection.category),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spaceLg,
                    tokens.spaceMd,
                    tokens.spaceLg,
                    tokens.spaceXl,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: metrics.columns,
                      crossAxisSpacing: tokens.spaceLg,
                      mainAxisSpacing: tokens.spaceLg,
                      // A full-width A4 page plus the caption beneath it,
                      // rather than a fixed ratio that made the page box a
                      // different shape at every viewport and cropped the
                      // design to fit.
                      mainAxisExtent: metrics.mainAxisExtent,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final template = visible[index];
                      return _TemplateCard(
                        key: templateCardKey(template.id),
                        template: template,
                        selected: template.id == widget.selectedId,
                        onTap: () => widget.onSelected(template.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Column count and cell height for one viewport width.
class _GridMetrics {
  const _GridMetrics({required this.columns, required this.mainAxisExtent});

  final int columns;
  final double mainAxisExtent;

  factory _GridMetrics.forWidth(
    double maxWidth,
    AppTokens tokens,
    TextScaler textScaler,
  ) {
    // Column maths runs on the width the cards actually get: the grid padding
    // and the gutters between cards are not theirs to use, and counting them
    // made every card narrower than intended.
    final usable = math.max(1.0, maxWidth - tokens.spaceLg * 2);
    // A card at a large accessibility text size needs to be *wider*, not to
    // shred its labels: at 2x a 156px column showed "Aurora …" and a cue that
    // was pure ellipsis. Both widths grow with the scaler at half strength and
    // capped, which collapses a phone to a single readable column somewhere
    // above 1.4x while leaving the default layout — and every column count the
    // layout tests pin — untouched at 1x.
    final widthFactor = (1 + (textScaler.scale(1) - 1) * 0.5).clamp(1.0, 1.4);
    final target = _targetTileWidth * widthFactor;
    final minimum = _minTileWidth * widthFactor;
    final fits = ((usable + tokens.spaceLg) / (target + tokens.spaceLg))
        .floor();
    // Widen to more columns on tablets rather than stretching two enormous
    // cards across the screen; drop to one only when two would be too narrow
    // to read as pages.
    final columns = usable < minimum * 2 + tokens.spaceLg
        ? 1
        : fits.clamp(2, 4);
    final tileWidth = math.max(
      1.0,
      (usable - tokens.spaceLg * (columns - 1)) / columns,
    );
    // The card pads the page on every side, so the page is narrower than the
    // cell by twice the padding.
    final pageWidth = math.max(1.0, tileWidth - tokens.spaceMd * 2);
    final caption =
        tokens.spaceMd +
        textScaler.scale(_nameLineHeight) +
        tokens.spaceXs +
        textScaler.scale(_cueLineHeight) * 2 +
        tokens.spaceXs +
        textScaler.scale(_bestForLineHeight) * 2;

    return _GridMetrics(
      columns: columns,
      mainAxisExtent: tokens.spaceMd * 2 + pageWidth / _pageAspect + caption,
    );
  }
}

/// Large heading, and the one promise this screen has to make.
class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({
    required this.title,
    required this.shown,
    required this.total,
    required this.compact,
  });

  final String title;
  final int shown;
  final int total;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final count = shown == total
        ? '$total designs.'
        : '$shown of $total designs.';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        compact ? 0 : tokens.spaceSm,
        tokens.spaceLg,
        compact ? tokens.spaceMd : tokens.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                (compact
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      // Large and tight, matching the app bar's own title
                      // treatment.
                      letterSpacing: -0.5,
                    ),
          ),
          SizedBox(height: compact ? tokens.spaceXs : tokens.spaceSm),
          // Announced on change: this line is the only confirmation a screen
          // reader user gets that a filter chip did anything.
          Semantics(
            liveRegion: true,
            child: Text(
              '$count Every one renders the same details, so you can switch '
              'any time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal category filter.
///
/// The categories are the registry's own [TemplateCategory] — the templates
/// were authored into them — rather than groupings invented for this screen.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<TemplateCategory> categories;
  final TemplateCategory? selected;
  final ValueChanged<TemplateCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
      child: Row(
        spacing: tokens.spaceSm,
        children: [
          _CategoryChip(
            label: 'All',
            value: null,
            selected: selected == null,
            onChanged: onChanged,
          ),
          for (final category in categories)
            _CategoryChip(
              label: categoryLabel(category),
              value: category,
              selected: selected == category,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final TemplateCategory? value;
  final bool selected;
  final ValueChanged<TemplateCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return ChoiceChip(
      key: categoryChipKey(value),
      label: Text(label),
      selected: selected,
      // The fill is the selected state. A checkmark on top of it only steals
      // width from the label at large text sizes.
      showCheckmark: false,
      onSelected: (_) => onChanged(value),
      // Raised chrome over the base surface, matching `chipTheme`. The visible
      // outline rather than the hairline: an unselected filter chip is a live
      // control, and a ~1.3:1 tint step is not a boundary anyone can find.
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      selectedColor: theme.colorScheme.primary,
      side: BorderSide(
        color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      // copyWith on the theme's own style, never a bare TextStyle: a bare one
      // drops ThemeData.fontFamily and falls back to Roboto.
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceSm,
      ),
    );
  }
}

/// Says where the current design went when a filter hid it.
///
/// Deliberately an offer rather than an action: it names the design, says which
/// category it is in, and leaves the jump to the user — the alternative,
/// switching the filter for them, would take the catalog away from someone who
/// came here to look at it. Only ever rendered when the selection really is off
/// screen, so it costs nothing in the common case.
class _HiddenSelectionNote extends StatelessWidget {
  const _HiddenSelectionNote({required this.template, required this.onShow});

  final ResumeTemplate template;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ink = theme.colorScheme.onPrimaryContainer;
    final message =
        '${template.name} is your current design, '
        'in ${categoryLabel(template.category)}.';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceMd,
        tokens.spaceLg,
        0,
      ),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceMd,
            tokens.spaceSm,
            tokens.spaceSm,
            tokens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
          // Wrap, not Row: at a large text size the sentence and the action do
          // not share a 360px line, and this is the row that would overflow.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spaceSm,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: ink),
                    SizedBox(width: tokens.spaceSm),
                    Flexible(
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onShow,
                style: TextButton.styleFrom(
                  // The container's own ink, not the accent: a light violet
                  // label on a violet container is the one pairing this
                  // palette cannot carry, and this pair is measured.
                  foregroundColor: ink,
                  padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd),
                ),
                child: const Text('Show it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One design: a white card holding the rasterized page, its name, what its
/// layout actually is, and who it suits.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    super.key,
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
    final cue = templateCues[template.id];
    final radius = BorderRadius.circular(tokens.radiusLg);

    return Semantics(
      button: true,
      selected: selected,
      label: [template.name, ?cue, template.bestFor].join('. '),
      child: Material(
        // The card wears its category's solid tint, selected or not. On matte
        // black a neutral card sits 1.08:1 above the background — technically a
        // step, visually nothing — so thirteen white pages floated on an
        // undifferentiated void and glared. A tint at 1.39–1.68:1 gives each
        // page a mat to sit in, groups the caption with the page it describes,
        // and makes the category filter something you can see the result of
        // rather than only read.
        color: categoryTint(template.category, tokens),
        // The ring goes around the *card*, never around the page: a coloured
        // edge drawn against the A4 sheet reads as part of the design being
        // advertised. Out here it is unambiguously app chrome.
        //
        // It is also what carries the selected state now that the fill is spent
        // on the category. That is a straight swap of one luminance cue for a
        // stronger one, not a downgrade: the old cue was a card one tier
        // brighter, which measured 1.08:1 against its neighbours, while the
        // accent ring measures 5.20–6.31:1 against every tint it can be drawn
        // on. Luminance, not hue, so it survives any colour-vision deficiency
        // exactly as the tier step was chosen to — and it is doubled in width
        // as well, so the cue is not carried by colour alone.
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // The caption repeats what the label above already says. Excluded
          // here rather than on the Semantics above, which would take the
          // InkWell's tap action with it and leave a button a screen reader
          // cannot press.
          child: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AspectRatio inside the flexible slot, so the framed page
                  // keeps its A4 shape whatever height the cell ends up with
                  // — any slack falls outside the frame instead of stretching
                  // or cropping the design.
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AspectRatio(
                        aspectRatio: _pageAspect,
                        child: _PageFrame(
                          template: template,
                          selected: selected,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceXs),
                  if (cue != null)
                    // Two lines: a phone column is about twenty characters
                    // wide, and on one line every two-column design truncated
                    // to the same "Two column · Photo · …" — the exact
                    // undifferentiated wall this screen exists to fix.
                    Text(
                      cue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  SizedBox(height: tokens.spaceXs),
                  // Two lines: at 360px the role list is wider than one line
                  // and truncating it hid the only description a card carries.
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
        ),
      ),
    );
  }
}

/// The rasterized page, framed, with the selection badge floated on it.
class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.template, required this.selected});

  final ResumeTemplate template;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        // Square, deliberately. A resume is a rectangular sheet and a rounded
        // corner does not soften it — it *crops* it: nine of the thirteen
        // designs ink at least one page corner and three fill all four, so the
        // arc cut a wedge out of the design and let the card tint show through
        // the paper. It bit harder here than in the preview, where the same
        // radius was removed for the same reason: 12dp of arc is ~8% of a
        // 150dp thumbnail against ~3% of the preview page.
        //
        // Always neutral. The selected ring is on the card; if it were here it
        // would look like a border the template itself prints.
        //
        // Eleven of the thirteen designs are light documents, and on matte
        // black a white rectangle needs no help being found — it glares. So
        // there is no shadow, and the edge is the mid-tone `outline` instead:
        // a mat that keeps 19:1 of paper from cutting straight into the card.
        // It is a real step on both sides — 3.40:1 against the paper it
        // contains, 3.38:1 or better against every tint it can be drawn on —
        // and it is the same ring the preview's A4 page carries, so a document
        // is framed identically wherever the app shows one.
        border: Border.all(color: theme.colorScheme.outline),
      ),
      // Kept, but hard-edged: with no arc there is nothing to antialias, and
      // the clip is still what stops the selection badge from growing past the
      // page at large text scales.
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Thumbnail(template: template),
          if (selected)
            // Bottom edge, inset: the least dense band of most resume pages,
            // and it puts the badge over the thumbnail rather than costing
            // every unselected card a reserved line of caption height.
            // Left/right anchored so the pill can never grow past the page at
            // large text sizes — its label ellipsizes instead.
            Positioned(
              left: tokens.spaceSm,
              right: tokens.spaceSm,
              bottom: tokens.spaceSm,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: _SelectedBadge(),
              ),
            ),
        ],
      ),
    );
  }
}

/// The unmistakable part of the selected state: a solid accent pill, with a
/// word on it, sitting on the chosen page.
///
/// App chrome floated on a document, the same relationship the preview's busy
/// pill has with the page it covers. Solid rather than tinted because the pill
/// has to hold up over both paper-white and the two deliberately dark
/// templates; `gallery_layout_test` checks it against every palette in the
/// catalog rather than assuming.
///
/// The ring is what makes that check pass, and on the dark palette the two
/// edges have swapped jobs. The accent is now a *light* violet and `onPrimary`
/// a near-black, so the fill is what separates the pill from Ember's charcoal
/// and Terminal's near-black pages (8.24:1 and 9.09:1), while on white paper
/// the fill drops to 1.61:1 and the dark ring carries it instead (17.76:1).
/// One of the two always holds; `gallery_layout_test` still measures
/// `max(fill, ring) >= 3:1` against every paper in the catalog.
class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: theme.colorScheme.onPrimary),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceSm,
          vertical: tokens.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 14,
              color: theme.colorScheme.onPrimary,
            ),
            SizedBox(width: tokens.spaceXs),
            Flexible(
              child: Text(
                'Selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
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
  /// Process-wide cache so scrolling the grid — or filtering it, which
  /// unmounts and later remounts tiles — does not re-render a design that has
  /// already been drawn once.
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _png;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Read synchronously and assign directly. Going through `setState` here
    // would be a build-phase rebuild request, and with a filter that remounts
    // already-rendered tiles this path is now hit routinely.
    final cached = _cache[widget.template.id];
    if (cached != null) {
      _png = cached;
      return;
    }
    _load();
  }

  Future<void> _load() async {
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
      if (png == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      // Cached before the mounted check: a tile filtered off screen mid-render
      // has still paid for the raster, and throwing it away would make the
      // work repeat the next time that category is shown.
      _cache[widget.template.id] = png;
      if (!mounted) return;
      setState(() => _png = png);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Placeholder and failure states sit on app chrome, not on paper white: a
  /// white rectangle inside the page frame reads as a design that has finished
  /// loading and come out blank. On the matte palette that means the brightest
  /// *neutral* tier — 15.06:1 from paper so it can never be mistaken for a
  /// rendered page, and a step away from every card tint it can be nested in,
  /// with the mat ring around it doing the rest of the delimiting.
  Widget _failure(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
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
        color: theme.colorScheme.surfaceContainerHighest,
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
