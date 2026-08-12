import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/form_fields.dart';

/// Widest the column is allowed to grow, matching the resume list: a paragraph
/// run across a full tablet is a reading problem, not a use of the space.
const _maxContentWidth = 640.0;

/// Widest a paragraph of body copy is allowed to run, in the same spirit.
const _maxProseWidth = 380.0;

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

/// What the app is and who made it.
///
/// Deliberately short. An about screen is a colophon, not a manual: what the
/// product does in one line, the one property of it that is worth a claim, the
/// credit, and the version. Everything else the user can find by using the app.
///
/// There is no link on it. No URL, contact address or legal entity was given
/// for [developerName], and a control that looks tappable and opens nothing is
/// worse than no control at all — so the credit is a plain statement until
/// there is a real destination to point it at. See the TODO below.
// TODO(codevioso): add the developer's URL here once one is supplied, as a
// TextButton in the credit card. Nothing is invented in the meantime.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const title = 'ResumeForge';
  static const tagline =
      'A no-signup resume builder. Pick a design, fill in one form, and '
      'export a print-ready PDF.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      // Untitled, like the gallery's: the screen's title is the heading in the
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
            // A list rather than a column: the two cards plus a heading are
            // taller than a landscape phone at a large text size, and this is
            // a screen with nothing on it worth clipping.
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                0,
                tokens.spaceLg,
                tokens.spaceXl,
              ),
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    // Large and tight, like every other screen heading.
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxProseWidth),
                  child: Text(tagline, style: muted),
                ),
                SizedBox(height: tokens.spaceXl),
                // The same card the editor's form sections are built from —
                // solid tint, recessed accent mark, hairline edge, one radius —
                // rather than a second card style invented for one screen. The
                // tone is chosen for its *tint*: slate and plum are far enough
                // apart to read as two things, and both carry `onSurface` and
                // `onSurfaceVariant` well past AA (measured in
                // `test/theme/contrast_test.dart`, against every tint).
                FormSectionCard(
                  icon: Icons.lock_outline,
                  title: 'Everything stays on this device',
                  tone: SectionTone.about,
                  children: [
                    Text(
                      'No accounts, no backend, no network. Your resumes are '
                      'saved on this device only, and the app works with '
                      'nothing connected.',
                      style: muted,
                    ),
                  ],
                ),
                // One node, not two: unmerged, a screen reader reads "Developed
                // by" and the name as separate stops, which is the one place on
                // this screen where the two halves are meaningless apart.
                MergeSemantics(
                  child: FormSectionCard(
                    icon: Icons.code_rounded,
                    title: 'Developed by',
                    tone: SectionTone.custom,
                    children: [
                      Text(
                        developerName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Version $appVersion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
