import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/phone.dart';

/// Shorthand for the tests below. Throws rather than returning null so a
/// mistyped ISO code fails loudly instead of silently testing nothing.
PhoneCountry iso(String code) {
  final country = phoneCountryByIso(code);
  if (country == null) throw StateError('no country for "$code"');
  return country;
}

void main() {
  group('the country table', () {
    test('has no duplicate ISO codes', () {
      final seen = <String, PhoneCountry>{};
      for (final country in phoneCountries) {
        final clash = seen[country.isoCode];
        expect(
          clash,
          isNull,
          reason:
              'ISO ${country.isoCode} is used by both "${clash?.name}" and '
              '"${country.name}"; the ISO lookup map would silently drop one',
        );
        seen[country.isoCode] = country;
      }
    });

    test('has a well-formed ISO code and name on every row', () {
      for (final country in phoneCountries) {
        expect(
          country.isoCode,
          matches(RegExp(r'^[A-Z]{2}$')),
          reason: '${country.name} has ISO code "${country.isoCode}"',
        );
        expect(country.name.trim(), isNotEmpty);
      }
    });

    test('has no empty dial code, and every one is + then digits', () {
      for (final country in phoneCountries) {
        expect(
          country.dialCode,
          isNotEmpty,
          reason: '${country.name} has no dial code',
        );
        expect(
          country.dialCode,
          matches(RegExp(r'^\+\d{1,3}$')),
          reason: '${country.name} has dial code "${country.dialCode}"',
        );
        expect(country.dialDigits, country.dialCode.substring(1));
      }
    });

    test('covers the world rather than a curated shortlist', () {
      // QA asked for "all country codes". The exact count moves as territories
      // are added, so this guards the order of magnitude, not a number.
      expect(phoneCountries.length, greaterThan(240));

      // A spread that a top-20 list would not survive.
      for (final code in [
        'BD',
        'US',
        'GB',
        'IN',
        'NG',
        'BR',
        'JP',
        'DE',
        'ZA',
        'AU',
        'TV',
        'NR',
        'VA',
        'AQ',
        'XK',
        'SS',
        'TL',
        'EH',
        'AX',
        'SJ',
      ]) {
        expect(
          phoneCountryByIso(code),
          isNotNull,
          reason: '$code is missing from the table',
        );
      }
    });

    test('is sorted by sortKey, which is what a dropdown shows', () {
      final names = phoneCountries.map((c) => c.name).toList();
      final keys = phoneCountries.map((c) => c.sortKey).toList();
      final sorted = [...keys]..sort();

      for (var i = 0; i < keys.length; i++) {
        expect(
          keys[i],
          sorted[i],
          reason:
              '"${names[i]}" is out of order at index $i; the table is kept '
              'sorted in source so the order is reviewable in a diff',
        );
      }
    });

    test(
      'folds diacritics so accented names sort where they are looked for',
      () {
        // The failure this prevents: code-unit ordering files Åland after
        // Zimbabwe, off the end of the list.
        expect(iso('AX').sortKey, 'aland islands');
        expect(iso('CI').sortKey, "cote d'ivoire");
        expect(iso('CW').sortKey, 'curacao');
        expect(iso('RE').sortKey, 'reunion');
        expect(iso('ST').sortKey, 'sao tome and principe');
        expect(iso('BL').sortKey, 'saint barthelemy');

        final aland = phoneCountries.indexOf(iso('AX'));
        expect(aland, lessThan(phoneCountries.indexOf(iso('AL'))));
        expect(aland, greaterThan(phoneCountries.indexOf(iso('AF'))));
      },
    );

    test('example numbers are national numbers, not international ones', () {
      for (final country in phoneCountries) {
        final example = country.exampleNumber;
        if (example == null) continue;

        expect(
          example,
          isNot(contains('+')),
          reason:
              '${country.name} example "$example" looks international; the '
              'field holds the national part and the dial code is added',
        );
        expect(
          example,
          matches(RegExp(r'^[\d()\-. ]+$')),
          reason: '${country.name} example "$example" has odd characters',
        );
      }
    });

    test('every shipped example passes our own plausibility check', () {
      // Catches a fat-fingered example that would put an impossible number
      // shape in front of the user as a placeholder.
      for (final country in phoneCountries) {
        final example = country.exampleNumber;
        if (example == null) continue;

        expect(
          checkPhoneNumber(example, country: country),
          PhoneIssue.ok,
          reason: '${country.name} example "$example" fails its own check',
        );
      }
    });

    test('leading digits are digit strings, and only where they can help', () {
      for (final country in phoneCountries) {
        if (country.leadingDigits.isEmpty) continue;

        for (final prefix in country.leadingDigits) {
          expect(
            prefix,
            matches(RegExp(r'^\d+$')),
            reason: '${country.name} has leading digits "$prefix"',
          );
        }
        expect(
          phoneCountriesByDialCode(country.dialCode).length,
          greaterThan(1),
          reason:
              '${country.name} carries leading digits but ${country.dialCode} '
              'is not shared, so they can never be consulted',
        );
      }
    });
  });

  group('shared dial codes', () {
    test('lookup by dial code returns every sharer, not "the" country', () {
      final nanp = phoneCountriesByDialCode('+1');
      expect(nanp.length, 25);
      expect(
        nanp.map((c) => c.isoCode),
        containsAll(['US', 'CA', 'BB', 'JM', 'PR', 'DO', 'TT']),
      );

      expect(
        phoneCountriesByDialCode('+7').map((c) => c.isoCode),
        containsAll(['RU', 'KZ']),
      );
      expect(phoneCountriesByDialCode('+44').length, 4);
      expect(phoneCountriesByDialCode('+590').length, 3);
    });

    test(
      'accepts a dial code with or without its +, and is empty when unknown',
      () {
        expect(phoneCountriesByDialCode('880').single.isoCode, 'BD');
        expect(phoneCountriesByDialCode('+880').single.isoCode, 'BD');
        expect(phoneCountriesByDialCode(' +880 ').single.isoCode, 'BD');
        expect(phoneCountriesByDialCode('+999'), isEmpty);
      },
    );

    test('every shared dial code has exactly one flagged fallback', () {
      final flagged = <String, List<String>>{};
      for (final country in phoneCountries) {
        if (country.isSharedCodeFallback) {
          (flagged[country.dialCode] ??= <String>[]).add(country.name);
        }
      }

      for (final code in phoneCountries.map((c) => c.dialCode).toSet()) {
        final sharers = phoneCountriesByDialCode(code);
        if (sharers.length == 1) {
          // Redundant on an unshared code, and a flag that means nothing is a
          // flag that will eventually contradict the table.
          expect(
            flagged[code],
            isNull,
            reason:
                '$code has one country (${sharers.single.name}) and needs no '
                'fallback flag',
          );
          continue;
        }
        expect(
          flagged[code],
          hasLength(1),
          reason:
              '$code is shared by ${sharers.length} countries and has '
              '${flagged[code]?.length ?? 0} flagged fallbacks '
              '(${flagged[code]}); splitting a number needs exactly one',
        );
      }
    });

    test('every dial code resolves to some country', () {
      // Shared or not, no code may be a dead end: that would leave
      // splitPhoneNumber with nothing to return for a real number.
      for (final code in phoneCountries.map((c) => c.dialCode).toSet()) {
        expect(defaultCountryForDialCode(code), isNotNull, reason: code);
      }
    });

    test('resolves a shared code by national prefix where it can', () {
      // The case the whole mechanism exists for: +1 is 25 countries.
      expect(splitPhoneNumber('+1 (246) 555-0123').country?.isoCode, 'BB');
      expect(splitPhoneNumber('+1 876 555 0123').country?.isoCode, 'JM');
      expect(splitPhoneNumber('+1 658 555 0123').country?.isoCode, 'JM');
      expect(splitPhoneNumber('+1 849 555 0123').country?.isoCode, 'DO');
      expect(splitPhoneNumber('+1 204 555 0123').country?.isoCode, 'CA');
      expect(splitPhoneNumber('+1 721 555 0123').country?.isoCode, 'SX');

      expect(splitPhoneNumber('+7 771 234 5678').country?.isoCode, 'KZ');
      expect(splitPhoneNumber('+44 1534 123456').country?.isoCode, 'JE');
      expect(splitPhoneNumber('+44 1481 123456').country?.isoCode, 'GG');
      expect(splitPhoneNumber('+44 1624 123456').country?.isoCode, 'IM');
      expect(splitPhoneNumber('+61 8 9162 1234').country?.isoCode, 'CC');
      expect(splitPhoneNumber('+61 8 9164 1234').country?.isoCode, 'CX');
      expect(splitPhoneNumber('+39 06 698 12345').country?.isoCode, 'VA');
      expect(splitPhoneNumber('+599 9 518 1234').country?.isoCode, 'CW');
      expect(splitPhoneNumber('+262 639 01 23 45').country?.isoCode, 'YT');
      expect(splitPhoneNumber('+47 79 12 34 56').country?.isoCode, 'SJ');
    });

    test('says so when it fell back to the default instead of resolving', () {
      final american = splitPhoneNumber('+1 415 555 0123');
      expect(american.country?.isoCode, 'US');
      expect(
        american.isGuess,
        isTrue,
        reason: '415 is not in any leading-digit list, so US is a fallback',
      );

      final russian = splitPhoneNumber('+7 912 345-67-89');
      expect(russian.country?.isoCode, 'RU');
      expect(russian.isGuess, isTrue);

      final british = splitPhoneNumber('+44 7700 900123');
      expect(british.country?.isoCode, 'GB');
      expect(british.isGuess, isTrue);
    });

    test('an unshared dial code is never reported as a guess', () {
      for (final number in [
        '+880 1712-345678',
        '+91 98765 43210',
        '+81 90-1234-5678',
      ]) {
        final parts = splitPhoneNumber(number);
        expect(parts.isGuess, isFalse, reason: number);
      }
      // Nor is one that a prefix actually resolved.
      expect(splitPhoneNumber('+1 246 555 0123').isGuess, isFalse);
      expect(splitPhoneNumber('+7 771 234 5678').isGuess, isFalse);
    });

    test('the longest dial code wins over a shorter prefix of it', () {
      // '+380' must not be read as '+38' (unassigned) or as '+3'.
      expect(splitPhoneNumber('+380 50 123 4567').country?.isoCode, 'UA');
      expect(splitPhoneNumber('+972 50-123-4567').country?.isoCode, 'IL');
      expect(splitPhoneNumber('+590 690 00 12 34').country?.isoCode, 'GP');
      // '+1' is reached only because no three- or two-digit code matched.
      expect(splitPhoneNumber('+1 204 555 0123').country?.isoCode, 'CA');

      // Spacing carries no information; only the digit stream does. These are
      // the same number written two ways, and both are Israeli.
      expect(
        splitPhoneNumber('+97 250 123 4567').country?.isoCode,
        splitPhoneNumber('+972 50 123 4567').country?.isoCode,
      );
    });

    test('defaultCountryForDialCode names the fallback, or nothing', () {
      expect(defaultCountryForDialCode('+1')?.isoCode, 'US');
      expect(defaultCountryForDialCode('+44')?.isoCode, 'GB');
      expect(defaultCountryForDialCode('+7')?.isoCode, 'RU');
      expect(defaultCountryForDialCode('880')?.isoCode, 'BD');
      expect(defaultCountryForDialCode('+999'), isNull);
    });
  });

  group('lookup by ISO code', () {
    test('finds a country whatever case or padding it is given', () {
      expect(phoneCountryByIso('BD')?.name, 'Bangladesh');
      expect(phoneCountryByIso('bd')?.name, 'Bangladesh');
      expect(phoneCountryByIso(' bd ')?.name, 'Bangladesh');
    });

    test('returns null rather than guessing', () {
      expect(phoneCountryByIso('ZZ'), isNull);
      expect(phoneCountryByIso(''), isNull);
      expect(phoneCountryByIso(null), isNull);
      expect(phoneCountryByIso('BGD'), isNull);
    });

    test('reaches every row in the table', () {
      for (final country in phoneCountries) {
        expect(phoneCountryByIso(country.isoCode), same(country));
      }
    });
  });

  group('placeholder derivation', () {
    test('comes from the example number, so the two cannot drift apart', () {
      final bangladesh = iso('BD');
      expect(bangladesh.exampleNumber, '1712-345678');
      expect(bangladesh.numberHint, '1712-345678');
      expect(bangladesh.fullNumberHint, '+880 1712-345678');
      expect(bangladesh.exampleFullNumber, '+880 1712-345678');
      expect(bangladesh.exampleDigits, '1712345678');
    });

    test('changes with the selected country, which is the QA ask', () {
      expect(phoneHint(iso('BD')), '1712-345678');
      expect(phoneHint(iso('US')), '(201) 555-0123');
      expect(phoneHint(iso('FR')), '6 12 34 56 78');
      expect(phoneHint(iso('IN')), '98765 43210');

      expect(phoneHint(iso('BD')), isNot(phoneHint(iso('US'))));
    });

    test('adds the dial code only when the field holds the whole number', () {
      expect(phoneHint(iso('BD')), '1712-345678');
      expect(phoneHint(iso('BD'), withDialCode: true), '+880 1712-345678');
    });

    test('falls back to plain wording where there is no example', () {
      final kiribati = iso('KI');
      expect(kiribati.exampleNumber, isNull);
      expect(kiribati.exampleDigits, isNull);
      expect(kiribati.exampleFullNumber, isNull);
      expect(kiribati.numberHint, 'Phone number');
      expect(kiribati.fullNumberHint, '+686 Phone number');
      expect(phoneHint(kiribati), 'Phone number');
    });

    test('has something to show before any country is chosen', () {
      expect(phoneHint(null), 'Phone number');
      expect(phoneHint(null, withDialCode: true), 'Phone number');
    });
  });

  group('the default country', () {
    test('is an explicit constant, and is in the table exactly once', () {
      expect(defaultPhoneCountry.isoCode, 'US');
      expect(
        phoneCountries.where((c) => c.isoCode == 'US'),
        hasLength(1),
        reason: 'the constant is spliced into the sorted table, not duplicated',
      );
      expect(phoneCountryByIso('US'), same(defaultPhoneCountry));
    });

    test('is what an unknown or absent region falls back to', () {
      expect(phoneCountryForRegion(null), same(defaultPhoneCountry));
      expect(phoneCountryForRegion(''), same(defaultPhoneCountry));
      // A locale with no region ("en"), and a UN M49 region ("419" for Latin
      // America) — both are things a real device reports.
      expect(phoneCountryForRegion('419'), same(defaultPhoneCountry));
      expect(phoneCountryForRegion('ZZ'), same(defaultPhoneCountry));
    });

    test('follows the locale region when it names a country we carry', () {
      expect(phoneCountryForRegion('GB').isoCode, 'GB');
      expect(phoneCountryForRegion('gb').isoCode, 'GB');
      expect(phoneCountryForRegion('BD').isoCode, 'BD');
    });
  });

  group('the plausibility check', () {
    test('is quiet about an empty field, which is a valid resume', () {
      expect(checkPhoneNumber(''), PhoneIssue.empty);
      expect(checkPhoneNumber('   '), PhoneIssue.empty);
      expect(PhoneIssue.empty.isAcceptable, isTrue);
      expect(PhoneIssue.empty.message, isNull);
    });

    test('accepts the separators people actually type', () {
      const accepted = [
        '+1 (415) 555-0123',
        '+1-415-555-0123',
        '+1.415.555.0123',
        '(415) 555 0123',
        '+880 1712-345678',
        '+44 (0)7700 900123',
        '+33 6 12 34 56 78',
        '+49 1512 3456789',
      ];
      for (final number in accepted) {
        expect(checkPhoneNumber(number), PhoneIssue.ok, reason: number);
      }
    });

    test('accepts a trailing extension rather than calling it a typo', () {
      for (final number in [
        '+1 415 555 0123 x210',
        '+1 415 555 0123 X210',
        '+1 415 555 0123 ext 210',
        '+1 415 555 0123 ext. 210',
        '+1 415 555 0123 #210',
        '+1 415 555 0123,210',
      ]) {
        expect(checkPhoneNumber(number), PhoneIssue.ok, reason: number);
      }
    });

    test('flags letters that are not an extension', () {
      expect(checkPhoneNumber('call me maybe'), PhoneIssue.unexpectedCharacter);
      expect(
        checkPhoneNumber('+1 415 555 ABCD'),
        PhoneIssue.unexpectedCharacter,
      );
      expect(
        checkPhoneNumber('+1 800 FLOWERS'),
        PhoneIssue.unexpectedCharacter,
      );
      expect(
        checkPhoneNumber('+1 415 5x55 0123'),
        PhoneIssue.unexpectedCharacter,
      );
      expect(checkPhoneNumber('415*555*0123'), PhoneIssue.unexpectedCharacter);
    });

    test('accepts a leading + and only a leading +', () {
      expect(checkPhoneNumber('+8801712345678'), PhoneIssue.ok);
      expect(checkPhoneNumber('8801712345678'), PhoneIssue.ok);
      expect(checkPhoneNumber('415+555+0123'), PhoneIssue.misplacedPlus);
      expect(checkPhoneNumber('+1 415+555 0123'), PhoneIssue.misplacedPlus);
      expect(checkPhoneNumber('++8801712345678'), PhoneIssue.misplacedPlus);
    });

    test('has a floor, at the shortest number that exists anywhere', () {
      expect(checkPhoneNumber('1'), PhoneIssue.tooShort);
      expect(checkPhoneNumber('123'), PhoneIssue.tooShort);
      expect(checkPhoneNumber('+'), PhoneIssue.tooShort);
      // Four national digits is Saint Helena's whole number, so it stands.
      expect(checkPhoneNumber('1234', country: iso('SH')), PhoneIssue.ok);
      // The same four digits are too short once the country code is counted
      // and the country code is only one digit.
      expect(checkPhoneNumber('+12345'), PhoneIssue.tooShort);
      expect(checkPhoneNumber('+123456'), PhoneIssue.ok);
    });

    test('has a ceiling, at the E.164 limit of fifteen digits', () {
      expect(checkPhoneNumber('+123456789012345'), PhoneIssue.ok);
      expect(checkPhoneNumber('+1234567890123456'), PhoneIssue.tooLong);
      expect(checkPhoneNumber('+1 234 567 890 123 456'), PhoneIssue.tooLong);
    });

    test('counts the selected country code towards the ceiling', () {
      final bangladesh = iso('BD'); // +880, three digits.
      expect(
        checkPhoneNumber('123456789012', country: bangladesh),
        PhoneIssue.ok,
        reason: '12 national + 3 dial = 15',
      );
      expect(
        checkPhoneNumber('1234567890123', country: bangladesh),
        PhoneIssue.tooLong,
        reason: '13 national + 3 dial = 16',
      );
      expect(
        checkPhoneNumber('1234567890123'),
        PhoneIssue.ok,
        reason: 'with no country selected there is no dial code to add',
      );
    });

    test(
      'ignores the selected country when the input carries its own code',
      () {
        // Someone pastes a full international number into a field where the
        // dropdown still says Bangladesh. The dial code must not be counted
        // twice and turn a fine number into "too long".
        expect(
          checkPhoneNumber('+1 415 555 0123', country: iso('BD')),
          PhoneIssue.ok,
        );
      },
    );

    test('claims nothing about whether the number is real', () {
      // All three are implausible for the country selected and all three pass:
      // the check has no metadata to say otherwise, and saying otherwise on a
      // guess would block real numbers.
      expect(checkPhoneNumber('0000000000', country: iso('US')), PhoneIssue.ok);
      expect(checkPhoneNumber('1234', country: iso('BD')), PhoneIssue.ok);
      expect(
        checkPhoneNumber('99999999999', country: iso('FR')),
        PhoneIssue.ok,
      );
    });

    test(
      'every issue a caller can act on carries wording, and ok does not',
      () {
        for (final issue in PhoneIssue.values) {
          if (issue.isAcceptable) {
            expect(issue.message, isNull, reason: '$issue');
          } else {
            expect(issue.message, isNotNull, reason: '$issue');
            expect(issue.message, isNotEmpty, reason: '$issue');
          }
        }
        expect(PhoneIssue.ok.isAcceptable, isTrue);
        expect(PhoneIssue.tooShort.isAcceptable, isFalse);
      },
    );
  });

  group('splitting a stored number', () {
    test('hands back the national part with the user spacing intact', () {
      final parts = splitPhoneNumber('+880 1712-345678');
      expect(parts.country?.isoCode, 'BD');
      expect(parts.nationalNumber, '1712-345678');
    });

    test('does not leave a bracket orphaned by the cut', () {
      // '+1 (415) ...' splits between '(' and ')'.
      expect(
        splitPhoneNumber('+1 (415) 555-0123').nationalNumber,
        '415 555-0123',
      );
      expect(splitPhoneNumber('+1 (204) 555-0123').country?.isoCode, 'CA');
    });

    test('reports no country at all when the string carries no dial code', () {
      // The state every resume saved before the dropdown existed is in. The
      // caller must not prepend a dial code to this.
      final parts = splitPhoneNumber('(415) 555-0134');
      expect(parts.country, isNull);
      expect(parts.nationalNumber, '(415) 555-0134');
      expect(parts.isGuess, isFalse);
    });

    test(
      'reports no country for an unassigned dial code, and keeps the text',
      () {
        final parts = splitPhoneNumber('+999 123 4567');
        expect(parts.country, isNull);
        expect(parts.nationalNumber, '+999 123 4567');
      },
    );

    test('survives empty and near-empty input', () {
      for (final input in ['', '   ', '+', '+ ']) {
        final parts = splitPhoneNumber(input);
        expect(parts.country, isNull, reason: '"$input"');
        expect(parts.isGuess, isFalse, reason: '"$input"');
      }
      expect(splitPhoneNumber('').nationalNumber, '');
    });
  });

  group('joining a number for storage', () {
    test('prefixes the dial code and changes nothing else', () {
      expect(joinPhoneNumber(iso('BD'), '1712-345678'), '+880 1712-345678');
      expect(joinPhoneNumber(iso('US'), '(415) 555-0134'), '+1 (415) 555-0134');
      expect(
        joinPhoneNumber(iso('FR'), ' 6 12 34 56 78 '),
        '+33 6 12 34 56 78',
      );
    });

    test('keeps a leading zero, which is the users to decide about', () {
      expect(joinPhoneNumber(iso('BD'), '01712-345678'), '+880 01712-345678');
    });

    test('stores nothing rather than a bare dial code', () {
      expect(joinPhoneNumber(iso('BD'), ''), '');
      expect(joinPhoneNumber(iso('BD'), '   '), '');
    });

    test('round-trips through splitPhoneNumber', () {
      for (final isoCode in ['BD', 'GB', 'IN', 'DE', 'JP', 'BR', 'KZ', 'JE']) {
        final country = iso(isoCode);
        final national = country.exampleNumber!;
        final parts = splitPhoneNumber(joinPhoneNumber(country, national));

        expect(parts.country?.isoCode, isoCode, reason: isoCode);
        expect(parts.nationalNumber, national, reason: isoCode);
      }
    });

    test('round-trips every example whose dial code is not shared', () {
      // The shared ones cannot round-trip by construction: '+1 555 0123' has
      // 25 possible sources and the table is honest about that rather than
      // pretending to pick.
      for (final country in phoneCountries) {
        final example = country.exampleNumber;
        if (example == null) continue;
        if (phoneCountriesByDialCode(country.dialCode).length > 1) continue;

        final parts = splitPhoneNumber(joinPhoneNumber(country, example));
        expect(parts.country?.isoCode, country.isoCode, reason: country.name);
        expect(parts.isGuess, isFalse, reason: country.name);
      }
    });
  });
}
