import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/features/map/data/location_platform.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FakeLocationPlatform extends Fake implements LocationPlatform {
  FakeLocationPlatform({
    this.permission = LocationPermission.whileInUse,
    this.dialogAnswer = LocationPermission.whileInUse,
    this.servicesOn = true,
    this.fix = const LatLng(24.7136, 46.6753),
    this.lastKnown,
  });

  LocationPermission permission;
  LocationPermission dialogAnswer;
  bool servicesOn;
  LatLng? fix;
  DeviceFix? lastKnown;
  Completer<void>? dialogGate;
  Completer<void>? fixGate;

  Map<String, Object> errors = <String, Object>{};

  int checks = 0;
  int dialogs = 0;
  int fixes = 0;

  final List<String> opened = <String>[];

  @override
  Future<LocationPermission> checkPermission() async {
    checks++;
    final Object? error = errors['check'];
    if (error != null) {
      throw error;
    }
    return permission == LocationPermission.deniedForever
        ? LocationPermission.denied
        : permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    if (permission == LocationPermission.deniedForever) {
      return permission;
    }
    dialogs++;
    await dialogGate?.future;
    return permission = dialogAnswer;
  }

  @override
  Future<bool> isServiceEnabled() async => servicesOn;

  @override
  Future<DeviceFix?> lastKnownFix() async {
    final Object? error = errors['lastKnown'];
    if (error != null) {
      throw error;
    }
    return lastKnown;
  }

  @override
  Future<DeviceFix> currentFix(Duration timeLimit) async {
    fixes++;
    await fixGate?.future;
    final Object? error = errors['fix'];
    if (error != null) {
      throw error;
    }
    final LatLng? position = fix;
    if (position == null) {
      return Completer<DeviceFix>().future;
    }
    return (position: position, time: DateTime.now());
  }

  @override
  Future<bool> openAppSettings() async {
    opened.add('app');
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    opened.add('location');
    return true;
  }
}
