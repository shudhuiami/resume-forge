import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/resume_repository.dart';
import '../models/resume.dart';
import '../render/preview_engine.dart';
import '../render/truncation_check.dart';
import '../templates/registry.dart';

@immutable
class EditorState {
  const EditorState({
    required this.doc,
    this.pdfBytes,
    this.isRendering = false,
    this.renderError,
    this.hasUnsavedChanges = false,
    this.truncation = const TruncationReport.none(),
  });

  final ResumeDocument doc;

  /// Latest successfully built PDF. Also what export sends, so the preview and
  /// the exported file cannot disagree.
  final Uint8List? pdfBytes;

  final bool isRendering;
  final Object? renderError;
  final bool hasUnsavedChanges;

  /// Sections the current design could not fit on the page. Empty when
  /// everything the user typed actually reaches the PDF.
  final TruncationReport truncation;

  ResumeData get data => doc.data;

  EditorState copyWith({
    ResumeDocument? doc,
    Uint8List? pdfBytes,
    bool? isRendering,
    Object? renderError = _noChange,
    bool? hasUnsavedChanges,
    TruncationReport? truncation,
  }) {
    return EditorState(
      doc: doc ?? this.doc,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      isRendering: isRendering ?? this.isRendering,
      renderError: identical(renderError, _noChange)
          ? this.renderError
          : renderError,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      truncation: truncation ?? this.truncation,
    );
  }

  static const _noChange = Object();
}

/// Owns one resume while it is being edited: state, live preview, autosave.
class EditorController extends ChangeNotifier {
  EditorController({
    required ResumeDocument doc,
    required this.repository,
    PreviewEngine? engine,
    this.autosaveDelay = const Duration(milliseconds: 800),
    this.truncationDelay = const Duration(milliseconds: 900),
  }) : _engine = engine ?? PreviewEngine(),
       _state = EditorState(doc: doc) {
    _sub = _engine.results.listen(
      (result) {
        if (_disposed) return;
        state = state.copyWith(
          pdfBytes: result.pdfBytes,
          isRendering: _engine.isBusy,
          renderError: null,
        );
        _scheduleTruncationCheck();
      },
      onError: (Object error) {
        if (_disposed) return;
        state = state.copyWith(isRendering: false, renderError: error);
      },
    );
    _requestPreview();
  }

  final ResumeRepository repository;

  late EditorState _state;
  bool _disposed = false;

  EditorState get state => _state;

  set state(EditorState next) {
    if (_disposed || next == _state) return;
    _state = next;
    notifyListeners();
  }

  final PreviewEngine _engine;
  final Duration autosaveDelay;

  /// How long typing must be quiet before the (render-costly) content check
  /// runs.
  final Duration truncationDelay;

  StreamSubscription<PreviewResult>? _sub;
  Timer? _autosave;

  /// Replaces the resume content.
  ///
  /// Called on every field change, so it must stay cheap: it updates state,
  /// asks the debounced preview for a re-render, and arms the debounced save.
  void updateData(ResumeData Function(ResumeData) transform) {
    final next = transform(state.data);
    if (next == state.data) return;

    state = state.copyWith(
      doc: state.doc.copyWith(data: next, updatedAt: DateTime.now()),
      hasUnsavedChanges: true,
      isRendering: true,
    );
    _requestPreview();
    _armAutosave();
  }

  /// Switches design without touching content — the product's core promise.
  void setTemplate(String templateId) {
    if (!isKnownTemplate(templateId) || templateId == state.doc.templateId) {
      return;
    }
    state = state.copyWith(
      doc: state.doc.copyWith(
        templateId: templateId,
        updatedAt: DateTime.now(),
      ),
      hasUnsavedChanges: true,
      isRendering: true,
    );
    _requestPreview();
    _armAutosave();
  }

  /// Re-runs the preview after a failed render.
  ///
  /// Without this the only way out of a render error was to type something
  /// else, because [updateData] and [setTemplate] both no-op when nothing
  /// changed — leaving the preview's Retry affordance with nothing to call.
  void retryPreview() {
    if (_disposed) return;
    state = state.copyWith(isRendering: true, renderError: null);
    _requestPreview();
  }

  void _requestPreview() => _engine.request(state.data, state.doc.templateId);

  void _armAutosave() {
    _autosave?.cancel();
    _autosave = Timer(autosaveDelay, saveNow);
  }

  /// Writes immediately. Called by the debounce, on app pause, and on leaving
  /// the editor — a backgrounded mobile app can be killed without warning, so
  /// waiting out a debounce is not safe.
  Future<void> saveNow() async {
    _autosave?.cancel();
    if (_disposed) return;
    final doc = state.doc;
    try {
      await repository.save(doc);
      if (_disposed) return;
      state = state.copyWith(hasUnsavedChanges: false);
    } catch (_) {
      // Keep the dirty flag so a later save retries rather than silently
      // dropping the user's work.
    }
  }

  Timer? _truncationTimer;
  int _truncationRun = 0;

  /// Checks for dropped content after the preview settles.
  ///
  /// Deliberately lazier than the preview: the check costs a render per
  /// populated section, so it waits for typing to stop and skips entirely for
  /// resumes too short to be at risk. The user learns while they are still
  /// editing rather than at the export dialog, which is the point.
  void _scheduleTruncationCheck() {
    _truncationTimer?.cancel();
    if (!TruncationCheck.mightOverflow(state.data)) {
      if (state.truncation.hasLoss) {
        state = state.copyWith(truncation: const TruncationReport.none());
      }
      return;
    }
    _truncationTimer = Timer(truncationDelay, _runTruncationCheck);
  }

  Future<void> _runTruncationCheck() async {
    final run = ++_truncationRun;
    final data = state.data;
    try {
      final report = await TruncationCheck.run(
        template: templateById(state.doc.templateId),
        data: data,
      );
      // Discard a result the user has already typed past.
      if (_disposed || run != _truncationRun) return;
      state = state.copyWith(truncation: report);
    } catch (_) {
      // A failed check must not claim content is fine or that it is lost.
      // Leaving the previous answer in place is the honest fallback.
    }
  }

  /// Builds the exact bytes to export, bypassing the debounce.
  Future<Uint8List> buildForExport() =>
      _engine.renderNow(state.data, state.doc.templateId);

  @override
  void dispose() {
    _disposed = true;
    _truncationTimer?.cancel();
    _autosave?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }
}
