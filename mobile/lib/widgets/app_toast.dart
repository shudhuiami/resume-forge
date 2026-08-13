import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/tokens.dart';

/// What a toast is telling the user, which decides its colour and its icon.
///
/// Colour alone never carries the difference — every variant has a distinct
/// glyph as well, because a red panel and a grey panel are the same panel to a
/// user who cannot separate them.
enum ToastVariant {
  /// Something happened and it worked. Auto-dismisses fastest.
  success,

  /// Neutral information.
  info,

  /// Something failed. Carries the error palette and stays longer.
  error,

  /// Work is in progress. **Never auto-dismisses** — the caller holds the
  /// handle and closes it when the work ends.
  progress,
}

/// A live toast, so the caller can take it away before its timer does.
///
/// Every call to [AppToast.show] returns one. Dismissing an already-dismissed
/// toast is a no-op rather than an error: the previous `SnackBar` code had to
/// guard against exactly that, because closing a bar that had left the queue
/// threw `Bad state: No element`.
class ToastHandle {
  ToastHandle._(this._entry, this._controller);

  final _ToastEntry _entry;
  final _ToastController _controller;

  bool get isShowing => _controller.isShowing(_entry);

  void dismiss() => _controller.remove(_entry);
}

/// Top-right, auto-fading notifications that do not block the page.
///
/// This replaces `ScaffoldMessenger`'s `SnackBar`, which sat at the bottom over
/// the content, stayed until dismissed or until a fixed duration elapsed, and
/// could only ever show one thing at a time.
///
/// **Why an overlay rather than a bottom sheet or a banner.** The toast is
/// painted into the [Overlay] as a box only as large as the card itself. A
/// `Column` does not absorb a hit that lands beside its children, so the
/// screen underneath stays live: the user can keep typing while a toast is up.
/// `test/widgets/app_toast_test.dart` proves that by tapping *through* the
/// strip beside a visible toast.
abstract final class AppToast {
  /// Auto-dismiss delays.
  ///
  /// These are not round numbers picked for tidiness. A confirmation only has
  /// to be *noticed* — it says something the user already knows they did — so
  /// it goes at 2.6s, comfortably above the ~2s that reads as a flash.
  /// Anything carrying an action has to be *read and reached*, which is why
  /// Material puts actionable messages at 6-10s, so those get 7s. And the
  /// timer pauses while a pointer is over the card, so a toast never
  /// disappears out from under a finger already travelling towards its button.
  static const successDwell = Duration(milliseconds: 2600);
  static const infoDwell = Duration(milliseconds: 4000);
  static const actionDwell = Duration(seconds: 7);

  /// How many toasts may stack before the oldest is retired. Three is the
  /// point where the stack starts covering content it should not.
  static const maxVisible = 3;

  /// Shows a toast in the top-right and returns a handle to it.
  ///
  /// [duration] overrides the variant's default. Pass [ToastVariant.progress]
  /// (or a null duration with it) for a toast that never leaves on its own.
  static ToastHandle show(
    BuildContext context, {
    required String message,
    ToastVariant variant = ToastVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final controller = _ToastController.of(context);
    final hasAction = onAction != null && actionLabel != null;
    final entry = _ToastEntry(
      message: message,
      variant: variant,
      actionLabel: hasAction ? actionLabel : null,
      onAction: hasAction ? onAction : null,
      duration: duration ?? _defaultDwell(variant, hasAction),
    );
    controller.add(entry, context);
    return ToastHandle._(entry, controller);
  }

  /// A toast that stays until its handle is dismissed. For work whose length
  /// is not known in advance — a PDF render can take a moment on a slow phone,
  /// and a notification that fades mid-render leaves the app looking idle.
  static ToastHandle showProgress(
    BuildContext context, {
    required String message,
  }) => show(context, message: message, variant: ToastVariant.progress);

  static Duration? _defaultDwell(ToastVariant variant, bool hasAction) =>
      switch (variant) {
        ToastVariant.progress => null,
        _ when hasAction => actionDwell,
        ToastVariant.success => successDwell,
        ToastVariant.error => actionDwell,
        ToastVariant.info => infoDwell,
      };
}

/// One queued toast. Identity matters — the handle, the stack and the
/// animation all key off the instance.
class _ToastEntry {
  _ToastEntry({
    required this.message,
    required this.variant,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
  });

  final String message;
  final ToastVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? duration;
}

/// The stack of live toasts for one [Overlay].
///
/// This lives *outside* the widget tree on purpose. `Overlay.insert` does not
/// build its entry synchronously, so a host widget cannot register itself in
/// time for the call that created it — the first toast would be dropped. The
/// controller owns the list, the overlay entry merely renders it.
class _ToastController extends ChangeNotifier {
  static final Map<OverlayState, _ToastController> _controllers = {};

  final List<_ToastEntry> entries = [];

  static _ToastController of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    // Overlays that have gone away take their controllers with them.
    _controllers.removeWhere((state, _) => !state.mounted);

