import 'digits.dart';

final RegExp _ignoredChars = RegExp(
  '[ \\-\u00A0\u200E\u200F\u202A-\u202E\u2066-\u2069]',
);

final RegExp _saudiMobile = RegExp(r'^(?:\+?966|00966|0)?(5\d{8})$');

String? normalizeSaudiPhone(String input) {
  final String cleaned = toLatinDigits(input).replaceAll(_ignoredChars, '');
  final RegExpMatch? match = _saudiMobile.firstMatch(cleaned);
  if (match == null) {
    return null;
  }
  return '966${match.group(1)}';
}

final RegExp _storedPhone = RegExp(r'^966(5\d{8})$');

String displaySaudiPhone(String phone12) {
  final RegExpMatch? match = _storedPhone.firstMatch(phone12);
  if (match == null) {
    return phone12;
  }
  return '0${match.group(1)}';
}
