import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/utils/digits.dart';

void main() {
  group('toLatinDigits', () {
    test('converts Arabic-Indic digits', () {
      expect(toLatinDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('converts Persian digits', () {
      expect(toLatinDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('converts mixed Arabic-Indic, Persian and Latin digits', () {
      expect(toLatinDigits('٠5۱1'), '0511');
    });

    test('leaves Latin digits and other characters unchanged', () {
      expect(toLatinDigits('+966 51-abc'), '+966 51-abc');
      expect(toLatinDigits('رقم'), 'رقم');
      expect(toLatinDigits(''), '');
    });
  });
}
