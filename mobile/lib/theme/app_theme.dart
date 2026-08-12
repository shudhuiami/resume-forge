import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Matte black Material 3 theme for the application shell.
///
/// **This palette is app chrome only.** Resume templates carry their own
/// independent document palettes and must never read from this [ColorScheme] —
/// a resume printed in the app's amber would be a defect, not a feature. The
/// two colour worlds stay strictly separate: this file styles the frame,
/// `templates/` styles the page inside it. Eleven of the thirteen designs are
/// light documents, so with a near-black frame the boundary is visible at a
/// glance: anything white on screen is the page, everything tinted is chrome.
///
/// **Nothing here is a gradient, and nothing here is glossy.** Depth comes from
/// flat, solid tints stepped against a neutral near-black — see
/// [AppTokens.cardTints] — and from one saturated accent. There is no ramp on
/// any surface, no glow under any mark, and no shadow under any panel. That is
/// the whole design: matte.
///
/// The base is deliberately *neutral* black rather than a tinted one. `#0E0E10`
/// has R and G equal and B two steps up, which is as much blue as it may carry
/// before it starts reading as the navy this palette replaced.
abstract final class AppTheme {
  /// Bundled UI typeface. See `assets/fonts` and the pubspec `fonts:` block.
  static const uiFontFamily = 'Inter';

  /// Base background: matte, neutral near-black.
  ///
  /// Duplicated outside Dart — `flutter_native_splash.yaml`, the Android window
  /// background, and the baked icon backdrop are all this exact colour, so the
  /// launch never flashes a different one. `test/brand/brand_assets_test.dart`
  /// fails if this value and those copies drift apart, so **do not change it
  /// without regenerating the brand assets**.
  static const _bg = Color(0xFF0E0E10);

  /// The deepest tier, below the base. Two jobs, and they are the same idea
  /// seen from either side: it is the *well* a form field, a design plate or a
  /// section mark is punched down into, and it is the "chrome on paper"
  /// surface — the busy pill and the preview's message card, which sit on a
  /// white A4 page and have to read unmistakably as app furniture lying on a
  /// document (20.01:1 against paper).
  static const _well = Color(0xFF08080A);

  /// Neutral surface tiers above the base, for chrome that carries no identity
  /// of its own. `Low` is the plain card, `Container` the step above it, `High`
  /// is raised chrome that floats over content — dialogs, sheets, chips, popup
  /// menus — and `Highest` is the placeholder a gallery thumbnail sits on
  /// before its page has rendered, which has to be told apart from paper white
  /// *and* from the two deliberately dark pages in the catalog.
  ///
  /// Screens that want identity take a solid tint from [AppTokens] instead.
  static const _panel = Color(0xFF17171A);
  static const _panelMid = Color(0xFF1A1A1E);
  static const _panelRaised = Color(0xFF1E1E22);
  static const _panelBrightest = Color(0xFF26262B);

  /// Boundary of real controls (outlined buttons, focusable inputs, chips, the
  /// sheet drag handle) and the mat ring around a document.
  ///
  /// **This is the value the palette turns on.** WCAG 1.4.11 asks a control
  /// boundary for 3:1 against the surface it is actually drawn on, and in this
  /// app that surface is usually one of the eight card tints, not the base. A
  /// boundary picked against the base alone lands around 2.2–2.5:1 on a tint —
  /// visible in a screenshot of an empty screen, invisible on the card the
  /// button is really sitting on. So it is solved from the other end: this is
  /// the *lightest* value that still lets the same colour serve as the mat ring
  /// around white paper.
  ///
  /// The window is genuinely narrow, and both ends are load-bearing:
  ///   * >= 3:1 on the lightest tint (ochre) forces luminance >= 0.224
  ///   * >= 3:1 against white paper caps luminance at 0.300
  /// At 0.259 it measures 3.38:1 on ochre, 3.40:1 on paper, 3.62–4.10:1 on the
  /// remaining tints, 4.43–5.89:1 on every neutral tier, and 5.68:1 on the
  /// base. One value, every surface, no per-tint derivation to keep in step.
  /// `contrast_test` iterates all fourteen rather than sampling.
  ///
  /// [_hairline] below is the decorative counterpart for dividers and card
  /// edges, where near-invisibility is the whole point.
  static const _outline = Color(0xFF8E8B85);
  static const _hairline = Color(0xFF2A2A2F);

