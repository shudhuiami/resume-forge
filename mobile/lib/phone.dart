/// Country dial codes, phone placeholders, and a plausibility check.
///
/// Built for QA-6: a country-code dropdown whose selection drives the phone
/// field's placeholder. Everything here is pure Dart — no widgets, no
/// `dart:ui` — so the table and its rules can be tested without pumping a
/// frame, and so the UI layer stays free to present it however it likes.
///
/// ## Why a bundled table and not a library
///
/// The obvious alternative is a `libphonenumber`-class package. It is several
/// megabytes, ships platform channels, and carries its own metadata database,
/// all to answer two questions: what does a number from this country look
/// like, and is this string roughly a phone number. This app ships no network
/// and a deliberately short dependency list; that trade is out of proportion.
/// So: one file, no dependency, and an honest account below of exactly what it
/// does and does not know.
///
/// ## What this file does NOT do
///
/// It does not validate. Without per-country metadata (assigned prefixes,
/// per-type length ranges, portability ranges) nothing here can tell you a
/// number is *real*. [checkPhoneNumber] answers a much smaller question —
/// "could this be a phone number at all" — and is named and documented so that
/// no caller mistakes it for more. It also never rewrites what the user typed:
/// no reformatting, no trunk-zero stripping, no country-code insertion. A
/// resume phone number that the app silently "corrects" into an undialable one
/// is a far worse bug than an oddly-spaced one.
///
/// ## Shared dial codes
///
/// Dial codes are not unique and the mapping runs both ways:
///
/// * `+1` covers 25 countries and territories (the North American Numbering
///   Plan), `+44` four, `+590` three, `+7`, `+39`, `+47`, `+61`, `+212`,
///   `+262`, `+290`, `+358`, `+599`, `+64` and `+672` two each.
/// * No country in this table has more than one dial code, but several *share*
///   one, so a `Map<String, PhoneCountry>` keyed by dial code would be lossy.
///
/// Three mechanisms handle this, in order of how much they actually know:
///
/// 1. [phoneCountriesByDialCode] returns a **list**. That is the honest answer
///    and the one callers should reach for first. There is no function that
///    returns "the" country for `+1`.
/// 2. [PhoneCountry.leadingDigits] carries the national-number prefixes that
///    genuinely disambiguate — the Caribbean area codes under `+1`, Kazakh
///    `6`/`7` under `+7`, the Crown dependency area codes under `+44`, and so
///    on. Where a prefix matches, [splitPhoneNumber] resolves the country for
///    real.
/// 3. [PhoneCountry.isSharedCodeFallback] marks exactly one sharer of each
///    shared code as the fallback for when nothing else resolved it. This is a
///    *display* choice for which row a dropdown starts on. It never changes a
///    number, and [PhoneNumberParts.isGuess] tells the caller when it was
///    used, so the UI can avoid presenting a coin-flip as a fact.
///
/// ## Data provenance
///
/// Dial codes are ITU-T E.164 assignments. Example numbers are the national
/// significant number written the way that country writes it, chosen to carry
/// the right digit count and grouping — they are illustrative, not real
/// subscriber numbers (North American ones use the `555-01xx` range reserved
/// for fiction). Where the national number length or shape was not something
/// this file could state with confidence, [PhoneCountry.exampleNumber] is left
/// null and the field falls back to a plain placeholder. An empty example is a
/// deliberate "we don't know", never an oversight — inventing a plausible
/// looking format would put a wrong number shape in front of the user with the
/// same confidence as a right one.
library;

/// One country or territory in the dial-code table.
///
/// The constructor is positional in its first three arguments on purpose: the
/// table below is ~250 rows and reads as columns. Named arguments would stretch
/// every row to five lines and make a mis-typed dial code harder to spot, not
/// easier.
class PhoneCountry {
  const PhoneCountry(
    this.isoCode,
    this.name,
    this.dialCode, {
    this.exampleNumber,
    this.leadingDigits = const <String>[],
    this.isSharedCodeFallback = false,
  });

  /// ISO 3166-1 alpha-2, upper case.
  ///
  /// Four entries use codes that are *exceptionally reserved* rather than
  /// assigned — `AC` (Ascension), `TA` (Tristan da Cunha), `XK` (Kosovo, a
  /// user-assigned code in common use), and `DG` is deliberately not used in
  /// favour of ISO's `IO` for the British Indian Ocean Territory. They are
  /// included because each is a distinct entry in E.164 and a user living
  /// there needs a row to pick.
  final String isoCode;

  /// English display name, and the sort order of [phoneCountries].
  final String name;

  /// E.164 country calling code, including the leading `+`.
  ///
  /// Not unique across the table — see the shared dial codes note on this
  /// library.
  final String dialCode;

  /// An example national significant number, grouped the way the country
  /// writes it, with no trunk prefix and no dial code.
  ///
  /// Null where this file cannot state the shape with confidence. The
  /// placeholder derives from this rather than from a separate format string,
  /// so there is nothing that can drift out of step with it.
  final String? exampleNumber;

  /// National-number prefixes that identify this country inside a *shared*
  /// dial code.
  ///
  /// Empty for the vast majority of the table, where the dial code alone is
  /// enough. Only populated where the prefixes are stable and well known: a
  /// stale entry here would resolve confidently to the wrong country, which is
  /// worse than not resolving at all, so anything uncertain is left out and
  /// falls through to [isSharedCodeFallback].
  final List<String> leadingDigits;

  /// Which country a *shared* [dialCode] falls back to when the national
  /// digits resolved nothing.
  ///
  /// Set only on shared dial codes — exactly one sharer each, asserted by a
  /// test. A country alone on its dial code needs no flag and carries none:
  /// it is the answer by arithmetic, and repeating that on two hundred rows
  /// would be noise that can fall out of step with the table.
  ///
  /// Where it is set, it is a convention rather than a finding, so callers see
  /// it through [PhoneNumberParts.isGuess] rather than as a determination. Use
  /// [defaultCountryForDialCode] instead of reading this directly; it handles
  /// both cases.
  final bool isSharedCodeFallback;

  /// [dialCode] without the `+`.
  String get dialDigits => dialCode.substring(1);

  /// [exampleNumber] reduced to digits, or null when there is no example.
  String? get exampleDigits {
    final example = exampleNumber;
    if (example == null) return null;
    return _digitsOf(example);
  }

  /// The full international form of [exampleNumber], or null when there is no
  /// example.
  ///
  /// For a helper line ("Example: +880 1712-345678") under a field that holds
  /// only the national part.
  String? get exampleFullNumber {
    final example = exampleNumber;
    if (example == null) return null;
    return '$dialCode $example';
  }

