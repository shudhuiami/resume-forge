import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'brand.dart';
import 'data/resume_repository.dart';
import 'screens/resume_list_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_providers.dart';
import 'theme/app_theme.dart';

/// Upper bound on opening local storage.
///
/// Hive is on-device and small, so this is never reached in practice — but
/// `Hive.initFlutter()` asks path_provider for the documents directory, and
/// that is a platform channel. A channel that never replies would otherwise
/// leave the splash animating forever with no way out, which is the one thing
/// a startup screen must not do. Generous rather than tight: first-run I/O on a
/// cold budget phone is slow, and a false failure here is worse than a slow
/// success.
const _startupTimeout = Duration(seconds: 15);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface framework errors with their message and stack. Without this a
  // failure inside a build or a callback reaches the browser as a bare
  // "Error", which is unactionable.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('${details.stack}');
  };

  // Async errors escaping a Future never reach FlutterError.onError; without
  // this they surface in the browser as an opaque "Error".
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('UNCAUGHT: $error');
    debugPrint('$stack');
    return true;
  };

  runApp(const ResumeStudioApp());
}

/// Opens local storage.
///
/// Deliberately **not** awaited before [runApp] any more. It used to be, so
/// that the resume list never had to render a "still connecting" state on a
/// local database — that guarantee is unchanged, because the list is still only
/// built once this has completed. What changed is what the user looks at while
/// it runs: a splash that is already animating, instead of whatever the OS was
/// showing. The work overlaps the animation rather than queueing behind it.
Future<ResumeRepository> openStorage() async {
  await Hive.initFlutter();
  return HiveResumeRepository.open();
}

class ResumeStudioApp extends StatefulWidget {
  const ResumeStudioApp({super.key, this.startup = openStorage});

  /// Injected so tests can drive a slow, a failing, and a recovering start
  /// without a real Hive box.
  final Future<ResumeRepository> Function() startup;

  @override
  State<ResumeStudioApp> createState() => _ResumeStudioAppState();
}

class _ResumeStudioAppState extends State<ResumeStudioApp> {
  /// Built once rather than per rebuild: the theme is a pure function of
  /// nothing, and both slots below want the same instance.
  final ThemeData _theme = AppTheme.build();

  ResumeRepository? _repository;
  Object? _error;
  bool _entranceComplete = false;

  /// Distinguishes the run a result belongs to, so a retry cannot be overtaken
  /// by the attempt it replaced.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final attempt = ++_attempt;
    try {
      final repository = await widget.startup().timeout(_startupTimeout);
      if (!mounted || attempt != _attempt) {
        // Nothing will ever read it; a box left open would hold a file lock.
        unawaited(repository.close());
        return;
      }
      setState(() {
        _repository = repository;
        _error = null;
      });
    } catch (error, stack) {
      debugPrint('STARTUP FAILED: $error');
      debugPrint('$stack');
      if (!mounted || attempt != _attempt) return;
      setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      // Back to the splash, which replays from the top. The handoff waits on
      // its entrance again rather than cutting the animation in half.
      _entranceComplete = false;
    });
    _boot();
  }

  void _onEntranceComplete() {
    if (_entranceComplete || !mounted) return;
    setState(() => _entranceComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen;
    if (_error != null) {
      screen = StartupFailureScreen(error: _error!, onRetry: _retry);
    } else if (_repository != null && _entranceComplete) {
      screen = const ResumeListScreen();
    } else {
      screen = SplashScreen(onEntranceComplete: _onEntranceComplete);
    }

    return ProviderScope(
      // The override is installed from the first frame and always names the
      // same provider, because Riverpod does not allow the *set* of overrides
      // to change across rebuilds. What changes is what it resolves to — and it
      // is only ever resolved after the handoff, since nothing above the resume
      // list reads a repository. Throwing rather than returning null keeps that
      // rule enforced instead of merely assumed.
      overrides: [
        repositoryProvider.overrideWith((ref) {
          final repository = _repository;
          if (repository == null) {
            throw StateError(
              'storage is still opening: nothing may read the repository '
              'before the splash hands off',
            );
          }
          return repository;
        }),
      ],
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: _theme,
        // The app is dark by design rather than following the system: the
        // colour-tinted dark chrome is part of the product's identity, and it is
        // also what keeps the app frame visually distinct from the — almost
        // always light — resume page it frames. Both slots point at the same
        // theme so a device in light mode gets the designed palette rather than
        // an unstyled fallback.
        darkTheme: _theme,
        themeMode: ThemeMode.dark,
        home: _Handoff(child: screen),
      ),
    );
  }
}

/// Crossfades the startup screens into the app.
///
/// The opaque backdrop is the point. An [AnimatedSwitcher] alone runs both
/// children at partial opacity through the middle of the transition, so two
/// screens that are each an opaque `surface` composite over the window's black
/// and dip to about three quarters brightness halfway — a visible flicker on
/// exactly the frame the app is trying to look seamless. With `surface` painted
/// behind them, only the *content* crossfades and the background never moves.
class _Handoff extends StatelessWidget {
  const _Handoff({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : splashHandoff,
        // The default layout builder stacks children loosely, which lets a
        // Scaffold shrink-wrap mid-transition. These are full screens and must
        // keep the viewport's size the whole way through.
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: child,
      ),
    );
  }
}
