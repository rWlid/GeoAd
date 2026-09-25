import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/constants.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/features/map/data/location_repository.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'fake_location_platform.dart';

final DateTime now = DateTime.utc(2026, 9, 25, 12);
const LatLng here = LatLng(24.72, 46.68);

LocationRepository repositoryOn(FakeLocationPlatform platform) =>
    LocationRepository(
      platform,
      timeout: const Duration(milliseconds: 20),
      now: () => now,
    );

void main() {
  group('access', () {
    test('granted while in use or always, with services on', () async {
      for (final LocationPermission permission in <LocationPermission>[
        LocationPermission.whileInUse,
        LocationPermission.always,
      ]) {
        final FakeLocationPlatform platform = FakeLocationPlatform(
          permission: permission,
        );
        expect(
          await repositoryOn(platform).access(ask: true),
          LocationAccess.granted,
        );
        expect(platform.dialogs, 0, reason: 'already granted: no dialog');
      }
    });

    test('denied without asking shows no dialog', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(
        permission: LocationPermission.denied,
      );

      expect(
        await repositoryOn(platform).access(ask: false),
        LocationAccess.denied,
      );
      expect(platform.dialogs, 0);
    });

    test('denied and asking returns what the dialog answers', () async {
      final Map<LocationPermission, LocationAccess> answers =
          <LocationPermission, LocationAccess>{
            LocationPermission.whileInUse: LocationAccess.granted,
            LocationPermission.denied: LocationAccess.denied,
            LocationPermission.deniedForever: LocationAccess.deniedForever,
          };
      for (final MapEntry<LocationPermission, LocationAccess> answer
          in answers.entries) {
        final FakeLocationPlatform platform = FakeLocationPlatform(
          permission: LocationPermission.denied,
          dialogAnswer: answer.key,
        );
        expect(await repositoryOn(platform).access(ask: true), answer.value);
        expect(platform.dialogs, 1);
      }
    });

    test('denied forever never shows the dialog', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform(
        permission: LocationPermission.deniedForever,
      );

      expect(
        await repositoryOn(platform).access(ask: true),
        LocationAccess.deniedForever,
      );
      expect(platform.dialogs, 0);
    });

    test('services off once permission is granted', () async {
      expect(
        await repositoryOn(FakeLocationPlatform(servicesOn: false))
            .access(ask: true),
        LocationAccess.servicesOff,
      );
    });

    test('a denial wins over services off', () async {
      expect(
        await repositoryOn(
          FakeLocationPlatform(
            permission: LocationPermission.denied,
            servicesOn: false,
          ),
        ).access(ask: false),
        LocationAccess.denied,
      );
    });

    test('a plugin error maps to locationUnavailable', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform()
        ..errors['check'] = const PermissionDefinitionsNotFoundException(
          'no manifest entry',
        );

      await expectLater(
        repositoryOn(platform).access(ask: true),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.kind,
            'kind',
            AppErrorKind.locationUnavailable,
          ),
        ),
      );
    });
  });

  group('recentPosition', () {
    test('a last known position under 2 minutes old', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform()
        ..lastKnown = (
          position: here,
          time: now.subtract(const Duration(minutes: 1, seconds: 59)),
        );

      expect(await repositoryOn(platform).recentPosition(), here);
      expect(lastKnownPositionMaxAge, const Duration(minutes: 2));
    });

    test('an older one, none, or a failure gives null', () async {
      final FakeLocationPlatform old = FakeLocationPlatform()
        ..lastKnown = (
          position: here,
          time: now.subtract(const Duration(minutes: 2, seconds: 1)),
        );
      final FakeLocationPlatform failing = FakeLocationPlatform()
        ..errors['lastKnown'] = const LocationServiceDisabledException();

      expect(await repositoryOn(old).recentPosition(), isNull);
      expect(await repositoryOn(FakeLocationPlatform()).recentPosition(), null);
      expect(await repositoryOn(failing).recentPosition(), isNull);
    });
  });

  group('currentPosition', () {
    final Matcher throwsUnavailable = throwsA(
      isA<AppException>().having(
        (AppException e) => e.kind,
        'kind',
        AppErrorKind.locationUnavailable,
      ),
    );

    test('returns the fresh fix', () async {
      expect(
        await repositoryOn(FakeLocationPlatform(fix: here)).currentPosition(),
        here,
      );
    });

    test('a fix that never comes times out as locationUnavailable, not as '
        'no connection', () async {
      await expectLater(
        repositoryOn(FakeLocationPlatform(fix: null)).currentPosition(),
        throwsUnavailable,
      );
      expect(locationTimeout, const Duration(seconds: 10));
    });

    test('a plugin error maps to locationUnavailable', () async {
      final FakeLocationPlatform platform = FakeLocationPlatform()
        ..errors['fix'] = const PositionUpdateException('no provider');

      await expectLater(
        repositoryOn(platform).currentPosition(),
        throwsUnavailable,
      );
    });
  });

  test('opens the app and the location settings', () async {
    final FakeLocationPlatform platform = FakeLocationPlatform();

    await repositoryOn(platform).openAppSettings();
    await repositoryOn(platform).openLocationSettings();

    expect(platform.opened, <String>['app', 'location']);
  });
}