  /// Matte amber, and the app's only accent.
  ///
  /// One saturated colour on a neutral black, spent on the things that act:
  /// the filled button, the FAB, section marks, focus, links, selection. It is
  /// also the fill of the launcher icon's page and of the splash mark, so the
  /// thing the user taps on the home screen is the colour that greets them —
  /// `test/brand/brand_assets_test.dart` pins that handshake.
  ///
  /// Light enough to be read *as text* on every surface in the app (8.73:1 on
  /// the base, 5.20:1 on the worst tint) and dark enough to carry near-black
  /// ink on top of it (8.46:1), which is what lets one colour be both the
  /// button fill and the button label elsewhere.
  static const _amber = Color(0xFFD8A657);

  /// Ink for anything drawn on top of a saturated accent. A near-black rather
  /// than white: on this palette the accents are light, so their labels invert.
  static const _onAccent = Color(0xFF141210);

  /// The two neutral "accents" [ColorScheme] insists on.
  ///
  /// This palette has exactly one accent, on purpose. `secondary` and
  /// `tertiary` exist because the scheme requires them, and they are held to
  /// warm stones rather than invented hues so that any Material default that
  /// reaches for one lands on a colour the palette actually contains — instead
  /// of quietly introducing a second brand colour nobody chose.
  static const _stoneWarm = Color(0xFFC7BCA6);
  static const _stoneNeutral = Color(0xFFB7B2AA);

  /// Failure. A warm coral rather than a pure red: on a neutral black a
  /// saturated red sits too dark to read as body copy, and this clears 6.26:1
  /// on the base while still taking near-black ink at 6.06:1.
  static const _danger = Color(0xFFE4715B);

  /// The surface behind failure copy, and the one place a deep red is used as a
  /// fill: the editor's truncation banner and the preview's stale banner.
  ///
  /// Held *below the whole card-tint band* — darker than plum, the darkest of
  /// the eight — so a warning strip can never be read as one more section card
  /// on a form made of them. That is asserted rather than eyeballed, because
  /// the first value tried for this sat 1.01:1 from plum and would have passed
  /// any check that only looked at the base. Still a real step above the base
  /// itself (1.25:1), still findable on white paper (15.43:1) since the stale
  /// banner is chrome lying on a document, and it carries a warm pink-white ink
  /// no card uses, at 11.51:1.
  static const _dangerSurface = Color(0xFF451410);
  static const _onDangerSurface = Color(0xFFF6D8D1);

  /// Warm off-white for headings and body, warm grey for supporting copy.
  /// Pure white on matte black is harsher than this palette wants at body
  /// sizes, and the warmth is what keeps the neutral base from reading blue.
  static const _onSurface = Color(0xFFF2F0EC);
  static const _onSurfaceMuted = Color(0xFFA8A5A0);

