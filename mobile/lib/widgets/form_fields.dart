import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Which section of the editor form a card belongs to, and therefore which
/// solid tint it is painted in.
///
/// The form stacks six sections of near-identical fields, and a page of six
/// identical cards gives the eye nothing to navigate by. **One tint per
/// section, fixed for the life of the app** — not cycled through a short list,
/// which is what the previous three-tone rotation did and which meant "About
/// you" and "Skills" were the same colour. A section is always the colour it
/// was the last time you scrolled past it, so the colour is worth learning.
///
/// The order below is also the order the sections appear in, and the tints are
/// assigned so that no two *adjacent* cards are close in hue: slate, rust,
/// moss, ochre, teal, plum. Scrolling from Experience to Education crosses a
/// red-brown to a green, not two greens.
///
/// Each value resolves to a token from [AppTokens] rather than naming a colour
/// of its own, so the tints stay inside the app palette and inside what
/// `test/theme/contrast_test.dart` already measures against every tint.
enum SectionTone {
  about,
  experience,
  education,
  skills,
  projects,
  custom;

  /// The section card's surface. Flat and opaque — there are no gradients in
  /// this app.
  Color panel(AppTokens tokens) => switch (this) {
    SectionTone.about => tokens.tintSlate,
    SectionTone.experience => tokens.tintRust,
    SectionTone.education => tokens.tintMoss,
    SectionTone.skills => tokens.tintOchre,
    SectionTone.projects => tokens.tintTeal,
    SectionTone.custom => tokens.tintPlum,
  };
}

/// Keeps a [TextEditingController] showing whatever the model currently holds.
///
/// This is the fix for the trap every field in this form used to sit in.
/// `TextFormField(initialValue: ...)` is read exactly once — `FormFieldState`
/// does not re-seed it in `didUpdateWidget` — so any code that replaced the
/// document wholesale (load sample, clear, undo) updated the model, the
/// preview and storage while the visible text stayed stale. The editor worked
/// around it by keying the whole form on a revision counter and rebuilding the
/// subtree from scratch; that fixed the three call sites that existed and left
/// the trap armed for the fourth.
///
/// Owning the controller closes it properly: the field follows the model from
/// wherever the change came from.
///
/// The guard is what makes this safe to do on a form that rebuilds on every
/// keystroke. Typing calls `onChanged`, which updates the model, which rebuilds
/// this widget with the value the user just typed — identical to the
/// controller's text, so nothing is written back and the caret is left alone.
/// Only a value that genuinely differs from what is on screen moves the text,
/// and then the caret goes to the end, which is where it belongs after content
/// the user did not type appears.
mixin _ModelBackedField<T extends StatefulWidget> on State<T> {
  final controller = TextEditingController();

  /// The value this field is currently meant to be showing.
  String get modelValue;

  @override
  void initState() {
    super.initState();
    controller.text = modelValue;
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (modelValue == controller.text) return;
    controller.value = TextEditingValue(
      text: modelValue,
      selection: TextSelection.collapsed(offset: modelValue.length),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// Text field for the resume editor.
///
/// Always renders a real label rather than relying on a placeholder: hint text
/// disappears the moment the user types, leaving long forms unlabelled exactly
/// when someone scrolls back to check what a half-filled field was for.
///
/// The soft-filled, underlined look comes from `inputDecorationTheme` — a stack
/// of these inside a [FormSectionCard] is meant to read as one grouped list,
/// not as a column of separate boxes.
class ResumeTextField extends StatefulWidget {
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
  State<ResumeTextField> createState() => _ResumeTextFieldState();
}

class _ResumeTextFieldState extends State<ResumeTextField>
    with _ModelBackedField {
  @override
  String get modelValue => widget.value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: TextField(
        controller: controller,
        onChanged: widget.onChanged,
        keyboardType: widget.keyboardType,
        // maxLines > 1 fields must accept Enter as a newline, not as "next".
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : widget.textInputAction,
        maxLines: widget.maxLines,
        textCapitalization: widget.textCapitalization,
        autofillHints: widget.autofillHints,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helper,
          alignLabelWithHint: widget.maxLines > 1,
        ),
      ),
    );
  }
}

/// Small recessed square holding one section glyph in the accent.
///
/// The mark that introduces a section: a bare bold word gave the form no entry
/// point, and every section looked like the one above it.
///
/// Deliberately the *same* well the fields below it are punched into, with the
/// amber glyph on top, rather than a second colour per section. The card
/// already carries the section's identity; if the tile carried it too they
/// would be the same colour and the tile would disappear. So the tile is a
/// recess in the card — 1.44:1 to 1.74:1 below whichever tint hosts it — and
/// the accent glyph reads at 9.06:1 on it whichever section it is.
///
/// Fixed size rather than text-scaled — it is an icon, not a line of copy, and
/// growing it with the type size only steals width from the heading beside it.
class SectionIconTile extends StatelessWidget {
  const SectionIconTile({super.key, required this.icon});

