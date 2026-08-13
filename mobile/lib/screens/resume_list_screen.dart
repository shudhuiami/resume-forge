import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/resume_repository.dart';
import '../models/resume.dart';
import '../state/app_providers.dart';
import '../templates/registry.dart';
import '../templates/template.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_fields.dart';
import 'about_screen.dart';
import 'editor_screen.dart';
import 'gallery_screen.dart';

/// Widest the list is allowed to grow. A tablet-width row puts a resume title
/// and its delete button half a screen apart and reads as an admin table, so
/// the content column stops here and centres.
const _maxContentWidth = 640.0;

/// Widest a paragraph of body copy is allowed to run, in the same spirit.
const _maxProseWidth = 380.0;

/// The plate's fallback glyph: a fixed graphic, so it does not grow with text.
const _plateGlyphSize = 22.0;

/// Content width at which the greeting and the browse action stop stacking and
/// sit side by side.
///
/// Below it (every phone in portrait) the header is a column. At or above it —
/// a tablet, or a landscape phone, where the content column has already hit its
/// 640 cap — stacking wasted the width and, on a short landscape viewport, ate
/// the entire screen before the first resume.
const _wideHeaderWidth = 560.0;

/// Width the browse action takes in that side-by-side header.
const _wideActionsWidth = 320.0;

/// Shape of the plate on a resume card: A4, the only shape a resume is printed
/// at, so the card carries the page proportion the rest of the app uses.
final _pageAspect = a4.width / a4.height;

/// Width of that plate. A fixed graphic rather than a text-scaled one.
const _plateWidth = 56.0;

/// Sections listed in a card's content summary, longest-lived first. Capped so
/// the line stays scannable rather than becoming an inventory.
const _summaryPartLimit = 3;

/// Bounds for the empty-state hero disc. The upper bound is what makes it the
/// centre of the screen rather than another icon; the lower bound is roughly
/// the old tinted tile, below which the mark stops reading as a mark.
const _heroMaxDiameter = 160.0;
const _heroMinDiameter = 64.0;

/// Height of the words around the hero at text scale 1 — the heading, the body
/// paragraph, the button, and the gaps between them. Subtracted from the
/// viewport before the disc is sized, so the disc gives up its space to the
/// words on a short screen instead of pushing them out of view.
///
/// Down from 232: the wordmark used to sit inside this pane and is now in the
/// screen's own top bar, above every state rather than only this one.
const _heroCopyReserve = 200.0;

/// Glyph size relative to the disc.
const _heroGlyphFraction = 0.42;

/// Home: everything the user has saved.
class ResumeListScreen extends ConsumerWidget {
  const ResumeListScreen({super.key});

