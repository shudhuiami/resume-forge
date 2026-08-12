import 'package:flutter/material.dart';

/// Spacing, radius, and the solid card tints of the app chrome.
///
/// Exposed as a [ThemeExtension] so screens pull values from the theme instead
/// of hard-coding numbers. If a widget needs a spacing, radius, or card tint
/// that is not here, that is a signal to extend this scale deliberately — not
/// to inline a one-off constant.
///
/// **No shadow tokens, and no gradient tokens, on purpose.** The chrome used to
/// separate a white panel from a near-white background with a diffuse shadow,
/// which is the only thing that works on a light palette. On the matte black
/// palette the same shadow is invisible: a card *lighter* than its background
/// casts nothing the eye can resolve, and `flutter_test` sets
/// `debugDisableShadows = true`, so a shadow can never be verified by the suite
/// either. Cards separate by a flat tint step — a card is a solid, hue-tinted
/// surface over a near-black base — plus a hairline
/// ([ColorScheme.outlineVariant]) to crisp the edge. That is one system for the
/// whole app; `cardTheme` carries `elevation: 0` to match.
///
/// The tints carry colour, which the rest of this file does not. That is the
/// point of the palette: depth comes from hue, never from a blend. Every one of
/// them is a single opaque colour — no ramp, no gloss, no glow anywhere in the
/// app.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 12,
    this.spaceLg = 16,
    this.spaceXl = 24,
    this.spaceXxl = 32,
    this.radiusSm = 12,
    this.radiusMd = 16,
    this.radiusLg = 24,
    this.radiusXl = 32,
    this.radiusPill = 999,
    this.minTouchTarget = 48,
    this.tintClay = const Color(0xFF4A2E26),
    this.tintRust = const Color(0xFF512A22),
    this.tintOchre = const Color(0xFF473719),
    this.tintOlive = const Color(0xFF333A22),
    this.tintMoss = const Color(0xFF26382C),
    this.tintTeal = const Color(0xFF123A3A),
    this.tintSlate = const Color(0xFF25304A),
    this.tintPlum = const Color(0xFF3D2438),
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

  /// Solid card surfaces, eight of them, matte.
  ///
  /// A card takes one of these instead of a single grey so a screen of stacked
  /// cards has something to navigate by: the editor gives each of its six
  /// sections one, and the gallery and the resume list give each design
  /// *category* one, so the same design is the same colour in both places.
  ///
  /// Deliberately muted and deliberately close together. Every one sits between
  /// 1.39:1 and 1.68:1 above the base — enough to read as a card, nowhere near
  /// enough to read as a highlight — and the whole set spans only 1.21:1 in
  /// brightness, so a column of them differs in *hue* and not in loudness. They
  /// are deep enough that `onSurface` clears 10.09:1 and `onSurfaceVariant`
  /// 4.68:1 on the worst of them, and that a field well punched back to
  /// `surfaceContainerLowest` still reads as a recess. All measured in
  /// `test/theme/contrast_test.dart`, against every tint rather than a sample.
  final Color tintClay;
  final Color tintRust;
  final Color tintOchre;
  final Color tintOlive;
  final Color tintMoss;
  final Color tintTeal;
  final Color tintSlate;
  final Color tintPlum;

  /// Every card tint, in one list.
  ///
  /// The contrast suite iterates this rather than a hand-written copy, so a
  /// tint added here cannot ship unmeasured — which is the whole reason the
  /// outline-on-a-tint problem is checkable at all.
  List<Color> get cardTints => [
    tintClay,
    tintRust,
    tintOchre,
    tintOlive,
    tintMoss,
    tintTeal,
    tintSlate,
    tintPlum,
  ];

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
    Color? tintClay,
    Color? tintRust,
    Color? tintOchre,
    Color? tintOlive,
    Color? tintMoss,
    Color? tintTeal,
    Color? tintSlate,
    Color? tintPlum,
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
      tintClay: tintClay ?? this.tintClay,
      tintRust: tintRust ?? this.tintRust,
      tintOchre: tintOchre ?? this.tintOchre,
      tintOlive: tintOlive ?? this.tintOlive,
      tintMoss: tintMoss ?? this.tintMoss,
      tintTeal: tintTeal ?? this.tintTeal,
      tintSlate: tintSlate ?? this.tintSlate,
      tintPlum: tintPlum ?? this.tintPlum,
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
      tintClay: Color.lerp(tintClay, other.tintClay, t)!,
      tintRust: Color.lerp(tintRust, other.tintRust, t)!,
      tintOchre: Color.lerp(tintOchre, other.tintOchre, t)!,
      tintOlive: Color.lerp(tintOlive, other.tintOlive, t)!,
      tintMoss: Color.lerp(tintMoss, other.tintMoss, t)!,
      tintTeal: Color.lerp(tintTeal, other.tintTeal, t)!,
      tintSlate: Color.lerp(tintSlate, other.tintSlate, t)!,
      tintPlum: Color.lerp(tintPlum, other.tintPlum, t)!,
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
