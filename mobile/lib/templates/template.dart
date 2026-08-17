import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/resume.dart';
import 'fonts.dart';

/// Document colours for one template.
///
/// Entirely separate from the app's [ColorScheme]. These are ink-on-paper
/// values for a printed page and are mostly light; the app chrome is dark.
class TemplatePalette {
  const TemplatePalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    this.paper = const PdfColor.fromInt(0xFFFFFFFF),
    this.ink = const PdfColor.fromInt(0xFF1A1A22),
    this.muted = const PdfColor.fromInt(0xFF6B6B7B),
    this.onPrimary = const PdfColor.fromInt(0xFFFFFFFF),
  });

  final PdfColor primary;
  final PdfColor secondary;
  final PdfColor accent;
  final PdfColor paper;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor onPrimary;
}

/// Everything a template needs to render one page.
///
/// Fonts arrive already loaded because template builders run where async asset
/// loading is unavailable.
class TemplateContext {
  const TemplateContext({
    required this.data,
    required this.palette,
    required this.families,
  });

  final ResumeData data;
  final TemplatePalette palette;
  final Map<FontFamily, LoadedFamily> families;

  LoadedFamily family(FontFamily f) {
    final loaded = families[f];
    if (loaded == null) {
      throw StateError(
        'Font family $f was not preloaded. Add it to the template\'s '
        'requiredFonts so the renderer loads it before building.',
      );
    }
    return loaded;
  }
}

enum TemplateCategory { corporate, creative, tech, academic, minimal }

/// A resume design.
///
/// Implementations describe a single A4 page as a `dart_pdf` widget tree. That
/// tree is the only source of truth for the design — the on-screen preview is
/// a rasterization of the very PDF this produces, never a reimplementation, so
/// preview and export cannot drift.
abstract class ResumeTemplate {
  const ResumeTemplate();

  String get id;
  String get name;
  String get description;
  String get bestFor;
  TemplateCategory get category;
  TemplatePalette get palette;

  /// Families this template must have loaded before [build] is called.
  Set<FontFamily> get requiredFonts;

  pw.Widget build(TemplateContext ctx);
}

/// A4 in PostScript points, which is what `dart_pdf` measures in.
const a4 = PdfPageFormat.a4;

/// Shared text-overflow guard.
///
/// Resume content is entirely user-supplied and frequently longer than a design
/// anticipates. Every text run in a template should pass through here or set
/// its own maxLines, so a long job title truncates instead of pushing the
/// layout off the page.
pw.Widget clampedText(
  String text, {
  required pw.TextStyle style,
  int maxLines = 1,
  pw.TextAlign? align,
}) {
  return pw.Text(
    text,
    style: style,
    maxLines: maxLines,
    overflow: pw.TextOverflow.clip,
    textAlign: align,
  );
}

