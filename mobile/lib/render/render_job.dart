import 'dart:typed_data';

import '../models/resume.dart';
import '../templates/fonts.dart';
import '../templates/registry.dart';
import 'pdf_renderer.dart';

/// A self-contained render request that can cross an isolate boundary.
///
/// Everything here copies cleanly: the resume travels as JSON, fonts as raw
/// bytes, and the template as its id (looked up again on the far side). No
/// parsed font objects, no widgets, no closures.
class RenderJob {
  const RenderJob({
    required this.templateId,
    required this.resumeJson,
    required this.fontBytes,
  });

  final String templateId;
  final Map<String, dynamic> resumeJson;
  final Map<FontFamily, FamilyBytes> fontBytes;
}

/// Isolate entry point.
///
/// Must stay top-level: `compute` cannot take a closure or instance method.
/// On web there are no isolates and `compute` runs this inline, which is
/// correct — the debounce is what keeps typing responsive there.
Future<Uint8List> renderJobEntryPoint(RenderJob job) async {
  final template = templateById(job.templateId);
  final data = ResumeData.fromJson(job.resumeJson);
  final families = {
    for (final entry in job.fontBytes.entries) entry.key: entry.value.parse(),
  };

  return PdfRenderer.renderWith(
    template: template,
    data: data,
    families: families,
  );
}
