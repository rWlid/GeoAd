import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

typedef DeviceFix = ({LatLng position, DateTime time});

class LocationPlatform {
  const LocationPlatform();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<DeviceFix?> lastKnownFix() async {
    final Position? position = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: true,
    );
    return position == null ? null : _fix(position);
  }

  Future<DeviceFix> currentFix(Duration timeLimit) async => _fix(
    await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: true,
        timeLimit: timeLimit,
      ),
    ),
  );

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static DeviceFix _fix(Position position) => (
    position: LatLng(position.latitude, position.longitude),
    time: position.timestamp,
  );
}
