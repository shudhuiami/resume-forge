import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Text field for the resume editor.
///
/// Always renders a real label rather than relying on a placeholder: hint text
/// disappears the moment the user types, leaving long forms unlabelled exactly
/// when someone scrolls back to check what a half-filled field was for.
class ResumeTextField extends StatelessWidget {
  const ResumeTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofillHints,
    this.helper,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: TextFormField(
        // A key tied to nothing but position would recycle controllers across
        // list reorders and move text into the wrong row.
        initialValue: value,
        onChanged: onChanged,
        keyboardType: keyboardType,
        // maxLines > 1 fields must accept Enter as a newline, not as "next".
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : textInputAction,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

/// Section heading inside the editor form.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceLg, bottom: tokens.spaceMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Card wrapper for one repeating entry (a job, a degree, a project).
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.title,
    required this.children,
    required this.onRemove,
    this.removeTooltip = 'Remove',
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceMd),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  // Icon-only control: without this the action is unlabelled
                  // for screen readers and ambiguous by sight.
                  tooltip: removeTooltip,
                ),
              ],
            ),
            SizedBox(height: tokens.spaceSm),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "Add another" action at the end of a repeating section.
class AddEntryButton extends StatelessWidget {
  const AddEntryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// Month/year text entry.
///
/// Deliberately free text rather than a date picker: resume dates are
/// month-granular and often partial, and a picker would force a day the user
/// never intended to state.
class MonthYearField extends StatelessWidget {
  const MonthYearField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: TextFormField(
        initialValue: value,
        enabled: enabled,
        onChanged: onChanged,
        keyboardType: TextInputType.datetime,
        inputFormatters: [LengthLimitingTextInputFormatter(10)],
        decoration: InputDecoration(labelText: label, hintText: 'YYYY-MM'),
      ),
    );
  }
}