  /// Placeholder for a field that holds the national part, with the dial code
  /// shown separately (a dropdown beside the field).
  ///
  /// Falls back to a plain wording rather than an invented format when this
  /// country has no example.
  String get numberHint => exampleNumber ?? _plainHint;

  /// Placeholder for a single field that holds the whole number.
  String get fullNumberHint => exampleFullNumber ?? '$dialCode $_plainHint';

  /// Sort and search key: [name] folded to lower-case ASCII.
  ///
  /// Without the fold, `String.compareTo` orders by UTF-16 code unit and files
  /// "Åland Islands" after "Zimbabwe" — the one place in a country dropdown a
  /// user will never look for it. Lower-casing keeps "DR Congo" from jumping
  /// ahead of "Denmark" for the same reason. Also the right key for
  /// type-to-search, so "cote" finds "Côte d'Ivoire".
  String get sortKey => _foldDiacritics(name).toLowerCase();

  @override
  String toString() => 'PhoneCountry($isoCode, $dialCode)';
}

const _plainHint = 'Phone number';

/// What [checkPhoneNumber] found.
///
/// Deliberately not called `PhoneValidity`, and [ok] is deliberately not called
/// `valid`: this type reports the absence of an obvious problem, which is a
/// much weaker claim than validity and the strongest one this file is entitled
/// to make.
enum PhoneIssue {
  /// Nothing obviously wrong. **Not** a claim that the number exists, that it
  /// is reachable, or that it belongs to the selected country.
  ok,

  /// Nothing entered. Phone is an optional field on a resume, so callers
  /// normally treat this as "no complaint" rather than as an error.
  empty,

  /// Fewer digits than any phone number anywhere has.
  tooShort,

  /// More digits than E.164 permits in total (15, dial code included).
  tooLong,

  /// Something that is neither a digit nor one of the accepted separators
  /// `+ - ( ) . / space`. Letters land here, except in a trailing extension
  /// such as `x210` or `ext. 210`, which is accepted and ignored.
  unexpectedCharacter,

  /// A `+` somewhere other than the very start.
  misplacedPlus;

  /// True when there is nothing to tell the user about.
  bool get isAcceptable => this == PhoneIssue.ok || this == PhoneIssue.empty;

  /// Short human wording, or null when there is nothing to say.
  ///
  /// Phrased as an observation rather than a verdict, because the check is not
  /// entitled to a verdict. Callers are encouraged to show these as a soft
  /// warning and still save what the user typed — a resume field that refuses
  /// a real number is a worse failure than one that accepts an odd one.
  String? get message => switch (this) {
    PhoneIssue.ok || PhoneIssue.empty => null,
    PhoneIssue.tooShort => 'That looks too short for a phone number.',
    PhoneIssue.tooLong => 'That is longer than a phone number can be.',
    PhoneIssue.unexpectedCharacter =>
      'Use digits, and + ( ) - or spaces to separate them.',
    PhoneIssue.misplacedPlus => 'A + belongs at the start of the number.',
  };
}

/// A phone number split into the country it names and the rest.
class PhoneNumberParts {
  const PhoneNumberParts({
    required this.country,
    required this.nationalNumber,
    required this.isGuess,
  });

  /// The country the dial code named, or null when the input carried no
  /// country code at all.
  ///
  /// **A null country does not mean "use the default".** It means
  /// [nationalNumber] holds the entire string the user has, country code or
  /// not, and prepending a dial code to it would invent digits. This is the
  /// normal state for resumes saved before the dropdown existed.
  final PhoneCountry? country;

  /// Everything after the dial code, with the user's own spacing preserved.
  ///
  /// Equal to the whole input when [country] is null.
  final String nationalNumber;

  /// True when [country] came from [PhoneCountry.isSharedCodeFallback] because the
  /// dial code is shared and no [PhoneCountry.leadingDigits] matched.
  ///
  /// A UI that pre-selects a dropdown row from this should not present a guess
  /// as a determination.
  final bool isGuess;
}

