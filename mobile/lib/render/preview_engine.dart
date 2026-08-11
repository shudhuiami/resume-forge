import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/resume.dart';
import '../templates/fonts.dart';
import '../templates/registry.dart';
import 'render_job.dart';

/// Result of one preview render.
@immutable
class PreviewResult {
  const PreviewResult({required this.pdfBytes, required this.revision});

  final Uint8List pdfBytes;

  /// Monotonic counter of the request that produced these bytes. Lets a
  /// consumer discard a late result that a newer request has superseded.
  final int revision;
}

/// Drives the debounced background render behind the live preview.
///
/// The contract that matters: **the preview is the PDF.** These bytes are the
/// same bytes the user exports, so the preview cannot drift from the file.
///
/// Three behaviours make it usable while typing:
/// * Edits are debounced, so a keystroke does not start a render.
/// * The render runs through `compute` — a real isolate on mobile, inline on
///   web where isolates do not exist.
/// * While a render is in flight, further edits mark the job dirty rather than
///   queueing; when it finishes, exactly one follow-up render runs with the
///   latest state. Without this, holding a key would queue a render per
///   keystroke and the preview would lag further behind the longer you type.
class PreviewEngine {
  PreviewEngine({
    this.debounce = const Duration(milliseconds: 300),
    Future<Uint8List> Function(RenderJob)? runner,
  }) : _runner = runner ?? _defaultRunner;

  final Duration debounce;
  final Future<Uint8List> Function(RenderJob) _runner;

  static Future<Uint8List> _defaultRunner(RenderJob job) =>
      compute(renderJobEntryPoint, job);

  final _controller = StreamController<PreviewResult>.broadcast();

  /// Emits a result per completed render, newest last.
  Stream<PreviewResult> get results => _controller.stream;

  Timer? _timer;
  bool _rendering = false;
  bool _dirty = false;
  int _revision = 0;
  ResumeData? _pending;
  String? _pendingTemplateId;
  bool _disposed = false;

  /// True while a render is running or scheduled — drives a subtle busy
  /// indicator without flashing the preview blank.
  bool get isBusy => _rendering || _timer?.isActive == true;

  /// Requests a preview for [data] on [templateId].
  ///
  /// Safe to call on every keystroke.
  void request(ResumeData data, String templateId) {
    if (_disposed) return;
    _pending = data;
    _pendingTemplateId = templateId;

    if (_rendering) {
      // Coalesce: the in-flight render will pick up this state when it lands.
      _dirty = true;
      return;
    }

    _timer?.cancel();
    _timer = Timer(debounce, _run);
  }

  /// Renders immediately, bypassing the debounce.
  ///
  /// Used for export and for the first paint, where waiting out the debounce
  /// would show an empty page for no reason.
  ///
  /// Deliberately does **not** cancel a queued preview render. Cancelling it
  /// looked like a saving — the export is rendering the same content anyway —
  /// but it stranded the caller: an edit followed by an export inside the
  /// debounce window dropped the queued render, so the editor kept stale bytes
  /// and stayed `isRendering` forever, showing a spinner that never resolved.
  /// A duplicate render costs far less than a stuck preview.
  Future<Uint8List> renderNow(ResumeData data, String templateId) async {
    final job = await _buildJob(data, templateId);
    return _runner(job);
  }

  Future<void> _run() async {
    final data = _pending;
    final templateId = _pendingTemplateId;
    if (data == null || templateId == null || _disposed) return;

    _rendering = true;
    _dirty = false;
    final revision = ++_revision;

    try {
      final job = await _buildJob(data, templateId);
      final bytes = await _runner(job);
      if (!_disposed && !_controller.isClosed) {
        _controller.add(PreviewResult(pdfBytes: bytes, revision: revision));
      }
    } catch (error, stack) {
      // A render failure must not kill the stream — the editor stays usable
      // and keeps showing the last good frame.
      if (!_disposed && !_controller.isClosed) {
        _controller.addError(error, stack);
      }
    } finally {
      _rendering = false;
      if (_dirty && !_disposed) {
        _dirty = false;
        unawaited(_run());
      }
    }
  }

  Future<RenderJob> _buildJob(ResumeData data, String templateId) async {
    final template = templateById(templateId);
    final fontBytes = await ResumeFonts.loadBytes(template.requiredFonts);
    return RenderJob(
      templateId: template.id,
      resumeJson: data.toJson(),
      fontBytes: fontBytes,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _controller.close();
  }
}
