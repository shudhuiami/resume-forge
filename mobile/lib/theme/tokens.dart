import 'package:flutter/material.dart';

/// Spacing, radius, and elevation values for app chrome.
///
/// Exposed as a [ThemeExtension] so screens pull values from the theme instead
/// of hard-coding numbers. If a widget needs a spacing or radius that is not
/// here, that is a signal to extend this scale deliberately — not to inline a
/// one-off constant.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 12,
    this.spaceLg = 16,
    this.spaceXl = 24,
    this.spaceXxl = 32,
    this.radiusSm = 10,
    this.radiusMd = 14,
    this.radiusLg = 20,
    this.radiusXl = 28,
    this.radiusPill = 999,
    this.minTouchTarget = 48,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusPill;

  /// Minimum tappable edge. Anything interactive smaller than this fails the
  /// accessibility review.
  final double minTouchTarget;

  @override
  AppTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusPill,
    double? minTouchTarget,
  }) {
    return AppTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusPill: radiusPill ?? this.radiusPill,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t),
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t),
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t),
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t),
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t),
      spaceXxl: lerpDouble(spaceXxl, other.spaceXxl, t),
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t),
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t),
      minTouchTarget: lerpDouble(minTouchTarget, other.minTouchTarget, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppTokensX on BuildContext {
  /// Design tokens for the current theme. Falls back to defaults so a widget
  /// tested outside [AppTheme] still renders rather than throwing.
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? const AppTokens();
}
