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

/// Formats a date range, collapsing empties rather than emitting stray dashes.
String formatRange(String start, String end, {bool current = false}) {
  final e = current ? 'Present' : end.trim();
  final s = start.trim();
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s — $e';
}
