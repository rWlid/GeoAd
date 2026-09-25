import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/utils/phone.dart';

void main() {
  group('normalizeSaudiPhone accepts', () {
    const Map<String, String> accepted = <String, String>{
      '0511110001': 'local 05 form',
      '511110001': 'without the leading 0',
      '966511110001': 'bare 966 (pasted from WhatsApp)',
      '+966511110001': '+966',
      '00966511110001': '00966',
      '٠٥١١١١٠٠٠١': 'Arabic-Indic digits',
      '۰۵۱۱۱۱۰۰۰۱': 'Persian digits',
      '+٩٦٦٥١١١١٠٠٠١': '+966 in Arabic-Indic digits',
      '051 111 0001': 'spaces',
      '051-111-0001': 'dashes',
      '+966 51 111 0001': '+966 with spaces',
      '051\u00A01110001': 'NBSP',
      ' 0511110001 ': 'leading and trailing spaces',
    };

    accepted.forEach((String input, String form) {
      test(form, () {
        expect(normalizeSaudiPhone(input), '966511110001');
      });
    });

    test('a pasted number wrapped in LRM and LRE…PDF', () {
      expect(
        normalizeSaudiPhone('\u200E\u202A+966 51 111 0001\u202C\u200E'),
        '966511110001',
      );
    });

    test('every invisible direction mark', () {
      const String marks =
          '\u200E\u200F\u202A\u202B\u202C\u202D\u202E'
          '\u2066\u2067\u2068\u2069';
      expect(normalizeSaudiPhone('${marks}0511110001$marks'), '966511110001');
    });

    test('seed user B', () {
      expect(normalizeSaudiPhone('0511110002'), '966511110002');
    });
  });

  group('normalizeSaudiPhone rejects', () {
    const Map<String, String> rejected = <String, String>{
      '': 'empty',
      '   ': 'only spaces',
      '0112345678': 'a landline',
      '051111000': '9 digits after 0',
      '05111100011': '11 digits',
      '51111000': '8 digits',
      '9665111100011': 'bare 966 with one digit too many',
      '+965511110001': 'another country code',
      '+9660511110001': '+966 followed by 0',
      '9660511110001': '966 followed by 0',
      '0966511110001': '0966',
      '+0511110001': '+ before 05',
      '++966511110001': 'double +',
      '966+511110001': '+ in the middle',
      '0511110a01': 'a letter inside',
      'abcdefghij': 'letters only',
      '(051) 111 0001': 'parentheses',
      '051.111.0001': 'dots',
      '051_111_0001': 'underscores',
      '051\t1110001': 'a tab',
      '051—111—0001': 'an em dash',
      '0511110001#': 'a trailing symbol',
      '4511110001': 'does not start with 05',
      '0411110001': '04 prefix',
    };

    rejected.forEach((String input, String form) {
      test(form, () {
        expect(normalizeSaudiPhone(input), isNull);
      });
    });
  });

  group('displaySaudiPhone (D-03)', () {
    test('shows a stored phone as 05XXXXXXXX', () {
      expect(displaySaudiPhone('966511110001'), '0511110001');
      expect(displaySaudiPhone('966599990099'), '0599990099');
    });

    test('round-trips with normalizeSaudiPhone', () {
      expect(
        displaySaudiPhone(normalizeSaudiPhone('+٩٦٦ ٥١ ١١١ ٠٠٠٢')!),
        '0511110002',
      );
    });

    test('returns anything not in the stored form unchanged', () {
      for (final String input in <String>[
        '',
        '0511110001',
        '96651111000',
        '966411110001',
      ]) {
        expect(displaySaudiPhone(input), input, reason: input);
      }
    });
  });
}
