import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/errors.dart';
import '../data/location_platform.dart';
import '../data/location_repository.dart';

final Provider<LocationPlatform> locationPlatformProvider =
    Provider<LocationPlatform>((Ref ref) => const LocationPlatform());

final Provider<LocationRepository> locationRepositoryProvider =
    Provider<LocationRepository>(
      (Ref ref) => LocationRepository(ref.watch(locationPlatformProvider)),
    );

sealed class BuyerLocation {
  const BuyerLocation();
}

final class LocatingBuyer extends BuyerLocation {
  const LocatingBuyer();
}

final class BuyerLocated extends BuyerLocation {
  const BuyerLocated(this.position);

  final LatLng position;

  @override
  bool operator ==(Object other) =>
      other is BuyerLocated && other.position == position;

  @override
  int get hashCode => position.hashCode;
}

final class BuyerLocationDenied extends BuyerLocation {
  const BuyerLocationDenied({this.forever = false});

  final bool forever;

  @override
  bool operator ==(Object other) =>
      other is BuyerLocationDenied && other.forever == forever;

  @override
  int get hashCode => forever.hashCode;
}

final class BuyerLocationServicesOff extends BuyerLocation {
  const BuyerLocationServicesOff();
}

final class BuyerLocationFailed extends BuyerLocation {
  const BuyerLocationFailed(this.error);

  final AppException error;
}

final NotifierProvider<BuyerLocationNotifier, BuyerLocation>
buyerLocationProvider = NotifierProvider<BuyerLocationNotifier, BuyerLocation>(
  BuyerLocationNotifier.new,
);

class BuyerLocationNotifier extends Notifier<BuyerLocation> {
  // calls must not overlap, the resume handler would race them
  bool _busy = false;

  LocationAccess? _lastAccess;

  @override
  BuyerLocation build() {
    unawaited(_locate(ask: true));
    return const LocatingBuyer();
  }

  Future<void> refresh() async {
    if (state is BuyerLocated) {
      await _locate(ask: false);
    }
  }

  Future<void> recheck() async {
    if (state is! BuyerLocated) {
      await _locate(ask: false, onlyIfChanged: true);
    }
  }

  Future<void> retry() => _locate(ask: false);

  Future<void> askAgain() => _locate(ask: true);

  Future<void> openAppSettings() =>
      ref.read(locationRepositoryProvider).openAppSettings();

  Future<void> openLocationSettings() =>
      ref.read(locationRepositoryProvider).openLocationSettings();

  Future<void> _locate({required bool ask, bool onlyIfChanged = false}) async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final LocationRepository repository = ref.read(
        locationRepositoryProvider,
      );
      LocationAccess access = await repository.access(ask: ask);
      if (!ref.mounted) {
        return;
      }
      if (!ask &&
          access == LocationAccess.denied &&
          _lastAccess == LocationAccess.deniedForever) {
        access = LocationAccess.deniedForever;
      }
      final bool changed = access != _lastAccess;
      _lastAccess = access;
      if (onlyIfChanged && !changed) {
        return;
      }
      switch (access) {
        case LocationAccess.denied:
          state = const BuyerLocationDenied();
          return;
        case LocationAccess.deniedForever:
          state = const BuyerLocationDenied(forever: true);
          return;
        case LocationAccess.servicesOff:
          state = const BuyerLocationServicesOff();
          return;
        case LocationAccess.granted:
          break;
      }
      if (state is! BuyerLocated) {
        state = const LocatingBuyer();
        final LatLng? recent = await repository.recentPosition();
        if (!ref.mounted) {
          return;
        }
        if (recent != null) {
          state = BuyerLocated(recent);
        }
      }
      final LatLng position = await repository.currentPosition();
      if (ref.mounted) {
        state = BuyerLocated(position);
      }
    } on AppException catch (error) {
      if (ref.mounted && state is! BuyerLocated) {
        state = BuyerLocationFailed(error);
      }
    } finally {
      _busy = false;
    }
  }
}
