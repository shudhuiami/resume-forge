import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../phone.dart';
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

/// Size [text] takes at the current text size, laid out with the real style.
///
/// Measured rather than assumed wherever a layout has to decide whether a
/// string still fits: a number that is right at one text size is wrong at every
/// other one. Shared, because the editor's toolbar height, its date pair, its
/// skill labels and the phone field's country control all need the same answer
/// and had started to grow their own copies of this.
Size measureText(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
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

/// Month/year text entry, with a picker on the side.
///
/// Still free text, and that is not a fallback: resume dates are often partial
/// ("2019", "Summer 2020") and the templates print whatever is here verbatim,
/// so the keyboard has to stay a first-class way in. The picker exists because
/// typing `YYYY-MM` from memory on a phone is a needless act of transcription,
/// not because typing was wrong.
///
/// Controller-backed for the same reason [ResumeTextField] is, and with one
/// extra job: switching "I currently work here" on clears the end date in the
/// model, and with a seeded field that cleared value never reached the screen —
/// the user saw a date sitting in a field the PDF was already printing
/// "Present" for. The picker rides on the same wire: it hands its answer to
/// [onChanged] and waits for the model to come back, so a date chosen from the
/// sheet reaches the screen by the one path that is already proven.
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

  Future<void> _pick() async {
    // The sheet needs the screen. Left up, the keyboard squeezes a
    // scroll-controlled sheet into the top of the phone and puts the month
    // grid behind the keys.
    FocusScope.of(context).unfocus();

    final picked = await showMonthYearPicker(
      context,
      // "Start" and "End" name a date on their own field; on a sheet covering
      // half the screen they need to say what they are.
      title: '${widget.label} date',
      initial: MonthYear.tryParse(widget.value),
      canClear: widget.value.trim().isNotEmpty,
    );
    if (picked == null || !mounted) return;
    widget.onChanged(picked);
  }

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
          // Null while the field is switched off, so the current-role case
          // cannot be talked into setting an end date the PDF would not print
          // anyway. `IconButton` fades its own glyph when it has nothing to
          // do, which is the same signal the disabled label and rule give.
          suffixIcon: IconButton(
            onPressed: widget.enabled ? _pick : null,
            icon: const Icon(Icons.calendar_month_outlined),
            // Icon-only control: without this it is unlabelled for screen
            // readers and ambiguous by sight.
            tooltip: 'Pick month and year',
          ),
        ),
      ),
    );
  }
}

