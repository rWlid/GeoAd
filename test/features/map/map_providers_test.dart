import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/constants.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/features/auth/providers/auth_providers.dart';
import 'package:geo_ad/features/map/data/location_repository.dart';
import 'package:geo_ad/features/map/data/pin.dart';
import 'package:geo_ad/features/map/providers/buyer_location_providers.dart';
import 'package:geo_ad/features/map/providers/map_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'fake_location_platform.dart';
import 'fake_map_repository.dart';
import 'fake_poll_timer.dart';

final Pin near = Pin.fromJson(pinRow());
final Pin far = Pin.fromJson(pinRow(adId: 'ad2', locationId: 'la2'));

const LatLng here = LatLng(24.72, 46.68);
const LatLng there = LatLng(24.75, 46.70);
const LatLng tapA = LatLng(24.70, 46.60);
const LatLng tapB = LatLng(24.69, 46.65);

ProviderContainer signedIn(
  FakeMapRepository repository, {
  FakeLocationPlatform? location,
  FakePollTimers? timers,
}) => ProviderContainer.test(
  overrides: [
    currentUserIdProvider.overrideWithValue(const AsyncData<String?>('a')),
    mapRepositoryProvider.overrideWithValue(repository),
    pollTimerProvider.overrideWithValue((timers ?? FakePollTimers()).call),
    if (location == null) ...[
      mapCenterProvider.overrideWithValue(testPointP),
      locationPlatformProvider.overrideWithValue(FakeLocationPlatform()),
    ] else
      locationRepositoryProvider.overrideWithValue(
        LocationRepository(location, timeout: const Duration(milliseconds: 20)),
      ),
  ],
);

Future<List<Pin>?> settled(ProviderContainer container) async {
  await pumpEventQueue();
  return container.read(nearbyPinsProvider).pins;
}

