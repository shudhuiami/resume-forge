import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';

import '../theme/tokens.dart';
import '../widgets/form_fields.dart';

/// Widest the column is allowed to grow, matching the resume list: a paragraph
/// run across a full tablet is a reading problem, not a use of the space.
const _maxContentWidth = 640.0;

/// Widest a paragraph of body copy is allowed to run, in the same spirit.
const _maxProseWidth = 380.0;

/// The product's name, spelled once for the whole app.
///
/// The version this build reports.
///
/// A const rather than a lookup: `package_info_plus` is not a dependency of
/// this app, and adding a package — plus its Android and iOS platform channels
/// — to print five characters would be by far the larger change on a build that
/// has no other reason to ask the platform anything.
///
/// The cost of a const is that it can drift from `pubspec.yaml`, so it is held
/// in step by a test rather than by memory: `test/screens/about_screen_test.dart`
/// reads the pubspec off disk and fails if the two disagree. **Change the
/// pubspec and this together.**
const appVersion = '1.0.0';

/// Exactly how the developer is credited. One spelling, in one place, lowercase
/// as given.
const developerName = 'codevioso';

/// The developer's own logo, bundled under `assets/vendor/`.
///
/// An image rather than a redrawing: it is somebody else's mark, so this app
/// does not approximate it, recolour it or stretch it. White on transparent,
/// which is the reason it is only ever laid on a dark card.
const developerLogoAsset = 'assets/vendor/codevioso-logo-white.webp';

/// The mark's intrinsic proportion — the asset is 800x152.
const _developerLogoAspect = 800 / 152;

/// Height the mark is drawn at when the system text size is 1.
///
/// Roughly a heading's cap height once the logo's own internal padding is taken
/// off, which is what makes it read as a credit rather than as a banner.
const _developerLogoHeight = 30.0;

/// Where the mark stops growing with the system text size.
///
/// It is a name, so it grows like one rather than staying an icon-sized fixed
/// graphic — but it is a *wide* name (5.26:1), and past roughly this scale it
/// runs out of card on a 360px phone. The [LayoutBuilder] in [_DeveloperLogo]
/// is what makes the cap true rather than merely likely.
const _logoMaxTextScale = 1.6;

/// Size of the glyph marking one privacy guarantee. A fixed graphic, like every
/// other mark in the app: it does not grow with the type beside it.
const _factGlyph = 18.0;

/// Addresses the credit logo from a test.
@visibleForTesting
const developerLogoKey = Key('developer-logo');

/// What the app is and who made it.
///
/// Deliberately short. An about screen is a colophon, not a manual: the brand,
/// what the product does in one line, the one property of it that is worth a
/// claim, the credit, and the version. Everything else the user can find by
/// using the app.
///
/// The one claim gets the room, because it is the actual differentiator rather
/// than a boast: there is no account, no server and no network call anywhere in
/// this app, so that is stated as three separate guarantees instead of one
/// sentence a reader skims past.
///
/// There is no link on it. No URL, contact address or legal entity was given
/// for [developerName], and a control that looks tappable and opens nothing is
/// worse than no control at all — so the credit is the mark and the name until
/// there is a real destination to point it at. See the TODO below.
// TODO(codevioso): add the developer's URL here once one is supplied, as a
// TextButton in the credit card. Nothing is invented in the meantime.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const tagline =
      'A no-signup resume builder. Pick a design, fill in one form, and '
      'export a print-ready PDF.';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      // Untitled, like the gallery's: the screen's title is the wordmark in the
      // body below, and repeating it in the bar would say the same thing twice
      // in two sizes. The bar is here for the back affordance.
      appBar: AppBar(),
      // The bar already clears the status bar; a second SafeArea at the top
      // would inset the body twice. The other three edges still matter — a
      // landscape phone puts a notch on one side and a gesture bar below.
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            // A list rather than a column: the two cards plus the brand block
            // are taller than a landscape phone at a large text size, and this
            // is a screen with nothing on it worth clipping.
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                0,
                tokens.spaceLg,
                tokens.spaceXl,
              ),
              children: [
                const _BrandBlock(),
                SizedBox(height: tokens.spaceXl),
                const _PrivacyCard(),
                const _CreditCard(),
                const _VersionFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The product name, with the one letter the brand colours.
///
/// The Resivo logo is a serif wordmark whose only colour is a gold dot on the
/// "i". The app cannot reproduce the logo's typeface — the UI is set in Inter,
/// and a second chrome typeface bundled to print six letters would be a bigger
/// change than the cue is worth — so what is carried inside the app is the
/// *accent*, not the drawing: the "i" takes [ColorScheme.primary], which is the
/// same amber as the mark's gold (8.73:1 on the base surface, so the letter is
/// legible type rather than decoration). At UI sizes the stem of an "i" is a
/// hairline, so what the eye actually reads is the gold dot.
///
/// It is deliberately **not** a picture. The pictorial mark belongs to the
/// launcher icon and the splash, which are generated from one geometry in
/// `assets/brand`; a second hand-drawn copy of it in a screen file would be a
/// second mark to keep in step, and the home screen's title row has an icon
/// button to share its width with at double text size.
///
/// One node to a screen reader — [Text.rich] would otherwise offer three, one
/// per span — and it reads back as the plain name.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.style, this.maxLines, this.overflow});

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: appName.substring(0, appNameAccentLetter)),
          TextSpan(
            text: appName[appNameAccentLetter],
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          TextSpan(text: appName.substring(appNameAccentLetter + 1)),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: appName,
    );
  }
}

