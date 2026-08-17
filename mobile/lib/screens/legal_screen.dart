import 'package:flutter/material.dart';

import '../legal.dart';
import '../theme/tokens.dart';

/// Widest the column is allowed to grow, matching the rest of the app.
const _maxContentWidth = 640.0;

/// Widest a paragraph is allowed to run. Legal prose is the longest reading in
/// the app, so this is the one screen where the measure genuinely matters.
const _maxProseWidth = 380.0;

/// Renders a [LegalDocument] — the privacy policy or the terms.
///
/// One screen for both, because they are the same shape: a title, the date the
/// wording took effect, an honest one-paragraph summary, then headed sections.
/// Two near-identical screens would be two places to fix a spacing bug.
///
/// The summary is not decoration. Nobody reads a policy in full, so the short
/// version goes first and in a card, where it will actually be seen; the
/// sections below it are for the reader who wants the detail.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                tokens.spaceLg,
                tokens.spaceLg,
                tokens.spaceXxl,
              ),
              children: [
                Text(
                  'In effect from $legalEffectiveDate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.spaceMd),
                _Summary(text: document.summary),
                SizedBox(height: tokens.spaceXl),
                for (final section in document.sections) ...[
                  Text(
                    section.heading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSm),
                  for (final paragraph in section.paragraphs)
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spaceMd),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxProseWidth,
                        ),
                        child: Text(
                          paragraph,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: tokens.spaceLg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plain-language version, in the tinted card treatment the About screen
/// uses for the thing it most wants read.
class _Summary extends StatelessWidget {
  const _Summary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spaceLg),
      decoration: BoxDecoration(
        color: tokens.tintSlate,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.45,
        ),
      ),
    );
  }
}
