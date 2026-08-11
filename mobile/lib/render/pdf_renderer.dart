import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../models/resume.dart';
import '../templates/fonts.dart';
import '../templates/template.dart';

/// Builds the single source of truth for a resume: the PDF itself.
///
/// The on-screen preview rasterizes the bytes this returns, so there is no
/// second rendering path that could disagree with the exported file.
abstract final class PdfRenderer {
  /// Renders [template] against [data] and returns PDF bytes.
  ///
  /// Fonts must already be loaded and passed in; asset loading is kept out of
  /// this method so it can run inside an isolate, where `rootBundle` is
  /// unavailable. Everything it does touch is pure Dart.
  static Future<Uint8List> renderWith({
    required ResumeTemplate template,
    required ResumeData data,
    required Map<FontFamily, LoadedFamily> families,
  }) async {
    final doc = pw.Document(
      title: data.personalInfo.fullName.isEmpty
          ? 'Resume'
          : '${data.personalInfo.fullName} — Resume',
      author: data.personalInfo.fullName.isEmpty
          ? null
          : data.personalInfo.fullName,
    );

    final ctx = TemplateContext(
      data: data,
      palette: template.palette,
      families: families,
    );

    doc.addPage(
      pw.Page(
        pageFormat: a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => template.build(ctx),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  /// Loads every family [template] declares, then renders.
  static Future<Uint8List> build({
    required ResumeTemplate template,
    required ResumeData data,
  }) async {
    final families = await ensureFonts(template);
    return renderWith(template: template, data: data, families: families);
  }

  /// Resolves a template's declared font families.
  static Future<Map<FontFamily, LoadedFamily>> ensureFonts(
    ResumeTemplate template,
  ) async {
    final entries = await Future.wait(
      template.requiredFonts.map(
        (f) async => MapEntry(f, await ResumeFonts.load(f)),
      ),
    );
    return Map.fromEntries(entries);
  }
}