/// Every country and territory with an E.164 dial code, ordered by [sortKey]
/// so the list can be handed straight to a dropdown.
///
/// Kept in sorted order in source rather than sorted at runtime: the order is
/// then reviewable in a diff, and a test asserts it. Countries with no
/// [PhoneCountry.exampleNumber] are the ones whose national number shape this
/// file could not state with confidence.
const List<PhoneCountry> phoneCountries = <PhoneCountry>[
  PhoneCountry('AF', 'Afghanistan', '+93', exampleNumber: '70 123 4567'),
  // Åland uses the Finnish plan; 018 is its own landline area.
  PhoneCountry('AX', 'Åland Islands', '+358', leadingDigits: ['18']),
  PhoneCountry('AL', 'Albania', '+355', exampleNumber: '67 212 3456'),
  PhoneCountry('DZ', 'Algeria', '+213', exampleNumber: '551 23 45 67'),
  PhoneCountry(
    'AS',
    'American Samoa',
    '+1',
    exampleNumber: '(684) 555-0123',
    leadingDigits: ['684'],
  ),
  PhoneCountry('AD', 'Andorra', '+376', exampleNumber: '312 345'),
  PhoneCountry('AO', 'Angola', '+244', exampleNumber: '923 123 456'),
  PhoneCountry(
    'AI',
    'Anguilla',
    '+1',
    exampleNumber: '(264) 555-0123',
    leadingDigits: ['264'],
  ),
  // The Australian Antarctic stations. Included because +672 1 is a real
  // assignment someone could be reached on, not as a joke entry.
  PhoneCountry('AQ', 'Antarctica', '+672', leadingDigits: ['1']),
  PhoneCountry(
    'AG',
    'Antigua and Barbuda',
    '+1',
    exampleNumber: '(268) 555-0123',
    leadingDigits: ['268'],
  ),
  PhoneCountry('AR', 'Argentina', '+54', exampleNumber: '11 2345-6789'),
  PhoneCountry('AM', 'Armenia', '+374', exampleNumber: '77 123456'),
  PhoneCountry('AW', 'Aruba', '+297', exampleNumber: '560 1234'),
  PhoneCountry('AC', 'Ascension Island', '+247'),
  // Shares +61 with Christmas Island and the Cocos Islands, both of which are
  // identified by a five-digit prefix; anything else on +61 is Australia.
  PhoneCountry(
    'AU',
    'Australia',
    '+61',
    exampleNumber: '412 345 678',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('AT', 'Austria', '+43', exampleNumber: '664 1234567'),
  PhoneCountry('AZ', 'Azerbaijan', '+994', exampleNumber: '40 123 45 67'),
  PhoneCountry(
    'BS',
    'Bahamas',
    '+1',
    exampleNumber: '(242) 555-0123',
    leadingDigits: ['242'],
  ),
  PhoneCountry('BH', 'Bahrain', '+973', exampleNumber: '3600 1234'),
  PhoneCountry('BD', 'Bangladesh', '+880', exampleNumber: '1712-345678'),
  PhoneCountry(
    'BB',
    'Barbados',
    '+1',
    exampleNumber: '(246) 555-0123',
    leadingDigits: ['246'],
  ),
  PhoneCountry('BY', 'Belarus', '+375', exampleNumber: '29 123-45-67'),
  PhoneCountry('BE', 'Belgium', '+32', exampleNumber: '470 12 34 56'),
  PhoneCountry('BZ', 'Belize', '+501', exampleNumber: '622-1234'),
  // Benin renumbered to ten digits in 2020 and the old eight-digit examples
  // are still in wide circulation; left blank rather than shipping either.
  PhoneCountry('BJ', 'Benin', '+229'),
  PhoneCountry(
    'BM',
    'Bermuda',
    '+1',
    exampleNumber: '(441) 555-0123',
    leadingDigits: ['441'],
  ),
  PhoneCountry('BT', 'Bhutan', '+975', exampleNumber: '17 12 34 56'),
  PhoneCountry('BO', 'Bolivia', '+591', exampleNumber: '712 34567'),
  PhoneCountry(
    'BA',
    'Bosnia and Herzegovina',
    '+387',
    exampleNumber: '61 123 456',
  ),
  PhoneCountry('BW', 'Botswana', '+267', exampleNumber: '71 123 456'),
  PhoneCountry('BR', 'Brazil', '+55', exampleNumber: '11 91234-5678'),
  PhoneCountry(
    'IO',
    'British Indian Ocean Territory',
    '+246',
    exampleNumber: '380 1234',
  ),
  PhoneCountry(
    'VG',
    'British Virgin Islands',
    '+1',
    exampleNumber: '(284) 555-0123',
    leadingDigits: ['284'],
  ),
  PhoneCountry('BN', 'Brunei', '+673', exampleNumber: '712 3456'),
  PhoneCountry('BG', 'Bulgaria', '+359', exampleNumber: '87 123 4567'),
  PhoneCountry('BF', 'Burkina Faso', '+226', exampleNumber: '70 12 34 56'),
  PhoneCountry('BI', 'Burundi', '+257', exampleNumber: '79 56 12 34'),
  PhoneCountry('KH', 'Cambodia', '+855', exampleNumber: '91 234 567'),
  PhoneCountry('CM', 'Cameroon', '+237', exampleNumber: '671 234 567'),
  // The area codes below are maintained best-effort and are not exhaustive:
  // Canada and the United States interleave in one plan and new overlays are
  // assigned every few years. A code missing here falls through to the United
  // States, which is exactly where every Canadian number landed before the
  // list existed — so the list can only improve the guess, and it only ever
  // affects which row a dropdown starts on.
  PhoneCountry(
    'CA',
    'Canada',
    '+1',
    exampleNumber: '(204) 555-0123',
    leadingDigits: [
      '204',
      '226',
      '236',
      '249',
      '250',
      '263',
      '289',
      '306',
      '343',
      '354',
      '365',
      '367',
      '368',
      '382',
      '403',
      '416',
      '418',
      '428',
      '431',
      '437',
      '438',
      '450',
      '468',
      '474',
      '506',
      '514',
      '519',
      '548',
      '579',
      '581',
      '584',
      '587',
      '604',
      '613',
      '639',
      '647',
      '672',
      '683',
      '705',
      '709',
      '742',
      '753',
      '778',
      '780',
      '782',
      '807',
      '819',
      '825',
      '867',
      '873',
      '879',
      '902',
      '905',
    ],
  ),
  PhoneCountry('CV', 'Cape Verde', '+238', exampleNumber: '991 12 34'),
  PhoneCountry(
    'BQ',
    'Caribbean Netherlands',
    '+599',
    exampleNumber: '318 1234',
    leadingDigits: ['3', '4', '7'],
  ),
  PhoneCountry(
    'KY',
    'Cayman Islands',
    '+1',
    exampleNumber: '(345) 555-0123',
    leadingDigits: ['345'],
  ),
  PhoneCountry(
    'CF',
    'Central African Republic',
    '+236',
    exampleNumber: '70 01 23 45',
  ),
  PhoneCountry('TD', 'Chad', '+235', exampleNumber: '63 01 23 45'),
  PhoneCountry('CL', 'Chile', '+56', exampleNumber: '9 6123 4567'),
  PhoneCountry('CN', 'China', '+86', exampleNumber: '131 2345 6789'),
  PhoneCountry(
    'CX',
    'Christmas Island',
    '+61',
    exampleNumber: '8 9164 1234',
    leadingDigits: ['89164'],
  ),
  PhoneCountry(
    'CC',
    'Cocos (Keeling) Islands',
    '+61',
    exampleNumber: '8 9162 1234',
    leadingDigits: ['89162'],
  ),
  PhoneCountry('CO', 'Colombia', '+57', exampleNumber: '321 1234567'),
  PhoneCountry('KM', 'Comoros', '+269', exampleNumber: '321 23 45'),
  PhoneCountry('CK', 'Cook Islands', '+682', exampleNumber: '71 234'),
  PhoneCountry('CR', 'Costa Rica', '+506', exampleNumber: '8312 3456'),
  PhoneCountry('CI', "Côte d'Ivoire", '+225', exampleNumber: '01 23 45 67 89'),
  PhoneCountry('HR', 'Croatia', '+385', exampleNumber: '91 234 5678'),
  PhoneCountry('CU', 'Cuba', '+53', exampleNumber: '5 123 4567'),
  PhoneCountry(
    'CW',
    'Curaçao',
    '+599',
    exampleNumber: '9 518 1234',
    leadingDigits: ['9'],
    isSharedCodeFallback: true,
  ),
  PhoneCountry('CY', 'Cyprus', '+357', exampleNumber: '96 123456'),
  PhoneCountry('CZ', 'Czechia', '+420', exampleNumber: '601 123 456'),
  PhoneCountry('DK', 'Denmark', '+45', exampleNumber: '20 12 34 56'),
  PhoneCountry('DJ', 'Djibouti', '+253', exampleNumber: '77 12 34 56'),
  PhoneCountry(
    'DM',
    'Dominica',
    '+1',
    exampleNumber: '(767) 555-0123',
    leadingDigits: ['767'],
  ),
  PhoneCountry(
    'DO',
    'Dominican Republic',
    '+1',
    exampleNumber: '(809) 555-0123',
    leadingDigits: ['809', '829', '849'],
  ),
  PhoneCountry('CD', 'DR Congo', '+243', exampleNumber: '991 234 567'),
  PhoneCountry('EC', 'Ecuador', '+593', exampleNumber: '99 123 4567'),
  PhoneCountry('EG', 'Egypt', '+20', exampleNumber: '100 123 4567'),
  PhoneCountry('SV', 'El Salvador', '+503', exampleNumber: '7012 3456'),
  PhoneCountry('GQ', 'Equatorial Guinea', '+240', exampleNumber: '222 123 456'),
  PhoneCountry('ER', 'Eritrea', '+291', exampleNumber: '7 123 456'),
  PhoneCountry('EE', 'Estonia', '+372', exampleNumber: '5123 4567'),
  PhoneCountry('SZ', 'Eswatini', '+268', exampleNumber: '7612 3456'),
  PhoneCountry('ET', 'Ethiopia', '+251', exampleNumber: '91 123 4567'),
  PhoneCountry('FK', 'Falkland Islands', '+500', exampleNumber: '51234'),
  PhoneCountry('FO', 'Faroe Islands', '+298', exampleNumber: '21 12 34'),
  PhoneCountry('FJ', 'Fiji', '+679', exampleNumber: '701 2345'),
  PhoneCountry(
    'FI',
    'Finland',
    '+358',
    exampleNumber: '41 2345678',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('FR', 'France', '+33', exampleNumber: '6 12 34 56 78'),
  PhoneCountry('GF', 'French Guiana', '+594', exampleNumber: '694 20 12 34'),
  PhoneCountry('PF', 'French Polynesia', '+689', exampleNumber: '87 12 34 56'),
  PhoneCountry('GA', 'Gabon', '+241', exampleNumber: '06 03 12 34'),
  PhoneCountry('GM', 'Gambia', '+220', exampleNumber: '301 2345'),
  PhoneCountry('GE', 'Georgia', '+995', exampleNumber: '555 12 34 56'),
  PhoneCountry('DE', 'Germany', '+49', exampleNumber: '1512 3456789'),
  PhoneCountry('GH', 'Ghana', '+233', exampleNumber: '24 123 4567'),
  PhoneCountry('GI', 'Gibraltar', '+350', exampleNumber: '5712 3456'),
  PhoneCountry('GR', 'Greece', '+30', exampleNumber: '691 234 5678'),
  PhoneCountry('GL', 'Greenland', '+299', exampleNumber: '22 12 34'),
  PhoneCountry(
    'GD',
    'Grenada',
    '+1',
    exampleNumber: '(473) 555-0123',
    leadingDigits: ['473'],
  ),
  PhoneCountry(
    'GP',
    'Guadeloupe',
    '+590',
    exampleNumber: '690 00 12 34',
    isSharedCodeFallback: true,
  ),
  PhoneCountry(
    'GU',
    'Guam',
    '+1',
    exampleNumber: '(671) 555-0123',
    leadingDigits: ['671'],
  ),
  PhoneCountry('GT', 'Guatemala', '+502', exampleNumber: '5123 4567'),
  // Landline area code: the Crown dependencies' mobile ranges sit inside UK
  // blocks and are not reliably separable, so only 01481 identifies Guernsey.
  PhoneCountry(
    'GG',
    'Guernsey',
    '+44',
    exampleNumber: '1481 123456',
    leadingDigits: ['1481'],
  ),
  PhoneCountry('GN', 'Guinea', '+224', exampleNumber: '601 12 34 56'),
  PhoneCountry('GW', 'Guinea-Bissau', '+245', exampleNumber: '955 012 345'),
  PhoneCountry('GY', 'Guyana', '+592', exampleNumber: '609 1234'),
  PhoneCountry('HT', 'Haiti', '+509', exampleNumber: '34 10 1234'),
  PhoneCountry('HN', 'Honduras', '+504', exampleNumber: '9123 4567'),
  PhoneCountry('HK', 'Hong Kong', '+852', exampleNumber: '5123 4567'),
  PhoneCountry('HU', 'Hungary', '+36', exampleNumber: '20 123 4567'),
  PhoneCountry('IS', 'Iceland', '+354', exampleNumber: '611 1234'),
  PhoneCountry('IN', 'India', '+91', exampleNumber: '98765 43210'),
  PhoneCountry('ID', 'Indonesia', '+62', exampleNumber: '812-345-678'),
  PhoneCountry('IR', 'Iran', '+98', exampleNumber: '912 345 6789'),
  PhoneCountry('IQ', 'Iraq', '+964', exampleNumber: '791 234 5678'),
  PhoneCountry('IE', 'Ireland', '+353', exampleNumber: '85 012 3456'),
  PhoneCountry(
    'IM',
    'Isle of Man',
    '+44',
    exampleNumber: '1624 123456',
    leadingDigits: ['1624'],
  ),
  PhoneCountry('IL', 'Israel', '+972', exampleNumber: '50-123-4567'),
  PhoneCountry(
    'IT',
    'Italy',
    '+39',
    exampleNumber: '312 345 6789',
    isSharedCodeFallback: true,
  ),
  PhoneCountry(
    'JM',
    'Jamaica',
    '+1',
    exampleNumber: '(876) 555-0123',
    leadingDigits: ['876', '658'],
  ),
  PhoneCountry('JP', 'Japan', '+81', exampleNumber: '90-1234-5678'),
  PhoneCountry(
    'JE',
    'Jersey',
    '+44',
    exampleNumber: '1534 123456',
    leadingDigits: ['1534'],
  ),
  PhoneCountry('JO', 'Jordan', '+962', exampleNumber: '79 012 3456'),
  PhoneCountry(
    'KZ',
    'Kazakhstan',
    '+7',
    exampleNumber: '771 234 5678',
    leadingDigits: ['6', '7'],
  ),
  PhoneCountry('KE', 'Kenya', '+254', exampleNumber: '712 123456'),
  PhoneCountry('KI', 'Kiribati', '+686'),
  PhoneCountry('XK', 'Kosovo', '+383', exampleNumber: '43 201 234'),
  PhoneCountry('KW', 'Kuwait', '+965', exampleNumber: '500 12345'),
  PhoneCountry('KG', 'Kyrgyzstan', '+996', exampleNumber: '700 123 456'),
  PhoneCountry('LA', 'Laos', '+856', exampleNumber: '20 23 123 456'),
  PhoneCountry('LV', 'Latvia', '+371', exampleNumber: '21 234 567'),
  PhoneCountry('LB', 'Lebanon', '+961', exampleNumber: '71 123 456'),
  PhoneCountry('LS', 'Lesotho', '+266', exampleNumber: '5012 3456'),
  PhoneCountry('LR', 'Liberia', '+231', exampleNumber: '77 012 3456'),
  PhoneCountry('LY', 'Libya', '+218', exampleNumber: '91 2345678'),
  PhoneCountry('LI', 'Liechtenstein', '+423', exampleNumber: '660 234 567'),
  PhoneCountry('LT', 'Lithuania', '+370', exampleNumber: '612 34567'),
  PhoneCountry('LU', 'Luxembourg', '+352', exampleNumber: '628 123 456'),
  PhoneCountry('MO', 'Macao', '+853', exampleNumber: '6612 3456'),
  PhoneCountry('MG', 'Madagascar', '+261', exampleNumber: '32 12 345 67'),
  PhoneCountry('MW', 'Malawi', '+265', exampleNumber: '991 23 45 67'),
  PhoneCountry('MY', 'Malaysia', '+60', exampleNumber: '12-345 6789'),
  PhoneCountry('MV', 'Maldives', '+960', exampleNumber: '771-2345'),
  PhoneCountry('ML', 'Mali', '+223', exampleNumber: '65 01 23 45'),
  PhoneCountry('MT', 'Malta', '+356', exampleNumber: '9696 1234'),
  PhoneCountry('MH', 'Marshall Islands', '+692', exampleNumber: '235 1234'),
  PhoneCountry('MQ', 'Martinique', '+596', exampleNumber: '696 20 12 34'),
  PhoneCountry('MR', 'Mauritania', '+222', exampleNumber: '22 12 34 56'),
  PhoneCountry('MU', 'Mauritius', '+230', exampleNumber: '5251 2345'),
  PhoneCountry(
    'YT',
    'Mayotte',
    '+262',
    exampleNumber: '639 01 23 45',
    leadingDigits: ['269', '639'],
  ),
  PhoneCountry('MX', 'Mexico', '+52', exampleNumber: '55 1234 5678'),
  PhoneCountry('FM', 'Micronesia', '+691', exampleNumber: '350 1234'),
  PhoneCountry('MD', 'Moldova', '+373', exampleNumber: '621 12 345'),
  PhoneCountry('MC', 'Monaco', '+377', exampleNumber: '6 12 34 56 78'),
  PhoneCountry('MN', 'Mongolia', '+976', exampleNumber: '8812 3456'),
  PhoneCountry('ME', 'Montenegro', '+382', exampleNumber: '67 123 456'),
  PhoneCountry(
    'MS',
    'Montserrat',
    '+1',
    exampleNumber: '(664) 555-0123',
    leadingDigits: ['664'],
  ),
  PhoneCountry(
    'MA',
    'Morocco',
    '+212',
    exampleNumber: '650-123456',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('MZ', 'Mozambique', '+258', exampleNumber: '82 123 4567'),
  PhoneCountry('MM', 'Myanmar', '+95', exampleNumber: '9 212 3456'),
  PhoneCountry('NA', 'Namibia', '+264', exampleNumber: '81 123 4567'),
  PhoneCountry('NR', 'Nauru', '+674', exampleNumber: '555 1234'),
  PhoneCountry('NP', 'Nepal', '+977', exampleNumber: '984-1234567'),
  PhoneCountry('NL', 'Netherlands', '+31', exampleNumber: '6 12345678'),
  PhoneCountry('NC', 'New Caledonia', '+687', exampleNumber: '75 12 34'),
  PhoneCountry(
    'NZ',
    'New Zealand',
    '+64',
    exampleNumber: '21 123 4567',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('NI', 'Nicaragua', '+505', exampleNumber: '8123 4567'),
  PhoneCountry('NE', 'Niger', '+227', exampleNumber: '93 12 34 56'),
  PhoneCountry('NG', 'Nigeria', '+234', exampleNumber: '802 123 4567'),
  PhoneCountry('NU', 'Niue', '+683'),
  PhoneCountry(
    'NF',
    'Norfolk Island',
    '+672',
    leadingDigits: ['3'],
    isSharedCodeFallback: true,
  ),
  PhoneCountry('KP', 'North Korea', '+850'),
  PhoneCountry('MK', 'North Macedonia', '+389', exampleNumber: '72 345 678'),
  PhoneCountry(
    'MP',
    'Northern Mariana Islands',
    '+1',
    exampleNumber: '(670) 555-0123',
    leadingDigits: ['670'],
  ),
  PhoneCountry(
    'NO',
    'Norway',
    '+47',
    exampleNumber: '406 12 345',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('OM', 'Oman', '+968', exampleNumber: '9212 3456'),
  PhoneCountry('PK', 'Pakistan', '+92', exampleNumber: '300 1234567'),
  PhoneCountry('PW', 'Palau', '+680', exampleNumber: '620 1234'),
  PhoneCountry('PS', 'Palestine', '+970', exampleNumber: '59 123 4567'),
  PhoneCountry('PA', 'Panama', '+507', exampleNumber: '6001-2345'),
  PhoneCountry('PG', 'Papua New Guinea', '+675', exampleNumber: '7012 3456'),
  PhoneCountry('PY', 'Paraguay', '+595', exampleNumber: '961 234 567'),
  PhoneCountry('PE', 'Peru', '+51', exampleNumber: '912 345 678'),
  PhoneCountry('PH', 'Philippines', '+63', exampleNumber: '917 123 4567'),
  PhoneCountry('PN', 'Pitcairn Islands', '+64'),
  PhoneCountry('PL', 'Poland', '+48', exampleNumber: '512 345 678'),
  PhoneCountry('PT', 'Portugal', '+351', exampleNumber: '912 345 678'),
  PhoneCountry(
    'PR',
    'Puerto Rico',
    '+1',
    exampleNumber: '(787) 555-0123',
    leadingDigits: ['787', '939'],
  ),
  PhoneCountry('QA', 'Qatar', '+974', exampleNumber: '3312 3456'),
  PhoneCountry(
    'RE',
    'Réunion',
    '+262',
    exampleNumber: '692 12 34 56',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('RO', 'Romania', '+40', exampleNumber: '712 034 567'),
  PhoneCountry(
    'RU',
    'Russia',
    '+7',
    exampleNumber: '912 345-67-89',
    isSharedCodeFallback: true,
  ),
  PhoneCountry('RW', 'Rwanda', '+250', exampleNumber: '720 123 456'),
  PhoneCountry('BL', 'Saint Barthélemy', '+590', exampleNumber: '690 00 12 34'),
  PhoneCountry('SH', 'Saint Helena', '+290', isSharedCodeFallback: true),
  PhoneCountry(
    'KN',
    'Saint Kitts and Nevis',
    '+1',
    exampleNumber: '(869) 555-0123',
    leadingDigits: ['869'],
  ),
  PhoneCountry(
    'LC',
    'Saint Lucia',
    '+1',
    exampleNumber: '(758) 555-0123',
    leadingDigits: ['758'],
  ),
  PhoneCountry('MF', 'Saint Martin', '+590', exampleNumber: '690 00 12 34'),
  PhoneCountry(
    'PM',
    'Saint Pierre and Miquelon',
    '+508',
    exampleNumber: '55 12 34',
  ),
  PhoneCountry(
    'VC',
    'Saint Vincent and the Grenadines',
    '+1',
    exampleNumber: '(784) 555-0123',
    leadingDigits: ['784'],
  ),
  PhoneCountry('WS', 'Samoa', '+685', exampleNumber: '72 12345'),
  PhoneCountry('SM', 'San Marino', '+378', exampleNumber: '66 66 12 12'),
  PhoneCountry(
    'ST',
    'São Tomé and Príncipe',
    '+239',
    exampleNumber: '981 2345',
  ),
  PhoneCountry('SA', 'Saudi Arabia', '+966', exampleNumber: '51 234 5678'),
  PhoneCountry('SN', 'Senegal', '+221', exampleNumber: '70 123 45 67'),
  PhoneCountry('RS', 'Serbia', '+381', exampleNumber: '60 123 4567'),
  PhoneCountry('SC', 'Seychelles', '+248', exampleNumber: '2 510 123'),
  PhoneCountry('SL', 'Sierra Leone', '+232', exampleNumber: '25 123456'),
  PhoneCountry('SG', 'Singapore', '+65', exampleNumber: '8123 4567'),
  PhoneCountry(
    'SX',
    'Sint Maarten',
    '+1',
    exampleNumber: '(721) 555-0123',
    leadingDigits: ['721'],
  ),
  PhoneCountry('SK', 'Slovakia', '+421', exampleNumber: '912 123 456'),
  PhoneCountry('SI', 'Slovenia', '+386', exampleNumber: '31 234 567'),
  PhoneCountry('SB', 'Solomon Islands', '+677', exampleNumber: '74 21234'),
  PhoneCountry('SO', 'Somalia', '+252', exampleNumber: '71 123456'),
  PhoneCountry('ZA', 'South Africa', '+27', exampleNumber: '71 123 4567'),
  PhoneCountry('KR', 'South Korea', '+82', exampleNumber: '10-2000-0000'),
  PhoneCountry('SS', 'South Sudan', '+211', exampleNumber: '977 123 456'),
  PhoneCountry('ES', 'Spain', '+34', exampleNumber: '612 34 56 78'),
  PhoneCountry('LK', 'Sri Lanka', '+94', exampleNumber: '71 234 5678'),
  PhoneCountry('SD', 'Sudan', '+249', exampleNumber: '91 123 1234'),
  PhoneCountry('SR', 'Suriname', '+597', exampleNumber: '741-2345'),
  PhoneCountry(
    'SJ',
    'Svalbard and Jan Mayen',
    '+47',
    exampleNumber: '79 12 34 56',
    leadingDigits: ['79'],
  ),
  PhoneCountry('SE', 'Sweden', '+46', exampleNumber: '70 123 45 67'),
  PhoneCountry('CH', 'Switzerland', '+41', exampleNumber: '78 123 45 67'),
  PhoneCountry('SY', 'Syria', '+963', exampleNumber: '944 123 456'),
  PhoneCountry('TW', 'Taiwan', '+886', exampleNumber: '912 345 678'),
  PhoneCountry('TJ', 'Tajikistan', '+992', exampleNumber: '917 12 3456'),
  PhoneCountry('TZ', 'Tanzania', '+255', exampleNumber: '621 234 567'),
  PhoneCountry('TH', 'Thailand', '+66', exampleNumber: '81 234 5678'),
  PhoneCountry('TL', 'Timor-Leste', '+670', exampleNumber: '7721 2345'),
  PhoneCountry('TG', 'Togo', '+228', exampleNumber: '90 11 23 45'),
  PhoneCountry('TK', 'Tokelau', '+690'),
  PhoneCountry('TO', 'Tonga', '+676', exampleNumber: '771 5123'),
  PhoneCountry(
    'TT',
    'Trinidad and Tobago',
    '+1',
    exampleNumber: '(868) 555-0123',
    leadingDigits: ['868'],
  ),
  PhoneCountry('TA', 'Tristan da Cunha', '+290', leadingDigits: ['8']),
  PhoneCountry('TN', 'Tunisia', '+216', exampleNumber: '20 123 456'),
  PhoneCountry('TR', 'Turkey', '+90', exampleNumber: '501 234 56 78'),
  PhoneCountry('TM', 'Turkmenistan', '+993', exampleNumber: '66 123456'),
  PhoneCountry(
    'TC',
    'Turks and Caicos Islands',
    '+1',
    exampleNumber: '(649) 555-0123',
    leadingDigits: ['649'],
  ),
  PhoneCountry('TV', 'Tuvalu', '+688'),
  PhoneCountry(
    'VI',
    'U.S. Virgin Islands',
    '+1',
    exampleNumber: '(340) 555-0123',
    leadingDigits: ['340'],
  ),
  PhoneCountry('UG', 'Uganda', '+256', exampleNumber: '712 345678'),
  PhoneCountry('UA', 'Ukraine', '+380', exampleNumber: '50 123 4567'),
  PhoneCountry(
    'AE',
    'United Arab Emirates',
    '+971',
    exampleNumber: '50 123 4567',
  ),
  // 07700 900xxx is Ofcom's range reserved for drama, so this example cannot
  // ring a real handset.
  PhoneCountry(
    'GB',
    'United Kingdom',
    '+44',
    exampleNumber: '7700 900123',
    isSharedCodeFallback: true,
  ),
  // Sorted here by name; declared separately above as [defaultPhoneCountry].
  defaultPhoneCountry,
  PhoneCountry('UY', 'Uruguay', '+598', exampleNumber: '94 231 234'),
  PhoneCountry('UZ', 'Uzbekistan', '+998', exampleNumber: '91 234 56 78'),
  PhoneCountry('VU', 'Vanuatu', '+678', exampleNumber: '591 2345'),
  // Vatican numbers sit inside the Italian plan on the 06 698 exchange; +379
  // is assigned to the Holy See but is not in service.
  PhoneCountry('VA', 'Vatican City', '+39', leadingDigits: ['06698']),
  PhoneCountry('VE', 'Venezuela', '+58', exampleNumber: '412-1234567'),
  PhoneCountry('VN', 'Vietnam', '+84', exampleNumber: '912 345 678'),
  PhoneCountry('WF', 'Wallis and Futuna', '+681', exampleNumber: '50 12 34'),
  PhoneCountry(
    'EH',
    'Western Sahara',
    '+212',
    exampleNumber: '528 812 345',
    leadingDigits: ['5288', '5289'],
  ),
  PhoneCountry('YE', 'Yemen', '+967', exampleNumber: '712 345 678'),
  PhoneCountry('ZM', 'Zambia', '+260', exampleNumber: '955 123 456'),
  PhoneCountry('ZW', 'Zimbabwe', '+263', exampleNumber: '71 234 5678'),
];

/// Where the dropdown starts when nothing better is known.
///
/// Made an explicit, named, documented constant rather than "whatever index 0
/// happens to be" or "whatever the first `+1` row is". Any default is a guess
/// about a stranger, so the only responsible thing is to make the guess
/// visible, cheap to change, and harmless: selecting a country never rewrites
/// what the user typed, so a wrong default costs one dropdown tap.
///
/// The United States because it is the largest single block under the most
/// widely shared dial code, because it is the only region this app already
/// assumed anywhere (`lib/data/sample_resume.dart` ships a `+1` number), and
/// because English is the app's only language today. None of those is a strong
/// argument — which is the point of naming it here rather than letting it
/// happen by accident.
///
/// Prefer [phoneCountryForRegion] where a locale region is available.
const PhoneCountry defaultPhoneCountry = PhoneCountry(
  'US',
  'United States',
  '+1',
  exampleNumber: '(201) 555-0123',
  isSharedCodeFallback: true,
);

final Map<String, PhoneCountry> _byIso = {
  for (final country in phoneCountries) country.isoCode: country,
};

final Map<String, List<PhoneCountry>> _byDialCode = () {
  final map = <String, List<PhoneCountry>>{};
  for (final country in phoneCountries) {
    (map[country.dialCode] ??= <PhoneCountry>[]).add(country);
  }
  return map;
}();

/// The country with this ISO 3166-1 alpha-2 code, or null.
///
/// Case-insensitive and whitespace-tolerant, because the codes reaching it come
/// from locales and stored strings as often as from literals. O(1).
PhoneCountry? phoneCountryByIso(String? isoCode) {
  if (isoCode == null) return null;
  return _byIso[isoCode.trim().toUpperCase()];
}

/// Every country sharing this dial code, in table order. Empty when the code is
/// not assigned. O(1).
///
/// Returns a list rather than a single country because that is the shape of the
/// data: `+1` has 25 answers and no way to choose between them from the dial
/// code alone. Callers wanting one country from a *whole number* want
/// [splitPhoneNumber], which can use the national digits to narrow it.
List<PhoneCountry> phoneCountriesByDialCode(String dialCode) {
  final key = dialCode.trim();
  return _byDialCode[key.startsWith('+') ? key : '+$key'] ??
      const <PhoneCountry>[];
}

/// The one country a bare dial code falls back to, or null when unassigned.
///
/// For the ~200 codes with a single country this is simply that country. For a
/// shared one it is a documented convention rather than a fact — see
/// [PhoneCountry.isSharedCodeFallback].
PhoneCountry? defaultCountryForDialCode(String dialCode) {
  final candidates = phoneCountriesByDialCode(dialCode);
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.single;
  for (final country in candidates) {
    if (country.isSharedCodeFallback) return country;
  }
  return null;
}

/// The country to start on for a locale region code, falling back to
/// [defaultPhoneCountry].
///
/// Pass `Localizations.localeOf(context).countryCode` or
/// `PlatformDispatcher.instance.locale.countryCode`. Taking the region as an
/// argument rather than reading it here keeps this library free of `dart:ui`
/// and testable without a binding.
///
/// Never throws and never returns null: a locale with no region (`en`), a
/// region this table does not carry, or a UN M49 region (`419` for Latin
/// America) all land on [defaultPhoneCountry].
PhoneCountry phoneCountryForRegion(String? regionCode) =>
    phoneCountryByIso(regionCode) ?? defaultPhoneCountry;

/// The placeholder for a phone field, given the selected country.
///
/// Derived from [PhoneCountry.exampleNumber] so there is one source of truth
/// for a country's shape; a country with no example still gets a usable plain
/// placeholder rather than a blank or an invented format.
///
/// [withDialCode] is for a single field holding the whole number; leave it
/// false when a dropdown already shows the dial code beside the field.
String phoneHint(PhoneCountry? country, {bool withDialCode = false}) {
  if (country == null) return _plainHint;
  return withDialCode ? country.fullNumberHint : country.numberHint;
}

/// Splits a stored phone string into the country its dial code names and the
/// rest of the number.
///
/// This is how a dropdown gets pre-selected from a resume that was saved before
/// the dropdown existed. It reads; it never rewrites. The returned
/// [PhoneNumberParts.nationalNumber] keeps the user's own spacing and any trunk
/// zero, because both are theirs.
///
/// A string that does not start with `+` yields a null country — not the
/// default. There is no way to tell `555 0123` from Ohio from `555 0123` from
/// anywhere else, and guessing would be the first step towards prepending a
/// wrong dial code to a working number.
PhoneNumberParts splitPhoneNumber(String input) {
  final text = input.trim();
  if (!text.startsWith('+')) {
    return PhoneNumberParts(
      country: null,
      nationalNumber: text,
      isGuess: false,
    );
  }

  // Digits with where each came from, so the national remainder can be handed
  // back as the user wrote it rather than as a digit run.
  final digits = StringBuffer();
  final sourceIndex = <int>[];
  for (var i = 0; i < text.length; i++) {
    if (_isDigit(text.codeUnitAt(i))) {
      digits.write(text[i]);
      sourceIndex.add(i);
    }
  }
  final digitRun = digits.toString();

  // Longest match first: '+380' (Ukraine) must win over '+38', and '+1' must
  // only be reached once no longer code matched.
  for (var length = _maxDialCodeDigits; length >= 1; length--) {
    if (digitRun.length < length) continue;
    final candidates = phoneCountriesByDialCode(
      '+${digitRun.substring(0, length)}',
    );
    if (candidates.isEmpty) continue;

    final nationalDigits = digitRun.substring(length);
    final rest = sourceIndex.length > length
        ? text.substring(sourceIndex[length])
        : '';

    final matched = _matchLeadingDigits(candidates, nationalDigits);
    return PhoneNumberParts(
      // The single country when the code is unshared; the flagged sharer
      // otherwise. `candidates.first` is unreachable — a test asserts every
      // shared code has exactly one flagged sharer — and is here so a bad edit
      // to the table degrades to the wrong dropdown row rather than to a crash
      // in the editor.
      country:
          matched ??
          (candidates.length == 1
              ? candidates.single
              : candidates.firstWhere(
                  (candidate) => candidate.isSharedCodeFallback,
                  orElse: () => candidates.first,
                )),
      nationalNumber: _trimSeparators(rest),
      isGuess: matched == null && candidates.length > 1,
    );
  }

  return PhoneNumberParts(country: null, nationalNumber: text, isGuess: false);
}

/// Joins a country and a national number into one string for storage.
///
/// The inverse of [splitPhoneNumber], and the only writer here. Deliberately
/// dumb: it prefixes the dial code and leaves the national part exactly as
/// typed. It does not strip a trunk zero — plenty of countries keep a leading
/// digit that only *looks* like one — and it does not regroup digits.
///
/// Returns an empty string for an empty national part, so an untouched field
/// stores nothing rather than a bare `+880` that reads as a broken number on
/// an exported resume.
String joinPhoneNumber(PhoneCountry country, String nationalNumber) {
  final national = nationalNumber.trim();
  if (national.isEmpty) return '';
  return '${country.dialCode} $national';
}

/// Looks for the ways a string obviously cannot be a phone number.
///
/// **This is a plausibility check, not validation.** It knows three things: what
/// characters phone numbers are written with, that E.164 caps a number at 15
/// digits, and that nothing anywhere is shorter than a handful. It does not
/// know which prefixes a country has assigned, how long numbers are there, or
/// whether this one was ever issued — so it cannot and does not say a number is
/// valid, or that it belongs to [country].
///
/// It errs towards accepting. A resume field that rejects somebody's real
/// number is a worse bug than one that accepts a typo, so anything this file is
/// unsure about passes: unusual lengths, unfamiliar groupings, trunk zeros,
/// and trailing extensions (`x210`, `ext. 210`) are all fine.
///
/// [country] is used only to count the dial code's digits towards the E.164
/// limit when [input] does not carry a `+` of its own. Its
/// [PhoneCountry.exampleNumber] length is deliberately *not* used as an
/// expected length: real national numbers vary in length within most countries
/// (Germany 10–11 digits, Indonesia 9–12), so a single example is evidence of
/// shape, never of correctness.
PhoneIssue checkPhoneNumber(String input, {PhoneCountry? country}) {
  final text = input.trim();
  if (text.isEmpty) return PhoneIssue.empty;

  final body = _withoutExtension(text);
  if (body.indexOf('+', 1) != -1) return PhoneIssue.misplacedPlus;

  final international = body.startsWith('+');
  var digitCount = 0;
  for (var i = international ? 1 : 0; i < body.length; i++) {
    final unit = body.codeUnitAt(i);
    if (_isDigit(unit)) {
      digitCount++;
    } else if (!_isSeparator(unit)) {
      return PhoneIssue.unexpectedCharacter;
    }
  }

  // An entry without its own '+' is a national number, so the selected
  // country's dial code counts towards the E.164 total even though it was
  // never typed.
  final total = international
      ? digitCount
      : digitCount + (country?.dialDigits.length ?? 0);

  if (digitCount < _minNationalDigits) return PhoneIssue.tooShort;
  // The total floor only applies when the country code is actually known.
  // A bare national number with no country selected could be from anywhere,
  // including the handful of territories with very short numbers, so there is
  // nothing to measure it against and it is left alone.
  if ((international || country != null) && total < _minTotalDigits) {
    return PhoneIssue.tooShort;
  }
  if (total > _maxTotalDigits) return PhoneIssue.tooLong;
  return PhoneIssue.ok;
}

/// E.164 caps an international number at 15 digits, country code included.
const _maxTotalDigits = 15;

/// The shortest numbers in service anywhere are around seven digits including
/// the country code (`+290` Saint Helena, `+683` Niue). Six is one below that,
/// chosen so the check flags a slip of the thumb without ever arguing with a
/// small territory whose plan this file does not model.
const _minTotalDigits = 6;

/// The shortest national numbers anywhere are four digits (Saint Helena, Niue,
/// Tokelau). Below that is not a truncated phone number, it is a typo.
const _minNationalDigits = 4;

/// The longest dial code in [phoneCountries] is three digits.
const _maxDialCodeDigits = 3;

/// A trailing extension: `x210`, `X 210`, `ext 210`, `ext. 210`, `#210`,
/// `,210`. Anchored to the end so a stray letter mid-number is still caught.
final _extension = RegExp(
  r'\s*(?:e?xt?\.?|[#,;])\s*\d+\s*$',
  caseSensitive: false,
);

String _withoutExtension(String text) => text.replaceFirst(_extension, '');

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// Space (plain and non-breaking), `-`, `(`, `)`, `.`, `/`, and the en dash a
/// phone keyboard or a paste from a web page can slip in.
bool _isSeparator(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0xA0 ||
    codeUnit == 0x2D ||
    codeUnit == 0x2013 ||
    codeUnit == 0x28 ||
    codeUnit == 0x29 ||
    codeUnit == 0x2E ||
    codeUnit == 0x2F;

String _digitsOf(String text) {
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (_isDigit(text.codeUnitAt(i))) buffer.write(text[i]);
  }
  return buffer.toString();
}

/// Tidies the remainder left after a dial code is taken off the front.
///
/// Drops the separators between the dial code and the first national digit,
/// and any bracket left orphaned by the cut — `+1 (415) 555-0123` splits
/// mid-bracket and would otherwise hand back `415) 555-0123`, which looks
/// broken in a field. Nothing else about the user's spacing is touched.
String _trimSeparators(String text) {
  var start = 0;
  while (start < text.length && !_isDigit(text.codeUnitAt(start))) {
    start++;
  }
  return _dropUnmatchedParens(text.substring(start).trim());
}

String _dropUnmatchedParens(String text) {
  if (!text.contains('(') && !text.contains(')')) return text;
  final buffer = StringBuffer();
  var open = 0;
  for (final character in text.split('')) {
    if (character == '(') {
      open++;
    } else if (character == ')') {
      if (open == 0) continue;
      open--;
    }
    buffer.write(character);
  }
  final kept = buffer.toString();
  return open == 0 ? kept : kept.replaceAll('(', '');
}

/// The candidate whose [PhoneCountry.leadingDigits] best matches, or null when
/// none does.
///
/// Longest match wins, so a five-digit Christmas Island prefix beats a
/// one-digit one if both ever collided.
PhoneCountry? _matchLeadingDigits(
  List<PhoneCountry> candidates,
  String nationalDigits,
) {
  PhoneCountry? best;
  var bestLength = 0;
  for (final candidate in candidates) {
    for (final prefix in candidate.leadingDigits) {
      if (prefix.length > bestLength && nationalDigits.startsWith(prefix)) {
        best = candidate;
        bestLength = prefix.length;
      }
    }
  }
  return best;
}

const _diacritics = <String, String>{
  'Å': 'A',
  'å': 'a',
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'í': 'i',
  'î': 'i',
  'ñ': 'n',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'ú': 'u',
  'ü': 'u',
};

String _foldDiacritics(String text) {
  if (!text.codeUnits.any((unit) => unit > 0x7F)) return text;
  final buffer = StringBuffer();
  for (final character in text.split('')) {
    buffer.write(_diacritics[character] ?? character);
  }
  return buffer.toString();
}
