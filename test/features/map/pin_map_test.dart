import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/features/map/data/pin.dart';
import 'package:geo_ad/features/map/ui/marker_icons.dart';
import 'package:geo_ad/features/map/ui/pin_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'fake_map_repository.dart';

const LatLng a = LatLng(24.72, 46.68);
const LatLng b = LatLng(24.75, 46.70);

bool refit(
  LatLng? oldCenter,
  bool oldFromDevice,
  LatLng? center,
  bool fromDevice,
) => cameraShouldRefit(
  oldCenter: oldCenter,
  oldFromDevice: oldFromDevice,
  center: center,
  fromDevice: fromDevice,
);

void main() {
  group('cameraShouldRefit (D-16)', () {
    test('the first centre, from the device or a tap', () {
      expect(refit(null, false, a, true), isTrue);
      expect(refit(null, false, a, false), isTrue);
    });

    test('a newer device position does not move the camera', () {
      expect(refit(a, true, b, true), isFalse);
    });

    test('a new tapped centre does', () {
      expect(refit(a, false, b, false), isTrue);
    });

    test('the device position replacing a tapped point does, once', () {
      expect(refit(a, false, b, true), isTrue);
      expect(refit(b, true, a, true), isFalse);
    });

    test('a tapped point replacing the device position does', () {
      expect(refit(a, true, b, false), isTrue);
    });

    test('nothing changed, or no centre: no refit', () {
      expect(refit(a, false, a, false), isFalse);
      expect(refit(a, true, a, true), isFalse);
      expect(refit(a, true, null, false), isFalse);
      expect(refit(null, false, null, false), isFalse);
    });
  });

  group('markersChanged (D-18)', () {
    Pin pin({
      String adId = 'ad1',
      String locationId = 'la1',
      bool isLive = false,
      bool isBusiness = true,
      double lat = 24.7226,
    }) {
      final Map<String, dynamic> row = pinRow(
        adId: adId,
        locationId: locationId,
        isLive: isLive,
        isBusiness: isBusiness,
      )..['lat'] = lat;
      return Pin.fromJson(row);
    }

    final Pin one = pin();
    final Pin two = pin(adId: 'ad2', locationId: 'la2');

    test('the same pins, in any order, keep the markers', () {
      expect(markersChanged(<Pin>[one, two], <Pin>[one, two]), isFalse);
      expect(markersChanged(<Pin>[one, two], <Pin>[two, one]), isFalse);
      expect(markersChanged(<Pin>[one], <Pin>[pin()]), isFalse);
      expect(markersChanged(const <Pin>[], const <Pin>[]), isFalse);
    });

    test('a pin added, removed, replaced or moved rebuilds them', () {
      expect(markersChanged(<Pin>[one], <Pin>[one, two]), isTrue);
      expect(markersChanged(<Pin>[one, two], <Pin>[one]), isTrue);
      expect(markersChanged(<Pin>[one], <Pin>[two]), isTrue);
      expect(markersChanged(<Pin>[one], <Pin>[pin(lat: 24.73)]), isTrue);
    });

    test('a pin switching live/fixed or business/individual rebuilds them', () {
      expect(markersChanged(<Pin>[one], <Pin>[pin(isLive: true)]), isTrue);
      expect(markersChanged(<Pin>[one], <Pin>[pin(isBusiness: false)]), isTrue);
    });
  });

  group('markerIconFor (D-19, D-43)', () {
    final MarkerIcons icons = (
      fixed: BitmapDescriptor.defaultMarkerWithHue(0),
      live: BitmapDescriptor.defaultMarkerWithHue(90),
      fixedStore: BitmapDescriptor.defaultMarkerWithHue(180),
      liveStore: BitmapDescriptor.defaultMarkerWithHue(270),
    );

    Pin pin({required bool isLive, required bool isBusiness}) => Pin.fromJson(
      pinRow(
        adId: 'ad1',
        locationId: 'la1',
        isLive: isLive,
        isBusiness: isBusiness,
      ),
    );

    test('an individual gets the plain icon, fixed or live', () {
      expect(
        markerIconFor(icons, pin(isLive: false, isBusiness: false)),
        same(icons.fixed),
      );
      expect(
        markerIconFor(icons, pin(isLive: true, isBusiness: false)),
        same(icons.live),
      );
    });

    test('a business gets the store icon, fixed or live', () {
      expect(
        markerIconFor(icons, pin(isLive: false, isBusiness: true)),
        same(icons.fixedStore),
      );
      expect(
        markerIconFor(icons, pin(isLive: true, isBusiness: true)),
        same(icons.liveStore),
      );
    });
  });
}
