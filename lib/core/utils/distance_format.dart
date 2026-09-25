import '../strings_ar.dart';

String formatKilometers(int meters) {
  final double km = meters / 1000;
  final bool whole = km == km.truncateToDouble();
  final String number = km.toStringAsFixed(whole ? 0 : 1);
  return '$number ${AppStrings.kilometers}';
}