/// Decodes a user photo, returning null when the bytes are unusable.
///
/// `pw.MemoryImage` throws on anything it cannot decode, and that exception
/// propagates out of `Document.save()` — so one corrupt or unsupported photo
/// would take down the entire resume render rather than just omitting the
/// portrait. Templates call this instead of constructing `MemoryImage`
/// directly, and lay out as if no photo were supplied when it returns null.
pw.MemoryImage? tryDecodePhoto(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// ENGINE HAZARD: a `pw.Column` DROPS A CHILD ENTIRELY when that child's height
// exceeds the space remaining — it does not clip it and does not overflow
// visibly.
//
// This is the most dangerous layout behaviour in dart_pdf because the failure
// is silent: a long resume simply loses its experience section, the PDF still
// parses, the page count is still one, and every test passes. It has already
// erased a whole template body once and a Competencies section twice.
//
// Defend against it by giving long content a bounded height — put the body in
// an `Expanded`, or cap it — so overflow trims one entry at a time instead of
// deleting the container. Always confirm with `pdftotext` that every section
// still appears, not merely that the document renders.
// ---------------------------------------------------------------------------

/// Fully rounded ("pill") radius for a box of [height].
///
/// **Never write `pw.BorderRadius.circular(999)`.** Flutter clamps an oversized
/// radius to half the box; `dart_pdf` does not — it emits a degenerate path
/// that floods the page with the fill colour and overpaints everything drawn
/// before it. The failure is invisible to `flutter analyze` and to any test
/// that only checks the PDF parses, so it must be prevented at the source.
pw.BorderRadius pillRadius(double height) =>
    pw.BorderRadius.circular(height / 2);

// ---------------------------------------------------------------------------
// THE URL RULE
//
// A resume carries three URLs — LinkedIn, website, and a link per project — and
// they are the only user-supplied strings that are both long and unbreakable.
// Every template draws them the same way. The rule is:
//
// 1. DISPLAY FORM. Strip the scheme (`https://`, `http://`), a leading `www.`,
//    and any trailing `/`. None of the three carries information on a printed
//    page, and together they cost 8-12 characters out of a column that is often
//    only ~150pt wide. Nothing else is removed: a path, query, or fragment the
//    user typed is theirs. See [urlDisplay].
//
// 2. NEVER LET THE ENGINE BREAK IT. `dart_pdf` splits text on whitespace only,
//    so a URL is one word; when that word is wider than its box the engine
//    bisects it at whatever character happens to fit. That is what makes a link
//    "look broken". Templates therefore never pass a URL to [clampedText] or
//    `pw.Text` — they call [urlText], which measures with the real font and
//    decides the break itself.
//
// 3. ONE LINE (`maxLines: 1`, the default) — used where the URL shares a line
//    with a title, as in a project row. The URL is shortened from the *middle
//    of the path*, keeping the host and the last segment:
//    `github.com/…/atlas-design-system`. The host is what a reader needs; a
//    deep path is not. If even that does not fit, the tail is cut instead, so
//    the host and the start of the path always survive:
//    `linkedin.com/in/alexandra-whitf…`. Either way the shortening is marked
//    with a `…` — visible, never silent.
//
// 4. MORE THAN ONE LINE — used where the URL owns its line, as in a contact
//    block. It breaks only *after* a URL delimiter (`/ . - _ ? # & = @ : ,`),
//    which is lossless and reads as a URL rather than as damage. A run between
//    two delimiters that is itself wider than the column is character-broken,
//    because there is no alternative; the last permitted line is elided with
//    `…` if content remains.
//
// 5. NEVER UNBOUNDED. A URL is never a non-flex child of a `pw.Row`. `dart_pdf`
//    lays a non-flex row child out with *unbounded* width, so a long URL sizes
//    itself to its full natural length, starves its `Expanded` sibling to zero
//    width — the project name collapses to a single letter — and paints past
//    the column into the margin. Pass [urlText] a `maxWidth`, or put it in an
//    `Expanded`/`Flexible`.
//
// 6. NEVER JOIN A URL INTO A LONGER RUN. Six contact blocks used to build one
//    string — `email · phone · location · linkedin · website` — and clamp it to
//    two lines. The clamp drops whatever falls past the last line, which is
//    always the website, and leaves a dangling separator where it was. Contact
//    values are laid out as atomic runs by [contactStrip] instead.
//
// The rule is deliberately shared while the *typography* is not: each design
// keeps its own font, size, and colour for a link. Three helpers implement it,
// and between them they cover every place a URL appears in the catalog:
//
//   [urlText]       one URL, on its own, in a box that already bounds it
//   [titleWithUrl]  a project name with its link at the far end of the line
//   [contactStrip]  the contact block: plain values and URLs on shared lines
//
// `test/templates/url_rule_test.dart` holds every design in the registry to
// all of it, so a template added later cannot quietly opt out.
// ---------------------------------------------------------------------------

/// Characters a URL may be broken *after*. See the URL rule, item 4.
const _urlBreakAfter = {'/', '.', '-', '_', '?', '#', '&', '=', '@', ':', ','};

/// The URL rule's display form: no scheme, no `www.`, no trailing slash.
///
/// Pure and total — safe to call on empty or malformed input, which is what a
/// free-text field produces.
String urlDisplay(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://'), '');
  s = s.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
  while (s.length > 1 && s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Draws a URL under the URL rule above.
///
/// Returns an empty box for empty input, so callers can hand it a field the
/// user left blank without guarding first.
///
/// [maxWidth] is a hard cap and is **required whenever this sits in a
/// `pw.Row`** — see item 5 of the rule. In a `pw.Column`, or inside an
/// `Expanded`, the incoming constraint already bounds it and [maxWidth] can be
/// omitted.
pw.Widget urlText(
  String raw, {
  required pw.TextStyle style,
  int maxLines = 1,
  double? maxWidth,
  pw.TextAlign? align,
}) {
  final display = urlDisplay(raw);
  if (display.isEmpty) return pw.SizedBox();

  final text = pw.LayoutBuilder(
    builder: (context, constraints) {
      var limit = maxWidth ?? double.infinity;
      if (constraints != null && constraints.hasBoundedWidth) {
        limit = math.min(limit, constraints.maxWidth);
      }

      return pw.Text(
        _fitUrl(display, style, context, limit, maxLines),
        style: style,
        // The break decision has already been made and baked into the string;
        // letting the engine wrap again would reintroduce the mid-token cut
        // this whole helper exists to prevent.
        softWrap: false,
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
        textAlign: align,
      );
    },
  );

  if (maxWidth == null) return text;
  return pw.ConstrainedBox(
    constraints: pw.BoxConstraints(maxWidth: maxWidth),
    child: text,
  );
}

/// A title with its URL set at the far end of the same line.
///
/// The shape seven designs use for a project entry, and the one that used to
/// break: with the URL as a plain non-flex `pw.Row` child it sized itself to
/// its full natural width, left the title's `Expanded` nothing, and painted
/// into the margin. Here the row is measured — the title keeps what it needs
/// (up to 72% of the line), the URL takes the rest, and it is shortened only
/// when it genuinely does not fit rather than at a guessed fraction.
pw.Widget titleWithUrl({
  required String title,
  required pw.TextStyle titleStyle,
  required String url,
  required pw.TextStyle urlStyle,
  double gap = 10,
  pw.CrossAxisAlignment crossAxisAlignment = pw.CrossAxisAlignment.start,
}) {
  final display = urlDisplay(url);
  if (display.isEmpty) return clampedText(title, style: titleStyle);

  return pw.LayoutBuilder(
    builder: (context, constraints) {
      double? cap;
      if (constraints != null && constraints.hasBoundedWidth) {
        final avail = math.max(0.0, constraints.maxWidth - gap);
        final titleKeep = math.min(
          _measurer(titleStyle, context)(title),
          avail * 0.72,
        );
        cap = math.max(avail * 0.28, avail - titleKeep);
      }

      return pw.Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          pw.Expanded(child: clampedText(title, style: titleStyle)),
          pw.SizedBox(width: gap),
          urlText(url, style: urlStyle, maxWidth: cap),
        ],
      );
    },
  );
}

/// The contact strip: email, phone, location and the two profile URLs on one
/// separated line, flowing onto a second when they no longer fit.
///
/// Each `(value, isUrl)` becomes one atomic run carrying its own separator, so
/// a value that does not fit moves to the next line *whole*. The alternative —
/// joining all five into one string and clamping it to two lines, which is what
/// six designs did — drops whatever falls past the clamp, always the website,
/// and leaves a dangling `·` where it was (QA-4).
///
/// The strip never grows past [maxLines]. That bound is not cosmetic: these
/// blocks sit at the top of a `pw.Column` that is already full at realistic
/// content, and one extra line there is enough for dart_pdf to delete a whole
/// section from the foot of the page. So when the runs will not pack into the
/// budget, the URLs are shortened — by exactly as much as it takes, found by
/// bisection against the same packing rule `pw.Wrap` uses — rather than the
/// block being allowed to push a job or a degree off the resume.
pw.Widget contactStrip(
  List<(String, bool)> items, {
  required pw.TextStyle style,
  int maxLines = 2,
  String separator = '   ·   ',
  pw.TextStyle? separatorStyle,
  pw.WrapAlignment alignment = pw.WrapAlignment.start,
}) {
  final present = items
      .where((e) => (e.$2 ? urlDisplay(e.$1) : e.$1.trim()).isNotEmpty)
      .toList();
  if (present.isEmpty) return pw.SizedBox();

  return pw.LayoutBuilder(
    builder: (context, constraints) {
      final sepStyle = separatorStyle ?? style;
      // Two separate bounds. `lineCap` is the safety limit every run gets —
      // nothing may be wider than the line it sits on. `urlCap` is only ever
      // narrower than that, and only URLs are held to it: a shortened email is
      // just a wrong email, so a plain value is never traded for a line.
      double? lineCap;
      double? urlCap;

      if (constraints != null && constraints.hasBoundedWidth) {
        final total = constraints.maxWidth;
        final width = _measurer(style, context);
        final sep = _measurer(sepStyle, context)(separator);

        // Natural run widths, each carrying its trailing separator.
        final runs = <double>[];
        for (var i = 0; i < present.length; i++) {
          final (value, isUrl) = present[i];
          runs.add(
            width(isUrl ? urlDisplay(value) : value.trim()) +
                (i == present.length - 1 ? 0 : sep),
          );
        }

        int linesWith(double limit) {
          var lines = 1;
          var run = 0.0;
          for (var i = 0; i < runs.length; i++) {
            final w = present[i].$2 ? math.min(runs[i], limit) : runs[i];
            if (i > 0 && run + w > total) {
              lines++;
              run = w;
            } else {
              run += w;
            }
          }
          return lines;
        }

        // `linesWith(0)` still over budget means the non-URL values alone
        // overflow it. Shortening the URLs cannot buy that back, and doing it
        // anyway would erase them for a reason that has nothing to do with
        // them, so the strip is simply allowed to run long.
        if (linesWith(double.infinity) > maxLines && linesWith(0) <= maxLines) {
          // Largest URL width the budget can carry. Bisection on a continuous
          // bound rather than a guessed fraction, so the URLs give up only the
          // space the strip actually needs.
          var low = 0.0;
          var high = total;
          for (var i = 0; i < 20; i++) {
            final mid = (low + high) / 2;
            if (linesWith(mid) <= maxLines) {
              low = mid;
            } else {
              high = mid;
            }
          }
          urlCap = math.max(0, low - sep);
        }
        lineCap = math.max(0, total - sep);
        urlCap = math.min(urlCap ?? lineCap, lineCap);
      }

      final children = <pw.Widget>[];
      for (var i = 0; i < present.length; i++) {
        final (value, isUrl) = present[i];
        pw.Widget run = isUrl
            ? urlText(value, style: style, maxWidth: urlCap)
            : clampedText(value.trim(), style: style);
        if (i == present.length - 1) {
          children.add(run);
          break;
        }
        if (!isUrl && lineCap != null) {
          run = pw.ConstrainedBox(
            constraints: pw.BoxConstraints(maxWidth: lineCap),
            child: run,
          );
        }
        children.add(
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              run,
              pw.Text(separator, style: sepStyle, maxLines: 1),
            ],
          ),
        );
      }
      return pw.Wrap(alignment: alignment, children: children);
    },
  );
}

