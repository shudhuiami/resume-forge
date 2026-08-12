import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// How long the splash entrance runs.
///
/// This is also the app's **only** minimum display time, and it is expressed
/// as "do not leave mid-beat" rather than as a delay: [SplashScreen] reports
/// when its entrance finishes, storage opens underneath it on its own
/// schedule, and `main.dart` hands off when *both* are done. Storage that takes
/// longer than this holds the splash for exactly as long as it needs and not a
/// frame more; storage that opens in 20ms — the normal case for a local Hive
/// box — costs the user this much and nothing else.
///
/// 460ms because the entrance has four staggered beats (the mat growing in
/// behind the page, the page rising, the content bars writing themselves in,
/// the wordmark) and they need room to read as a sequence rather than as a
/// flicker; and because Android's own splash-screen API caps an icon animation
/// at 1000ms, which is the ceiling this has to sit comfortably under.
const splashEntrance = Duration(milliseconds: 460);

/// Crossfade from the splash to the app.
///
/// Only the *content* crossfades — see `_Handoff` in `main.dart`, which parks
/// an opaque surface behind both screens so the two identical backgrounds
/// cannot dip toward black halfway through.
const splashHandoff = Duration(milliseconds: 200);

/// A4, the only shape a resume is printed at.
///
/// This and the constants under it are mirrored in
/// `assets/brand/generate_brand.py`, which bakes the same drawing into the
/// launcher icon and the native splash. If one moves, both move.
const _pageAspect = 1 / 1.4142135623730951;

/// Page corner radius as a fraction of page width.
const _pageCorner = 0.12;

/// Bounds of one content bar, as fractions of the page box.
typedef _Bar = ({double left, double top, double right, double bottom});

/// The mark's content: a header block and two lines. Three, not five — the
/// same drawing has to survive being a 48px launcher icon, and a fourth line
/// closes the gaps into mush at that size.
const _bars = <_Bar>[
  (left: 0.155, top: 0.200, right: 0.675, bottom: 0.340),
  (left: 0.155, top: 0.460, right: 0.875, bottom: 0.560),
  (left: 0.155, top: 0.660, right: 0.655, bottom: 0.760),
];

/// The mark's box relative to the page: room around it for the mat.
///
/// Deliberately unchanged from when a blurred glow lived in that room and
/// needed all of it. The box is what [ForgeMark.heightFor] divides the viewport
/// by, so shrinking it to fit the smaller mat would grow the page on screen —
/// and the page's on-screen size is measured into `assets/brand`, which is the
/// one number the native handoff cannot afford to move. The mat gets a roomy
/// box instead, which on a splash is air rather than waste.
const _boxHeightRatio = 1.30;
const _boxWidthRatio = _pageAspect * 1.85;

/// The mat's margin around the page, as a fraction of page width.
///
/// Uniform on all four sides — the same number horizontally and vertically, not
/// the same *fraction* of two different edge lengths, which on a 1:√2 page
/// would read as a border that is thicker at the top than at the sides.
const _matMargin = 0.15;

/// How small the mat starts before it grows out from under the page.
const _matRise = 0.90;

/// Height the mark is allowed to take.
///
/// The upper bound is what stops a tablet from rendering a 300px logo; the
/// lower bound is roughly where the three content bars stop being separable,
/// below which the mark reads as a coloured rectangle.
const _markMaxHeight = 200.0;
const _markMinHeight = 72.0;

/// Share of the viewport's width the mark's box may take.
///
/// 0.55 of the box is 0.30 of the screen once the A4 page is inset in it, which
/// is about where a splash logo stops looking incidental and starts looking
/// placed.
const _markWidthShare = 0.55;

/// Height of the wordmark, the tagline and the gaps around them at text scale
/// 1. Subtracted from the viewport before the mark is sized, so on a short
/// screen the mark gives up its space to the words instead of pushing them out.
const _copyReserve = 150.0;

/// Widest the tagline is allowed to run.
const _maxProseWidth = 380.0;

/// Addresses the mark from a test.
@visibleForTesting
const forgeMarkKey = Key('forge-mark');

/// The ResumeForge mark: an A4 page in one solid accent colour, its content
/// bars punched back to the surface colour, lying on a flat mat.
///
/// Flat throughout, and that is the point of it. The page used to carry a
/// five-stop ramp and to sit on a blurred, faded copy of that same ramp; the
/// palette is now matte, so the page is a single opaque accent and the glow has
/// become a mat — an opaque, hard-edged plate a shade above the background,
/// which is the flat way to say "this document is resting on something".
///
/// Geometry is shared with the launcher icon (see `assets/brand`), so the thing
/// that animates in here is literally the thing on the home screen the user
/// just tapped. The mat is the one part that is not: it grows from nothing, so
/// it is absent on the frame the icon is cut from, exactly as the glow was.
/// Every colour comes from the theme; the only literals are the proportions.
///
/// [progress] runs 0..1 and drives the whole drawing — the mat growing out from
/// under the page, the page's scale, and the staggered draw-in of the three
/// content bars. At 0 it is the blank page the native splash shows; at 1 it is
/// the finished mark, which is also what reduced-motion renders on the very
/// first frame.
class ForgeMark extends StatelessWidget {
  const ForgeMark({super.key, required this.height, this.progress = 1.0});

