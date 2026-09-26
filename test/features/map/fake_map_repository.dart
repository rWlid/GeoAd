import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/features/map/data/map_repository.dart';
import 'package:geo_ad/features/map/data/pin.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Map<String, dynamic> pinRow({
  String adId = 'ad1',
  String locationId = 'la1',
  bool isLive = false,
  bool isBusiness = true,
}) => <String, dynamic>{
  'ad_id': adId,
  'location_id': locationId,
  'lat': 24.7226,
  'lng': 46.6753,
  'is_live': isLive,
  'distance_m': 1000.2,
  'seller_id': 'user-a',
  'display_name': 'متجر النخبة',
  'is_business': isBusiness,
  'logo_path': 'user-a/seed-missing-logo.png',
  'phone': '966511110001',
};

class FakeMapRepository extends Fake implements MapRepository {
  FakeMapRepository({this.pins = const <Pin>[]});

  List<Pin> pins;
  Completer<void>? gate;
  Map<LatLng, Completer<void>> gateByCenter = <LatLng, Completer<void>>{};
  Object? error;
  final List<int> radii = <int>[];
  final List<LatLng> centers = <LatLng>[];

  int running = 0;
  int mostRunning = 0;

  int get calls => radii.length;

  @override
  Future<List<Pin>> nearbyAds({
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final LatLng center = LatLng(lat, lng);
    radii.add(radiusMeters);
    centers.add(center);
    running++;
    if (running > mostRunning) {
      mostRunning = running;
    }
    try {
      await gate?.future;
      await gateByCenter[center]?.future;
      if (error != null) {
        throw error!;
      }
      return pins;
    } finally {
      running--;
    }
  }
}