/// Width of a string in [style], in PDF points, at layout time.
double Function(String) _measurer(pw.TextStyle style, pw.Context context) {
  final font = style.font?.getFont(context);
  final size = style.fontSize ?? 12;
  final letterSpacing = (style.letterSpacing ?? 0) / size;
  return (String s) {
    if (s.isEmpty || font == null) return 0;
    try {
      return (font.stringMetrics(s, letterSpacing: letterSpacing) * size).width;
    } catch (_) {
      // A glyph the subset font cannot measure must not take down the render.
      return double.infinity;
    }
  };
}

/// Lays [display] out into at most [maxLines] lines no wider than [limit],
/// returning the newline-joined result.
String _fitUrl(
  String display,
  pw.TextStyle style,
  pw.Context context,
  double limit,
  int maxLines,
) {
  if (!limit.isFinite || limit <= 0) return display;
  if (style.font == null) return display;

  return fitUrlLines(
    display,
    limit: limit,
    maxLines: maxLines,
    width: _measurer(style, context),
  ).join('\n');
}

/// The URL rule's line breaking, with measurement injected.
///
/// Public so it can be tested against a known measure rather than only through
/// a rendered page: this is where "never mid-token" and "always marked with `…`"
/// are actually decided, and both failed silently before.
///
/// Guarantees, for any [limit] > 0 and [maxLines] >= 1:
/// - every returned line measures at most [limit];
/// - at most [maxLines] lines are returned;
/// - a break falls immediately after a URL delimiter unless the run between two
///   delimiters is itself wider than [limit];
/// - if content had to be dropped, the last line ends with `…`.
List<String> fitUrlLines(
  String display, {
  required double limit,
  required int maxLines,
  required double Function(String) width,
}) {
  if (display.isEmpty) return const <String>[];
  if (width(display) <= limit) return <String>[display];

  final lines = <String>[];
  var rest = display;
  while (rest.isNotEmpty) {
    if (lines.length == maxLines - 1) {
      lines.add(_elideUrl(rest, limit, width));
      break;
    }
    final cut = _breakUrl(rest, limit, width);
    lines.add(rest.substring(0, cut));
    rest = rest.substring(cut);
  }
  return lines;
}

