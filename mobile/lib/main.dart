import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'data/resume_repository.dart';
import 'screens/resume_list_screen.dart';
import 'state/app_providers.dart';
import 'theme/app_theme.dart';

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

  // Open storage before the first frame so the resume list never has to render
  // a "still connecting" state on a local database.
  await Hive.initFlutter();
  final repository = await HiveResumeRepository.open();

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: const ResumeForgeApp(),
    ),
  );
}

class ResumeForgeApp extends StatelessWidget {
  const ResumeForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResumeForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // The app is dark by design rather than following the system, because
      // the palette is part of the product's identity.
      darkTheme: AppTheme.build(),
      themeMode: ThemeMode.dark,
      home: const ResumeListScreen(),
    );
  }
}