    final existing = _controllers[overlay];
    if (existing != null) return existing;

    final controller = _ToastController();
    _controllers[overlay] = controller;
    overlay.insert(
      OverlayEntry(builder: (_) => _ToastLayer(controller: controller)),
    );
    return controller;
  }

  bool isShowing(_ToastEntry entry) => entries.contains(entry);

  void add(_ToastEntry entry, BuildContext context) {
    entries.insert(0, entry);
    while (entries.length > AppToast.maxVisible) {
      entries.removeLast();
    }
    notifyListeners();
    // Announced explicitly: a toast is painted into the overlay and never
    // takes focus, so without this it is invisible to a screen reader. The
    // card is also a live region, which covers readers that re-scan the tree;
    // the announcement covers the ones that do not. Errors interrupt; the
    // rest wait their turn.
    SemanticsService.sendAnnouncement(
      View.of(context),
      entry.message,
      Directionality.of(context),
      assertiveness: entry.variant == ToastVariant.error
          ? Assertiveness.assertive
          : Assertiveness.polite,
    );
  }

  void remove(_ToastEntry entry) {
    if (!entries.remove(entry)) return;
    notifyListeners();
  }
}

/// Renders whatever the controller currently holds, in the top-right.
class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.controller});

  final _ToastController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.entries.isEmpty) return const SizedBox.shrink();

        final tokens = context.tokens;
        final media = MediaQuery.of(context);
        // Right-aligned with a cap on a wide screen; on a phone the card spans
        // the width it is given, because a 320dp card hard against the right
        // edge of a 360dp screen is not a design, it is an accident.
        final maxWidth = media.size.width < 520.0 ? double.infinity : 420.0;

        return Positioned(
          top: media.padding.top + tokens.spaceMd,
          left: tokens.spaceMd,
          right: tokens.spaceMd,
          child: Align(
            alignment: Alignment.topRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final entry in controller.entries)
                    _ToastCard(
                      key: ObjectKey(entry),
                      entry: entry,
                      onDismiss: () => controller.remove(entry),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One card: slides down and fades in, counts down, and leaves the same way.
class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.entry, required this.onDismiss});

  final _ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  static const _enter = Duration(milliseconds: 220);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _enter,
  );
  Timer? _timer;
  bool _paused = false;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here rather than in initState: this is the earliest point a
    // MediaQuery exists. The splash screen establishes the same pattern.
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      if (reduced) {
        _controller.value = 1;
      } else if (_controller.status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    } else if (!reduced && _controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final duration = widget.entry.duration;
    if (duration == null || _paused) return;
    _timer = Timer(duration, widget.onDismiss);
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _timer?.cancel();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final isError = widget.entry.variant == ToastVariant.error;

    final background = isError
        ? scheme.errorContainer
        : scheme.surfaceContainerHigh;
    final ink = isError ? scheme.onErrorContainer : scheme.onSurface;
    final border = isError ? scheme.error : scheme.outline;

    final card = Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceSm),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(color: border),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceLg,
            vertical: tokens.spaceMd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ToastMark(variant: widget.entry.variant, ink: ink),
              SizedBox(width: tokens.spaceMd),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.entry.message,
                      style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                    ),
                    if (widget.entry.actionLabel case final label?)
                      Padding(
                        padding: EdgeInsets.only(top: tokens.spaceXs),
                        child: TextButton(
                          onPressed: () {
                            widget.onDismiss();
                            widget.entry.onAction?.call();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: isError
                                ? scheme.onErrorContainer
                                : scheme.primary,
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spaceSm,
                            ),
                            minimumSize: Size(0, tokens.minTouchTarget),
                          ),
                          child: Text(label),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final dismissible = Dismissible(
      key: ObjectKey(widget.entry),
      direction: DismissDirection.up,
      onDismissed: (_) => widget.onDismiss(),
      child: card,
    );

    // Hovering (desktop) or holding (touch) freezes the countdown so the
    // toast cannot vanish while the user is reaching for its action.
    final interactive = MouseRegion(
      onEnter: (_) => _pause(),
      onExit: (_) => _resume(),
      child: Listener(
        onPointerDown: (_) => _pause(),
        onPointerUp: (_) => _resume(),
        onPointerCancel: (_) => _resume(),
        child: dismissible,
      ),
    );

    final semantic = Semantics(
      container: true,
      liveRegion: true,
      child: interactive,
    );

    if (_reducedMotion) return semantic;

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.25),
          end: Offset.zero,
        ).animate(curve),
        child: semantic,
      ),
    );
  }
}

/// The variant's glyph — or its spinner, for work in progress.
class _ToastMark extends StatelessWidget {
  const _ToastMark({required this.variant, required this.ink});

  final ToastVariant variant;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    if (variant == ToastVariant.progress) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return Icon(
      switch (variant) {
        ToastVariant.success => Icons.check_circle_outline,
        ToastVariant.error => Icons.error_outline,
        _ => Icons.info_outline,
      },
      size: 18,
      color: ink,
    );
  }
}