/// Length of the longest prefix of [s] whose rendering satisfies [fits].
///
/// Text width is monotonic in prefix length, so this bisects rather than
/// measuring every candidate — the helper runs on every preview render.
int _longestPrefix(int length, bool Function(int) fits) {
  var low = 0;
  var high = length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (fits(mid)) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

/// Longest prefix of [s] that fits [limit], preferring a URL delimiter.
int _breakUrl(String s, double limit, double Function(String) width) {
  if (width(s) <= limit) return s.length;

  final fits = _longestPrefix(
    s.length,
    (n) => width(s.substring(0, n)) <= limit,
  );
  if (fits == 0) return 1; // A single glyph is wider than the box; take one.

  for (var i = fits; i > 0; i--) {
    if (_urlBreakAfter.contains(s[i - 1])) return i;
  }
  return fits; // One unbroken run wider than the column: character break.
}

/// Shortens [s] to one line of at most [limit], marked with `…`.
String _elideUrl(String s, double limit, double Function(String) width) {
  if (width(s) <= limit) return s;

  final slash = s.indexOf('/');
  if (slash > 0) {
    final host = s.substring(0, slash);
    final segments = s
        .substring(slash + 1)
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    for (var keep = segments.length - 1; keep >= 1; keep--) {
      final candidate =
          '$host/…/${segments.sublist(segments.length - keep).join('/')}';
      if (width(candidate) <= limit) return candidate;
    }
  }

  // No middle to drop, or dropping it did not buy enough: cut the tail. This
  // keeps the host and as much of the path as fits, which is strictly more
  // than a bare `host/…` would show.
  final fits = _longestPrefix(
    s.length - 1,
    (n) => width('${s.substring(0, n)}…') <= limit,
  );
  return fits > 0 ? '${s.substring(0, fits)}…' : '…';
}

// ---------------------------------------------------------------------------
// THE SKILLS RULE
//
// Skills is the section this catalog has lost most often, and every loss was
// silent. Three separate failures shipped: Quill and Linen deleted the whole
// section once a resume reached four roles; Terminal drew its `~/skills`
// heading over an empty band, advertising a section it did not contain; and
// eight of the thirteen designs cut a long name off mid-phrase with no mark,
// keeping anywhere from 29 to 62 characters depending on which design the user
// happened to pick. The rule exists so none of the three can come back.
//
// 1. SKILLS IS NEVER THE LAST NON-FLEX CHILD OF A HEIGHT-BOUNDED COLUMN.
//    See the ENGINE HAZARD note above: a `pw.Column` stops laying out at the
//    first child that does not fit and paints nothing from there on. Last
//    position is therefore the first to be deleted. Where a design puts skills
//    at the foot of the page, the *growing* content above it — experience,
//    projects, custom sections — goes in a `pw.Flexible(fit: FlexFit.loose)`,
//    which is measured last and takes only the space that is left. The trailing
//    block is then a plain child again, measured first, and cannot be evicted.
//    `FlexFit.loose` and not `Expanded`: a tight fit would pin the block to the
//    page foot and open a gap on a short resume.
//
// 2. A HEADING AND ITS SKILLS ARE ONE WIDGET. Two sibling children can be split
//    by the same truncation, which is how Terminal ended up with a labelled
//    empty band. A heading over nothing is worse than no section at all: it
//    tells the reader something was lost without saying what. Build the heading
//    and the content as a single indivisible child so they stand or fall
//    together.
//
// 3. A NAME IS DRAWN IN FULL, OR SHORTENED WITH A VISIBLE `…`. Never cut
//    without a mark. There is deliberately **no catalog-wide character budget**
//    for a skill name: Meridian's slate rail is 148 pt and Ledger's row is
//    460 pt, and one number cannot be honest about both — it would either waste
//    the wide designs or truncate the narrow ones twice over. What is shared is
//    the *behaviour*, exactly as it is for a URL (rule item 3 above): how many
//    characters fit is the design's business, that the reader can see something
//    was removed is the catalog's. [markedText] measures with the real font and
//    decides the break itself. It is the counterpart to [clampedText] — same
//    job, except the reader can tell it happened.
//
// 4. A CONTINUOUS RUN SAYS HOW MANY NAMES IT DROPPED. Quill and Linen set
//    skills as one flowing line of names rather than as discrete chips. A name
//    lost off the end of that run leaves no gap and no mark, so [skillRun]
//    closes with `+N more` instead. Chip and meter designs are not given this
//    marker: they enumerate discrete items, and their `take(n)` cap is a
//    declared density decision that a reader can see the shape of. That is a
//    judgement, not an oversight — revisit it if the caps ever start hiding
//    more than they show.
//
// 5. LEVEL 0 MEANS "NOT RATED", NOT "RATED ZERO". The editor's own slider
//    labels it "None". Four designs draw a 0–5 meter, and drawing that meter
//    empty is a lie twice over: it reports a rating the user never gave, and an
//    entirely unfilled track is indistinguishable from one that failed to
//    render. [skillRating] returns null for level 0 and those designs draw the
//    name alone — which is exactly what the six designs that ignore `level`
//    already do, so it is a shape the catalog is already consistent about.
//
// `test/templates/skills_test.dart` holds every design in the registry to items
// 1, 2, 3 and 5, so a template added later cannot quietly opt out.
// ---------------------------------------------------------------------------

/// A skill's rating on the 0–5 scale, or null when the user did not give one.
///
/// See the skills rule, item 5. Out-of-range values are clamped rather than
/// rejected: `level` comes from stored JSON and a bad value must cost the
/// meter, not the render.
int? skillRating(Skill skill) {
  final level = skill.level;
  if (level <= 0) return null;
  return level > 5 ? 5 : level;
}

/// The mark a design uses for skills it did not draw. See the rule, item 4.
String skillsHiddenLabel(int hidden) => '+$hidden more';

/// A section heading and its entries, laid out so the heading can never be left
/// standing alone.
///
/// Skills rule item 2, generalised. A `pw.Column` stops laying out at the first
/// child that does not fit, so a heading and its entries as sibling children
/// can be split exactly between them — which is how Terminal ended up drawing
/// `~/skills` over an empty band. Binding the heading to the *first* entry
/// makes that split impossible, while leaving every later entry a separate
/// child so the section still gives up one row at a time rather than
/// disappearing whole.
///
/// Returns children to be spread into the parent Column, not a single widget:
/// grouping the entries too would trade an orphan heading for an all-or-nothing
/// section, which is the worse of the two.
List<pw.Widget> headedSection({
  required pw.Widget heading,
  required List<pw.Widget> entries,
}) {
  if (entries.isEmpty) return const <pw.Widget>[];
  return <pw.Widget>[
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [heading, entries.first],
    ),
    ...entries.skip(1),
  ];
}