/// The brand, and what the product is, in that order.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shrinks rather than clips. "Resivo" is one unbreakable word with no
        // wrap opportunity in it, so at an extreme accessibility text size the
        // only alternatives are cutting the product's name in half or running
        // it off the edge of the screen. It fits unscaled well past 3x on the
        // narrowest phone; this is what happens after that.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: BrandWordmark(
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              // Large and tight, like every other heading in the app.
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(height: tokens.spaceSm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxProseWidth),
          child: Text(
            AboutScreen.tagline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The product's one real claim, given the room it earns.
///
/// The same card the editor's form sections are built from — solid tint,
/// recessed accent mark, hairline edge, one radius — rather than a second card
/// style invented for one screen. The tone is chosen for its *tint*: slate and
/// plum are far enough apart to read as two things, and both carry `onSurface`
/// and `onSurfaceVariant` well past AA (measured in
/// `test/theme/contrast_test.dart`, against every tint).
///
/// It used to be one sentence — "No accounts, no backend, no network." — which
/// is the kind of line a reader's eye slides over. The same three facts as
/// three marked guarantees are the same promise with somewhere to land, and
/// nothing is added: the closing line is the rest of the original sentence.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  static const guarantees = [
    'No account to create',
    'No backend, nothing uploaded',
    'Works with nothing connected',
  ];

  static const storageLine = 'Your resumes are saved on this device only.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FormSectionCard(
      icon: Icons.lock_outline,
      title: 'Everything stays on this device',
      tone: SectionTone.about,
      children: [
        for (final guarantee in guarantees) _Guarantee(guarantee),
        Text(
          storageLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One guarantee: an accent tick and the fact it is vouching for.
///
/// The tick is `primary` on the slate tint at 5.94:1 — past what a meaningful
/// graphic needs by a factor of two, and past AA for text as well, which is the
/// bar a mark carrying this much of the screen's meaning should clear. The copy
/// beside it is `onSurface` rather than the muted ink the rest of the screen's
/// prose takes: these are the headline facts of the card, not its footnotes.
class _Guarantee extends StatelessWidget {
  const _Guarantee(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: Row(
        // Top-aligned, so a fact that wraps to two lines at a large text size
        // keeps its tick beside the first line rather than floating to the
        // middle of the block.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_rounded,
            size: _factGlyph,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: tokens.spaceMd),
          // Wraps rather than ellipsizes: a promise the user cannot finish
          // reading is worse than one that takes a second line.
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Who made it, credited with their own mark.
///
/// One node, not two: unmerged, a screen reader reads "Developed by" and the
/// logo's label as separate stops, which is the one place on this screen where
/// the two halves are meaningless apart.
class _CreditCard extends StatelessWidget {
  const _CreditCard();

  @override
  Widget build(BuildContext context) {
    return const MergeSemantics(
      child: FormSectionCard(
        icon: Icons.code_rounded,
        title: 'Developed by',
        tone: SectionTone.custom,
        children: [_DeveloperLogo()],
      ),
    );
  }
}

/// The developer's logo, drawn at its own proportions and nobody else's.
///
/// Shipped as an image on purpose, and left exactly as supplied: no tint, no
/// `colorBlendMode`, no stretch. Width leads and height follows it, so the
/// 800x152 proportion survives every viewport — including the one that would
/// otherwise break it, a 360px phone at double text size, where the
/// [LayoutBuilder] cap takes over before the card runs out of width.
///
/// It is white on transparent, so it depends on the dark ground underneath it:
/// on the plum card that is 13.92:1, which is the whole reason no plate is
/// drawn behind it.
///
/// Sized like a name rather than like an icon — it grows with the system text
/// size up to [_logoMaxTextScale] — because that is what it is. At its largest
/// it is ~253px wide, inside the 296px a 360px phone's card leaves.
///
/// Decoded at its own resolution rather than through a `cacheWidth`: the source
/// is 800px across and it is drawn at 158–253 logical px, which on a 2x or 3x
/// screen is already at or below native. A cache width would be one more number
/// to be wrong on the next device.
class _DeveloperLogo extends StatelessWidget {
  const _DeveloperLogo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _logoMaxTextScale);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          scaler.scale(_developerLogoHeight) * _developerLogoAspect,
          constraints.maxWidth,
        );
        return Image.asset(
          developerLogoAsset,
          key: developerLogoKey,
          // Both stated, and stated from one number: an image given only a
          // width would reserve no height until it decoded, and the card would
          // jump on the frame it arrived.
          width: width,
          height: width / _developerLogoAspect,
          fit: BoxFit.contain,
          // Without this a screen reader lands on an unlabelled graphic exactly
          // where the developer's name should be.
          semanticLabel: developerName,
          // A missing or undecodable asset must still credit them rather than
          // leaving a hole in the card — the same rule the gallery's thumbnails
          // follow.
          errorBuilder: (context, error, stack) => Text(
            developerName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        );
      },
    );
  }
}

/// The build, as a footer rather than as an orphan line.
///
/// The rule is what makes it read as the end of the page: without it the
/// version sat directly under the last card in the same margin every other
/// block uses, and looked like a paragraph someone forgot to finish.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: tokens.spaceXl),
        Text(
          'Version $appVersion',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
