import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/theme/tokens.dart';

/// WCAG 2.1 relative-contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const cs = AppTheme.colorScheme;
  const tokens = AppTokens();

  /// The eight solid card tints, named so a failure says which one broke.
  ///
  /// Spelled out here rather than read off `cardTints` alone, and then checked
  /// *against* `cardTints` below: a tint added to the token set without being
  /// added here would otherwise ship with none of this measured against it,
  /// which is exactly the hole that let a control boundary sit at 2.33:1 on a
  /// card in the first place.
  final tints = <String, Color>{
    'clay': tokens.tintClay,
    'rust': tokens.tintRust,
    'ochre': tokens.tintOchre,
    'olive': tokens.tintOlive,
    'moss': tokens.tintMoss,
    'teal': tokens.tintTeal,
    'slate': tokens.tintSlate,
    'plum': tokens.tintPlum,
  };

  /// The six neutral tiers, for chrome that carries no identity of its own.
  final neutrals = <String, Color>{
    'surface': cs.surface,
    'surfaceContainerLowest': cs.surfaceContainerLowest,
    'surfaceContainerLow': cs.surfaceContainerLow,
    'surfaceContainer': cs.surfaceContainer,
    'surfaceContainerHigh': cs.surfaceContainerHigh,
    'surfaceContainerHighest': cs.surfaceContainerHighest,
  };

  /// Every surface a screen can put a widget on.
  final surfaces = <String, Color>{...neutrals, ...tints};

  /// The matte palette is a near-black base carrying flat, deeply desaturated
  /// card tints and one saturated accent. Two traps come with that shape and
  /// neither is eyeballed here: an accent picked as a button fill is usually
  /// too dark to read as text on a card, and — the one this palette actually
  /// hit — a control boundary picked against the base is nowhere near 3:1
  /// against the tint the control is really drawn on. The thresholds are the
  /// same ones the previous palettes were held to; only the colours under them
  /// changed.
  group('WCAG AA contrast', () {
    const bodyText = 4.5;
    const largeTextAndUi = 3.0;

    void expectAtLeast(String label, Color fg, Color bg, double threshold) {
      final ratio = contrastRatio(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(threshold),
        reason:
            '$label contrast is ${ratio.toStringAsFixed(2)}:1, '
            'needs ${threshold.toStringAsFixed(1)}:1',
      );
    }

    test('the named tints are exactly the token set', () {
      expect(
        tints.values.toSet(),
        tokens.cardTints.toSet(),
        reason:
            'a card tint that is not in this table is a card tint nothing '
            'below measures — add it here when you add it to AppTokens',
      );
      expect(tints, hasLength(tokens.cardTints.length));
    });

    test('body text on every surface tier and every card tint', () {
      surfaces.forEach((name, surface) {
        expectAtLeast('onSurface/$name', cs.onSurface, surface, bodyText);
      });
    });

    test('muted secondary text stays readable', () {
      surfaces.forEach((name, surface) {
        expectAtLeast(
          'onSurfaceVariant/$name',
          cs.onSurfaceVariant,
          surface,
          bodyText,
        );
      });
    });

    test('filled button labels against their fills', () {
      expectAtLeast('onPrimary/primary', cs.onPrimary, cs.primary, bodyText);
      expectAtLeast(
        'onSecondary/secondary',
        cs.onSecondary,
        cs.secondary,
        bodyText,
      );
      expectAtLeast(
        'onTertiary/tertiary',
        cs.onTertiary,
        cs.tertiary,
        bodyText,
      );
      expectAtLeast('onError/error', cs.onError, cs.error, bodyText);
    });

    test('container variants', () {
      expectAtLeast(
        'onPrimaryContainer/primaryContainer',
        cs.onPrimaryContainer,
        cs.primaryContainer,
        bodyText,
      );
      expectAtLeast(
        'onSecondaryContainer/secondaryContainer',
        cs.onSecondaryContainer,
        cs.secondaryContainer,
        bodyText,
      );
      expectAtLeast(
        'onTertiaryContainer/tertiaryContainer',
        cs.onTertiaryContainer,
        cs.tertiaryContainer,
        bodyText,
      );
      expectAtLeast(
        'onErrorContainer/errorContainer',
        cs.onErrorContainer,
        cs.errorContainer,
        bodyText,
      );
    });

    /// **The problem this palette turned on.**
    ///
    /// WCAG 1.4.11 asks a control boundary for 3:1 against the surface it is
    /// actually drawn on. In this app that surface is usually a card tint, not
    /// the base: the editor's "Add role" buttons sit on the section card, the
    /// gallery's cards and the resume rows are tinted, and an outlined button
    /// is unfilled precisely so it can sit on any of them.
    ///
    /// A boundary chosen against the near-black base alone passes there and
    /// fails everywhere that matters — the value this palette started from
    /// measured 3.65:1 on the base and **2.33:1 on clay**. It is solved with a
    /// single lighter outline rather than eight derived ones, which is only
    /// possible because the tints share a 1.21:1 brightness band; the same
    /// colour then has to survive being the mat ring around white paper, which
    /// caps it from the other side. Both ends are asserted, so neither can be
    /// relaxed to make the other easier.
    test('control boundaries clear 3:1 on every surface they can sit on', () {
      surfaces.forEach((name, surface) {
        expectAtLeast('outline/$name', cs.outline, surface, largeTextAndUi);
      });
    });

    test('the outline is bounded from above as well as below', () {
      // The mat ring around a document is the same colour as a control
      // boundary, so it cannot be lightened indefinitely to clear the tints —
      // past this it stops being a step down from the page it frames.
      expectAtLeast(
        'outline/paper (the ceiling)',
        cs.outline,
        const Color(0xFFFFFFFF),
        largeTextAndUi,
      );
      // And the tint that binds from below. Named explicitly: if a lighter
      // tint is ever added, this is the assertion that should be updated to
      // name it, not the threshold.
      final onOchre = contrastRatio(cs.outline, tokens.tintOchre);
      final onPaper = contrastRatio(cs.outline, const Color(0xFFFFFFFF));
      expect(
        onOchre,
        greaterThanOrEqualTo(largeTextAndUi),
        reason:
            'ochre is the lightest tint, at ${onOchre.toStringAsFixed(2)}:1',
      );
      expect(
        onPaper,
        greaterThanOrEqualTo(largeTextAndUi),
        reason: 'paper is the ceiling, at ${onPaper.toStringAsFixed(2)}:1',
      );
    });

    /// Form fields are wells punched down to `surfaceContainerLowest`, so every
    /// part of a field — its label, its value, its rule — is read against that
    /// deepest tint and not against the card it is cut into. One fill serves
    /// cards of eight different hues, which is only safe if it clears the
    /// thresholds on its own.
    test('soft-filled input fields', () {
      expectAtLeast(
        'onSurface/surfaceContainerLowest (typed value)',
        cs.onSurface,
        cs.surfaceContainerLowest,
        bodyText,
      );
      expectAtLeast(
        'onSurfaceVariant/surfaceContainerLowest (label and hint)',
        cs.onSurfaceVariant,
        cs.surfaceContainerLowest,
        bodyText,
      );
      // The fill differs from the tint it is cut into by 1.44:1 to 1.74:1 —
      // a deeper recess than the previous palette's 1.23:1, and still nowhere
      // near a boundary anyone can see. The rule under the field is what makes
      // it findable, so it carries the full non-text UI threshold — at rest,
      // not only on focus.
      expectAtLeast(
        'outline/surfaceContainerLowest (resting rule)',
        cs.outline,
        cs.surfaceContainerLowest,
        largeTextAndUi,
      );
      expectAtLeast(
        'primary/surfaceContainerLowest (focused rule)',
        cs.primary,
        cs.surfaceContainerLowest,
        largeTextAndUi,
      );
      expectAtLeast(
        'error/surfaceContainerLowest (error rule)',
        cs.error,
        cs.surfaceContainerLowest,
        largeTextAndUi,
      );
    });

    test('the field well is a real recess in every card tint', () {
      tints.forEach((name, tint) {
        final step = contrastRatio(cs.surfaceContainerLowest, tint);
        expect(
          step,
          greaterThanOrEqualTo(1.35),
          reason:
              'the well is only ${step.toStringAsFixed(2)}:1 below $name; '
              'a field has to look punched into its card',
        );
        expect(
          cs.surfaceContainerLowest.computeLuminance(),
          lessThan(tint.computeLuminance()),
          reason: 'the well must be below $name, not above it',
        );
      });
    });

    test('the field fill is a recess, and the disabled rule says so', () {
      // Asserting the *upper* bound, deliberately. A disabled end date (the "I
      // currently work here" case) drops to the hairline, and a control that
      // has stopped being a control must stop looking like one: staying under
      // 3:1 is how that is said.
      final disabled = contrastRatio(
        cs.outlineVariant,
        cs.surfaceContainerLowest,
      );
      expect(
        disabled,
        lessThan(3.0),
        reason:
            'the disabled rule measures ${disabled.toStringAsFixed(2)}:1; '
            'above 3:1 a disabled field reads as typeable',
      );
    });

    /// The rule was once the *only* thing marking a disabled field, and one
    /// hairline is not a state. Setting a flat `labelStyle` colour in the input
    /// theme overrides Material's own disabled resolution, so a switched-off
    /// end date carried a label exactly as bright as the live field beside it —
    /// measured at 1.00:1 apart.
    ///
    /// Both halves are re-derived for this palette rather than assumed to carry
    /// over: the well is deeper than the previous one, so the same alpha
    /// blended darker. What is asserted is the *step* plus a legibility floor,
    /// not a text minimum — WCAG exempts an inactive control from that
    /// precisely because it is meant to look unavailable.
    test('a disabled field reads as disabled', () {
      final disabledInk = cs.onSurfaceVariant.withValues(
        alpha: AppTheme.disabledInkAlpha,
      );
      final onFill = Color.alphaBlend(disabledInk, cs.surfaceContainerLowest);

      final step = contrastRatio(onFill, cs.onSurfaceVariant);
      expect(
        step,
        greaterThanOrEqualTo(2.0),
        reason:
            'the disabled label is ${step.toStringAsFixed(2)}:1 from the '
            'enabled one; at 1.00:1 the two states were the same colour',
      );
      // Still readable enough to identify which field has been switched off —
      // a label nobody can read is a different defect from one nobody can tell
      // apart. This is the half that pulls against the step above, and 0.54 is
      // where the two meet.
      expectAtLeast(
        'disabled label/surfaceContainerLowest',
        onFill,
        cs.surfaceContainerLowest,
        largeTextAndUi,
      );
    });

    /// The overflow menu sits on the raised neutral tier, which puts every
    /// colour it carries on a surface nothing else in the app uses for text.
    test('the overflow menu carries its own copy', () {
      const menu = 'surfaceContainerHigh (popup menu)';
      expectAtLeast(
        'onSurface/$menu',
        cs.onSurface,
        cs.surfaceContainerHigh,
        bodyText,
      );
      expectAtLeast(
        'onSurfaceVariant/$menu',
        cs.onSurfaceVariant,
        cs.surfaceContainerHigh,
        bodyText,
      );
      // "Clear all fields" is marked destructive before the tap, not only in
      // the dialog after it.
      expectAtLeast('error/$menu', cs.error, cs.surfaceContainerHigh, bodyText);
      // A popup has no scrim and no screen behind it to be laid on, so unlike
      // a dialog it needs a real edge of its own.
      expectAtLeast(
        'outline/$menu (its only boundary)',
        cs.outline,
        cs.surfaceContainerHigh,
        largeTextAndUi,
      );
    });

    test(
      'accent used as text (text buttons, links, marks) on every surface',
      () {
        surfaces.forEach((name, surface) {
          expectAtLeast('primary/$name', cs.primary, surface, bodyText);
        });
      },
    );

    /// Destructive **copy** is confined to the neutral tiers, and this is the
    /// pair of assertions that keeps it there.
    ///
    /// The previous palette claimed error text also appeared "inside section
    /// cards and inside list rows" and asserted 4.5:1 against the three panel
    /// tints. That claim was already untrue — the overflow menu is a popup on
    /// the raised neutral tier, the delete controls are icon buttons in
    /// `onSurfaceVariant`, and no field in this form validates — so it was
    /// defending a case that does not exist.
    ///
    /// It matters now because it cannot be true on this palette: the error
    /// accent measures 3.73:1 to 4.52:1 on the eight tints, so an AA-legible
    /// red on a card would have to be a pale pink, which is not what a warning
    /// looks like. The design rule instead: on a tinted card, failure is said
    /// with `errorContainer` — a whole banner — never with bare error text. The
    /// accent still has to be *findable* there, so it carries the 3:1 non-text
    /// floor on every tint.
    test(
      'destructive copy is AA on every surface that actually carries it',
      () {
        neutrals.forEach((name, surface) {
          expectAtLeast('error/$name', cs.error, surface, bodyText);
        });
      },
    );

    test('the error accent is still findable on a card tint', () {
      tints.forEach((name, tint) {
        expectAtLeast('error/$name', cs.error, tint, largeTextAndUi);
      });
    });

    test('failure surfaces sit below the whole card-tint band', () {
      // The truncation banner and the stale banner are `errorContainer`, and
      // the editor stacks it directly above a form made of tinted cards. The
      // first value tried for it landed 1.01:1 from plum — a warning strip
      // indistinguishable from a section — and would have passed any check
      // that only measured it against the base. So it is measured against
      // every tint, and required to be under all of them.
      for (final entry in tints.entries) {
        final step = contrastRatio(cs.errorContainer, entry.value);
        expect(
          cs.errorContainer.computeLuminance(),
          lessThan(entry.value.computeLuminance()),
          reason:
              'errorContainer must be darker than ${entry.key}, or a banner '
              'reads as another card',
        );
        expect(
          step,
          greaterThanOrEqualTo(1.10),
          reason:
              'errorContainer is only ${step.toStringAsFixed(3)}:1 from '
              '${entry.key}',
        );
      }
      // And still a step above the base it is laid on, or the banner
      // disappears instead of warning anyone.
      expect(
        contrastRatio(cs.errorContainer, cs.surface),
        greaterThanOrEqualTo(1.20),
      );
    });

    /// The single inverted surface: snackbars, and only snackbars. It is light
    /// on a dark app, which is the whole reason it exists — and the reason the
    /// busy pill on the white A4 page must not use it.
    test('inverted chrome', () {
      expectAtLeast(
        'onInverseSurface/inverseSurface',
        cs.onInverseSurface,
        cs.inverseSurface,
        bodyText,
      );
      expectAtLeast(
        'inversePrimary/inverseSurface',
        cs.inversePrimary,
        cs.inverseSurface,
        bodyText,
      );
    });

    /// App chrome drawn on top of a rendered resume page. The page is white
    /// because it is a document, so these are measured against white rather
    /// than against any app surface. Matte black raises the stakes: the jump
    /// from base to paper is 19:1, wider than the indigo palette's, so both the
    /// overlays and the mat ring were re-measured rather than assumed.
    group('chrome on paper', () {
      const paper = Color(0xFFFFFFFF);

      test('the busy pill and the message card are found on white paper', () {
        expectAtLeast(
          'surfaceContainerLowest/paper',
          cs.surfaceContainerLowest,
          paper,
          largeTextAndUi,
        );
        expectAtLeast(
          'errorContainer/paper (stale banner)',
          cs.errorContainer,
          paper,
          largeTextAndUi,
        );
      });

      test('what is written on that chrome is readable', () {
        expectAtLeast(
          'onSurface/surfaceContainerLowest (pill label)',
          cs.onSurface,
          cs.surfaceContainerLowest,
          bodyText,
        );
        expectAtLeast(
          'primary/surfaceContainerLowest (pill spinner)',
          cs.primary,
          cs.surfaceContainerLowest,
          largeTextAndUi,
        );
        expectAtLeast(
          'onErrorContainer/errorContainer (stale banner copy)',
          cs.onErrorContainer,
          cs.errorContainer,
          bodyText,
        );
      });

      test('the mat ring frames the page from both sides', () {
        // The ring replaced the drop shadow under the A4 page and under every
        // gallery thumbnail. It only works if it is a real step *away* from the
        // paper as well as a real edge against the chrome behind it — and on
        // this palette "the chrome behind it" includes five card tints.
        expectAtLeast(
          'outline/paper (inner edge of the mat)',
          cs.outline,
          paper,
          largeTextAndUi,
        );
        expectAtLeast(
          'outline/surface (outer edge of the mat)',
          cs.outline,
          cs.surface,
          largeTextAndUi,
        );
        tints.forEach((name, tint) {
          expectAtLeast(
            'outline/$name (mat on a card)',
            cs.outline,
            tint,
            largeTextAndUi,
          );
        });
      });

      test('the thumbnail placeholder can never be read as a page', () {
        // It stands in for a document that has not rendered yet. Two of the
        // thirteen designs are deliberately dark pages, so "not white" is not
        // enough on its own.
        expectAtLeast(
          'surfaceContainerHighest/paper',
          cs.surfaceContainerHighest,
          paper,
          largeTextAndUi,
        );
        expectAtLeast(
          'onSurfaceVariant/surfaceContainerHighest (its label)',
          cs.onSurfaceVariant,
          cs.surfaceContainerHighest,
          bodyText,
        );
        expectAtLeast(
          'primary/surfaceContainerHighest (its spinner)',
          cs.primary,
          cs.surfaceContainerHighest,
          largeTextAndUi,
        );
      });
    });
  });

  group('theme wiring', () {
    test('exposes design tokens as a theme extension', () {
      final theme = AppTheme.build();
      expect(theme.extension<AppTokens>(), isNotNull);
      expect(theme.extension<AppTokens>()!.minTouchTarget, 48);
      expect(theme.extension<AppTokens>()!.cardTints, hasLength(8));
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    /// The base is a *neutral* near-black, which is the whole point of the
    /// re-tone: the palette it replaced was a deep indigo and read as navy.
    test('the base carries no colour cast', () {
      final base = AppTheme.colorScheme.surface;
      final r = (base.r * 255).round();
      final g = (base.g * 255).round();
      final b = (base.b * 255).round();
      expect(r, g, reason: 'a neutral black has equal red and green');
      expect(
        b - r,
        lessThanOrEqualTo(4),
        reason:
            'blue runs $b against $r of red; past a couple of steps this '
            'starts reading as navy again',
      );
      expect(base.computeLuminance(), lessThan(0.01));
    });

    /// One separation language. Cards are set apart by a flat tint step plus a
    /// hairline; nothing in the app is held up by a shadow, which on a matte
    /// base would be invisible anyway — and which `flutter_test` disables, so
    /// it could never have been verified here.
    test('no surface separates itself with a shadow', () {
      final theme = AppTheme.build();
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.shadowColor, const Color(0x00000000));
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.snackBarTheme.elevation, 0);
      expect(theme.floatingActionButtonTheme.elevation, 0);
      // `PopupMenuButton` defaults to elevation 8 with a black shadow, so the
      // editor's overflow menu was the last surface still separating itself the
      // old way. Unset themes are the whole risk here, which is why this is
      // asserted per surface rather than as a claim in a comment.
      expect(theme.popupMenuTheme.elevation, 0);
      expect(theme.popupMenuTheme.shadowColor, const Color(0x00000000));
    });

    /// A popup is the one raised surface with nothing behind it to separate it
    /// — no scrim like a dialog, no screen it is laid on like a card — so its
    /// tint step alone was never going to be enough.
    test('the overflow menu is a raised surface with a real edge', () {
      final theme = AppTheme.build();
      expect(
        theme.popupMenuTheme.color,
        AppTheme.colorScheme.surfaceContainerHigh,
      );
      final shape = theme.popupMenuTheme.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppTheme.colorScheme.outline);
      expect(
        theme.popupMenuTheme.labelTextStyle,
        isNull,
        reason:
            'a flat label style overrides Material\'s disabled resolution, '
            'which is what keeps a greyed-out menu item looking greyed out',
      );
    });

    /// A card tint has to stand on its own, because it is what says "card".
    /// The plain neutral tier does not and is not asked to: it is 1.08:1 above
    /// the base and leans on `outlineVariant` for its edge, which is why the
    /// two are asserted to different bars rather than to one average.
    test('every card tint is a visible step above the base surface', () {
      final base = AppTheme.colorScheme.surface;
      for (final entry in tints.entries) {
        expect(
          entry.value.computeLuminance(),
          greaterThan(base.computeLuminance()),
          reason: '${entry.key} is not above the base surface',
        );
        final step = contrastRatio(entry.value, base);
        expect(
          step,
          greaterThanOrEqualTo(1.35),
          reason:
              '${entry.key} steps up by only ${step.toStringAsFixed(2)}:1, '
              'which is not a card edge',
        );
      }
    });

    test('the plain neutral card leans on its hairline instead', () {
      final step = contrastRatio(
        AppTheme.colorScheme.surfaceContainerLow,
        AppTheme.colorScheme.surface,
      );
      expect(step, greaterThan(1.0));
      expect(
        step,
        lessThan(1.35),
        reason:
            'it measures ${step.toStringAsFixed(2)}:1 — if it ever grew past '
            'the tints it would stop being the quiet option',
      );
      expect(AppTheme.build().cardTheme.shape, isA<RoundedRectangleBorder>());
      final shape = AppTheme.build().cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppTheme.colorScheme.outlineVariant);
    });

    /// And they have to stay in one family. A card in each of eight wildly
    /// different brightnesses reads as a bug, not as a palette — and it is this
    /// property that lets one outline value clear 3:1 on all of them.
    test('the card tints share one luminance band', () {
      final luminances = tokens.cardTints
          .map((c) => c.computeLuminance())
          .toList();
      final spread =
          (luminances.reduce(math.max) + 0.05) /
          (luminances.reduce(math.min) + 0.05);
      expect(
        spread,
        lessThan(1.25),
        reason:
            'the tints differ by ${spread.toStringAsFixed(3)}:1 in brightness; '
            'they are meant to differ in hue. Widen this and the single '
            'outline value stops clearing 3:1 on the lightest of them',
      );
    });

    /// The dark chrome depends on it: light glyphs on a matte status bar and a
    /// system nav bar that matches the scaffold instead of ending the screen in
    /// a mismatched strip.
    test('system overlay is configured for a dark background', () {
      expect(AppTheme.systemOverlay.statusBarIconBrightness, Brightness.light);
      expect(AppTheme.systemOverlay.statusBarBrightness, Brightness.dark);
      expect(
        AppTheme.systemOverlay.systemNavigationBarIconBrightness,
        Brightness.light,
      );
      expect(
        AppTheme.systemOverlay.systemNavigationBarColor,
        AppTheme.colorScheme.surface,
      );
    });

    test('interactive defaults meet the minimum touch target', () {
      final theme = AppTheme.build();
      final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(size?.height, greaterThanOrEqualTo(48));
    });
  });
}
