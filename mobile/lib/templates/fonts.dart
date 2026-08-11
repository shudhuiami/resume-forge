import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Type families available to resume templates.
///
/// Georgia and Times are deliberately absent: they are Microsoft core fonts,
/// cannot be licensed for redistribution, and do not exist on Android. [serif]
/// resolves to Lora as the substitute.
enum FontFamily { sans, serif, mono }

/// One family's loaded weights, ready to hand to a `pw.TextStyle`.
class LoadedFamily {
  const LoadedFamily({
    required this.regular,
    required this.bold,
    this.semiBoldOrNull,
  });

  final pw.Font regular;
  final pw.Font bold;

  /// Null for families that ship no 600 weight. Prefer [semiBold], which
  /// resolves the fallback.
  final pw.Font? semiBoldOrNull;

  /// Falls back to [bold] for families with no 600 weight, so a template
  /// asking for semibold never silently drops to regular.
  pw.Font get semiBold => semiBoldOrNull ?? bold;
}

/// Loads and caches the bundled PDF fonts.
///
/// Families are loaded on demand rather than all at once: a template that uses
/// only the sans family should not pay to decode the serif and mono files.
/// Results are cached for the process lifetime, so the debounced preview loop
/// re-renders without re-decoding fonts on every keystroke.
abstract final class ResumeFonts {
  static final Map<FontFamily, LoadedFamily> _cache = {};
  static final Map<FontFamily, Future<LoadedFamily>> _inFlight = {};

  static const _assets = {
    FontFamily.sans: (
      regular: 'assets/fonts/Inter-Regular.ttf',
      semiBold: 'assets/fonts/Inter-SemiBold.ttf',
      bold: 'assets/fonts/Inter-Bold.ttf',
    ),
    FontFamily.serif: (
      regular: 'assets/fonts/Lora-Regular.ttf',
      semiBold: null,
      bold: 'assets/fonts/Lora-Bold.ttf',
    ),
    FontFamily.mono: (
      regular: 'assets/fonts/JetBrainsMono-Regular.ttf',
      semiBold: null,
      bold: 'assets/fonts/JetBrainsMono-Bold.ttf',
    ),
  };

  /// Synchronously returns an already-loaded family, or null.
  ///
  /// Template builders run inside an isolate where async loading is not
  /// available, so fonts must be resolved via [load] before building.
  static LoadedFamily? peek(FontFamily family) => _cache[family];

  static Future<LoadedFamily> load(FontFamily family) {
    final cached = _cache[family];
    if (cached != null) return Future.value(cached);

    // Deduplicate concurrent loads — the gallery kicks off many thumbnail
    // renders at once and would otherwise decode the same file repeatedly.
    return _inFlight[family] ??= _load(family).then((loaded) {
      _cache[family] = loaded;
      _inFlight.remove(family);
      return loaded;
    });
  }

  static Future<LoadedFamily> _load(FontFamily family) async {
    final paths = _assets[family]!;
    final regular = pw.Font.ttf(await rootBundle.load(paths.regular));
    final bold = pw.Font.ttf(await rootBundle.load(paths.bold));
    final semiBoldPath = paths.semiBold;
    final semiBold = semiBoldPath == null
        ? null
        : pw.Font.ttf(await rootBundle.load(semiBoldPath));

    return LoadedFamily(regular: regular, bold: bold, semiBoldOrNull: semiBold);
  }

  /// Preloads every family. Used before a bulk render (gallery thumbnails)
  /// where paying all decode costs once up front beats staggering them.
  static Future<void> loadAll() async {
    await Future.wait(FontFamily.values.map(load));
  }

  /// Test-only: clears the cache so a test can assert load behaviour.
  static void resetForTest() {
    _cache.clear();
    _inFlight.clear();
  }
}