  final IconData icon;

  /// Edge of the tile. Public so a header can indent its second line to line
  /// up with the title beside the tile rather than under it.
  static const size = 40.0;
  static const _glyph = 22.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Icon(icon, size: _glyph, color: scheme.primary),
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
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Optional: without it the header falls back to a plain text heading.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // The tile pairs with the title line only. Hung against the whole block it
    // drifts to the middle of a wrapped subtitle at large text sizes and stops
    // reading as the mark on the heading.
    final hasIcon = icon != null;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasIcon) ...[
                SectionIconTile(icon: icon!),
                SizedBox(width: tokens.spaceMd),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    // Large and tight, matching the app bar: the heading is
                    // what carries contrast in otherwise quiet chrome.
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(
                // Indented under the title, not under the tile.
                left: hasIcon ? SectionIconTile.size + tokens.spaceMd : 0,
                top: tokens.spaceXs / 2,
              ),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Solid-tinted card holding one section of the form, introduced by an icon
/// tile.
///
/// The form's unit of structure. Everything that belongs to "Experience" lives
/// in one of these, so the page reads as five or six objects rather than as
/// forty consecutive inputs — and each one carries its section's own solid
/// tint, so they are also five or six *distinguishable* objects.
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    required this.tone,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final SectionTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Card, not a hand-rolled Container: the app's panel shape and hairline
    // edge come from `cardTheme` and stay in step with the resume list. Only
    // the fill is overridden, and it is overridden with a token rather than a
    // colour mixed here.
    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceLg),
      color: tone.panel(tokens),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: icon, title: title, subtitle: subtitle),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One repeating entry (a job, a degree, a project) inside a [FormSectionCard].
///
/// Deliberately not a card of its own: a card nested in a card of the same tint
/// has no edge to show for itself. A rule above the entry and a recessed label
/// pill mark where one role ends and the next begins, which needs no shadow at
/// all and reads at a glance while scrolling.
class EntryGroup extends StatelessWidget {
  const EntryGroup({
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
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider carries its own vertical space, so the rule doubles as the
        // gap between one entry and the last.
        Divider(height: tokens.spaceLg),
        Row(
          children: [
            // Align keeps the pill hugging its label instead of stretching the
            // full width, while Expanded still bounds it so a long skill name
            // ellipsizes rather than overflowing.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _EntryLabel(title: title),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              // Icon-only control: without this the action is unlabelled for
              // screen readers and ambiguous by sight.
              tooltip: removeTooltip,
            ),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        ...children,
      ],
    );
  }
}

/// "ROLE 2", "SKILL", and the like: a recessed pill saying which entry you are
/// looking at.
///
/// Takes the same well as the section mark and the fields, for the same reason:
/// the card it sits on already carries the section's colour, and a second tint
/// here would either match it (and vanish) or fight it. Muted ink at 8.15:1 on
/// the well — structural rather than shouting.
class _EntryLabel extends StatelessWidget {
  const _EntryLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// "Add another" action at the end of a repeating section.
///
/// Full width on purpose: it closes the section card, so a left-hugging pill
/// left the card ending on an unexplained gap.
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Month/year text entry.
///
/// Deliberately free text rather than a date picker: resume dates are
/// month-granular and often partial, and a picker would force a day the user
/// never intended to state.
///
/// Controller-backed for the same reason [ResumeTextField] is, and with one
/// extra job: switching "I currently work here" on clears the end date in the
/// model, and with a seeded field that cleared value never reached the screen —
/// the user saw a date sitting in a field the PDF was already printing
/// "Present" for.
class MonthYearField extends StatefulWidget {
  const MonthYearField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.disabledHelper,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Shown under the field while it is switched off, so a control the user
  /// cannot type into says why rather than just refusing the tap.
  final String? disabledHelper;

  @override
  State<MonthYearField> createState() => _MonthYearFieldState();
}

class _MonthYearFieldState extends State<MonthYearField>
    with _ModelBackedField {
  @override
  String get modelValue => widget.value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: TextField(
        controller: controller,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        keyboardType: TextInputType.datetime,
        inputFormatters: [LengthLimitingTextInputFormatter(10)],
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'YYYY-MM',
          helperText: widget.enabled ? null : widget.disabledHelper,
        ),
      ),
    );
  }
}