/// Text that is shortened with a visible `…` rather than cut in silence.
///
/// The counterpart to [clampedText], and what the skills rule's item 3 requires
/// for a skill name. Use it for any short user-supplied label whose loss the
/// reader would otherwise have no way to notice — a skill, a technology tag.
/// Prose that already runs to several lines does not need it: a paragraph that
/// stops reads as a paragraph that stops, and an ellipsis on every clipped
/// summary would be noise.
///
/// [maxWidth] is required wherever this sits in a `pw.Row`, whose non-flex
/// children are laid out unbounded; in a `pw.Column` or a `pw.Wrap` the
/// incoming constraint already bounds it and [maxWidth] can be omitted.
pw.Widget markedText(
  String name, {
  required pw.TextStyle style,
  int maxLines = 1,
  double? maxWidth,
  pw.TextAlign? align,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return pw.SizedBox();

  final text = pw.LayoutBuilder(
    builder: (context, constraints) {
      var limit = maxWidth ?? double.infinity;
      if (constraints != null && constraints.hasBoundedWidth) {
        limit = math.min(limit, constraints.maxWidth);
      }
      if (!limit.isFinite || style.font == null) {
        return clampedText(
          trimmed,
          style: style,
          maxLines: maxLines,
          align: align,
        );
      }

      return pw.Text(
        fitTextLines(
          trimmed,
          limit: limit,
          maxLines: maxLines,
          width: _measurer(style, context),
        ).join('\n'),
        style: style,
        // The breaks are already decided and baked into the string; letting the
        // engine wrap again would reintroduce the unmarked cut this exists to
        // prevent.
        softWrap: false,
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
        textAlign: align,
      );
    },
  );

  if (maxWidth == null) return text;
  return pw.ConstrainedBox(
    constraints: pw.BoxConstraints(maxWidth: maxWidth),
    child: text,
  );
}

/// Skill names as one continuous separated run, closed by `+N more` when some
/// of them do not fit. See the skills rule, item 4.
///
/// Names are dropped whole. A run that ended mid-name would read as a typo
/// rather than as a truncation, which is the failure this replaces.
///
/// [maxNames] is the design's own density cap. Names past it are not drawn but
/// are still counted in the marker, because to the reader there is no
/// difference between a name the cap removed and one the last line could not
/// hold.
pw.Widget skillRun(
  List<String> names, {
  required pw.TextStyle style,
  int maxLines = 3,
  int? maxNames,
  String separator = ' · ',
  double? maxWidth,
}) {
  final present = names
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toList(growable: false);
  if (present.isEmpty) return pw.SizedBox();

  final capped = maxNames == null || maxNames >= present.length
      ? present
      : present.sublist(0, math.max(0, maxNames));

  String runOf(int keep) {
    final head = capped.take(keep).join(separator);
    final hidden = present.length - keep;
    if (hidden <= 0) return head;
    final tail = skillsHiddenLabel(hidden);
    return head.isEmpty ? tail : '$head$separator$tail';
  }

  return pw.LayoutBuilder(
    builder: (context, constraints) {
      var limit = maxWidth ?? double.infinity;
      if (constraints != null && constraints.hasBoundedWidth) {
        limit = math.min(limit, constraints.maxWidth);
      }

      pw.Widget draw(String run) => pw.Text(
        fitTextLines(
          run,
          limit: limit,
          maxLines: maxLines,
          width: _measurer(style, context),
        ).join('\n'),
        style: style,
        softWrap: false,
        maxLines: maxLines,
        overflow: pw.TextOverflow.clip,
      );

      if (!limit.isFinite || style.font == null) {
        return clampedText(runOf(capped.length), style: style, maxLines: 1);
      }

      final width = _measurer(style, context);
      for (var keep = capped.length; keep > 0; keep--) {
        if (_lineCount(runOf(keep), limit, width) <= maxLines) {
          return draw(runOf(keep));
        }
      }
      // Not even one name and the marker fit. The marker alone is still true,
      // and it is the one thing on the page that says content is missing.
      return draw(runOf(0));
    },
  );
}

/// Lays [text] out into at most [maxLines] lines no wider than [limit].
///
/// Public so the skills rule's item 3 can be tested against a known measure
/// rather than only through a rendered page — the same reason [fitUrlLines] is.
///
/// Guarantees, for any [limit] > 0 and [maxLines] >= 1:
/// - at most [maxLines] lines are returned;
/// - every line measures at most [limit], unless a single word cannot be
///   broken small enough, in which case one character is taken;
/// - breaks fall on whitespace unless one word is itself wider than [limit];
/// - if content had to be dropped, the last line ends with `…`.
List<String> fitTextLines(
  String text, {
  required double limit,
  required int maxLines,
  required double Function(String) width,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const <String>[];
  if (maxLines < 1 || !limit.isFinite || limit <= 0) return <String>[trimmed];
  if (width(trimmed) <= limit) return <String>[trimmed];

  // Each word carries the whitespace that follows it, so the run's own spacing
  // survives being taken apart and put back together. Splitting on `\s+` and
  // rejoining with one space would silently retype Linen's wide `   ·   `
  // skills separator as a narrow one — a typographic change smuggled in by a
  // line breaker, which is not its job.
  final words = RegExp(
    r'\S+\s*',
  ).allMatches(trimmed).map((m) => m[0]!).toList();

  final lines = <String>[];
  var current = '';
  var i = 0;

  while (i < words.length) {
    // The last line the caller allows: everything still unplaced has to go on
    // it, so this is the only place a `…` is ever added.
    if (lines.length == maxLines - 1) {
      final rest = (current + words.sublist(i).join()).trimRight();
      lines.add(_elideText(rest, limit, width));
      return lines;
    }

    final candidate = current + words[i];
    // Trailing space costs nothing at the end of a line, so it is not measured.
    if (width(candidate.trimRight()) <= limit) {
      current = candidate;
      i++;
      continue;
    }
    if (current.isNotEmpty) {
      lines.add(current.trimRight());
      current = '';
      continue;
    }
    // One word wider than the whole line. There is no whitespace to break on,
    // so it is character-broken — the same last resort the URL rule takes.
    final word = words[i].trimRight();
    final fits = _longestPrefix(
      word.length,
      (n) => width(word.substring(0, n)) <= limit,
    );
    final take = fits < 1 ? 1 : fits;
    lines.add(word.substring(0, take));
    words[i] = words[i].substring(take);
  }
  final tail = current.trimRight();
  if (tail.isNotEmpty) lines.add(tail);
  return lines;
}

/// Lines [text] needs at [limit] with no maximum — i.e. with nothing dropped.
int _lineCount(String text, double limit, double Function(String) width) =>
    fitTextLines(
      text,
      limit: limit,
      // Large enough that the eliding branch is unreachable, so the result is
      // the true cost of the string rather than a clamped one.
      maxLines: 1 << 30,
      width: width,
    ).length;

/// Shortens [s] to one line of at most [limit], marked with `…`.
String _elideText(String s, double limit, double Function(String) width) {
  if (width(s) <= limit) return s;
  final fits = _longestPrefix(
    s.length,
    (n) => width('${s.substring(0, n).trimRight()}…') <= limit,
  );
  if (fits < 1) return '…';
  return '${s.substring(0, fits).trimRight()}…';
}

/// Formats a date range, collapsing empties rather than emitting stray dashes.
String formatRange(String start, String end, {bool current = false}) {
  final e = current ? 'Present' : end.trim();
  final s = start.trim();
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s — $e';
}
