import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/map_repository.dart';
import '../data/pin.dart';
import 'buyer_location_providers.dart';

final Provider<MapRepository> mapRepositoryProvider = Provider<MapRepository>(
  (Ref ref) => MapRepository(Supabase.instance.client),
);

const LatLng testPointP = LatLng(24.7136, 46.6753);

final NotifierProvider<ManualCenterNotifier, LatLng?> manualCenterProvider =
    NotifierProvider<ManualCenterNotifier, LatLng?>(ManualCenterNotifier.new);

class ManualCenterNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void set(LatLng point) => state = point;
}

final Provider<LatLng?> mapCenterProvider = Provider<LatLng?>((Ref ref) {
  final BuyerLocation location = ref.watch(buyerLocationProvider);
  return location is BuyerLocated
      ? location.position
      : ref.watch(manualCenterProvider);
});

typedef PollTimer = Timer Function(Duration duration, void Function() onTick);

final Provider<PollTimer> pollTimerProvider = Provider<PollTimer>(
  (Ref ref) => Timer.new,
);

final NotifierProvider<MapVisibleNotifier, bool> mapVisibleProvider =
    NotifierProvider<MapVisibleNotifier, bool>(MapVisibleNotifier.new);

class MapVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool visible) => state = visible;
}

@immutable
class NearbyPins {
  const NearbyPins({this.pins, this.error, this.loading = false});

  final List<Pin>? pins;
  final AppException? error;
  final bool loading;
}

final NotifierProvider<NearbyPinsNotifier, NearbyPins> nearbyPinsProvider =
    NotifierProvider<NearbyPinsNotifier, NearbyPins>(NearbyPinsNotifier.new);

class NearbyPinsNotifier extends Notifier<NearbyPins> {
  int _generation = 0;
  bool _running = false;
  Timer? _timer;
  bool _centerFromDevice = false;
  bool _refreshing = false;
  bool _pollMovedDevice = false;

  @override
  NearbyPins build() {
    ref.onDispose(_stop);
    final String? userId = ref.watch(
      currentUserIdProvider.select((AsyncValue<String?> id) => id.value),
    );
    if (userId == null) {
      return const NearbyPins();
    }
    ref.listen<LatLng?>(mapCenterProvider, _onCenter);
    ref.listen<BuyerLocation>(buyerLocationProvider, (
      BuyerLocation? previous,
      BuyerLocation next,
    ) {
      if (_refreshing &&
          previous is BuyerLocated &&
          next is BuyerLocated &&
          previous.position != next.position) {
        _pollMovedDevice = true;
      }
    });
    ref.listen<bool>(mapVisibleProvider, (_, bool visible) {
      if (!visible) {
        _cancelTimer();
      } else if (!_running) {
        _poll();
      }
    });
    _centerFromDevice = ref.read(buyerLocationProvider) is BuyerLocated;
    final LatLng? center = ref.read(mapCenterProvider);
    if (center == null) {
      return const NearbyPins();
    }
    unawaited(_fetch(center));
    return const NearbyPins(loading: true);
  }

  void retry() {
    final LatLng? center = ref.read(mapCenterProvider);
    if (center != null) {
      state = const NearbyPins(loading: true);
      unawaited(_fetch(center));
    }
  }

  void _onCenter(LatLng? previous, LatLng? next) {
    final bool wasFromDevice = _centerFromDevice;
    _centerFromDevice = ref.read(buyerLocationProvider) is BuyerLocated;
    if (next == null) {
      _stop();
      state = const NearbyPins();
      return;
    }
    final bool fromPoll = _pollMovedDevice;
    _pollMovedDevice = false;
    if (previous != null && wasFromDevice && _centerFromDevice && fromPoll) {
      return;
    }
    _onBuyerChange();
  }

  void _onBuyerChange() {
    final LatLng? center = ref.read(mapCenterProvider);
    if (center == null) {
      return;
    }
    if (state.pins == null) {
      state = const NearbyPins(loading: true);
    }
    unawaited(_fetch(center));
  }

  void _poll() {
    _timer = null;
    final LatLng? center = ref.read(mapCenterProvider);
    if (_running || center == null || !ref.read(mapVisibleProvider)) {
      return;
    }
    _refreshing = true;
    unawaited(
      ref
          .read(buyerLocationProvider.notifier)
          .refresh()
          .whenComplete(() => _refreshing = false),
    );
    unawaited(_fetch(center));
  }

  Future<void> _fetch(LatLng center) async {
    _cancelTimer();
    final int generation = ++_generation;
    _running = true;
    final List<Pin> pins;
    try {
      pins = await ref
          .read(mapRepositoryProvider)
          .nearbyAds(
            lat: center.latitude,
            lng: center.longitude,
            radiusMeters: defaultSearchRadiusMeters,
          );
    } catch (error, stackTrace) {
      final NearbyPins? current = _currentFor(generation);
      if (current != null) {
        state = NearbyPins(
          pins: current.pins,
          error: AppException.from(error, stackTrace),
        );
        _finish();
      }
      return;
    }
    final NearbyPins? current = _currentFor(generation);
    if (current == null) {
      return;
    }
    final List<Pin>? last = current.pins;
    if (last == null ||
        !samePins(last, pins) ||
        current.error != null ||
        current.loading) {
      state = NearbyPins(pins: pins);
    }
    _finish();
  }

  NearbyPins? _currentFor(int generation) {
    if (!ref.mounted) {
      return null;
    }
    // read state before comparing generations, it can start a query
    final NearbyPins current = state;
    return generation == _generation ? current : null;
  }

  void _finish() {
    _running = false;
    final bool visible = ref.read(mapVisibleProvider);
    final LatLng? center = ref.read(mapCenterProvider);
    if (visible && center != null && !_running) {
      _cancelTimer();
      _timer = ref.read(pollTimerProvider)(mapPollInterval, _poll);
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _stop() {
    _cancelTimer();
    _generation++;
    _running = false;
    _pollMovedDevice = false;
  }
}

@visibleForTesting
bool samePins(List<Pin> a, List<Pin> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (!_samePin(a[i], b[i])) {
      return false;
    }
  }
  return true;
}

bool _samePin(Pin a, Pin b) =>
    a.adId == b.adId &&
    a.locationId == b.locationId &&
    a.lat == b.lat &&
    a.lng == b.lng &&
    a.isLive == b.isLive &&
    a.isBusiness == b.isBusiness;
