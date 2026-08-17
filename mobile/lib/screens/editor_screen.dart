import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/photo_service.dart';
import '../data/sample_resume.dart';
import '../models/resume.dart';
import '../render/pdf_export.dart';
import '../render/truncation_check.dart';
import '../state/app_providers.dart';
import '../state/editor_controller.dart';
import '../templates/registry.dart';
import '../theme/tokens.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_fields.dart';
import '../widgets/pdf_page_view.dart';
import 'gallery_screen.dart';

/// Widest the editor form is allowed to grow. Beyond this a single-line field
/// stretches far past a comfortable reading measure and the form stops looking
/// like a document editor.
const _maxFormWidth = 640.0;

/// Form-first resume editor.
///
/// The preview lives in its own tab rather than beside the form. An A4 page
/// scaled to phone width puts body text near 5pt — too small to read and far
/// too small to touch — so editing happens in the form and the page is
/// something you check, not something you type into.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.document, this.fileSaver});

  final ResumeDocument document;

  /// Seam for the platform save dialog.
  ///
  /// Null in the app, which is what makes [PdfExport.save] use the real
  /// Storage Access Framework picker. A widget test passes a stub so the
  /// saved / dismissed / failed outcomes can each be driven through the UI —
  /// none of them is reachable otherwise, because the picker is an activity no
  /// test can answer.
  @visibleForTesting
  final PdfFileSaver? fileSaver;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final EditorController _controller;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = EditorController(
      doc: widget.document,
      repository: ref.read(repositoryProvider),
    );
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded app can be killed without further warning, so flush
    // rather than waiting out the autosave debounce.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.saveNow();
    // The undo offer cannot outlive the editor it undoes into. Dismissing an
    // already-dismissed toast is a no-op, so no guard is needed here.
    _undoBar?.dismiss();
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// True from the tap on Done until the editor is off the stack. Keeps a
  /// double tap from popping twice, which would take the resume list with it.
  bool _leaving = false;

  /// Flushes anything still owed to storage, then goes back to the list.
  ///
  /// Not a save button, and deliberately not labelled as one: every keystroke
  /// is already on its way to disk and the indicator beside the title has been
  /// saying so. What this adds is the *end* of the job — a way out that is a
  /// control rather than a gesture, and one that closes the one window where
  /// leaving could show the list a stale row: the 800ms the autosave debounce
  /// is still counting down.
  ///
  /// No toast on the way out. It would fire on every single exit to repeat
  /// what the indicator already said, and the list the user lands on shows the
  /// saved document itself — a confirmation that something was written, from
  /// the thing that was written. Toasts in this app are spent on outcomes
  /// nothing on screen can show.
  Future<void> _done() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _controller.saveNow();
      if (!mounted) return;

      // The one exit worth interrupting. Leaving now would drop the edits
      // with the controller, so this stays put and says why instead.
      if (_controller.state.saveState == SaveState.failed) {
        AppToast.show(
          context,
          message: 'Could not save this resume. Your changes are still here.',
          variant: ToastVariant.error,
          actionLabel: 'Try again',
          onAction: _done,
        );
        return;
      }
      Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  /// True from the tap until the platform has been handed the PDF. Keeps the
  /// action from being fired twice, which would build the document twice and
  /// stack two share sheets.
  bool _exporting = false;

  /// Asks where the PDF should go, then sends it there.
  ///
  /// The question comes *before* the build rather than after it. It costs
  /// nothing while nothing is happening, it keeps the number of things
  /// stacked on top of the progress snackbar down to the truncation warning
  /// alone, and a user who backs out never pays for a render they did not
  /// want.
  Future<void> _export() async {
    if (_exporting) return;

    // One option is not a choice. Where the platform has no save picker —
    // web and desktop, per `canSaveToDisk` — the tap goes straight to the
    // share sheet, exactly as it did before this chooser existed, rather than
    // opening a sheet with a single row or a row that is only there to be
    // disabled.
    final destination = PdfExport.canSaveToDisk
        ? await _chooseExportDestination()
        : _ExportDestination.share;
    if (destination == null || !mounted) return;

    await _runExport(destination);
  }

  Future<_ExportDestination?> _chooseExportDestination() =>
      _showChooser<_ExportDestination>(
        context,
        title: 'Export PDF',
        options: const [
          _ChooserOption(
            value: _ExportDestination.share,
            // The same glyph as the app bar action that opened this sheet.
            icon: Icons.ios_share,
            label: 'Share',
            description: 'Send the PDF through another app.',
          ),
          _ChooserOption(
            value: _ExportDestination.save,
            icon: Icons.save_alt,
            label: 'Save to device',
            description: 'Choose where to keep the file.',
          ),
        ],
      );

  Future<void> _runExport(_ExportDestination destination) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    // Held open for exactly as long as the work takes. A fixed duration was
    // wrong in both directions: it vanished mid-build on a slow render,
    // leaving the app looking idle, and it lingered over the share sheet on a
    // fast one. The progress variant never auto-dismisses for that reason.
    final progress = AppToast.showProgress(context, message: 'Preparing PDF…');

    try {
      // Run alongside the export build rather than after it: the check costs
      // one render per populated section, and serialising them would double
      // the wait before the share sheet appears.
      final results = await Future.wait([
        _controller.buildForExport(),
        TruncationCheck.run(
          template: templateById(_controller.state.doc.templateId),
          data: _controller.state.data,
        ),
      ]);
      final bytes = results[0] as Uint8List;
      final truncation = results[1] as TruncationReport;

      // Closed before the sheet opens, and unconditionally — this toast
      // outlives the route, so an early back press must not strand it.
      progress.dismiss();
      if (!mounted) return;

      // Templates drop content that does not fit rather than flowing to a
      // second page, so a long career can lose whole roles. Sending a resume
      // with a job missing is worse than any delay this dialog costs.
      if (truncation.hasLoss && !await _confirmTruncatedExport(truncation)) {
        return;
      }
      if (!mounted) return;

      final info = _controller.state.data.personalInfo;
      final outcome = switch (destination) {
        _ExportDestination.share => await PdfExport.share(
          pdfBytes: bytes,
          info: info,
        ),
        _ExportDestination.save => await PdfExport.save(
          pdfBytes: bytes,
          info: info,
          saver: widget.fileSaver,
        ),
      };
      if (!mounted) return;

      switch (outcome.status) {
        // The platform share sheet is its own confirmation, and a sheet or
        // picker the user backed out of is them changing their mind. Neither
        // is worth a message.
        case ExportStatus.shared:
        case ExportStatus.dismissed:
          break;
        // A save picker closes leaving no trace of what happened, so this is
        // the one outcome that has to say so itself. It says the *name*: the
        // location the platform hands back is a `content://` URI, which is
        // documented as unfit to show a user.
        case ExportStatus.saved:
          AppToast.show(
            context,
            message: 'Saved as ${PdfExport.fileNameFor(info)}',
            variant: ToastVariant.success,
          );
        case ExportStatus.failed:
          _showExportFailure(outcome.message, destination);
      }
    } catch (_) {
      progress.dismiss();
      if (!mounted) return;
      _showExportFailure('Could not prepare the PDF for export.', destination);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Warns that the PDF is missing content, and lets the user decide.
  ///
  /// Deliberately not a silent block and not a silent send: the user is the
  /// only one who knows whether a shorter resume is acceptable, but they
  /// cannot make that call if nothing tells them content was cut.
  Future<bool> _confirmTruncatedExport(TruncationReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Some content will be left out'),
        content: Text(
          '${report.describe()}\n\n'
          'Shorten your entries, or pick a design that fits more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go back and edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export anyway'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showExportFailure(String? message, _ExportDestination destination) {
    AppToast.show(
      context,
      message: message ?? 'Could not export the PDF.',
      variant: ToastVariant.error,
      actionLabel: 'Try again',
      // Retries the destination the user already picked rather than
      // reopening the chooser: they answered that question once, and a
      // failed save is not a reason to ask it again.
      onAction: () => _runExport(destination),
    );
  }

  /// Swaps the design without touching content — the product's core promise,
  /// so this must never round-trip through anything that could drop fields.
  Future<void> _changeTemplate() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (routeContext) => GalleryScreen(
          selectedId: _controller.state.doc.templateId,
          onSelected: (id) => Navigator.of(routeContext).pop(id),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _controller.setTemplate(picked);
    // Jump to the preview so the change is visible immediately; switching a
    // design and being left staring at the form reads as nothing happening.
    _tabs.animateTo(1);
  }

  /// True while a photo request is in flight.
  ///
  /// The platform picker is single-flight — a second request comes back as
  /// `already_active` — so a double tap is dropped here rather than turned
  /// into an error the user has to read and dismiss.
  bool _pickingPhoto = false;

  /// Asks where the photo should come from, then goes and gets it.
  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;

    // One option is not a choice. A device that reports no camera is offered
    // the library directly — which is what this button did before the chooser
    // existed — rather than a sheet with one row, or a camera row sitting
    // there greyed out with nothing to say for itself.
    final source = ref.read(photoServiceProvider).supportsCamera
        ? await _choosePhotoSource()
        : _PhotoSource.gallery;
    if (source == null || !mounted) return;

    await _pickPhotoFrom(source);
  }

  Future<_PhotoSource?> _choosePhotoSource() {
    final hasPhoto = _controller.state.data.personalInfo.photo != null;
    return _showChooser<_PhotoSource>(
      context,
      // Says which of the two things the tap is about to do, since the same
      // sheet serves the empty tile and the replace action.
      title: hasPhoto ? 'Replace photo' : 'Add photo',
      options: const [
        _ChooserOption(
          value: _PhotoSource.camera,
          icon: Icons.photo_camera_outlined,
          label: 'Take a photo',
          description: 'Open the camera and capture one now.',
        ),
        _ChooserOption(
          value: _PhotoSource.gallery,
          // Worded to match the service's own advice when the camera is
          // unavailable — "Choose an existing photo instead" then names a row
          // that is really on the sheet.
          icon: Icons.photo_library_outlined,
          label: 'Choose an existing photo',
          description: 'Pick one from your photo library.',
        ),
      ],
    );
  }

  Future<void> _pickPhotoFrom(_PhotoSource source) async {
    if (_pickingPhoto) return;
    _pickingPhoto = true;

    final service = ref.read(photoServiceProvider);
    try {
      final result = switch (source) {
        _PhotoSource.camera => await service.pickFromCamera(),
        _PhotoSource.gallery => await service.pickFromGallery(),
      };
      if (!mounted) return;

      switch (result.status) {
        case PhotoPickStatus.picked:
          _controller.updateData(
            (d) => d.copyWith(
              personalInfo: d.personalInfo.copyWith(photo: result.bytes),
            ),
          );
        // Backing out of the camera or the library is not a failure and says
        // nothing, exactly as a dismissed chooser says nothing.
        case PhotoPickStatus.cancelled:
          break;
        case PhotoPickStatus.denied:
        case PhotoPickStatus.failed:
          _showPhotoProblem(result.message, source);
      }
    } finally {
      _pickingPhoto = false;
    }
  }

  /// Surfaces the service's own explanation of a failed pick.
  ///
  /// The sentence is the service's, never this screen's: it is what tells a
  /// device with no camera (nothing to fix, use the library) apart from a
  /// refused permission (fixable in Settings), and replacing it with one
  /// generic line here would throw that distinction away.
  void _showPhotoProblem(String? message, _PhotoSource source) {
    AppToast.show(
      context,
      message: message ?? 'Could not add the photo.',
      variant: ToastVariant.error,
      // Every way the camera can fail — no hardware, a refused permission,
      // no camera app — leaves exactly one way forward, and the message
      // already names it. This is that sentence made tappable, so the user
      // is not sent back to hunt for the button they just used. A library
      // failure has no such second route, so it gets no action.
      actionLabel: source == _PhotoSource.camera ? 'Choose photo' : null,
      onAction: source == _PhotoSource.camera
          ? () => _pickPhotoFrom(_PhotoSource.gallery)
          : null,
    );
  }

  /// The live undo offer, if one is showing. Held so it can be closed when the
  /// editor goes away — a toast lives in the overlay and outlives its route,
  /// and an Undo that no longer has an editor to act on is a dead button.
  ToastHandle? _undoBar;

  /// True when there is anything at all in this resume worth losing.
  ///
  /// Stricter than [ResumeData.isEmpty], which ignores a photo and a
  /// half-filled entry — both of which a destructive action would still throw
  /// away.
  bool get _hasContent => _controller.state.data != const ResumeData();

  /// Replaces the entire document in one step, through the same path as a
  /// normal edit so autosave, the preview, and the truncation check all run.
  ///
  /// Nothing extra is needed to make the change visible: the fields are
  /// controller-backed and follow the model wherever the change came from.
  /// This used to bump a revision counter that the form was keyed on, which
  /// rebuilt every field from scratch to work around uncontrolled fields that
  /// only ever read their value once.
  void _replaceData(ResumeData next, {required String message}) {
    final previous = _controller.state.data;
    _controller.updateData((_) => next);

    // Only one undo offer can be live: the previous one undoes into a
    // document that no longer exists.
    _undoBar?.dismiss();
    _undoBar = AppToast.show(
      context,
      message: message,
      // Long enough to notice that everything changed and to act on it.
      actionLabel: 'Undo',
      onAction: () {
        if (!mounted) return;
        _controller.updateData((_) => previous);
      },
    );
  }

  /// Fills the resume with the example document.
  ///
  /// Reuses the same fixture the gallery renders its thumbnails from, so what
  /// the user picked a design by is what they get when they ask to see it
  /// filled in.
  Future<void> _loadSample() async {
    if (_hasContent) {
      final replace = await confirmDestructive(
        context,
        title: 'Replace what you have written?',
        message:
            'Everything in this resume is swapped for an example one. '
            'Your design stays as it is.',
        confirmLabel: 'Replace',
      );
      if (!replace || !mounted) return;
    }
    _replaceData(sampleResume, message: 'Sample resume loaded.');
  }

  Future<void> _clearAll() async {
    final clear = await confirmDestructive(
      context,
      title: 'Clear this resume?',
      message:
          'Every field is emptied, including your photo. '
          'Your design stays as it is.',
      confirmLabel: 'Clear',
    );
    if (!clear || !mounted) return;
    _replaceData(const ResumeData(), message: 'Resume cleared.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          appBar: AppBar(
            // Measured, because the title is two lines and a toolbar does not
            // grow to fit one.
            toolbarHeight: _EditorTitle.toolbarHeight(context),
            title: _EditorTitle(
              title: state.doc.displayTitle,
              saveState: state.saveState,
            ),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.edit_outlined), text: 'Edit'),
                Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'Preview'),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _changeTemplate,
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Change design',
              ),
              IconButton(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                tooltip: 'Export PDF',
              ),
              // The finishing action, next to the overflow menu where an
              // "I am done here" control belongs. A check rather than a word
              // because every other control in this bar is a glyph, and a
              // 74px text button here costs the document title more room than
              // a 360px phone has to give.
              IconButton(
                onPressed: _done,
                icon: const Icon(Icons.check),
                tooltip: 'Done',
              ),
              // Whole-document actions live here rather than in a button row
              // above the fields: both are used at most once per resume, and a
              // permanent row would push the first thing the user came to type
              // further down every phone screen.
              _DocumentMenu(
                canClear: _hasContent,
                onLoadSample: _loadSample,
                onClear: _clearAll,
              ),
            ],
          ),
          body: Column(
            children: [
              // Above the tabs so it is visible whether the user is typing or
              // looking at the page. Content that never reaches the PDF is not
              // something to discover at the export dialog.
              //
              // **Always in this list**, drawing nothing when there is no loss
              // to report, so the column's child count and types never change
              // while the user is typing. Everything they have written lives
              // under the `Expanded` below — every field's State, its
              // controller and its FocusNode — and a child list that changes
              // shape is how that subtree gets remounted and the keyboard
              // dropped mid-sentence.
              //
              // Flutter's own reconciliation already survives an insert at the
              // front here, because it matches the trailing children from the
              // bottom of the list and this `Expanded` is last; that is
              // asserted directly in `editor_keyboard_test.dart` rather than
              // assumed. Keeping the count constant makes it structural
              // instead of a property of where the conditional child happens
              // to sit — the alternative, keying the children, states the same
              // thing but only holds while every future edit remembers to
              // carry the keys.
              _TruncationBanner(report: state.truncation),
              Expanded(child: _tabViews(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _tabViews(EditorState state) {
    return TabBarView(
      controller: _tabs,
      children: [
        _EditorForm(controller: _controller, onPickPhoto: _pickPhoto),
        Padding(
          padding: EdgeInsets.all(context.tokens.spaceLg),
          child: PdfPageView(
            pdfBytes: state.pdfBytes,
            isRendering: state.isRendering,
            buildError: state.renderError,
            onRetry: _controller.retryPreview,
          ),
        ),
      ],
    );
  }
}

/// The document's name, and one quiet line under it about whether it is safe.
///
/// The editor autosaves and always has, which is fine right up until someone
/// wants to be *sure* — at which point an editor with no visible save state is
/// indistinguishable from one that is quietly losing their work. This is the
/// answer to that, not a save button: it reports what the controller is
/// actually doing rather than offering a lever that repeats what already
/// happened.
///
/// **A second line rather than a chip beside the name.** Laid out inline it
/// was measured off the screen: with a leading arrow and four actions, a 360px
/// phone leaves the title around 100px, and the status could only fit by
/// dropping to a bare glyph — which is not reassurance, it is a symbol nobody
/// asked to learn. Stacked, the word is always there and the name keeps the
/// width it had before this existed. It costs no height at all at normal text
/// size: two lines come to 46px inside the 56px toolbar.
class _EditorTitle extends StatelessWidget {
  const _EditorTitle({required this.title, required this.saveState});

  final String title;
  final SaveState saveState;

  /// Air above and below the two lines, so the block is not pressed against
  /// the status bar and the tab strip.
  static const _breathing = 12.0;

  /// How tall the toolbar has to be for both lines at the current text size.
  ///
  /// [AppBar] does not grow to fit its title — the toolbar is a fixed box and
  /// a title taller than it overflows — so the height is measured with the
  /// real styles at the real scale rather than assumed. Never below
  /// [kToolbarHeight], so nothing shrinks the bar below the standard.
  static double toolbarHeight(BuildContext context) {
    final theme = Theme.of(context);
    final titleLine = _measureText(
      context,
      'Ag',
      theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
    ).height;
    final statusLine = math.max(
      _SaveStatus.glyphSize,
      _measureText(context, 'Ag', _statusStyle(theme, saveOk: true)).height,
    );
    return math.max(kToolbarHeight, titleLine + statusLine + _breathing);
  }

  static TextStyle? _statusStyle(ThemeData theme, {required bool saveOk}) =>
      theme.textTheme.labelMedium?.copyWith(
        color: saveOk
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.error,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        _SaveStatus(
          state: saveState,
          labelStyle: _statusStyle(
            theme,
            saveOk: saveState != SaveState.failed,
          ),
        ),
      ],
    );
  }
}

/// Size [text] takes at the current text size, laid out with the real style.
///
/// Measured rather than assumed for the same reason the skill rating label is:
/// a number that is right at one text size is wrong at every other one.
Size _measureText(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Saving / saved / not saved, in that order of interest.
///
/// Deliberately unshowy: muted ink, label type, no animation and no live
/// region. It changes on every keystroke, and a status that announced itself
/// each time — a spinner, a flash, a screen reader interrupt — would be an
/// alarm bell wired to the space bar. It is here to be *checked*, not noticed.
class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.state, required this.labelStyle});

  final SaveState state;
  final TextStyle? labelStyle;

  /// Fixed, like every other glyph in the chrome: it is a mark, not a line of
  /// copy, and growing it with the type size only steals width from the word
  /// beside it.
  static const glyphSize = 16.0;

  static String labelFor(SaveState state) => switch (state) {
    SaveState.saved => 'Saved',
    SaveState.saving => 'Saving…',
    SaveState.failed => 'Not saved',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = labelFor(state);

    return Semantics(
      label: label,
      // One node saying one thing. Unmerged, the glyph and the word are two
      // separate stops either side of the document's name.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (state) {
              SaveState.saved => Icons.check_circle_outline,
              SaveState.saving => Icons.sync,
              SaveState.failed => Icons.error_outline,
            },
            size: glyphSize,
            color: labelStyle?.color,
          ),
          SizedBox(width: tokens.spaceXs),
          // Flexible: at double text size "Not saved" is wider than the title
          // slot a small phone can spare, and an ellipsis is the one outcome
          // here that is neither an overflow nor a lie.
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