  /// Height of the page itself. The widget is larger than this — see
  /// [boxSizeFor] — because the glow needs somewhere to fall.
  final double height;

  /// 0 = nothing drawn yet, 1 = the finished mark.
  final double progress;

  /// The box a mark of [height] occupies.
  static Size boxSizeFor(double height) =>
      Size(height * _boxWidthRatio, height * _boxHeightRatio);

  /// Largest mark that fits the space left after the copy is reserved.
  ///
  /// Sized from the viewport rather than fixed: a landscape phone at double
  /// text size has barely a heading's worth of height to spare, and a mark that
  /// insists on its full size there pushes the wordmark off the screen.
  static double heightFor(BoxConstraints constraints, TextScaler scaler) {
    final byHeight = constraints.maxHeight.isFinite
        ? (constraints.maxHeight - scaler.scale(_copyReserve)) / _boxHeightRatio
        : double.infinity;
    final byWidth = constraints.maxWidth * _markWidthShare / _boxWidthRatio;
    return math.min(byHeight, byWidth).clamp(_markMinHeight, _markMaxHeight);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = boxSizeFor(height);

    // Decorative: the wordmark underneath already names the app, so a screen
    // reader announcing the drawing as well would just repeat it.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          key: forgeMarkKey,
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: _MarkPainter(
              // The accent, straight and undiluted — the same value
              // `assets/brand/generate_brand.py` bakes into the icon, which is
              // what `test/brand/brand_assets_test.dart` checks the two ends of.
              fill: scheme.primary,
              // Raised chrome, because that is what the mat is: a plate the
              // page floats above. It is decoration rather than a control
              // boundary, so it is held to being *visible* against the
              // background rather than to 3:1 — and if the palette ever flattens
              // the panel tiers into the base, the mat quietly disappears and
              // leaves the flat mark, which reads perfectly well on its own.
              mat: scheme.surfaceContainerHigh,
              // The bars are punched back to the colour behind the page, which
              // is the same surface the splash and the launcher icon's backdrop
              // are painted in. Cheaper than a real cut-out (`BlendMode.clear`
              // needs a saveLayer) and indistinguishable on this background.
              ink: scheme.surface,
              progress: progress.clamp(0.0, 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.fill,
    required this.mat,
    required this.ink,
    required this.progress,
  });

  final Color fill;
  final Color mat;
  final Color ink;
  final double progress;

  /// Eased slice of [progress] between [begin] and [end].
  double _at(double begin, double end, {Curve curve = Curves.easeOutCubic}) {
    if (end <= begin) return progress >= end ? 1 : 0;
    return curve.transform(
      ((progress - begin) / (end - begin)).clamp(0.0, 1.0),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pageHeight = size.height / _boxHeightRatio;
    final pageWidth = pageHeight * _pageAspect;
    final centre = size.center(Offset.zero);

    // Beat one: the mat grows out from under the page.
    //
    // It starts at nothing, which is the whole reason it is allowed to exist:
    // frame zero has to be the bare page and nothing else, because that is the
    // image the native splash is showing when Flutter takes over. Whatever
    // happens after frame zero is free.
    final rise = _at(0.0, 0.70, curve: Curves.easeOut);
    if (rise > 0) {
      final margin = pageWidth * _matMargin;
      final grown = _matRise + (1 - _matRise) * rise;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centre,
            width: (pageWidth + margin * 2) * grown,
            height: (pageHeight + margin * 2) * grown,
          ),
          // Concentric with the page's own corner: the page radius plus the
          // margin, so the mat's edge stays a constant distance from the
          // page's the whole way round instead of pinching at the corners.
          Radius.circular((pageWidth * _pageCorner + margin) * grown),
        ),
        // Fades to fully opaque. Flat, hard-edged and one colour — where the
        // glow it replaced was a blur, which is a gradient by another name.
        Paint()..color = mat.withValues(alpha: rise),
      );
    }

    // The page rises into place rather than fading in.
    //
    // Deliberately opaque from the very first frame.
    // `assets/brand/splash_logo.png` is this exact drawing — the page with no
    // bars and no mat — sized to land at the same height, so the OS's splash
    // and Flutter's first frame show the same object. A page that faded in from
    // nothing would mean the mark vanished for a beat at the handoff, which is
    // the flicker this whole arrangement exists to avoid.
    final scale = 0.88 + 0.12 * _at(0.0, 0.55);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(scale)
      ..translate(-centre.dx, -centre.dy);

    final page = Rect.fromCenter(
      center: centre,
      width: pageWidth,
      height: pageHeight,
    );
    final shape = RRect.fromRectAndRadius(
      page,
      Radius.circular(pageWidth * _pageCorner),
    );

    canvas.drawRRect(shape, Paint()..color = fill);

