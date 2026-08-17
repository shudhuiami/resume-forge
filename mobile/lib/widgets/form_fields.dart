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