enum _DocumentAction { loadSample, clear }

/// Overflow menu for actions that act on the resume as a whole.
class _DocumentMenu extends StatelessWidget {
  const _DocumentMenu({
    required this.canClear,
    required this.onLoadSample,
    required this.onClear,
  });

  /// False when the resume is already blank — clearing nothing would be a
  /// control that looks live and does nothing.
  final bool canClear;
  final VoidCallback onLoadSample;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<_DocumentAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More actions',
      onSelected: (action) {
        switch (action) {
          case _DocumentAction.loadSample:
            onLoadSample();
          case _DocumentAction.clear:
            onClear();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DocumentAction.loadSample,
          child: _MenuRow(
            icon: Icons.auto_awesome_outlined,
            label: 'Load sample data',
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        PopupMenuItem(
          value: _DocumentAction.clear,
          enabled: canClear,
          child: _MenuRow(
            icon: Icons.backspace_outlined,
            label: 'Clear all fields',
            // Marked as destructive before the tap, not only in the dialog
            // after it. Dropped when disabled so the item still reads as
            // unavailable rather than as a live red action.
            color: canClear ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: context.tokens.spaceMd),
        // A menu is as wide as its widest item, so long labels get a line
        // break rather than a clipped word.
        Flexible(
          child: Text(label, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

class _EditorForm extends StatelessWidget {
  const _EditorForm({required this.controller, required this.onPickPhoto});

  final EditorController controller;
  final VoidCallback onPickPhoto;

  ResumeData get data => controller.state.data;

  void _edit(ResumeData Function(ResumeData) f) => controller.updateData(f);

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final info = data.personalInfo;

    // A tablet-width form runs single-line fields edge to edge across ~736px,
    // which reads as an admin table rather than a document editor and drags the
    // eye across a lot of empty space between a label and its value. Matches
    // the constraint the resume list already applies.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxFormWidth),
        child: _buildForm(context, tokens, info),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppTokens tokens, PersonalInfo info) {
    return ListView(
      // Addressable so tests can scroll this list rather than the TabBarView's
      // own PageView, which is the first Scrollable in the tree.
      key: const Key('editor-form-list'),
      // Room for the keyboard plus the last field, so the bottom entry is not
      // pinned under the keyboard when it opens.
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        MediaQuery.viewInsetsOf(context).bottom + tokens.spaceXxl * 2,
      ),
      children: [
        FormSectionCard(
          icon: Icons.badge_outlined,
          tone: SectionTone.about,
          title: 'About you',
          subtitle: 'The header of every design is built from this.',
          children: [
            _PhotoTile(
              photo: info.photo,
              onPick: onPickPhoto,
              onRemove: () {
                _edit(
                  (d) => d.copyWith(
                    personalInfo: d.personalInfo.copyWith(photo: null),
                  ),
                );
              },
            ),
            SizedBox(height: tokens.spaceLg),
            ResumeTextField(
              label: 'Full name',
              value: info.fullName,
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _edit(
                (d) => d.copyWith(
                  personalInfo: d.personalInfo.copyWith(fullName: v),
                ),
              ),
            ),
            ResumeTextField(
              label: 'Job title',
              value: info.title,
              hint: 'Senior Product Designer',
              onChanged: (v) => _edit(
                (d) =>
                    d.copyWith(personalInfo: d.personalInfo.copyWith(title: v)),
              ),
            ),
            ResumeTextField(
              label: 'Email',
              value: info.email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autofillHints: const [AutofillHints.email],
              onChanged: (v) => _edit(
                (d) =>
                    d.copyWith(personalInfo: d.personalInfo.copyWith(email: v)),
              ),
            ),
            ResumeTextField(
              label: 'Phone',
              value: info.phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              onChanged: (v) => _edit(
                (d) =>
                    d.copyWith(personalInfo: d.personalInfo.copyWith(phone: v)),
              ),
            ),
            ResumeTextField(
              label: 'Location',
              value: info.location,
              onChanged: (v) => _edit(
                (d) => d.copyWith(
                  personalInfo: d.personalInfo.copyWith(location: v),
                ),
              ),
            ),
            ResumeTextField(
              label: 'LinkedIn',
              value: info.linkedin,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.url,
              onChanged: (v) => _edit(
                (d) => d.copyWith(
                  personalInfo: d.personalInfo.copyWith(linkedin: v),
                ),
              ),
            ),
            ResumeTextField(
              label: 'Website',
              value: info.website,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.url,
              onChanged: (v) => _edit(
                (d) => d.copyWith(
                  personalInfo: d.personalInfo.copyWith(website: v),
                ),
              ),
            ),
            ResumeTextField(
              label: 'Summary',
              value: info.summary,
              maxLines: 5,
              helper:
                  'Two or three sentences on what you do and what you are known for.',
              onChanged: (v) => _edit(
                (d) => d.copyWith(
                  personalInfo: d.personalInfo.copyWith(summary: v),
                ),
              ),
            ),
          ],
        ),

        FormSectionCard(
          icon: Icons.work_outline,
          tone: SectionTone.experience,
          title: 'Experience',
          subtitle: data.experiences.isEmpty ? 'No roles added yet' : null,
          children: [
            for (final (i, e) in data.experiences.indexed)
              EntryGroup(
                key: ValueKey(e.id),
                title: 'ROLE ${i + 1}',
                removeTooltip: 'Remove this role',
                onRemove: () => _edit(
                  (d) => d.copyWith(
                    experiences: [...d.experiences]
                      ..removeWhere((x) => x.id == e.id),
                  ),
                ),
                children: [
                  ResumeTextField(
                    label: 'Position',
                    value: e.position,
                    onChanged: (v) =>
                        _editExperience(e.id, (x) => x.copyWith(position: v)),
                  ),
                  ResumeTextField(
                    label: 'Company',
                    value: e.company,
                    onChanged: (v) =>
                        _editExperience(e.id, (x) => x.copyWith(company: v)),
                  ),
                  _DateFieldPair(
                    start: MonthYearField(
                      label: 'Start',
                      value: e.startDate,
                      onChanged: (v) => _editExperience(
                        e.id,
                        (x) => x.copyWith(startDate: v),
                      ),
                    ),
                    end: MonthYearField(
                      label: 'End',
                      value: e.endDate,
                      enabled: !e.current,
                      // The switch below turns this field off, and a field
                      // that has gone quiet with no explanation reads as
                      // broken. This says what the PDF will print instead.
                      disabledHelper: 'Shows “Present”',
                      onChanged: (v) =>
                          _editExperience(e.id, (x) => x.copyWith(endDate: v)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: e.current,
                    title: const Text('I currently work here'),
                    onChanged: (v) => _editExperience(
                      e.id,
                      // Clearing the end date matters: a stale value would keep
                      // rendering behind the "Present" label in the PDF.
                      (x) =>
                          x.copyWith(current: v, endDate: v ? '' : x.endDate),
                    ),
                  ),
                  ResumeTextField(
                    label: 'What you did',
                    value: e.description,
                    maxLines: 4,
                    onChanged: (v) => _editExperience(
                      e.id,
                      (x) => x.copyWith(description: v),
                    ),
                  ),
                ],
              ),
            SizedBox(height: tokens.spaceSm),
            AddEntryButton(
              label: 'Add role',
              onPressed: () => _edit(
                (d) => d.copyWith(
                  experiences: [
                    ...d.experiences,
                    Experience(id: _newId('exp')),
                  ],
                ),
              ),
            ),
          ],
        ),

        FormSectionCard(
          icon: Icons.school_outlined,
          tone: SectionTone.education,
          title: 'Education',
          subtitle: data.education.isEmpty ? 'No education added yet' : null,
          children: [
            for (final (i, e) in data.education.indexed)
              EntryGroup(
                key: ValueKey(e.id),
                title: 'EDUCATION ${i + 1}',
                removeTooltip: 'Remove this entry',
                onRemove: () => _edit(
                  (d) => d.copyWith(
                    education: [...d.education]
                      ..removeWhere((x) => x.id == e.id),
                  ),
                ),
                children: [
                  ResumeTextField(
                    label: 'Institution',
                    value: e.institution,
                    onChanged: (v) =>
                        _editEducation(e.id, (x) => x.copyWith(institution: v)),
                  ),
                  ResumeTextField(
                    label: 'Degree',
                    value: e.degree,
                    onChanged: (v) =>
                        _editEducation(e.id, (x) => x.copyWith(degree: v)),
                  ),
                  ResumeTextField(
                    label: 'Field of study',
                    value: e.field,
                    onChanged: (v) =>
                        _editEducation(e.id, (x) => x.copyWith(field: v)),
                  ),
                  _DateFieldPair(
                    start: MonthYearField(
                      label: 'Start',
                      value: e.startDate,
                      onChanged: (v) =>
                          _editEducation(e.id, (x) => x.copyWith(startDate: v)),
                    ),
                    end: MonthYearField(
                      label: 'End',
                      value: e.endDate,
                      onChanged: (v) =>
                          _editEducation(e.id, (x) => x.copyWith(endDate: v)),
                    ),
                  ),
                ],
              ),
            SizedBox(height: tokens.spaceSm),
            AddEntryButton(
              label: 'Add education',
              onPressed: () => _edit(
                (d) => d.copyWith(
                  education: [
                    ...d.education,
                    Education(id: _newId('edu')),
                  ],
                ),
              ),
            ),
          ],
        ),

        FormSectionCard(
          icon: Icons.bolt_outlined,
          tone: SectionTone.skills,
          title: 'Skills',
          subtitle:
              'Rated out of five. Some designs show the rating, some just the name.',
          children: [
            for (final s in data.skills)
              EntryGroup(
                key: ValueKey(s.id),
                title: s.name.isEmpty ? 'SKILL' : s.name.toUpperCase(),
                removeTooltip: 'Remove this skill',
                onRemove: () => _edit(
                  (d) => d.copyWith(
                    skills: [...d.skills]..removeWhere((x) => x.id == s.id),
                  ),
                ),
                children: [
                  ResumeTextField(
                    label: 'Skill',
                    value: s.name,
                    onChanged: (v) =>
                        _editSkill(s.id, (x) => x.copyWith(name: v)),
                  ),
                  _SkillSlider(
                    value: s.level,
                    onChanged: (v) =>
                        _editSkill(s.id, (x) => x.copyWith(level: v)),
                  ),
                ],
              ),
            SizedBox(height: tokens.spaceSm),
            AddEntryButton(
              label: 'Add skill',
              onPressed: () => _edit(
                (d) => d.copyWith(
                  skills: [
                    ...d.skills,
                    Skill(id: _newId('sk')),
                  ],
                ),
              ),
            ),
          ],
        ),

        FormSectionCard(
          icon: Icons.rocket_launch_outlined,
          tone: SectionTone.projects,
          title: 'Projects',
          subtitle: data.projects.isEmpty ? 'No projects added yet' : null,
          children: [
            for (final p in data.projects)
              EntryGroup(
                key: ValueKey(p.id),
                title: p.name.isEmpty ? 'PROJECT' : p.name.toUpperCase(),
                removeTooltip: 'Remove this project',
                onRemove: () => _edit(
                  (d) => d.copyWith(
                    projects: [...d.projects]..removeWhere((x) => x.id == p.id),
                  ),
                ),
                children: [
                  ResumeTextField(
                    label: 'Name',
                    value: p.name,
                    onChanged: (v) =>
                        _editProject(p.id, (x) => x.copyWith(name: v)),
                  ),
                  ResumeTextField(
                    label: 'Description',
                    value: p.description,
                    maxLines: 3,
                    onChanged: (v) =>
                        _editProject(p.id, (x) => x.copyWith(description: v)),
                  ),
                  ResumeTextField(
                    label: 'Technologies',
                    value: p.technologies,
                    helper: 'Comma separated — each becomes a chip.',
                    onChanged: (v) =>
                        _editProject(p.id, (x) => x.copyWith(technologies: v)),
                  ),
                  ResumeTextField(
                    label: 'Link',
                    value: p.link,
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (v) =>
                        _editProject(p.id, (x) => x.copyWith(link: v)),
                  ),
                ],
              ),
            SizedBox(height: tokens.spaceSm),
            AddEntryButton(
              label: 'Add project',
              onPressed: () => _edit(
                (d) => d.copyWith(
                  projects: [
                    ...d.projects,
                    Project(id: _newId('prj')),
                  ],
                ),
              ),
            ),
          ],
        ),

        FormSectionCard(
          icon: Icons.dashboard_customize_outlined,
          tone: SectionTone.custom,
          title: 'Custom sections',
          subtitle: 'Certifications, publications, languages — anything else.',
          children: [
            for (final section in data.customSections)
              EntryGroup(
                key: ValueKey(section.id),
                title: section.sectionTitle.isEmpty
                    ? 'SECTION'
                    : section.sectionTitle.toUpperCase(),
                removeTooltip: 'Remove this section',
                onRemove: () => _edit(
                  (d) => d.copyWith(
                    customSections: [...d.customSections]
                      ..removeWhere((x) => x.id == section.id),
                  ),
                ),
                children: [
                  ResumeTextField(
                    label: 'Section title',
                    value: section.sectionTitle,
                    onChanged: (v) => _editSection(
                      section.id,
                      (x) => x.copyWith(sectionTitle: v),
                    ),
                  ),
                  for (final item in section.items)
                    Padding(
                      key: ValueKey(item.id),
                      padding: EdgeInsets.only(bottom: tokens.spaceSm),
                      child: Column(
                        children: [
                          ResumeTextField(
                            label: 'Title',
                            value: item.title,
                            onChanged: (v) => _editSectionItem(
                              section.id,
                              item.id,
                              (x) => x.copyWith(title: v),
                            ),
                          ),
                          ResumeTextField(
                            label: 'Subtitle',
                            value: item.subtitle,
                            onChanged: (v) => _editSectionItem(
                              section.id,
                              item.id,
                              (x) => x.copyWith(subtitle: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  AddEntryButton(
                    label: 'Add item',
                    onPressed: () => _editSection(
                      section.id,
                      (x) => x.copyWith(
                        items: [
                          ...x.items,
                          CustomItem(id: _newId('ci')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: tokens.spaceSm),
            AddEntryButton(
              label: 'Add section',
              onPressed: () => _edit(
                (d) => d.copyWith(
                  customSections: [
                    ...d.customSections,
                    CustomSection(id: _newId('cs')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _editExperience(String id, Experience Function(Experience) f) => _edit(
    (d) => d.copyWith(
      experiences: [
        for (final x in d.experiences)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editEducation(String id, Education Function(Education) f) => _edit(
    (d) => d.copyWith(
      education: [
        for (final x in d.education)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editSkill(String id, Skill Function(Skill) f) => _edit(
    (d) => d.copyWith(
      skills: [
        for (final x in d.skills)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editProject(String id, Project Function(Project) f) => _edit(
    (d) => d.copyWith(
      projects: [
        for (final x in d.projects)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editSection(String id, CustomSection Function(CustomSection) f) =>
      _edit(
        (d) => d.copyWith(
          customSections: [
            for (final x in d.customSections)
              if (x.id == id) f(x) else x,
          ],
        ),
      );

  void _editSectionItem(
    String sectionId,
    String itemId,
    CustomItem Function(CustomItem) f,
  ) => _editSection(
    sectionId,
    (s) => s.copyWith(
      items: [
        for (final i in s.items)
          if (i.id == itemId) f(i) else i,
      ],
    ),
  );
}

/// A start date and an end date: side by side while they fit, stacked when
/// they stop fitting.
///
/// Two dates on one line is the right shape for a form — a role's dates are
/// one fact and reading them as a pair is faster than reading them as a list —
/// right up until half a row cannot hold a date. With the picker button taking
/// a 48px touch target out of each column, double text size on a 360px phone
/// leaves about 94px for the value, and `2019-04` needs more than that: the
/// user's own date gets clipped inside its own field, which is a worse failure
/// than a taller form.
///
/// The switch is measured rather than set at a width breakpoint, because what
/// runs out of room is a string at a text size, not a screen.
class _DateFieldPair extends StatelessWidget {
  const _DateFieldPair({required this.start, required this.end});

  final Widget start;
  final Widget end;

  /// The longest value the field accepts, laid out to find out how much room a
  /// date actually needs here.
  static const _widestValue = '2019-04';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Everything in the field that is not the value: the decoration's
        // leading content padding, and the picker button's touch target.
        final chrome = tokens.spaceLg + tokens.minTouchTarget;
        final needed =
            _measureText(
              context,
              _widestValue,
              theme.textTheme.bodyLarge,
            ).width +
            chrome;
        final column = (constraints.maxWidth - tokens.spaceMd) / 2;

        if (column < needed) {
          return Column(children: [start, end]);
        }
        return Row(
          // The disabled end date carries a helper line under it, so the two
          // columns are not the same height.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: start),
            SizedBox(width: tokens.spaceMd),
            Expanded(child: end),
          ],
        );
      },
    );
  }
}

class _SkillSlider extends StatelessWidget {
  const _SkillSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = [
    'None',
    'Basic',
    'Working',
    'Good',
    'Strong',
    'Expert',
  ];

  /// Most of the row the word is allowed to take. Past this the slider stops
  /// being something anyone can aim at.
  static const _maxLabelFraction = 0.45;

  /// Width the widest rating word needs at the current text size.
  ///
  /// This used to be a flat 68px, which is a fixed graphic's worth of space
  /// given to a line of copy: at double text size "Strong" did not fit, and
  /// because it is one word it could not wrap either — it broke mid-word into
  /// "Stron / g" and the second line spilled up over the slider above. The
  /// widest label is laid out with the real style at the real scale, the same
  /// way the home screen's quick actions measure theirs, so the box is right at
  /// every text size instead of at one of them.
  static double _labelWidth(BuildContext context, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var width = 0.0;
    for (final label in _labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: scaler,
        maxLines: 1,
        textDirection: direction,
      )..layout();
      width = math.max(width, painter.width);
      painter.dispose();
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final clamped = value.clamp(0, 5);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wanted = _labelWidth(context, style) + tokens.spaceSm;
        final width = math.min(
          wanted,
          constraints.maxWidth * _maxLabelFraction,
        );

        return Row(
          children: [
            Expanded(
              child: Slider(
                value: clamped.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                // Screen readers announce the word, not a bare number, which
                // on its own says nothing about what "3" means.
                label: _labels[clamped],
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(
              width: width,
              child: Text(
                _labels[clamped],
                // Belt and braces: if the cap ever bites, the word ellipsizes
                // on one line rather than splitting across two.
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The photo, its explanation, and the actions that change it, as one object.
///
/// Previously an avatar and a button floating above the first text field, with
/// nothing to say what they belonged to. Housed in the same well the fields are
/// punched into so it reads as part of the "About you" group, with the avatar
/// raised back up to a lighter tint so it still stands out as the subject of
/// the controls beneath it.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final dynamic photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  static const _avatarSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final has = photo != null;

    return Container(
      padding: EdgeInsets.all(tokens.spaceLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Raised out of the well it sits in, not sunk further into
                  // it: an empty avatar drawn in the same tint as its
                  // surroundings is a hole, not a placeholder.
                  color: theme.colorScheme.surfaceContainerHigh,
                  // The visible outline, not the decorative hairline: this
                  // circle is the subject of the actions below it, and a tint
                  // step alone leaves it with no edge to speak of.
                  border: Border.all(color: theme.colorScheme.outline),
                  image: has
                      ? DecorationImage(
                          image: MemoryImage(photo),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: has
                    ? null
                    : Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
              SizedBox(width: tokens.spaceLg),
              // The copy takes the remaining width and wraps: at double text
              // size a fixed row of avatar plus two lines is the first thing
              // on this screen that would run off the edge.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photo',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXs / 2),
                    Text(
                      'Optional — not every design shows one.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          // Below the row rather than beside it: a button sharing the row with
          // the avatar and the copy has nowhere left to go once either grows.
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceSm,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(
                  has ? 'Replace photo' : 'Add photo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (has)
                TextButton(onPressed: onRemove, child: const Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where a photo comes from.
enum _PhotoSource { camera, gallery }

/// Where a finished PDF goes.
enum _ExportDestination { share, save }

/// One row of a chooser sheet.
class _ChooserOption<T> {
  const _ChooserOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.description,
  });

  final T value;
  final IconData icon;

  /// The action, in the user's words. Lives in a real [Text], never in a
  /// tooltip: a tooltip is unreachable by touch and by TalkBack.
  final String label;

  /// One line saying what picking this actually does.
  final String description;
}

/// Asks the user to pick one of [options].
///
/// The app's two choosers — photo source and export destination — are the same
/// object with different rows, so they are the same *pattern* rather than two
/// separate inventions: a modal sheet, a heading, and one full-width row per
/// option carrying a recessed mark, the action, and a line explaining it.
///
/// A sheet rather than a dialog because both choices are a branch in a flow the
/// user has already committed to, not a question about it, and because a sheet
/// puts its rows at the bottom of a phone screen where a thumb already is.
/// Everything about its shape — the raised tier, the flat edge, the drag
/// handle, the corner radius — comes from `bottomSheetTheme`.
///
/// Returns null when the user dismisses it by the handle, the barrier or the
/// back gesture, which every caller must treat as "changed their mind".
///
/// **Only ever opened with two or more options.** A sheet holding a single row
/// is a tap charged for a choice that does not exist, so a caller whose second
/// option is unavailable on this device goes straight to the one that is left —
/// see the `supportsCamera` and `canSaveToDisk` gates at the call sites.
Future<T?> _showChooser<T>(
  BuildContext context, {
  required String title,
  required List<_ChooserOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Both together are what keep two rows of supporting text safe at double
    // text size: the sheet may grow past the default 9/16 of the screen, and
    // `useSafeArea` stops a grown sheet sliding under the status bar or the
    // notch. In landscape at 2x the content is taller than the viewport, and
    // the scroll view inside the sheet is what carries it.
    isScrollControlled: true,
    useSafeArea: true,
    // A sheet spanning a 768px tablet leaves each row's copy stranded beside a
    // hand's width of empty space. Matches the form's own measure.
    constraints: const BoxConstraints(maxWidth: _maxFormWidth),
    builder: (context) => _ChooserSheet(title: title, options: options),
  );
}

class _ChooserSheet<T> extends StatelessWidget {
  const _ChooserSheet({required this.title, required this.options});

  final String title;
  final List<_ChooserOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return SafeArea(
      // The route already holds the top edge clear (`useSafeArea`); taking it
      // again here would pad the sheet twice. The bottom is this widget's own
      // problem — the last row must clear the gesture bar.
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                0,
                tokens.spaceLg,
                tokens.spaceSm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    // Large and tight, matching the app bar and the form's
                    // section headings.
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            for (final option in options)
              _ChooserRow<T>(
                option: option,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
            SizedBox(height: tokens.spaceMd),
          ],
        ),
      ),
    );
  }
}

/// One option, as a row.
///
/// A [ListTile] rather than a hand-built row: it already resolves the minimum
/// tile height, the leading gap and the ink shape from `listTileTheme`, it
/// carries its own button semantics and tap action, and it grows vertically
/// when the description wraps at large text sizes rather than clipping it.
class _ChooserRow<T> extends StatelessWidget {
  const _ChooserRow({required this.option, required this.onTap});

  final _ChooserOption<T> option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // One node, not three. Unmerged, a screen reader makes the label and its
    // supporting line two separate stops either side of the button, so the
    // explanation is read apart from the thing it explains.
    return MergeSemantics(
      child: Padding(
        // Inset so the themed rounded highlight has an edge to sit inside
        // instead of running into the sheet's own. Row inset plus content
        // padding comes to `spaceLg`, which lines the mark up under the
        // heading.
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
        child: ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(
            horizontal: tokens.spaceSm,
            vertical: tokens.spaceSm,
          ),
          // The same recessed plate that introduces every section of the form:
          // `surfaceContainerLowest` with the accent glyph on it. The
          // established treatment for a mark nested in a raised surface,
          // reused rather than reinvented a third time.
          leading: SectionIconTile(icon: option.icon),
          title: Text(option.label),
          subtitle: Text(option.description),
          subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Tells the user, while they are still editing, that the page cannot hold
/// everything they have typed.
///
/// Uses the error container rather than a warning yellow: content missing from
/// a resume someone is about to send is a failure, not a hint.
///
/// Renders nothing at all when there is nothing to report, rather than being
/// left out of its parent's child list — see the note at the call site.
class _TruncationBanner extends StatelessWidget {
  const _TruncationBanner({required this.report});

  final TruncationReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Zero height, and nothing in the semantics tree either: a screen reader
    // must not stop on an empty warning.
    if (!report.hasLoss) return const SizedBox.shrink();

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceLg,
          vertical: tokens.spaceMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Text(
                report.describe(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