/// Phone number, with the country code picked from a list rather than
/// remembered.
///
/// ## What it holds
///
/// The model keeps one free-text `phone` string and the templates print it
/// verbatim. This field presents that string as two controls — the country code
/// and the rest of the number — and puts it back together with
/// [joinPhoneNumber] on every keystroke. Nothing is reformatted, regrouped or
/// "corrected" on the way through: a resume number the app silently rewrote
/// into an undialable one would be a far worse defect than an oddly spaced one.
///
/// ## A stored number with no `+`
///
/// [splitPhoneNumber] reports a **null country** for any stored string that
/// does not start with `+` — which is every resume saved before this field
/// existed. Null does not mean "use the default"; it means the whole string is
/// the number the user has. So the code control reads "None", the entire string
/// stays in the number field, and typing writes it back with nothing added. A
/// dial code is only ever put in front of an existing number when the user
/// picks one, because doing it for them would invent digits they never typed.
///
/// An **empty** field is the one place a country is chosen for them: there is
/// no number to corrupt, [joinPhoneNumber] stores nothing until they type, and
/// the code is on screen beside the field before the first keystroke. It comes
/// from the locale region through [phoneCountryForRegion], which is documented
/// as a visible, cheap-to-change guess rather than a finding.
///
/// ## A whole number typed into the number field
///
/// A leading `+` is taken at its word. Someone pasting `+44 20 7946 0018` has
/// given a complete number, and joining the selected code onto the front of it
/// would store `+1 +44 20 7946 0018`; instead the string is stored exactly as
/// pasted and the code control follows it. This is the only place the field
/// moves text the user typed, it only ever moves a dial code from the number
/// into the control beside it, and it waits until a code has actually resolved
/// — `+4` on the way to `+41` stays where it was typed.
///
/// ## A guessed country
///
/// `+1` covers 25 countries and [PhoneNumberParts.isGuess] says when the one
/// that came back was the table's fallback rather than a real resolution. The
/// control shows the dial code either way — that much was read off the user's
/// own text — but it only *names* the country when the answer was real, and
/// opening the picker on a guess marks no row as chosen and pre-fills the
/// search with the shared code instead. The app does not answer a question it
/// cannot.
///
/// ## Validation
///
/// There is none, deliberately. [checkPhoneNumber] asks the much smaller
/// question of whether a string could be a phone number at all, and what it
/// finds appears as a note under the field *after* the user has moved on — not
/// as an error, not on the keystroke that provoked it, and never as a reason to
/// refuse the value. Whatever is typed is what is stored and exported.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Phone',
  });

  /// Finder handle for the country control. The control renders a dial code,
  /// which is also a string the number beside it contains, so a test that went
  /// looking for it by text would find the wrong one.
  @visibleForTesting
  static const codeButtonKey = Key('phone-country-code');

  /// The whole stored number, dial code and all.
  final String value;

  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  /// Deliberately **not** [_ModelBackedField]. That mixin keeps a field showing
  /// whatever the model holds by comparing the two on every rebuild, which is
  /// right when the field and the model hold the same string. Here they do not:
  /// this controller holds the national part, and re-deriving it from the model
  /// on every keystroke would hand the user's own text back through
  /// [splitPhoneNumber], which drops the separators sitting between the dial
  /// code and the first digit — typing `(` into an empty field would erase it
  /// again before the next keystroke.
  ///
  /// So the controller is the user's text, and [_pushed] is how an echo of this
  /// field's own write is told apart from the document being replaced under it
  /// (load sample, undo, clear) — the case the mixin exists for, and the one
  /// still handled below.
  final _controller = TextEditingController();
  final _focus = FocusNode();

  PhoneCountry? _country;

  /// True when [_country] came from a shared dial code's fallback rather than
  /// from the number itself. Never true for a country the user picked.
  bool _isGuess = false;

  /// The last string this field handed to `onChanged`.
  String? _pushed;

  /// Whether the empty-field default has already been applied. Without it,
  /// choosing "No country code" on an empty field would be undone by the next
  /// dependency change.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _adopt(widget.value);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    if (widget.value.trim().isEmpty) {
      // Locale, not a hard-coded country. `maybeLocaleOf` so the field still
      // renders outside a Localizations scope, where the table's own default
      // takes over.
      _country = phoneCountryForRegion(
        Localizations.maybeLocaleOf(context)?.countryCode,
      );
      _isGuess = false;
    }
  }

  @override
  void didUpdateWidget(covariant PhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Our own write coming back around: the controller already holds the text
    // it was made from, and touching it here would move the caret on every
    // keystroke.
    if (widget.value == _pushed) return;
    // Anything else replaced the document under us. A rebuild is already
    // running, so this needs no setState.
    _adopt(widget.value);
  }

  /// Reads a stored number into the two controls.
  void _adopt(String value) {
    final parts = splitPhoneNumber(value);
    if (value.trim().isNotEmpty) {
      // May be null, which is the honest answer for a number with no `+`.
      _country = parts.country;
      _isGuess = parts.isGuess;
    }
    // An emptied field keeps whichever country is showing: backspacing a number
    // away is not a request to change the code, and nothing is stored for an
    // empty national part anyway.
    if (_controller.text != parts.nationalNumber) {
      _controller.value = TextEditingValue(
        text: parts.nationalNumber,
        selection: TextSelection.collapsed(offset: parts.nationalNumber.length),
      );
    }
    _pushed = value;
  }

  /// The note is written for someone who has stopped typing. Shown while the
  /// caret is still in the field it would fire on every keystroke of a number
  /// that is merely half entered, which is scolding rather than helping.
  void _onFocusChanged() => setState(() {});

  /// Writes what the two controls currently amount to.
  ///
  /// The `+` branch is for the number people actually have to hand: a whole
  /// international one, pasted or typed straight into the field. Joining a dial
  /// code onto the front of that would store `+1 +44 20 7946 0018` — a number
  /// that dials nowhere — so a leading `+` is taken as what it says, stored
  /// verbatim, and the controls follow it. It is the one place this field moves
  /// text the user typed, it only ever moves a dial code out of the number and
  /// into the control beside it, and the digits are unchanged either way.
  void _push(String national) {
    if (national.trimLeft().startsWith('+')) {
      final parts = splitPhoneNumber(national);
      setState(() {
        _country = parts.country;
        _isGuess = parts.isGuess;
      });
      // Only once a dial code has actually resolved. Half of one — `+4` on the
      // way to `+41` — is still the user's text and stays where they typed it.
      if (parts.country != null && _controller.text != parts.nationalNumber) {
        _controller.value = TextEditingValue(
          text: parts.nationalNumber,
          selection: TextSelection.collapsed(
            offset: parts.nationalNumber.length,
          ),
        );
      }
      _pushed = national;
      widget.onChanged(national);
      return;
    }

    final country = _country;
    final next = country == null
        ? national
        : joinPhoneNumber(country, national);
    _pushed = next;
    widget.onChanged(next);
  }

  Future<void> _pickCountry() async {
    // The sheet needs the screen, exactly as the month picker does: left up,
    // the keyboard squeezes a scroll-controlled sheet into the top of the phone
    // and puts the list behind the keys.
    FocusScope.of(context).unfocus();

    final choice = await showPhoneCountryPicker(
      context,
      // A guess is not a selection, so nothing is marked chosen and the search
      // opens on the shared code instead — 25 real candidates rather than one
      // coin flip presented as an answer.
      current: _isGuess ? null : PhoneCountryChoice(_country),
      initialQuery: _isGuess ? _country?.dialCode : null,
    );
    if (choice == null || !mounted) return;

    setState(() {
      _country = choice.country;
      _isGuess = false;
    });
    // The number itself is untouched; only what goes in front of it changes.
    _push(_controller.text);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// What the check has to say, or null when it has nothing to say or the user
  /// is still typing.
  String? get _note {
    if (_focus.hasFocus) return null;
    return checkPhoneNumber(widget.value, country: _country).message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Measured, not switched on a width breakpoint, for the reason the
          // date pair is: what runs out of room is a string at a text size, not
          // a screen. At double text size on a 360px phone the code control and
          // a country's own example number cannot share a line, and a number
          // field too narrow to show the format it is asking for is worse than
          // a taller form.
          final code = _codeWidth(context, theme, tokens);
          final number =
              measureText(
                context,
                phoneHint(_country),
                theme.textTheme.bodyLarge,
              ).width +
              tokens.spaceLg * 2;
          final stacked = constraints.maxWidth - code - tokens.spaceMd < number;

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _codeControl(),
                SizedBox(height: tokens.spaceMd),
                _numberField(),
              ],
            );
          }
          return Row(
            // The number field grows a note under it; the two columns are not
            // the same height.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: code, child: _codeControl()),
              SizedBox(width: tokens.spaceMd),
              Expanded(child: _numberField()),
            ],
          );
        },
      ),
    );
  }

  /// Widest the code control ever needs to be: the longest dial code in the
  /// table, or the word standing in for no code at all, plus its own chrome.
  ///
  /// The rounding up is not decoration. Measured to the pixel, `+880` came back
  /// exactly as wide as the box it was given and the control shipped its own
  /// value as `+…`, which is the one string it must never show.
  double _codeWidth(BuildContext context, ThemeData theme, AppTokens tokens) {
    final value = math.max(
      measureText(context, '+000', theme.textTheme.bodyLarge).width,
      measureText(context, _noCode, theme.textTheme.bodyLarge).width,
    );
    final label = measureText(context, 'Code', theme.textTheme.bodySmall).width;
    return math.max(value + _chevron, label) +
        tokens.spaceLg * 2 +
        tokens.spaceSm;
  }

  /// Room the drop-down arrow takes beside the value.
  static const _chevron = 24.0;

  /// What the control reads when the number carries no country code.
  static const _noCode = 'None';

  /// The dial code, and a way into the picker.
  ///
  /// The code and never the country's name. The code is a fact — it is either
  /// in the user's own text or it is the one they just chose — while the name
  /// behind a shared code may be a guess, and at a large text size a name would
  /// truncate to `Bangl…` in the one layout that had room for it. The name is
  /// where it can be shown in full and marked as current: in the picker, in the
  /// tooltip, and in what a screen reader reads out.
  Widget _codeControl() {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final country = _country;
    final named = country != null && !_isGuess;

    return Semantics(
      key: PhoneField.codeButtonKey,
      button: true,
      label: 'Country code',
      // Named only where the country is a finding rather than the table's
      // fallback for a shared code.
      value: country == null
          ? _noCode
          : (named ? '${country.name}, ${country.dialCode}' : country.dialCode),
      child: Tooltip(
        message: named
            ? '${country.name} (${country.dialCode})'
            : 'Country code',
        child: InkWell(
          onTap: _pickCountry,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusSm),
          ),
          // The value is read out by the node above; left in, a screen reader
          // stops on the bare dial code a second time.
          child: ExcludeSemantics(
            child: InputDecorator(
              // The label stays up: this control always shows a value, so a
              // label resting over it would only ever be in the way.
              decoration: const InputDecoration(
                labelText: 'Code',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      country?.dialCode ?? _noCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField() {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final note = _note;

    return TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: _push,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      decoration: InputDecoration(
        labelText: widget.label,
        // Raised, so the example below it is on screen without the field being
        // tapped first. Material rests a label over its own placeholder, which
        // would have hidden the format until the moment after it stopped being
        // useful — and hidden it completely from someone who has just picked a
        // country and wants to see what that country's numbers look like. The
        // code control beside it keeps its label up for the same reason, so the
        // pair reads as one block.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        // The country's own example, which is the whole point of choosing one:
        // a placeholder that shows the shape this number is written in here.
        hintText: phoneHint(_country),
        // Two lines, because at double text size on a small phone a
        // fourteen-character example is wider than any field on the screen and
        // Material cuts a one-line hint off mid-format. Half a format is worse
        // than a wrapped one.
        hintMaxLines: 2,
        // A widget rather than `helperText`, so what the check found reads as a
        // note and not as a verdict. It is never `errorText`: the field is not
        // in an error state, nothing is blocked, and what the user typed is
        // already saved.
        helper: note == null
            ? null
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: tokens.spaceXs),
                  Expanded(
                    child: Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// What [showPhoneCountryPicker] came back with.
///
/// A bare `PhoneCountry?` could not carry this: null would have to mean both
/// "dismissed, change nothing" and "keep this number without a country code",
/// and those are opposite instructions.
@immutable
class PhoneCountryChoice {
  const PhoneCountryChoice(this.country);

  /// Null when the user asked for no country code at all.
  final PhoneCountry? country;
}

/// Asks which country's dial code belongs in front of a number.
///
/// A sheet with a search field rather than a [DropdownButton]: the table holds
/// 246 countries, and a menu that long is a scroll with no way to aim. This is
/// the same shape the app's other pickers take — scroll-controlled, safe-area
/// aware, capped at the form's own measure on a tablet.
///
/// Returns null when the sheet is dismissed by the handle, the barrier or the
/// back gesture, which the caller must treat as "changed their mind".
///
/// [current] carries three states and needs all three: a country, "no country
/// code", and *nothing marked at all* — which is what a shared dial code the
/// table could only guess at deserves. Passing a bare `PhoneCountry?` would
/// have collapsed the last two into one and ticked "No country code" beside a
/// number that plainly has one.
Future<PhoneCountryChoice?> showPhoneCountryPicker(
  BuildContext context, {
  PhoneCountryChoice? current,
  String? initialQuery,
}) {
  return showModalBottomSheet<PhoneCountryChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxWidth: _pickerMaxWidth,
      // Short of the full screen on purpose: a strip of the form stays visible
      // behind it, so the sheet reads as something laid over the editor rather
      // than as a new page the back gesture has to be guessed at.
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (context) =>
        _PhoneCountrySheet(current: current, initialQuery: initialQuery),
  );
}

class _PhoneCountrySheet extends StatefulWidget {
  const _PhoneCountrySheet({required this.current, required this.initialQuery});

  final PhoneCountryChoice? current;
  final String? initialQuery;

  @override
  State<_PhoneCountrySheet> createState() => _PhoneCountrySheetState();
}

class _PhoneCountrySheetState extends State<_PhoneCountrySheet> {
  late final _search = TextEditingController(text: widget.initialQuery ?? '');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim();

  /// Matches on name, on the diacritic-folded name, on the ISO code, and on
  /// the dial code's digits — "cote", "Côte", "CI" and "225" all find the same
  /// row, because a country dropdown is searched by whichever of those the user
  /// happens to know.
  bool _matches(PhoneCountry country, String query) {
    if (query.isEmpty || query == '+') return true;
    final lower = query.toLowerCase();
    if (country.name.toLowerCase().contains(lower)) return true;
    if (country.sortKey.contains(lower)) return true;
    if (country.isoCode.toLowerCase() == lower) return true;
    final digits = lower.replaceAll(RegExp('[^0-9]'), '');
    return digits.isNotEmpty && country.dialDigits.startsWith(digits);
  }

  /// How many countries share the code being searched for, when that is what is
  /// being searched for.
  ///
  /// This is the sentence that explains an unmarked list to someone who arrived
  /// here from a `+1` number: the app has not lost their country, it never knew
  /// it.
  String? get _sharedNote {
    final query = _query;
    if (query.isEmpty) return null;
    final digits = query.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty || digits != query.replaceFirst('+', '').trim()) {
      return null;
    }
    final sharers = phoneCountriesByDialCode(digits);
    if (sharers.length < 2) return null;
    return '${sharers.length} countries and territories use +$digits.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final query = _query;
    final results = phoneCountries
        .where((country) => _matches(country, query))
        .toList(growable: false);
    final note = _sharedNote;

    // The rows above the results: the country in use, and the way back to a
    // number with no code at all. Built here so they can ride in the same
    // scrollable as the results — see the note on the list below.
    final leading = <Widget>[
      // The country already in use, shown where it can be seen without
      // scrolling a 246-row builder to wherever it happens to be — which would
      // need a fixed row height the list does not have at every text size.
      // Only while the search is empty, because during a search this is not a
      // result.
      if (query.isEmpty && widget.current?.country != null)
        _CountryRow(
          title: widget.current!.country!.name,
          subtitle: 'Currently in use',
          trailing: widget.current!.country!.dialCode,
          selected: true,
          onTap: () => Navigator.of(context).pop(widget.current),
        ),
      _CountryRow(
        title: 'No country code',
        subtitle: 'Keep the number exactly as it is typed.',
        // Ticked only where that really is the state of the number. A guessed
        // country leaves every row unticked, including this one: the number
        // does have a code, the app just cannot say whose.
        selected: widget.current != null && widget.current!.country == null,
        onTap: () => Navigator.of(context).pop(const PhoneCountryChoice(null)),
      ),
      Divider(height: tokens.spaceLg),
    ];

    return SafeArea(
      // The route already holds the top edge clear (`useSafeArea`); taking it
      // again here would pad the sheet twice.
      top: false,
      child: Padding(
        // The list, not the keyboard, owns the bottom of the sheet: without
        // this the rows a search just produced sit behind the keys that
        // produced them.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
              child: Semantics(
                header: true,
                child: Text(
                  'Country code',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    // Large and tight, matching the app bar and the form's
                    // section headings.
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spaceMd),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Search',
                  hintText: 'Country, code, or +880',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear search',
                        ),
                ),
              ),
            ),
            if (note != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spaceLg,
                  tokens.spaceSm,
                  tokens.spaceLg,
                  0,
                ),
                child: Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SizedBox(height: tokens.spaceSm),
            // Everything below the search scrolls together, the leading rows
            // included.
            //
            // They were siblings of the list to begin with, which read well on
            // a phone held upright and overflowed a landscape one by 14px: a
            // heading, a search field and two two-line rows are taller than the
            // 258px a landscape sheet has to give, and a `Flexible` list can
            // shrink to nothing while its fixed siblings cannot. In one list
            // the short viewport simply scrolls.
            Flexible(
              child: ListView.builder(
                // 246 rows: built on demand, never all at once.
                itemCount: leading.length + math.max(1, results.length),
                padding: EdgeInsets.only(bottom: tokens.spaceMd),
                itemBuilder: (context, index) {
                  if (index < leading.length) return leading[index];
                  if (results.isEmpty) return _NoMatches(query: query);
                  final country = results[index - leading.length];
                  return _CountryRow(
                    title: country.name,
                    trailing: country.dialCode,
                    selected:
                        widget.current?.country?.isoCode == country.isoCode,
                    onTap: () =>
                        Navigator.of(context).pop(PhoneCountryChoice(country)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the country sheet.
class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // One node, not three: unmerged, the name, its code and the tick are
    // separate stops either side of the row that carries the tap.
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
        child: ListTile(
          onTap: onTap,
          selected: selected,
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(
                  trailing!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (selected) ...[
                SizedBox(width: tokens.spaceSm),
                Icon(Icons.check, size: 20, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A search with nothing to show for it.
///
/// A list that simply goes empty reads as a screen that broke; this says what
/// happened and what to do about it.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceLg,
          vertical: tokens.spaceXl,
        ),
        child: Column(
          children: [
            Icon(Icons.search_off, color: theme.colorScheme.onSurfaceVariant),
            SizedBox(height: tokens.spaceSm),
            Text(
              'No country matches “$query”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: tokens.spaceXs),
            Text(
              'Try the country name, its two-letter code, or its dial code.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A month and a year, which is all a resume date ever states.
///
/// There is no day here on purpose. Every template prints a month and a year,
/// so a day-precision picker would collect a number the document cannot show
/// and the user never meant to claim.
@immutable
class MonthYear {
  const MonthYear(this.year, this.month);

  final int year;

  /// 1–12.
  final int month;

  /// Reads the `YYYY-MM` the field writes.
  ///
  /// Returns null for anything else — including the partial and free-form
  /// dates the field still accepts — because those have no single month for a
  /// picker to open on. A null start is not an error; it just means the sheet
  /// opens on the current year.
  static MonthYear? tryParse(String raw) {
    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) return null;
    return MonthYear(int.parse(match.group(1)!), month);
  }

  /// The one shape the field, storage and the templates all agree on.
  String format() => '$year-${month.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is MonthYear && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => format();
}

/// Widest the picker sheet grows.
///
/// Matches the measure the editor form and the app's chooser sheets already
/// use: a sheet spanning a 768px tablet strands twelve small chips beside a
/// hand's width of empty space.
const _pickerMaxWidth = 640.0;

/// Asks for a month and a year.
///
/// Returns null when the user dismisses the sheet — by the handle, the barrier
/// or the back gesture — which the caller must treat as "changed their mind"
/// and leave the field exactly as it was. An empty string means "no date", and
/// anything else is a `YYYY-MM`.
///
/// A sheet rather than a dialog, and rather than [showDatePicker]. The stock
/// picker is day-precision and would produce dates no template can render; a
/// sheet is what this app already opens when a flow branches, it puts the
/// months where a thumb is, and — being scroll-controlled — it survives double
/// text size on a small phone by scrolling, which a dialog of the same content
/// does not.
Future<String?> showMonthYearPicker(
  BuildContext context, {
  required String title,
  MonthYear? initial,
  bool canClear = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: _pickerMaxWidth),
    builder: (context) =>
        _MonthYearSheet(title: title, initial: initial, canClear: canClear),
  );
}

class _MonthYearSheet extends StatefulWidget {
  const _MonthYearSheet({
    required this.title,
    required this.initial,
    required this.canClear,
  });

  final String title;
  final MonthYear? initial;
  final bool canClear;

  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Read by screen readers and by anyone holding a chip down: "Sep" is a
  /// three-letter abbreviation, and abbreviations are what a screen reader
  /// spells out one letter at a time.
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Far enough back to cover a first degree for anyone still working, and far
  /// enough forward for an expected graduation date. Not further forward than
  /// that: every future year is a row the list has to be scrolled past to
  /// reach the years people actually put on a resume.
  static const _minYear = 1950;
  static final _maxYear = DateTime.now().year + 5;

  late int _year = widget.initial?.year ?? DateTime.now().year;

  /// True while the year list has replaced the months.
  ///
  /// It replaces them rather than sitting above them so the sheet holds one
  /// scrolling list at a time: eighty years nested inside a scroll view that
  /// also scrolls is two gestures fighting over one finger.
  bool _pickingYear = false;

  void _chooseMonth(int month) =>
      Navigator.of(context).pop(MonthYear(_year, month).format());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return SafeArea(
      // The route already holds the top edge clear (`useSafeArea`); taking it
      // again here would pad the sheet twice.
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
              child: Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    // Large and tight, matching the app bar and the form's
                    // section headings.
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            _YearBar(
              year: _year,
              expanded: _pickingYear,
              onPrevious: _year > _minYear
                  ? () => setState(() => _year--)
                  : null,
              onNext: _year < _maxYear ? () => setState(() => _year++) : null,
              onToggle: () => setState(() => _pickingYear = !_pickingYear),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                0,
                tokens.spaceLg,
                tokens.spaceMd,
              ),
              child: _pickingYear ? _years() : _monthGrid(),
            ),
            if (widget.canClear)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spaceLg,
                  0,
                  tokens.spaceLg,
                  tokens.spaceMd,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(''),
                    icon: const Icon(Icons.backspace_outlined, size: 18),
                    label: const Text('Clear date'),
                  ),
                ),
              ),
            SizedBox(height: tokens.spaceMd),
          ],
        ),
      ),
    );
  }

  /// Chip lettering.
  ///
  /// `copyWith` on the theme's own style, never a bare [TextStyle]: a bare one
  /// drops `ThemeData.fontFamily` and falls back to Roboto — the wrong face on
  /// device and no face at all on web, where Roboto is not bundled. The
  /// gallery's category chips carry the same note for the same reason.
  TextStyle? _chipLabelStyle(ThemeData theme) =>
      theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface);

  Widget _monthGrid() {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final selected = widget.initial;

    // Wrap rather than a fixed grid: three columns is right at normal text
    // size and wrong at double, and a Wrap reflows to whatever actually fits
    // instead of clipping the month names.
    return Wrap(
      spacing: tokens.spaceSm,
      runSpacing: tokens.spaceSm,
      children: [
        for (var month = 1; month <= 12; month++)
          ChoiceChip(
            label: Text(_shortMonths[month - 1]),
            labelStyle: _chipLabelStyle(theme),
            tooltip: _months[month - 1],
            selected: selected?.month == month && selected?.year == _year,
            onSelected: (_) => _chooseMonth(month),
          ),
      ],
    );
  }

  Widget _years() {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // Newest first. The years anyone is most likely to want are the last
    // twenty, and putting 1950 at the top would mean scrolling past seventy
    // of them to reach the common case.
    return Wrap(
      spacing: tokens.spaceSm,
      runSpacing: tokens.spaceSm,
      children: [
        for (var year = _maxYear; year >= _minYear; year--)
          ChoiceChip(
            label: Text('$year'),
            labelStyle: _chipLabelStyle(theme),
            selected: year == _year,
            onSelected: (_) => setState(() {
              _year = year;
              _pickingYear = false;
            }),
          ),
      ],
    );
  }
}

/// The year, and the three ways to change it.
///
/// A stepper for the common nudge of one year either way, and the year itself
/// as a button onto the full list for the graduation date that is forty years
/// back and would otherwise cost forty taps.
class _YearBar extends StatelessWidget {
  const _YearBar({
    required this.year,
    required this.expanded,
    required this.onPrevious,
    required this.onNext,
    required this.onToggle,
  });

  final int year;
  final bool expanded;

  /// Null at the end of the range, so the arrow reads as unavailable rather
  /// than dead.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous year',
          ),
          // Expanded, so the arrows keep their full touch targets and the
          // year takes whatever is left at any text size.
          Expanded(
            child: TextButton(
              onPressed: onToggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '$year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next year',
          ),
        ],
      ),
    );
  }
}
