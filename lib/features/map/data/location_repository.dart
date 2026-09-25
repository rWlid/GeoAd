import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import 'location_platform.dart';

enum LocationAccess { granted, denied, deniedForever, servicesOff }

class LocationRepository {
  LocationRepository(
    this._platform, {
    this.timeout = locationTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LocationPlatform _platform;

  final Duration timeout;

  final DateTime Function() _now;

  Future<LocationAccess> access({required bool ask}) async {
    try {
      LocationPermission permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await _platform.requestPermission();
      }
      switch (permission) {
        case LocationPermission.deniedForever:
          return LocationAccess.deniedForever;
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return LocationAccess.denied;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      return await _platform.isServiceEnabled()
          ? LocationAccess.granted
          : LocationAccess.servicesOff;
    } catch (error, stackTrace) {
      throw AppException.location(error, stackTrace);
    }
  }

  Future<LatLng?> recentPosition() async {
    try {
      final DeviceFix? fix = await _platform.lastKnownFix();
      if (fix == null ||
          _now().difference(fix.time) > lastKnownPositionMaxAge) {
        return null;
      }
      return fix.position;
    } catch (error) {
      debugPrint('Last known position failed: $error');
      return null;
    }
  }

  Future<LatLng> currentPosition() async {
    try {
      final DeviceFix fix = await _platform
          .currentFix(timeout)
          .timeout(timeout);
      return fix.position;
    } catch (error, stackTrace) {
      throw AppException.location(error, stackTrace);
    }
  }

  Future<void> openAppSettings() => _platform.openAppSettings();

  Future<void> openLocationSettings() => _platform.openLocationSettings();
}