  static const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _amber,
    onPrimary: _onAccent,
    // The container slots alias three of the card tints rather than inventing
    // three more colours. Same palette, fewer values to keep measured, and a
    // Material default can only ever land on a colour the app already uses.
    primaryContainer: Color(0xFF473719), // ochre
    onPrimaryContainer: _onSurface,
    secondary: _stoneWarm,
    onSecondary: _onAccent,
    secondaryContainer: Color(0xFF25304A), // slate
    onSecondaryContainer: _onSurface,
    tertiary: _stoneNeutral,
    onTertiary: _onAccent,
    tertiaryContainer: Color(0xFF3D2438), // plum
    onTertiaryContainer: _onSurface,
    error: _danger,
    onError: _onAccent,
    errorContainer: _dangerSurface,
    onErrorContainer: _onDangerSurface,
    surface: _bg,
    onSurface: _onSurface,
    // In a dark scheme the tiers run the other way to a light one: "lowest" is
    // the deepest well and "highest" the brightest neutral panel.
    surfaceContainerLowest: _well,
    surfaceContainerLow: _panel,
    surfaceContainer: _panelMid,
    surfaceContainerHigh: _panelRaised,
    surfaceContainerHighest: _panelBrightest,
    onSurfaceVariant: _onSurfaceMuted,
    outline: _outline,
    outlineVariant: _hairline,
    // The one light surface in the app, and it means exactly what its name
    // says: inverted. Snackbars only. It is deliberately *not* the surface for
    // chrome that sits on the white A4 page — a pale pill on pale paper is a
    // disappearance, which is why that chrome takes [_well] instead.
    inverseSurface: _onSurface,
    onInverseSurface: _panelMid,
    inversePrimary: Color(0xFF6B4E15),
    shadow: Color(0xFF000000),
    // Neutral black, like the base. A tinted scrim over a matte black app
    // would put a hue back into the one place the palette has none.
    scrim: Color(0xFF000000),
  );

  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // Dark background: the status bar and nav bar glyphs have to be light to
    // stay visible. `statusBarBrightness` is the iOS spelling and describes the
    // *background*, so it is the inverse of the Android icon brightness.
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: _bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// One state of the input rule.
  ///
  /// The fill is rounded at the top and squared onto the rule at the bottom,
  /// which is what keeps a soft-filled field from reading as a floating pill
  /// detached from its own boundary line.
  static InputBorder _fieldBorder(Color color, {double width = 1}) {
    const tokens = AppTokens();
    return UnderlineInputBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radiusSm),
      ),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// How far a disabled field's copy is faded back toward its own fill.
  ///
  /// A disabled control is exempt from the text contrast minimum precisely
  /// because it is supposed to look unavailable — what matters is the *step*
  /// away from the enabled state, which is what a user reads the state off.
  ///
  /// Re-derived for this palette rather than carried over: the well is deeper
  /// than the old one, so the same alpha blended darker and cost legibility.
  /// The two requirements pull against each other — a heavier fade separates
  /// the states better but sinks the label into the fill — and 0.54 is where
  /// they meet. At this alpha the label measures **3.04:1 on the field fill**
  /// (still legible, so a switched-off field can still be identified — the same
  /// figure the previous palette landed on) and **2.68:1 against the enabled
  /// label** it has to be told apart from. Both asserted in
  /// `test/theme/contrast_test.dart`.
  @visibleForTesting
  static const disabledInkAlpha = 0.54;

  /// The palette's answer for "this control is off".
  ///
  /// Stating it once matters: setting a flat `labelStyle` colour in
  /// `inputDecorationTheme` *overrides* Material's own disabled resolution, so
  /// every state a field can be in has to be spelled out here or the disabled
  /// one silently inherits the enabled colour.
  static TextStyle _fieldInk(Set<WidgetState> states, Color enabled) {
    if (states.contains(WidgetState.disabled)) {
      return TextStyle(
        color: _onSurfaceMuted.withValues(alpha: disabledInkAlpha),
      );
    }
    return TextStyle(color: enabled);
  }

  static ThemeData build() {
    const tokens = AppTokens();
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      // Bundled, not downloaded. Material's default Roboto is fetched from a
      // CDN on web, which blocks first paint when the network is unavailable
      // and is a dependency this app has no reason to carry.
      fontFamily: uiFontFamily,
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
        // M3 tints a raised surface with the primary colour, in proportion to
        // its elevation. Kept off: every card here already carries an authored
        // solid tint, and an automatic amber wash over them would drag teal and
        // plum back toward amber — flattening the exact variety the tints exist
        // to create. Every surface's colour is stated, never derived.
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          // Large and tight, per the reference: headings hold the contrast in
          // an otherwise low-contrast chrome.
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        // The plain card. Screens that carry an identity pass one of the
        // `AppTokens` tints instead.
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        // Separated from the background by a flat tint step first and a
        // hairline second, never by a shadow. One system, and the one that
        // works on a matte base — see the note on `AppTokens`.
        elevation: 0,
        shadowColor: Colors.transparent,
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
          elevation: 0,
          // Pill, not a rounded rectangle: the solid amber action is the one
          // shape in the app that is allowed to look like a physical button.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
          // The family must be named explicitly. A bare TextStyle here drops
          // ThemeData.fontFamily and falls back to Roboto — the wrong typeface
          // on device, and invisible text on web where Roboto is not bundled.
          textStyle: const TextStyle(
            fontFamily: uiFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, tokens.minTouchTarget),
          foregroundColor: colorScheme.onSurface,
          // Unfilled, so the button sits on whichever tint hosts it rather than
          // punching a fixed-colour plate through a teal or plum card. Its
          // boundary is the whole control, which is why that boundary is the
          // accessible outline and not the decorative hairline — and why that
          // outline had to be solved against every tint, not against the base.
          backgroundColor: Colors.transparent,
          side: BorderSide(color: colorScheme.outline),
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceXl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
          textStyle: const TextStyle(
            fontFamily: uiFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, tokens.minTouchTarget),
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
          textStyle: const TextStyle(
            fontFamily: uiFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        // Flat, like everything else. A solid amber pill over a matte black
        // list is already the highest-contrast object on the screen; a shadow
        // under it would be invisible and is not what is holding it up.
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
        extendedTextStyle: const TextStyle(
          fontFamily: uiFontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      // Soft-filled, underlined fields. A form is eight to forty of these in a
      // column, and a box drawn round every one of them turns a section into a
      // stack of identical rectangles with no grouping left to read. The tint
      // marks the field's extent, the rule marks its boundary, and a run of
      // them inside one card reads as a single list.
      //
      // The fill is the deepest tier, so a field is a well punched through its
      // card back down past the base surface. That is one fill for cards of
      // eight different hues, and it works precisely because it is a *recess*
      // rather than a competing tint — 1.44:1 to 1.74:1 below the tint it is
      // cut into, which is a deeper recess than the previous palette managed.
      //
      // The rule is still not decoration: that 1.4–1.7:1 is far under the 3:1
      // WCAG 1.4.11 wants from the edge of a control, so the `outline`
      // underline is what makes a field locatable (5.89:1 against the fill).
      // Focus doubles it and switches it to the amber; error switches it to the
      // error colour. Both are unmistakable against a resting warm grey.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: EdgeInsets.fromLTRB(
          tokens.spaceLg,
          tokens.spaceLg,
          tokens.spaceLg,
          tokens.spaceMd,
        ),
        // Resolved per state rather than flat. A flat colour here wins over
        // Material's own disabled resolution, which is how the disabled end
        // date — the "I currently work here" case — ended up with a label
        // exactly as bright as the field beside it that you *can* type into.
        // The rule under it dropped to the hairline as designed, but a 1px
        // difference was the only thing saying the control was off.
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => _fieldInk(states, colorScheme.onSurfaceVariant),
        ),
        // A label floats as soon as its field holds text, so a flat accent
        // colour here painted every label in a filled-in form amber and left
        // nothing to mark the field the user is actually in. The accent is
        // spent on focus only.
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.error)) {
            return TextStyle(color: colorScheme.error);
          }
          if (states.contains(WidgetState.focused)) {
            return TextStyle(color: colorScheme.primary);
          }
          return _fieldInk(states, colorScheme.onSurfaceVariant);
        }),
        hintStyle: WidgetStateTextStyle.resolveWith(
          (states) => _fieldInk(states, colorScheme.onSurfaceVariant),
        ),
        helperStyle: WidgetStateTextStyle.resolveWith(
          (states) => _fieldInk(states, colorScheme.onSurfaceVariant),
        ),
        // Material truncates helper and error text to a single line by
        // default, which turned a full sentence of guidance under the summary
        // field into "…". Advice the user cannot finish reading is worse than
        // an extra line of height.
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: _fieldBorder(colorScheme.outline),
        enabledBorder: _fieldBorder(colorScheme.outline),
        // Dropping to the hairline is the point: a disabled end date (the
        // "I currently work here" case) should stop reading as something you
        // can type into, and a boundary below 3:1 is exactly how a control
        // says it is not one.
        disabledBorder: _fieldBorder(colorScheme.outlineVariant),
        focusedBorder: _fieldBorder(colorScheme.primary, width: 2),
        errorBorder: _fieldBorder(colorScheme.error),
        focusedErrorBorder: _fieldBorder(colorScheme.error, width: 2),
      ),
      chipTheme: ChipThemeData(
        // Raised chrome, not a well: a filter chip is a control that sits on
        // top of the screen's base surface, and the tint step is what says so.
        // The step alone is ~1.16:1 though, so the boundary carries the visible
        // outline rather than the hairline — an unselected chip is a real
        // control and has to be locatable as one.
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: colorScheme.outline),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
      ),
      // Presented surfaces take the raised tier and no shadow: what separates
      // them from the screen behind is the modal scrim plus the tint step, both
      // of which survive on a matte base where a drop shadow does not.
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXl),
        ),
      ),
      // The editor's overflow menu. `PopupMenuButton` defaults to elevation 8
      // with a black `shadowColor`, so while every card, dialog, sheet,
      // snackbar and FAB had been flattened, this one still painted a falloff
      // nobody could see.
      //
      // Flattened to match, and given a boundary the others do not need: a
      // dialog is separated by its modal scrim and a card by the screen it is
      // laid on, but a popup has neither. Without an edge, `surfaceContainer`
      // sat 1.04:1 from the panel behind it. The raised tier plus the visible
      // outline is what makes it read as a thing floating over the form.
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        // `labelTextStyle` is deliberately left to Material's own defaults:
        // they resolve `WidgetState.disabled` to a faded ink, and a flat style
        // here would override that and hand "Clear all fields" the same
        // brightness when it is unavailable as when it is live — the same trap
        // the input theme above just had to be dug out of.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        modalBackgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        // The handle is a control affordance, so it takes the visible outline
        // rather than the hairline.
        dragHandleColor: colorScheme.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusXl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: uiFontFamily,
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: colorScheme.outlineVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        // The one inverted surface in the app, and the only place `inverse*`
        // is used: a dark snackbar on a dark app is a message nobody sees, so
        // it flips to light with dark ink and a deep amber accent.
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: uiFontFamily,
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
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
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
      ),
    );
  }
}
