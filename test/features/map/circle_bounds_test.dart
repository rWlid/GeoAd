import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/features/map/providers/map_providers.dart';
import 'package:geo_ad/features/map/ui/circle_bounds.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

double _distance(LatLng a, LatLng b) {
  const double earthRadius = 6371008.8;
  double rad(double degrees) => degrees * math.pi / 180;
  final double dLat = rad(b.latitude - a.latitude);
  final double dLng = rad(b.longitude - a.longitude);
  final double h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

void main() {
  test('the box edges are 5 km from P, within 0.5%', () {
    final LatLngBounds bounds = circleBounds(testPointP, 5000);
    final LatLng north = LatLng(
      bounds.northeast.latitude,
      testPointP.longitude,
    );
    final LatLng south = LatLng(
      bounds.southwest.latitude,
      testPointP.longitude,
    );
    final LatLng east = LatLng(testPointP.latitude, bounds.northeast.longitude);
    final LatLng west = LatLng(testPointP.latitude, bounds.southwest.longitude);

    for (final LatLng edge in <LatLng>[north, south, east, west]) {
      expect(_distance(testPointP, edge), closeTo(5000, 25));
    }
  });

  test('the box is centred on the circle', () {
    final LatLngBounds bounds = circleBounds(testPointP, 5000);

    expect(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      closeTo(testPointP.latitude, 1e-9),
    );
    expect(
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      closeTo(testPointP.longitude, 1e-9),
    );
  });
}