  /// Opens the gallery, and starts a resume on whatever design comes back.
  ///
  /// Both entry points land here because choosing a design *is* the create
  /// flow — there is no "look at designs and do nothing" destination in this
  /// app, and a control that opened a dead end would be worse than one that
  /// admits where it goes. They differ in framing only: [selectedId] pre-marks
  /// the default for someone who just wants to get going, and null leaves the
  /// gallery unmarked for someone who came to browse.
  Future<void> _createNew(
    BuildContext context,
    WidgetRef ref, {
    String? selectedId,
    String title = 'Start with a design',
  }) async {
    final templateId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          selectedId: selectedId,
          title: title,
          onSelected: (id) => Navigator.of(context).pop(id),
        ),
      ),
    );
    if (templateId == null || !context.mounted) return;

    final doc = newResumeDocument(templateId: templateId);
    await ref.read(repositoryProvider).save(doc);
    if (!context.mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditorScreen(document: doc)));
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ResumeDocument doc,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditorScreen(document: doc)));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ResumeDocument doc,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this resume?',
      message:
          '"${doc.displayTitle}" will be permanently removed from this device.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await ref.read(repositoryProvider).delete(doc.id);
    }
  }

  Future<void> _openAbout(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
  }

  /// Asks before the system back closes the app.
  ///
  /// Deliberately **not** [confirmDestructive]: leaving is not destructive.
  /// Every edit in this app autosaves and everything is on the device, so
  /// nothing is at risk and the copy must not imply that anything is — hence a
  /// plain question, a sentence of reassurance, and the ordinary filled button
  /// rather than the error-coloured one that means "this throws work away".
  /// The shape is otherwise the same dialog: same theme, same `Cancel`-on-the-
  /// left ordering, same "dismissed means no".
  ///
  /// Double-back-to-exit was the alternative and is not what was asked for: a
  /// toast that only appears after the first press is a rule you have to
  /// already know, and it still closes the app for anyone who taps twice.
  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave $appName?'),
        content: const Text(
          'Your resumes are saved on this device and will be here when you '
          'come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave ?? false) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumes = ref.watch(resumeListProvider);

    // The empty state carries its own primary action, so the FAB would be a
    // second identical call to action on the same screen.
    final showFab = resumes.valueOrNull?.isNotEmpty ?? true;

    // Scoped to the root, and scoped by asking rather than by assuming. A
    // `PopScope` is consulted for the route it is *in*, so this can only ever
    // intercept a back press aimed at the home screen itself — the editor and
    // the gallery are pushed on top and pop normally, untouched. The check is
    // what keeps that true if this screen is ever pushed rather than launched
    // into: somewhere down a stack, back means "go back", not "quit".
    final isRoot = ModalRoute.of(context)?.isFirst ?? false;

    return PopScope(
      canPop: !isRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmLeave(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // The header sits on the background rather than in a bar, so there is
        // no AppBar left to publish the overlay style for this route. Without
        // this the status bar keeps whatever the previously pushed route set.
        value: AppTheme.systemOverlay,
        child: Scaffold(
          // The one create action on the screen, and icon-only on purpose: a
          // FAB is a fixed graphic where an extended one grows with its label,
          // which at double text size on a 360px phone took a third of the
          // width and parked itself over the first resume. Its tooltip is its
          // label for anyone who needs one read out.
          floatingActionButton: showFab
              ? FloatingActionButton(
                  onPressed: () =>
                      _createNew(context, ref, selectedId: defaultTemplate.id),
                  tooltip: 'New resume',
                  child: const Icon(Icons.add),
                )
              : null,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Outside the scroll view and above every state: it is
                    // where the product is named on a first run, and where the
                    // one route off this screen that is not a resume lives, so
                    // it has to be reachable while the list is loading, empty,
                    // broken, or scrolled to the bottom.
                    _TopBar(onAbout: () => _openAbout(context)),
                    Expanded(
                      child: resumes.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => _ErrorState(
                          onRetry: () => ref.invalidate(resumeListProvider),
                        ),
                        data: (docs) {
                          if (docs.isEmpty) {
                            return _EmptyState(
                              onCreate: () => _createNew(
                                context,
                                ref,
                                selectedId: defaultTemplate.id,
                              ),
                            );
                          }
                          return _ResumeHome(
                            docs: docs,
                            onBrowse: () => _createNew(
                              context,
                              ref,
                              title: 'Browse designs',
                            ),
                            onOpen: (doc) => _open(context, ref, doc),
                            onDelete: (doc) =>
                                _confirmDelete(context, ref, doc),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The screen's title row: the product, and the way off this screen.
///
/// This is what replaced a stacked eyebrow-over-greeting header. One line at
/// the top of the screen, in one size, in the same place in every state — so
/// the app is named on a first run (which the greeting could not do, since it
/// only renders once something is saved) and the information button has a
/// stable home in the corner the user reaches for it.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAbout});

  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      // Tighter on the right: the icon button carries its own 48px touch
      // target, so a full inset there would push the glyph well inside the
      // margin the content below keeps. Same treatment as a resume row's
      // delete button, so the two line up in a column.
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceSm,
        0,
      ),
      child: Row(
        children: [
          const Expanded(child: Wordmark()),
          IconButton(
            onPressed: onAbout,
            icon: const Icon(Icons.info_outline),
            tooltip: 'About $appName',
          ),
        ],
      ),
    );
  }
}

/// The populated home: greeting, the browse action, then the saved resumes.
///
/// One scroll view rather than a fixed header over a list — on a landscape
/// phone at a large text size the greeting and the action alone are taller than
/// the viewport, and a pinned header there would leave a couple of rows peeping
/// through a slot.
class _ResumeHome extends StatelessWidget {
  const _ResumeHome({
    required this.docs,
    required this.onBrowse,
    required this.onOpen,
    required this.onDelete,
  });

  final List<ResumeDocument> docs;
  final VoidCallback onBrowse;
  final ValueChanged<ResumeDocument> onOpen;
  final ValueChanged<ResumeDocument> onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            tokens.spaceSm,
            tokens.spaceLg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeHeader(onBrowse: onBrowse),
                SizedBox(height: tokens.spaceXl),
                _SectionHeading(count: docs.length),
                SizedBox(height: tokens.spaceMd),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            // Clearance for the FAB, so the last card is not parked underneath
            // it.
            tokens.spaceXxl * 2.5,
          ),
          sliver: SliverList.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spaceMd),
                child: _ResumeCard(
                  doc: doc,
                  onTap: () => onOpen(doc),
                  onDelete: () => onDelete(doc),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Greeting and the browse action, stacked or side by side.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final browse = _BrowseDesignsCard(onTap: onBrowse);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideHeaderWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Greeting(),
              SizedBox(height: tokens.spaceLg),
              browse,
            ],
          );
        }
        return Row(
          children: [
            const Expanded(child: _Greeting()),
            SizedBox(width: tokens.spaceXl),
            SizedBox(width: _wideActionsWidth, child: browse),
          ],
        );
      },
    );
  }
}

