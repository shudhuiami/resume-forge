import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Dark, colourful Material 3 theme for the application shell.
///
/// **This palette is app chrome only.** Resume templates carry their own
/// independent, mostly light document palettes and must never read from this
/// [ColorScheme] — a resume printed in the app's dark violet would be a defect,
/// not a feature. The two colour worlds stay strictly separate: this file
/// styles the frame, `templates/` styles the page inside it.
abstract final class AppTheme {
  /// Deep near-black with a violet cast, so large dark areas read as
  /// deliberate rather than as an unstyled background.
  static const _bg = Color(0xFF0B0A12);
  static const _surface = Color(0xFF15131F);
  static const _surfaceHigh = Color(0xFF1E1B2C);

  /// Boundary of real controls (outlined buttons, focusable inputs). Held at
  /// >=3:1 against the base surface per WCAG 1.4.11 — a border the user cannot
  /// see is not a border. `outlineVariant` below is the decorative counterpart
  /// for dividers and card edges, where low contrast is intentional.
  static const _outline = Color(0xFF6E6796);

  static const _violet = Color(0xFFA78BFA);
  static const _cyan = Color(0xFF5EEAD4);
  static const _pink = Color(0xFFF9A8D4);
  static const _danger = Color(0xFFFCA5A5);

  /// Foreground colours are deliberately light-tinted rather than pure white —
  /// pure white on near-black is harsh at body sizes.
  static const _onSurface = Color(0xFFEDE9F5);
  static const _onSurfaceMuted = Color(0xFFA9A2C0);

  static const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _violet,
    onPrimary: Color(0xFF1E1033),
    primaryContainer: Color(0xFF3B2E63),
    onPrimaryContainer: Color(0xFFE9DDFF),
    secondary: _cyan,
    onSecondary: Color(0xFF00312A),
    secondaryContainer: Color(0xFF14453D),
    onSecondaryContainer: Color(0xFFC5F5EC),
    tertiary: _pink,
    onTertiary: Color(0xFF3D1029),
    tertiaryContainer: Color(0xFF5C2743),
    onTertiaryContainer: Color(0xFFFFD9E8),
    error: _danger,
    onError: Color(0xFF3F0A0A),
    errorContainer: Color(0xFF6B2020),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: _bg,
    onSurface: _onSurface,
    surfaceContainerLowest: Color(0xFF08070E),
    surfaceContainerLow: _surface,
    surfaceContainer: _surfaceHigh,
    surfaceContainerHigh: Color(0xFF272238),
    surfaceContainerHighest: Color(0xFF302A44),
    onSurfaceVariant: _onSurfaceMuted,
    outline: _outline,
    outlineVariant: Color(0xFF2A2640),
    inverseSurface: _onSurface,
    onInverseSurface: _bg,
    inversePrimary: Color(0xFF5B3FBF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  /// Accent gradient used sparingly for hero surfaces and the primary action.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF22D3EE)],
  );

  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: _bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build() {
    const tokens = AppTokens();
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return base.copyWith(
      extensions: const [tokens],
      textTheme: base.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, tokens.minTouchTarget),
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceXl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, tokens.minTouchTarget),
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceXl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, tokens.minTouchTarget),
          foregroundColor: colorScheme.primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spaceLg,
          vertical: tokens.spaceLg,
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        modalBackgroundColor: colorScheme.surfaceContainer,
        showDragHandle: true,
        dragHandleColor: colorScheme.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusXl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHigh,
      ),
    );
  }
}