    final barPaint = Paint()..color = ink;
    for (var i = 0; i < _bars.length; i++) {
      final bar = _bars[i];
      // Staggered, so the content writes itself onto the page top to bottom.
      final drawn = _at(0.25 + i * 0.14, 0.57 + i * 0.14);
      if (drawn <= 0) continue;

      final top = page.top + pageHeight * bar.top;
      final barHeight = pageHeight * (bar.bottom - bar.top);
      final left = page.left + pageWidth * bar.left;
      final barWidth = pageWidth * (bar.right - bar.left) * drawn;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          Radius.circular(barHeight / 2),
        ),
        barPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress ||
      old.fill != fill ||
      old.mat != mat ||
      old.ink != ink;
}

/// The animated brand frame shown while local storage opens.
///
/// It does no work of its own beyond drawing: no plugins, no channels, no I/O,
/// nothing that can hang. Startup runs in `main.dart` underneath it and this
/// screen only reports, through [onEntranceComplete], that it has finished
/// saying what it has to say.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onEntranceComplete});

  /// Fired once the entrance has played out — or, when the platform asks for
  /// reduced motion, after the first frame of the static mark. Never fired
  /// synchronously from a build.
  final VoidCallback? onEntranceComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: splashEntrance,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Reduced motion is a MediaQuery, so this is the earliest it can be read —
    // initState has no inherited widgets yet.
    if (MediaQuery.disableAnimationsOf(context)) {
      // Straight to the resting frame. The controller is never started, so
      // nothing ticks and there is no animation to interrupt. Set before the
      // listener is attached, because assigning `value` fires a status change
      // and handing off from inside didChangeDependencies would call setState
      // on an ancestor mid-build.
      _controller.value = 1;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEntranceComplete?.call();
      });
      return;
    }

    _controller
      ..addStatusListener(_onStatus)
      ..forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onEntranceComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // There is no AppBar here to publish it, and the app's very first screen
      // is the one most likely to inherit whatever the OS was showing — light
      // status-bar glyphs on this background would be invisible.
      value: AppTheme.systemOverlay,
      child: Scaffold(
        // Stated rather than inherited: this exact colour is the contract with
        // the native splash (flutter_native_splash.yaml) and with the Android
        // window background (values/colors.xml). If the three ever disagree the
        // user sees a flash of another colour at launch.
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = ForgeMark.heightFor(
                constraints,
                MediaQuery.textScalerOf(context),
              );
              final inset = tokens.spaceXl;

              // Never overflows, and only actually scrolls in the cases that
              // cannot fit at all — a landscape phone at double text size.
              return SingleChildScrollView(
                padding: EdgeInsets.all(inset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - inset * 2),
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => _Content(
                        progress: _controller.value,
                        markHeight: height,
                        tokens: tokens,
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One frame of the splash at a given [progress].
class _Content extends StatelessWidget {
  const _Content({
    required this.progress,
    required this.markHeight,
    required this.tokens,
    required this.theme,
  });

  final double progress;
  final double markHeight;
  final AppTokens tokens;
  final ThemeData theme;

  static double _at(double value, double begin, double end) => Curves.easeOut
      .transform(((value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final wordmark = _at(progress, 0.42, 0.80);
    final tagline = _at(progress, 0.58, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ForgeMark(height: markHeight, progress: progress),
        SizedBox(height: tokens.spaceLg),
        Opacity(
          opacity: wordmark,
          // Rises the last few pixels into place under the mark.
          child: Transform.translate(
            offset: Offset(0, tokens.spaceSm * (1 - wordmark)),
            // A wordmark is a graphic, not a paragraph: at 2x text on a 360px
            // phone it otherwise wrapped to "ResumeForg / e", which is worse
            // for everyone including the person who asked for larger text.
            // scaleDown only ever shrinks, so it still grows with text scale
            // right up until it would break.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'ResumeForge',
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spaceSm),
        Opacity(
          opacity: tagline,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxProseWidth),
            child: Text(
              'Everything stays on this device',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when local storage will not open.
///
/// The splash must never be a place the user gets stuck: `main.dart` puts a
/// watchdog on startup, and anything that throws or runs long lands here with
/// something to read and something to press, rather than on a mark that
/// animates forever.
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inset = tokens.spaceXl;
              return SingleChildScrollView(
                padding: EdgeInsets.all(inset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - inset * 2),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxProseWidth,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: tokens.minTouchTarget * 1.5,
                            height: tokens.minTouchTarget * 1.5,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(
                                tokens.radiusLg,
                              ),
                            ),
                            child: Icon(
                              Icons.error_outline,
                              size: tokens.spaceXxl,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          SizedBox(height: tokens.spaceLg),
                          Text(
                            'Could not open your saved resumes',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: tokens.spaceSm),
                          Text(
                            'ResumeForge keeps everything on this device, and '
                            'its local storage did not open. Nothing has been '
                            'lost — it just cannot be read yet.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: tokens.spaceSm),
                          // The technical detail, in the small print. Useless to
                          // most people and the only useful thing in the world to
                          // whoever gets the bug report.
                          Text(
                            _detail(error),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: tokens.spaceXl),
                          FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// A timeout has a message nobody can act on, so it gets said in words.
  static String _detail(Object error) =>
      error is TimeoutException ? 'Storage did not respond.' : error.toString();
}