/// One supporting line under the title.
///
/// This used to be three stacked things — the product name as an eyebrow, a
/// headline-sized "Welcome back", and two muted lines under that — which is
/// four lines of chrome before the first resume and no hierarchy to speak of,
/// since each one was simply smaller than the last. The name moved up into the
/// title row, where it also gets to exist on a first run; the promise about the
/// device is made properly on the about screen and in the empty state; what is
/// left is a single line that says where you are and what to do.
///
/// There are no accounts here, so there is no name to greet anyone by and none
/// is invented. "Welcome back" is the strongest honest thing this screen can
/// say: it only ever renders when the device already holds saved work, so the
/// user demonstrably has been here before.
class _Greeting extends StatelessWidget {
  const _Greeting();

  static const text = 'Welcome back. Pick up where you left off.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxProseWidth),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The product name, as the screen's title.
///
/// The app name lived in the `AppBar` title until the bar was removed, and it
/// then lived only inside the greeting — which renders solely once a resume has
/// been saved, so a first run named the product nowhere at all. It sits in the
/// screen's own title row now, above every state, at one size: an eyebrow above
/// a larger greeting was a hierarchy that put the smallest type at the top and
/// the app's name in the least emphatic thing on the screen.
///
/// It is [BrandWordmark] rather than plain text, so the one place the app names
/// itself in every state is also the place it carries the brand's accent —
/// spelled and coloured identically to the heading on the about screen.
///
/// **The text-scale cap is gone.** It existed because "ResumeForge" is eleven
/// characters and one unbreakable word, and past ~1.6x it had nothing left to
/// do on a 360px phone beside a 48px icon button except ellipsize into
/// "ResumeForg…". "Resivo" is six characters: it measures ~67px at 1x and
/// ~200px at 3x, against the 288px this row leaves on the narrowest phone, so
/// it now scales without a ceiling like everything else on the screen.
/// `test/screens/resume_list_layout_test.dart` asserts the row's own outcome —
/// that the name is never ellipsized and the button stays on screen — rather
/// than asserting the mechanism that used to guarantee it.
@visibleForTesting
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BrandWordmark(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        // Large and tight, matching the app bar's own title treatment on every
        // pushed screen.
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Addresses a header action from a test.
@visibleForTesting
Key quickActionKey(String label) => ValueKey('quick-action:$label');

/// The way into the design gallery for someone who came to look rather than to
/// start.
///
/// It is the only header action left. "New resume" used to sit beside it as a
/// second tile, and the FAB in the corner did exactly the same job — two
/// controls, one destination, a hand's width apart. The FAB is the one that
/// survived: it is the only create action that is still on screen once the
/// list has been scrolled, which is precisely when someone decides they want
/// another resume, and it stays a fixed size at every text scale.
///
/// A row rather than the old square tile: one control does not need half a row
/// of width, and the chevron says the card goes somewhere, which a bare tile
/// never did. The plain card tier is deliberate — on this screen and in the
/// gallery a solid tint means "this is a design", so a control that is not one
/// must not wear one.
class _BrowseDesignsCard extends StatelessWidget {
  const _BrowseDesignsCard({required this.onTap});

  final VoidCallback onTap;

  static const label = 'Browse designs';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // A Card, like the resume rows below it: same radius, same hairline, same
    // flat separation from the background. A hand-rolled panel here would be a
    // second, slightly different card style on one screen.
    return Card(
      key: quickActionKey(label),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceLg,
            vertical: tokens.spaceMd,
          ),
          child: Row(
            children: [
              // The same recessed accent mark the editor's sections and its
              // design chooser carry, reused rather than reinvented at a
              // fourth size.
              const SectionIconTile(icon: Icons.grid_view_rounded),
              SizedBox(width: tokens.spaceMd),
              // Wraps rather than ellipsizes: at double text size "Browse
              // designs" does not fit one line beside a mark and a chevron,
              // and a header action that reads "Browse d…" is worse than one
              // that takes a second line.
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: tokens.spaceSm),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Your resumes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One saved resume.
///
/// Deliberately **not** a rasterized page. Drawing a real first-page thumbnail
/// per row means, per row: a PDF build (26-68ms on a warm desktop VM, measured;
/// several times that on a low-end phone), a `compute` isolate spawn with the
/// font bytes copied across it, and then a PDFium rasterization that cannot
/// leave the platform thread at all. The gallery gets away with it because its
/// thirteen designs render one fixed sample document and cache process-wide;
/// here every document is different and every autosave bumps `updatedAt`, so
/// the cache key changes under the exact row the user just came back from.
/// That work would land on the app's cold-start screen, unbounded in the number
/// of rows. Nor is a hand-drawn mock of the design an option — a fake preview
/// is worse than none.
///
/// So the card carries what it can honestly show: whose resume it is, which
/// design it is on, how much of it is filled in, and when it was last touched.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  final ResumeDocument doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final template = templateById(doc.templateId);

    return Card(
      // The design's category tint, from the same function the gallery paints
      // its cards with. Pick a Tech design and the row you come back to is the
      // same teal the card you chose it from was — the colour is worth learning
      // because it means the same thing in both places.
      color: categoryTint(template.category, tokens),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Tighter on the right: the delete button carries its own 48px touch
          // target, so a full inset there would push the glyph well inside the
          // margin the rest of the card keeps.
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            tokens.spaceLg,
            tokens.spaceSm,
            tokens.spaceLg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DesignPlate(doc: doc),
              SizedBox(width: tokens.spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doc.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXs),
                    Text(
                      _summarize(doc.data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: tokens.spaceMd),
                    // Wrap, not Row: at a large text size the design chip and
                    // the edited stamp do not fit on one line beside a plate
                    // and a delete button, and this is the row that would
                    // overflow first.
                    Wrap(
                      spacing: tokens.spaceSm,
                      runSpacing: tokens.spaceXs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DesignChip(name: template.name),
                        Text(
                          'Edited ${relativeEditedAt(doc.updatedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete ${doc.displayTitle}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// How much of the resume is filled in, from the content itself.
  ///
  /// The most useful thing a row can say about a document nobody can see the
  /// inside of: whether it is a real resume or an empty shell you started and
  /// abandoned. Asserted through the rendered card rather than directly, so the
  /// test covers what the user reads.
  static String _summarize(ResumeData data) {
    if (data.isEmpty) return 'Not started yet';

    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';

    final parts = <String>[
      if (data.experiences.isNotEmpty)
        plural(data.experiences.length, 'role', 'roles'),
      if (data.education.isNotEmpty)
        plural(data.education.length, 'degree', 'degrees'),
      if (data.skills.isNotEmpty) plural(data.skills.length, 'skill', 'skills'),
      if (data.projects.isNotEmpty)
        plural(data.projects.length, 'project', 'projects'),
    ];

    if (parts.isEmpty) return 'Personal details only';
    return parts.take(_summaryPartLimit).join(' · ');
  }
}

/// Month names for the long-ago case. Spelled out rather than pulled from
/// `intl`: the app carries no localisation, and adding a package to format
/// three words would be the larger change.
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// When the resume was last touched, as something that can be read aloud.
///
/// Past a month the row used to fall back to `2026-07`, so it said "Edited
/// 2026-07" — a stamp rather than a phrase, and ambiguous about which day it
/// meant. A resume kept for a year of occasional applications is a real case,
/// so the long tail gets a real date.
///
/// Top level rather than a static on the private card, so a test can reach it:
/// `@visibleForTesting` on a member of a private class is not visible to
/// anything.
@visibleForTesting
String relativeEditedAt(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return 'on ${when.day} ${_months[when.month - 1]} ${when.year}';
}

/// Page-shaped plate carrying the initials on the resume.
///
/// A4 proportioned so it reads as a document rather than as a contact avatar,
/// but it does not pretend to be a preview of the design: no header band, no
/// fake text lines, nothing that could be mistaken for the page that would
/// print. The initials come from the resume's own content, so no two rows for
/// two different people look alike.
///
/// Punched down to the well and marked in the accent, exactly like the editor's
/// section marks. The design's own colour is the card *around* this plate now,
/// so a second colour here would either match it and vanish or fight it; a
/// recess reads on all five category tints without either.
class _DesignPlate extends StatelessWidget {
  const _DesignPlate({required this.doc});

  final ResumeDocument doc;

  /// Up to two initials from the name, falling back to the headline.
  ///
  /// Works in code points rather than code units: a name starting with an
  /// emoji or an astral-plane script would otherwise be cut through the middle
  /// of a surrogate pair and render as a replacement glyph.
  @visibleForTesting
  static String initialsFor(ResumeData data) {
    final source = data.personalInfo.fullName.trim().isNotEmpty
        ? data.personalInfo.fullName
        : data.personalInfo.title;
    final words = source
        .split(RegExp(r'\s+'))
        .where((w) => w.runes.isNotEmpty)
        .take(2);
    return words
        .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final initials = initialsFor(doc.data);

    return SizedBox(
      width: _plateWidth,
      child: AspectRatio(
        aspectRatio: _pageAspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
          child: Center(
            child: initials.isEmpty
                // Nothing to draw initials from yet, so the plate says
                // "document" instead of showing a blank sheet.
                ? Icon(
                    Icons.description_outlined,
                    size: _plateGlyphSize,
                    color: theme.colorScheme.primary,
                  )
                : Text(
                    initials,
                    maxLines: 1,
                    // The plate is a fixed graphic; at a large text size the
                    // initials must stay inside it rather than burst it.
                    textScaler: TextScaler.noScaling,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Names the design a resume is on.
///
/// A recess in the card, like the plate above it: the row's colour already says
/// which family the design belongs to, and this says which design.
class _DesignChip extends StatelessWidget {
  const _DesignChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceSm,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Centred full-screen message that survives a short viewport.
///
/// Landscape phones and large accessibility text both shrink the space below
/// the app bar past what an icon-plus-copy-plus-button stack needs, so the
/// stack scrolls instead of overflowing, and still centres when it fits.
class _MessagePane extends StatelessWidget {
  const _MessagePane({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = tokens.spaceXl;
        return SingleChildScrollView(
          padding: EdgeInsets.all(inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - inset * 2),
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        );
      },
    );
  }
}

/// Rounded square holding one icon on a solid fill.
///
/// The failure pane is one of the few places in the app where an icon stands
/// alone with nothing around it, and on a bare background a lone glyph reads as
/// an artefact rather than as a deliberate mark.
///
/// One flat colour, no ramp and no scrim shading. The gradient variant used to
/// live here purely so a white glyph could survive the warm end of the hero
/// ramp; with the ramp gone there is nothing left for it to solve, so it is
/// deleted rather than kept as an unused parameter. The size and radius
/// parameters went the same way with the quick-action tiles that used them: the
/// header's mark is `SectionIconTile` now, which is the app's small version of
/// exactly this.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  static const _size = 72.0;
  static const _glyph = 32.0;

  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Icon(icon, size: _glyph, color: foreground),
    );
  }
}

/// Addresses the empty state's hero disc from a test.
@visibleForTesting
const heroDiscKey = Key('hero-disc');

/// The app's accent motif: one solid amber disc carrying the document glyph.
///
/// It used to be a five-stop pink/violet/blue ramp over a blurred copy of
/// itself, and the ramp is why it needed maths: white was the only glyph colour
/// that worked across all five stops, but the warm end measured ~2.1:1 against
/// it, so the core of the disc was shaded with the theme scrim to drag the
/// contrast back over 3:1 — a constant, a radial fade and a test that sampled
/// the ramp at fifty points, all in service of a decision the palette has now
/// unmade. **All of it is deleted rather than left dormant.** A solid fill has
/// one contrast pair, and it is the same one the rest of the app uses:
/// `onPrimary` on `primary`, 8.46:1, nearly three times what a meaningful
/// graphic needs.
///
/// The glow went with it. The brief for this palette is matte — no gloss, no
/// gradient, no glow — and a blurred translucent halo is all three.
///
/// The colour is the accent rather than a colour of its own, which also makes
/// this the same amber the launcher icon's page is filled with: the mark on the
/// home screen the user just tapped, and the first thing in the app they see.
class _HeroDisc extends StatelessWidget {
  const _HeroDisc({required this.icon, required this.diameter});

  final IconData icon;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: heroDiscKey,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
      child: Center(
        child: Icon(
          icon,
          size: diameter * _heroGlyphFraction,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  /// Disc diameter for the space the pane actually has.
  ///
  /// Sized from the viewport rather than fixed: a landscape phone at double
  /// text size has barely a heading's worth of height to spare, and a hero that
  /// insists on 160px there pushes the CTA out of reach. The copy is reserved
  /// first, the disc takes what is left.
  static double _diameterFor(BoxConstraints constraints, TextScaler scaler) {
    final forCopy = scaler.scale(_heroCopyReserve);
    final byHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight - forCopy
        : double.infinity;
    // Narrow viewports cap it too, so the disc never spans the whole width.
    final byWidth = constraints.maxWidth / 2;
    return math
        .min(byHeight, byWidth)
        .clamp(_heroMinDiameter, _heroMaxDiameter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    // Reads the same constraints _MessagePane does, one level further out.
    return LayoutBuilder(
      builder: (context, constraints) => _MessagePane(
        children: _children(
          theme,
          tokens,
          _diameterFor(constraints, MediaQuery.textScalerOf(context)),
        ),
      ),
    );
  }

  List<Widget> _children(ThemeData theme, AppTokens tokens, double diameter) {
    return [
      // The wordmark used to lead this pane, because a first run had nowhere
      // else that named the product. The screen's title row does that now, in
      // every state, so the pane is back to one hero and the copy under it —
      // and the height that line was costing on the viewport with least to
      // spare goes back to the disc.
      _HeroDisc(icon: Icons.description_outlined, diameter: diameter),
      SizedBox(height: tokens.spaceLg),
      Text(
        'No resumes yet',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      SizedBox(height: tokens.spaceSm),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxProseWidth),
        child: Text(
          'Pick a design, fill in your details, and export a PDF. '
          'Everything stays on this device.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      SizedBox(height: tokens.spaceXl),
      FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: const Text('Create your first resume'),
      ),
    ];
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return _MessagePane(
      children: [
        _IconTile(
          icon: Icons.error_outline,
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
        ),
        SizedBox(height: tokens.spaceLg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxProseWidth),
          child: Text(
            'Could not load your saved resumes',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        SizedBox(height: tokens.spaceLg),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
