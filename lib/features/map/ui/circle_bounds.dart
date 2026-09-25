import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

const double _metersPerDegree = 111320;

LatLngBounds circleBounds(LatLng center, double radiusMeters) {
  final double dLat = radiusMeters / _metersPerDegree;
  final double dLng =
      radiusMeters /
      (_metersPerDegree * math.cos(center.latitude * math.pi / 180));
  return LatLngBounds(
    southwest: LatLng(center.latitude - dLat, center.longitude - dLng),
    northeast: LatLng(center.latitude + dLat, center.longitude + dLng),
  );
}
