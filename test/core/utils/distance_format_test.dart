import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/utils/distance_format.dart';

void main() {
  test('whole kilometres have no decimals', () {
    expect(formatKilometers(1000), '1 كم');
    expect(formatKilometers(2000), '2 كم');
    expect(formatKilometers(5000), '5 كم');
  });

  test('half kilometres have one decimal', () {
    expect(formatKilometers(1500), '1.5 كم');
    expect(formatKilometers(3500), '3.5 كم');
  });
}