void main() {
  group('nearbyPinsProvider', () {
    test('always queries with the fixed 2 km radius', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near]);
      final ProviderContainer container = signedIn(repository);
      container.listen(nearbyPinsProvider, (_, _) {});

      expect(await settled(container), <Pin>[near]);
      expect(defaultSearchRadiusMeters, 2000);
      expect(repository.radii, <int>[2000]);
    });
  });

  group('polling (D-17)', () {
    late FakePollTimers timers;

    setUp(() => timers = FakePollTimers());

    ProviderContainer polling(
      FakeMapRepository repository, {
      FakeLocationPlatform? location,
    }) {
      final ProviderContainer container = signedIn(
        repository,
        location: location,
        timers: timers,
      );
      container.listen(nearbyPinsProvider, (_, _) {});
      return container;
    }

    NearbyPins stateOf(ProviderContainer container) =>
        container.read(nearbyPinsProvider);

    test('polls every 12 s, counted from the end of the last query', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near]);
      final ProviderContainer container = polling(repository);

      expect(await settled(container), <Pin>[near]);
      expect(repository.calls, 1);
      expect(timers.pending.single.duration, const Duration(seconds: 12));

      for (int poll = 2; poll <= 4; poll++) {
        timers.fire();
        await settled(container);
        expect(repository.calls, poll);
        expect(timers.pending.single.duration, mapPollInterval);
      }
      expect(repository.centers.toSet(), <LatLng>{testPointP});
      expect(repository.radii.toSet(), <int>{2000});
    });

    test('no timer while a query runs, so polls never overlap', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near]);
      final ProviderContainer container = polling(repository);
      await settled(container);

      repository.gate = Completer<void>();
      timers.fire();
      await pumpEventQueue();
      expect(repository.running, 1);
      expect(timers.pending, isEmpty);

      container.read(mapVisibleProvider.notifier).set(false);
      container.read(mapVisibleProvider.notifier).set(true);
      await pumpEventQueue();
      expect(repository.calls, 2);
      expect(timers.pending, isEmpty);

      repository.gate!.complete();
      await settled(container);
      expect(timers.pending, hasLength(1));
      expect(repository.mostRunning, 1);
    });

    test('pauses off screen, and queries once at once when back', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near]);
      final ProviderContainer container = polling(repository);
      await settled(container);
      expect(timers.pending, hasLength(1));

      container.read(mapVisibleProvider.notifier).set(false);
      expect(timers.pending, isEmpty);
      await settled(container);
      expect(repository.calls, 1);

      repository.pins = <Pin>[near, far];
      container.read(mapVisibleProvider.notifier).set(true);
      await settled(container);
      expect(repository.calls, 2);
      expect(stateOf(container).pins, <Pin>[near, far]);
      expect(timers.pending, hasLength(1));
    });

    test('a query that ends while off screen starts no timer', () async {
      final FakeMapRepository repository = FakeMapRepository()
        ..gate = Completer<void>();
      final ProviderContainer container = polling(repository);
      await pumpEventQueue();

      container.read(mapVisibleProvider.notifier).set(false);
      repository.gate!.complete();
      await settled(container);

      expect(stateOf(container).pins, isEmpty);
      expect(timers.pending, isEmpty);
    });

    test('a tapped centre queries at once, even while a query runs; the '
        'older answer is ignored', () async {
      final Completer<void> slow = Completer<void>();
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[far])
        ..gateByCenter = <LatLng, Completer<void>>{tapA: slow};
      final ProviderContainer container = polling(
        repository,
        location: FakeLocationPlatform(
          permission: LocationPermission.denied,
          dialogAnswer: LocationPermission.denied,
        ),
      );
      await pumpEventQueue();

      container.read(manualCenterProvider.notifier).set(tapA);
      await pumpEventQueue();
      expect(stateOf(container).loading, isTrue);

      repository.pins = <Pin>[near];
      container.read(manualCenterProvider.notifier).set(tapB);
      expect(await settled(container), <Pin>[near]);

      slow.complete();
      await settled(container);
      expect(repository.centers, <LatLng>[tapA, tapB]);
      expect(stateOf(container).pins, <Pin>[near]);
      expect(timers.pending, hasLength(1));
    });

    test('denied and nothing tapped: no query and no timer', () async {
      final FakeMapRepository repository = FakeMapRepository();
      final ProviderContainer container = polling(
        repository,
        location: FakeLocationPlatform(
          permission: LocationPermission.denied,
          dialogAnswer: LocationPermission.denied,
        ),
      );
      await settled(container);
      container.read(mapVisibleProvider.notifier).set(false);
      container.read(mapVisibleProvider.notifier).set(true);
      await settled(container);

      expect(repository.calls, 0);
      expect(timers.started, isEmpty);
      expect(stateOf(container).loading, isFalse);

      container.read(manualCenterProvider.notifier).set(tapA);
      await settled(container);
      expect(repository.centers, <LatLng>[tapA]);
      expect(timers.pending, hasLength(1));
    });

    test('each poll refreshes the position; the move it brings waits for '
        'the next poll', () async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: here);
      final ProviderContainer container = polling(
        repository,
        location: platform,
      );
      await settled(container);
      expect(repository.centers, <LatLng>[here]);

      platform.fix = there;
      timers.fire();
      await settled(container);
      expect(container.read(mapCenterProvider), there);
      expect(platform.fixes, 2);
      expect(repository.centers, <LatLng>[here, here]);

      timers.fire();
      await settled(container);
      expect(repository.centers, <LatLng>[here, here, there]);
    });

    test('a revoked permission on a poll stops polling', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near]);
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: here);
      final ProviderContainer container = polling(
        repository,
        location: platform,
      );
      await settled(container);

      platform.permission = LocationPermission.denied;
      timers.fire();
      await settled(container);

      expect(container.read(mapCenterProvider), isNull);
      expect(stateOf(container).pins, isNull);
      expect(timers.pending, isEmpty);
      expect(repository.calls, 2);
    });

    test('a failed poll keeps the last pins with the error; the next good '
        'poll clears it', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near]);
      final ProviderContainer container = polling(repository);
      await settled(container);

      repository.error = const AppException(AppErrorKind.network);
      timers.fire();
      await settled(container);
      expect(stateOf(container).pins, <Pin>[near]);
      expect(stateOf(container).error?.kind, AppErrorKind.network);
      expect(stateOf(container).loading, isFalse);
      expect(timers.pending, hasLength(1), reason: 'keeps polling');

      repository.error = null;
      timers.fire();
      await settled(container);
      expect(stateOf(container).pins, <Pin>[near]);
      expect(stateOf(container).error, isNull);
    });

    test('a failed first load has no pins; a later poll brings them', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near])
        ..error = const FormatException('bad row');
      final ProviderContainer container = polling(repository);
      await settled(container);
      expect(stateOf(container).pins, isNull);
      expect(stateOf(container).error?.kind, AppErrorKind.unknown);

      repository.error = null;
      timers.fire();
      await pumpEventQueue();
      expect(stateOf(container).loading, isFalse, reason: 'no loading flash');
      expect(await settled(container), <Pin>[near]);
      expect(stateOf(container).error, isNull);
    });

    test('retry shows loading and queries at once', () async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[near])
        ..error = const AppException(AppErrorKind.network);
      final ProviderContainer container = polling(repository);
      await settled(container);

      repository.error = null;
      container.read(nearbyPinsProvider.notifier).retry();
      expect(stateOf(container).loading, isTrue);
      expect(stateOf(container).error, isNull);
      expect(await settled(container), <Pin>[near]);
      expect(timers.pending, hasLength(1));
    });

    test('the same result sets no new state (D-18)', () async {
      final FakeMapRepository repository = FakeMapRepository(
        pins: <Pin>[near, far],
      );
      final ProviderContainer container = polling(repository);
      await settled(container);
      final NearbyPins first = stateOf(container);
      int changes = 0;
      container.listen(nearbyPinsProvider, (_, _) => changes++);

      repository.pins = <Pin>[
        Pin.fromJson(pinRow()),
        Pin.fromJson(pinRow(adId: 'ad2', locationId: 'la2')),
      ];
      timers.fire();
      await settled(container);

      expect(changes, 0);
      expect(identical(stateOf(container), first), isTrue);

      repository.pins = <Pin>[near];
      timers.fire();
      await settled(container);
      expect(changes, 1);
      expect(stateOf(container).pins, <Pin>[near]);
    });

    test('empty and non-empty results follow each poll, with loading only on '
        'the first load (5.3)', () async {
      final FakeMapRepository repository = FakeMapRepository()
        ..gate = Completer<void>();
      final ProviderContainer container = polling(repository);
      final List<NearbyPins> seen = <NearbyPins>[];
      container.listen(
        nearbyPinsProvider,
        (_, NearbyPins next) => seen.add(next),
        fireImmediately: true,
      );
      expect(stateOf(container).loading, isTrue);
      repository.gate!.complete();
      repository.gate = null;
      expect(await settled(container), isEmpty);

      for (final List<Pin> result in <List<Pin>>[
        <Pin>[near],
        <Pin>[],
        <Pin>[far],
      ]) {
        repository.pins = result;
        timers.fire();
        expect(await settled(container), result);
      }
      expect(seen.map((NearbyPins state) => state.loading), <bool>[
        true,
        false,
        false,
        false,
        false,
      ]);
    });
  });

  group('samePins', () {
    test('equal field by field', () {
      expect(samePins(<Pin>[near, far], <Pin>[near, far]), isTrue);
      expect(samePins(<Pin>[near], <Pin>[Pin.fromJson(pinRow())]), isTrue);
    });

    test('a pin, the order or a field differs', () {
      expect(samePins(<Pin>[near], <Pin>[near, far]), isFalse);
      expect(samePins(<Pin>[near, far], <Pin>[far, near]), isFalse);
      expect(
        samePins(<Pin>[near], <Pin>[Pin.fromJson(pinRow(isBusiness: false))]),
        isFalse,
      );
      expect(
        samePins(<Pin>[near], <Pin>[Pin.fromJson(pinRow(isLive: true))]),
        isFalse,
      );
    });
  });

  group('buyer location (D-16)', () {
    ProviderContainer on(
      FakeLocationPlatform platform,
      FakeMapRepository repository,
    ) {
      final ProviderContainer container = signedIn(
        repository,
        location: platform,
      );
      container.listen(nearbyPinsProvider, (_, _) {});
      return container;
    }

    BuyerLocation locationOf(ProviderContainer container) =>
        container.read(buyerLocationProvider);

    test(
      'granted: the centre and the query follow the device position',
      () async {
        final FakeMapRepository repository = FakeMapRepository();
        final ProviderContainer container = on(
          FakeLocationPlatform(fix: here),
          repository,
        );

        expect(locationOf(container), isA<LocatingBuyer>());
        expect(container.read(mapCenterProvider), isNull);
        await pumpEventQueue();

        expect(locationOf(container), const BuyerLocated(here));
        expect(container.read(mapCenterProvider), here);
        await settled(container);
        expect(repository.centers, <LatLng>[here]);

        container.read(manualCenterProvider.notifier).set(tapA);
        expect(container.read(mapCenterProvider), here);
      },
    );

    test('a last known position under 2 minutes old starts the query at '
        'once; the fresh fix replaces it', () async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: here)
        ..lastKnown = (
          position: there,
          time: DateTime.now().subtract(const Duration(seconds: 90)),
        )
        ..fixGate = Completer<void>();
      final ProviderContainer container = on(platform, repository);
      await pumpEventQueue();

      expect(locationOf(container), const BuyerLocated(there));
      await settled(container);
      expect(repository.centers, <LatLng>[there]);

      platform.fixGate!.complete();
      await pumpEventQueue();

      expect(locationOf(container), const BuyerLocated(here));
      await settled(container);
      expect(repository.centers, <LatLng>[there, here]);
    });

    test('an older last known position is not used: the map waits for the '
        'fresh fix', () async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: here)
        ..lastKnown = (
          position: there,
          time: DateTime.now().subtract(const Duration(minutes: 3)),
        )
        ..fixGate = Completer<void>();
      final ProviderContainer container = on(platform, repository);
      await pumpEventQueue();

      expect(locationOf(container), isA<LocatingBuyer>());
      expect(container.read(mapCenterProvider), isNull);
      expect(repository.calls, 0);

      platform.fixGate!.complete();
      await pumpEventQueue();

      expect(locationOf(container), const BuyerLocated(here));
      await settled(container);
      expect(repository.centers, <LatLng>[here]);
    });

    test(
      'denied: no query until a tap; another tap moves the centre',
      () async {
        final FakeMapRepository repository = FakeMapRepository();
        final FakeLocationPlatform platform = FakeLocationPlatform(
          permission: LocationPermission.denied,
          dialogAnswer: LocationPermission.denied,
        );
        final ProviderContainer container = on(platform, repository);
        await pumpEventQueue();

        expect(locationOf(container), const BuyerLocationDenied());
        expect(platform.dialogs, 1);
        expect(container.read(mapCenterProvider), isNull);
        expect(await settled(container), isNull);
        expect(repository.calls, 0);

        container.read(manualCenterProvider.notifier).set(tapA);
        await settled(container);
        container.read(manualCenterProvider.notifier).set(tapB);
        await settled(container);

        expect(container.read(mapCenterProvider), tapB);
        expect(repository.centers, <LatLng>[tapA, tapB]);
      },
    );

    test('askAgain after a denial: once granted, the device position replaces '
        'the tapped point', () async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform platform = FakeLocationPlatform(
        permission: LocationPermission.denied,
        dialogAnswer: LocationPermission.denied,
        fix: here,
      );
      final ProviderContainer container = on(platform, repository);
      await pumpEventQueue();
      container.read(manualCenterProvider.notifier).set(tapA);
      await settled(container);

      platform.dialogAnswer = LocationPermission.whileInUse;
      await container.read(buyerLocationProvider.notifier).askAgain();

      expect(platform.dialogs, 2);
      expect(locationOf(container), const BuyerLocated(here));
      expect(container.read(mapCenterProvider), here);
      await settled(container);
      expect(repository.centers, <LatLng>[tapA, here]);
    });

    test(
      'denied forever: no dialog; recheck after the settings locates',
      () async {
        final FakeLocationPlatform platform = FakeLocationPlatform(
          permission: LocationPermission.deniedForever,
          fix: here,
        );
        final ProviderContainer container = on(platform, FakeMapRepository());
        await pumpEventQueue();

        expect(locationOf(container), const BuyerLocationDenied(forever: true));
        expect(platform.dialogs, 0);

        await container.read(buyerLocationProvider.notifier).openAppSettings();
        platform.permission = LocationPermission.whileInUse;
        await container.read(buyerLocationProvider.notifier).recheck();

        expect(platform.opened, <String>['app']);
        expect(platform.dialogs, 0);
        expect(locationOf(container), const BuyerLocated(here));
      },
    );

    test('denying twice stays "forever" through the resume after the dialog, '
        'whose check can only say denied on Android', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(
        permission: LocationPermission.denied,
        dialogAnswer: LocationPermission.denied,
      );
      final ProviderContainer container = on(platform, FakeMapRepository());
      final BuyerLocationNotifier notifier = container.read(
        buyerLocationProvider.notifier,
      );
      await pumpEventQueue();
      expect(locationOf(container), const BuyerLocationDenied());

      platform.dialogAnswer = LocationPermission.deniedForever;
      await notifier.askAgain();
      expect(locationOf(container), const BuyerLocationDenied(forever: true));

      await notifier.recheck();
      expect(locationOf(container), const BuyerLocationDenied(forever: true));
      expect(platform.fixes, 0);

      platform.permission = LocationPermission.whileInUse;
      await notifier.recheck();
      expect(locationOf(container), isA<BuyerLocated>());
    });

    test('services off: recheck after turning them on locates', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(
        servicesOn: false,
        fix: here,
      );
      final ProviderContainer container = on(platform, FakeMapRepository());
      await pumpEventQueue();

      expect(locationOf(container), isA<BuyerLocationServicesOff>());
      expect(container.read(mapCenterProvider), isNull);

      await container
          .read(buyerLocationProvider.notifier)
          .openLocationSettings();
      platform.servicesOn = true;
      await container.read(buyerLocationProvider.notifier).recheck();

      expect(platform.opened, <String>['location']);
      expect(locationOf(container), const BuyerLocated(here));
    });

    test('a fix that times out fails with locationUnavailable; a tap still '
        'sets the centre, and retry locates', () async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: null);
      final ProviderContainer container = on(platform, repository);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final BuyerLocation failed = locationOf(container);
      expect(failed, isA<BuyerLocationFailed>());
      expect(
        (failed as BuyerLocationFailed).error.kind,
        AppErrorKind.locationUnavailable,
      );
      expect(repository.calls, 0);

      container.read(manualCenterProvider.notifier).set(tapA);
      await settled(container);
      expect(repository.centers, <LatLng>[tapA]);

      platform.fix = here;
      await container.read(buyerLocationProvider.notifier).retry();

      expect(locationOf(container), const BuyerLocated(here));
      await settled(container);
      expect(repository.centers, <LatLng>[tapA, here]);
    });

    test('after a failed fix, a resume with nothing changed asks for no new '
        'position and keeps the error', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: null);
      final ProviderContainer container = on(platform, FakeMapRepository());
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(locationOf(container), isA<BuyerLocationFailed>());
      expect(platform.fixes, 1);

      await container.read(buyerLocationProvider.notifier).recheck();

      expect(platform.checks, 2, reason: 'the access is still checked');
      expect(platform.fixes, 1);
      expect(locationOf(container), isA<BuyerLocationFailed>());

      await container.read(buyerLocationProvider.notifier).recheck();
      expect(platform.fixes, 1);
    });

    test(
      'after a failed fix, a resume where the access changed locates',
      () async {
        final FakeLocationPlatform platform = FakeLocationPlatform(fix: null);
        final ProviderContainer container = on(platform, FakeMapRepository());
        await Future<void>.delayed(const Duration(milliseconds: 60));
        final BuyerLocationNotifier notifier = container.read(
          buyerLocationProvider.notifier,
        );

        platform.servicesOn = false;
        await notifier.recheck();
        expect(locationOf(container), isA<BuyerLocationServicesOff>());

        platform
          ..servicesOn = true
          ..fix = here;
        await notifier.recheck();
        expect(platform.fixes, 2);
        expect(locationOf(container), const BuyerLocated(here));
      },
    );

    test('refresh moves the centre, keeps it when the fix fails, and switches '
        'to denied when permission was revoked', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(fix: here);
      final ProviderContainer container = on(platform, FakeMapRepository());
      final BuyerLocationNotifier notifier = container.read(
        buyerLocationProvider.notifier,
      );
      await pumpEventQueue();
      expect(locationOf(container), const BuyerLocated(here));

      platform.fix = there;
      await notifier.refresh();
      expect(container.read(mapCenterProvider), there);

      platform.errors['fix'] = const PositionUpdateException('lost the fix');
      await notifier.refresh();
      expect(locationOf(container), const BuyerLocated(there));

      platform.permission = LocationPermission.denied;
      await notifier.refresh();
      expect(locationOf(container), const BuyerLocationDenied());
      expect(platform.dialogs, 0, reason: 'refresh never shows the dialog');
    });

    test('refresh does nothing without a position', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(
        permission: LocationPermission.deniedForever,
      );
      final ProviderContainer container = on(platform, FakeMapRepository());
      await pumpEventQueue();
      final int checks = platform.checks;

      await container.read(buyerLocationProvider.notifier).refresh();

      expect(platform.checks, checks);
    });

    test('recheck is skipped while the permission dialog or the fix is in '
        'flight (the dialog pauses and resumes the activity)', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(
        permission: LocationPermission.denied,
        fix: here,
      )..dialogGate = Completer<void>();
      final ProviderContainer container = on(platform, FakeMapRepository());
      final BuyerLocationNotifier notifier = container.read(
        buyerLocationProvider.notifier,
      );
      await pumpEventQueue();
      expect(platform.dialogs, 1);

      await notifier.recheck();
      expect(platform.checks, 1);
      expect(locationOf(container), isA<LocatingBuyer>());

      platform.fixGate = Completer<void>();
      platform.dialogGate!.complete();
      await pumpEventQueue();
      expect(platform.fixes, 1);

      await notifier.recheck();
      expect(platform.checks, 1);
      expect(platform.fixes, 1);

      platform.fixGate!.complete();
      await pumpEventQueue();
      expect(locationOf(container), const BuyerLocated(here));
      expect(platform.dialogs, 1);
    });
  });
}
