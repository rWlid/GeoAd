import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/constants.dart';
import 'package:geo_ad/core/errors.dart';
import 'package:geo_ad/core/strings_ar.dart';
import 'package:geo_ad/core/theme.dart';
import 'package:geo_ad/core/widgets/offline_banner.dart';
import 'package:geo_ad/features/auth/providers/auth_providers.dart';
import 'package:geo_ad/features/map/data/pin.dart';
import 'package:geo_ad/features/map/providers/buyer_location_providers.dart';
import 'package:geo_ad/features/map/providers/map_providers.dart';
import 'package:geo_ad/features/map/ui/map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_location_platform.dart';
import 'fake_map_repository.dart';

final Pin ad1 = Pin.fromJson(pinRow());

final Pin ad7 = Pin.fromJson(
  pinRow(adId: 'ad7', locationId: 'lb2', isBusiness: false),
);

final Pin live = Pin.fromJson(
  pinRow(adId: 'ad9', locationId: 'live1', isLive: true),
);

Finder pinMarker(Pin pin) => find.byKey(ValueKey<String>('pin:${pin.key}'));
final Finder mapSurface = find.byKey(const ValueKey<String>('map-surface'));
final Finder retry = find.widgetWithText(FilledButton, AppStrings.retry);
final Finder radiusButton = find.byTooltip(AppStrings.searchRadius);

LatLng? shownCenter;
bool? shownFromDevice;
List<Pin> shownPins = const <Pin>[];

List<double> shownTopPaddings = <double>[];

LatLng nextTap = const LatLng(24.70, 46.60);

final ValueNotifier<bool> tabShown = ValueNotifier<bool>(true);

Widget fakeMap({
  required LatLng? center,
  required bool centerFromDevice,
  required List<Pin> pins,
  required ValueChanged<LatLng> onMapTap,
  required double topPadding,
}) {
  shownTopPaddings.add(topPadding);
  shownCenter = center;
  shownFromDevice = centerFromDevice;
  shownPins = pins;
  return GestureDetector(
    key: const ValueKey<String>('map-surface'),
    behavior: HitTestBehavior.opaque,
    onTap: () => onMapTap(nextTap),
    child: Align(
      alignment: AlignmentDirectional.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final Pin pin in pins)
            Text(pin.key, key: ValueKey<String>('pin:${pin.key}')),
        ],
      ),
    ),
  );
}

void main() {
  setUp(() {
    shownCenter = null;
    shownFromDevice = null;
    nextTap = const LatLng(24.70, 46.60);
    shownPins = const <Pin>[];
    shownTopPaddings = <double>[];
    tabShown.value = true;
  });

  Future<void> pumpMap(
    WidgetTester tester,
    FakeMapRepository repository, {
    FakeLocationPlatform? location,
    bool inShell = false,
  }) {
    final Widget map = ValueListenableBuilder<bool>(
      valueListenable: tabShown,
      builder: (_, bool shown, Widget? child) =>
          TickerMode(enabled: shown, child: child!),
      child: const MapScreen(mapBuilder: fakeMap),
    );
    return tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(userId: 'user-b', name: 'سعد'),
          ),
          mapRepositoryProvider.overrideWithValue(repository),
          locationPlatformProvider.overrideWithValue(
            location ?? FakeLocationPlatform(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: inShell
              ? Scaffold(
                  body: map,
                  bottomNavigationBar: const SizedBox(height: 80),
                )
              : map,
        ),
      ),
    );
  }

  group('states', () {
    testWidgets('shows loading over the map until the pins arrive', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1])
        ..gate = Completer<void>();
      await pumpMap(tester, repository);
      await tester.pump();

      expect(find.text(AppStrings.mapLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(mapSurface, findsOneWidget);
      expect(shownCenter, testPointP);
      expect(shownPins, isEmpty);

      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.mapLoading), findsNothing);
      expect(pinMarker(ad1), findsOneWidget);
      expect(repository.calls, 1);
    });

    testWidgets('shows the error with retry, and retry loads the pins', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1])
        ..error = const AppException(AppErrorKind.network);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.mapErrorTitle), findsOneWidget);
      expect(find.text(AppStrings.errorNoConnection), findsOneWidget);
      expect(pinMarker(ad1), findsNothing);

      repository
        ..error = null
        ..gate = Completer<void>();
      await tester.tap(retry);
      await tester.pump();

      expect(find.text(AppStrings.mapLoading), findsOneWidget);
      expect(find.text(AppStrings.mapErrorTitle), findsNothing);

      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.mapErrorTitle), findsNothing);
      expect(pinMarker(ad1), findsOneWidget);
      expect(repository.calls, 2);
    });

    testWidgets('maps an unexpected error to the generic message (D-26)', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository()
        ..error = const FormatException('nearby_ads.lat is not a number');
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.mapErrorTitle), findsOneWidget);
      expect(find.text(AppStrings.errorUnknown), findsOneWidget);
      expect(find.textContaining('nearby_ads'), findsNothing);
    });

    testWidgets('shows the empty state when there are no pins (5.3)', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, FakeMapRepository());
      await tester.pumpAndSettle();

      expect(find.text('لا توجد إعلانات قريبة حاليًا'), findsOneWidget);
      expect(mapSurface, findsOneWidget);
    });

    testWidgets('passes every pin to the map and shows no status card', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, FakeMapRepository(pins: <Pin>[ad1, ad7, live]));
      await tester.pumpAndSettle();

      expect(shownPins, <Pin>[ad1, ad7, live]);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('pads the map under the status bar', (
      WidgetTester tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      await pumpMap(tester, FakeMapRepository(pins: <Pin>[ad1]));
      await tester.pumpAndSettle();

      expect(shownTopPaddings.last, 24);
    });
  });

  group('radius (D-32)', () {
    testWidgets('fixed at 2 km: the button shows it, the query uses it, and '
        'tapping it opens nothing', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: radiusButton, matching: find.text('2 كم')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
      expect(repository.radii, <int>[2000]);

      await tester.tap(radiusButton);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(
        find.descendant(of: radiusButton, matching: find.text('2 كم')),
        findsOneWidget,
      );
      expect(repository.radii, <int>[2000]);
    });
  });

  group('polling (D-17, D-18)', () {
    Future<void> nextPoll(WidgetTester tester) async {
      await tester.pump(mapPollInterval);
      await tester.pump();
    }

    final Finder banner = find.byType(OfflineBanner);

    testWidgets('polls every 12 s while the map shows', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);

      await tester.pump(const Duration(seconds: 11));
      expect(repository.calls, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(repository.calls, 2);
      await nextPoll(tester);
      expect(repository.calls, 3);
    });

    testWidgets('pauses on another tab; back on the tab, queries at once', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      tabShown.value = false;
      await tester.pump();
      await tester.pump(const Duration(minutes: 1));
      expect(repository.calls, 1);

      tabShown.value = true;
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 2);
      await nextPoll(tester);
      expect(repository.calls, 3);
    });

    testWidgets('pauses while a page is pushed over the map; the pop queries '
        'at once', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      unawaited(
        Navigator.of(tester.element(mapSurface)).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('صفحة')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(repository.calls, 1);

      Navigator.of(tester.element(find.text('صفحة'))).pop();
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 2);
      await tester.pumpAndSettle();
      await nextPoll(tester);
      expect(repository.calls, 3);
    });

    testWidgets('the pop while a query runs starts no second one', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      unawaited(
        Navigator.of(tester.element(mapSurface)).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('صفحة')),
          ),
        ),
      );
      repository.gate = Completer<void>();
      await tester.pump(mapPollInterval);
      expect(repository.running, 1);
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('صفحة'))).pop();
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(repository.mostRunning, 1);

      repository.gate!.complete();
      await tester.pumpAndSettle();
      await nextPoll(tester);
      expect(repository.calls, 3);
      expect(repository.mostRunning, 1);
    });

    testWidgets('pauses while the app is hidden; on return, queries at once', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 1));
      expect(repository.calls, 1);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(repository.calls, 2);
    });

    testWidgets('keeps polling while only inactive (e.g. the notification '
        'shade)', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await nextPoll(tester);
      expect(repository.calls, 2);
    });

    testWidgets('a failed poll keeps the pins and shows the offline banner at '
        'the top, clear of the radius button; the next good poll hides it', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository, inShell: true);
      await tester.pumpAndSettle();

      repository.error = const AppException(AppErrorKind.network);
      await nextPoll(tester);

      expect(pinMarker(ad1), findsOneWidget);
      expect(banner, findsOneWidget);
      expect(
        find.descendant(
          of: banner,
          matching: find.text(AppStrings.errorNoConnection),
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.mapErrorTitle), findsNothing);
      expect(retry, findsNothing);
      final Rect bannerRect = tester.getRect(banner);
      expect(bannerRect.bottom, lessThan(tester.getRect(radiusButton).top));
      expect(bannerRect.bottom, lessThan(tester.getRect(mapSurface).center.dy));

      repository.error = null;
      await nextPoll(tester);
      expect(banner, findsNothing);
      expect(pinMarker(ad1), findsOneWidget);
    });

    testWidgets('an unexpected poll failure shows its own message in the '
        'banner (D-26)', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      repository.error = const FormatException('nearby_ads.lat');
      await nextPoll(tester);

      expect(
        find.descendant(
          of: banner,
          matching: find.text(AppStrings.errorUnknown),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('nearby_ads'), findsNothing);
    });

    testWidgets('a failed first load keeps the error card; a later poll '
        'replaces it with the pins', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1])
        ..error = const AppException(AppErrorKind.network);
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.mapErrorTitle), findsOneWidget);
      expect(banner, findsNothing);

      repository.error = null;
      await nextPoll(tester);
      expect(find.text(AppStrings.mapErrorTitle), findsNothing);
      expect(find.text(AppStrings.mapLoading), findsNothing);
      expect(pinMarker(ad1), findsOneWidget);
    });

    testWidgets('the empty state follows each poll, never flashing to '
        'loading (5.3)', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository();
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();
      final Finder empty = find.text(AppStrings.mapEmpty);
      final Finder loading = find.text(AppStrings.mapLoading);
      expect(empty, findsOneWidget);

      Future<void> pollWith(List<Pin> pins) async {
        repository
          ..pins = pins
          ..gate = Completer<void>();
        await tester.pump(mapPollInterval);
        expect(repository.running, 1);
        expect(loading, findsNothing);
        repository.gate!.complete();
        await tester.pump();
        await tester.pump();
        expect(loading, findsNothing);
      }

      await pollWith(<Pin>[ad1]);
      expect(empty, findsNothing);
      expect(pinMarker(ad1), findsOneWidget);

      await pollWith(<Pin>[]);
      expect(empty, findsOneWidget);
      expect(pinMarker(ad1), findsNothing);

      await pollWith(<Pin>[]);
      expect(empty, findsOneWidget);
    });

    testWidgets('an unchanged poll passes the same pins, so the markers stay '
        '(D-18)', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(
        pins: <Pin>[ad1, live],
      );
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();
      final List<Pin> before = shownPins;

      repository.pins = <Pin>[Pin.fromJson(pinRow()), live];
      await nextPoll(tester);

      expect(repository.calls, 2);
      expect(identical(shownPins, before), isTrue);
    });
  });

  group('location (D-16)', () {
    const LatLng device = LatLng(24.7136, 46.6753);
    final Finder allow = find.widgetWithText(
      FilledButton,
      AppStrings.locationAllow,
    );

    final Finder manualCard = find.text(AppStrings.locationManualCenter);

    Future<void> tapMapAt(WidgetTester tester, LatLng point) async {
      nextTap = point;
      await tester.tapAt(tester.getTopLeft(mapSurface) + const Offset(8, 200));
      await tester.pumpAndSettle();
    }

    testWidgets('locating: a card, no circle and no query until the position '
        'comes; then the circle and the query follow it', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      final FakeLocationPlatform location = FakeLocationPlatform()
        ..fixGate = Completer<void>();
      await pumpMap(tester, repository, location: location);
      await tester.pump();

      expect(find.text(AppStrings.locationLocating), findsOneWidget);
      expect(find.text(AppStrings.mapLoading), findsNothing);
      expect(shownCenter, isNull);
      expect(repository.calls, 0);

      location.fixGate!.complete();
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.locationLocating), findsNothing);
      expect(shownCenter, device);
      expect(shownFromDevice, isTrue);
      expect(repository.centers, <LatLng>[device]);
      expect(pinMarker(ad1), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('granted: a tap on the map never moves the centre', (
      WidgetTester tester,
    ) async {
      final FakeMapRepository repository = FakeMapRepository();
      await pumpMap(tester, repository);
      await tester.pumpAndSettle();

      await tapMapAt(tester, const LatLng(24.60, 46.50));

      expect(shownCenter, device);
      expect(repository.calls, 1);
    });

    testWidgets('denied: the hint and the allow button, no query; a tap sets '
        'the centre and queries there', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository(pins: <Pin>[ad1]);
      final FakeLocationPlatform location = FakeLocationPlatform(
        permission: LocationPermission.denied,
        dialogAnswer: LocationPermission.denied,
      );
      await pumpMap(tester, repository, location: location);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.locationDeniedTitle), findsOneWidget);
      expect(find.text(AppStrings.locationTapHint), findsOneWidget);
      expect(allow, findsOneWidget);
      expect(find.text(AppStrings.mapEmpty), findsNothing);
      expect(shownCenter, isNull);
      expect(repository.calls, 0);
      expect(
        Directionality.of(
          tester.element(find.text(AppStrings.locationDeniedTitle)),
        ),
        TextDirection.rtl,
      );

      const LatLng tapped = LatLng(24.70, 46.60);
      await tapMapAt(tester, tapped);

      expect(shownCenter, tapped);
      expect(shownFromDevice, isFalse);
      expect(repository.centers, <LatLng>[tapped]);
      expect(pinMarker(ad1), findsOneWidget);
      expect(find.text(AppStrings.locationDeniedTitle), findsNothing);
      expect(manualCard, findsOneWidget);
      expect(
        find.widgetWithText(TextButton, AppStrings.locationAllow),
        findsOneWidget,
      );

      const LatLng moved = LatLng(24.69, 46.65);
      await tapMapAt(tester, moved);
      expect(shownCenter, moved);
      expect(repository.centers, <LatLng>[tapped, moved]);
    });

    testWidgets('allowing after a denial: the device position replaces the '
        'tapped point', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform location = FakeLocationPlatform(
        permission: LocationPermission.denied,
        dialogAnswer: LocationPermission.denied,
      );
      await pumpMap(tester, repository, location: location);
      await tester.pumpAndSettle();
      await tapMapAt(tester, const LatLng(24.70, 46.60));

      location.dialogAnswer = LocationPermission.whileInUse;
      await tester.tap(find.text(AppStrings.locationAllow));
      await tester.pumpAndSettle();

      expect(location.dialogs, 2);
      expect(shownCenter, device);
      expect(shownFromDevice, isTrue);
      expect(repository.centers.last, device);
      expect(manualCard, findsNothing);
    });

    testWidgets('denied forever: the settings button opens the app settings, '
        'and a tap still sets the centre', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform location = FakeLocationPlatform(
        permission: LocationPermission.deniedForever,
      );
      await pumpMap(tester, repository, location: location);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.locationDeniedForeverTitle), findsOneWidget);
      expect(find.text(AppStrings.locationDeniedForeverBody), findsOneWidget);
      expect(location.dialogs, 0);

      await tester.tap(find.text(AppStrings.locationOpenSettings));
      await tester.pumpAndSettle();
      expect(location.opened, <String>['app']);

      await tapMapAt(tester, const LatLng(24.70, 46.60));
      expect(repository.centers, <LatLng>[const LatLng(24.70, 46.60)]);
      expect(manualCard, findsOneWidget);
    });

    testWidgets('a second denial shows the settings card, and it stays after '
        'the resume that follows the dialog', (WidgetTester tester) async {
      final FakeLocationPlatform location = FakeLocationPlatform(
        permission: LocationPermission.denied,
        dialogAnswer: LocationPermission.denied,
      );
      await pumpMap(tester, FakeMapRepository(), location: location);
      await tester.pumpAndSettle();

      location.dialogAnswer = LocationPermission.deniedForever;
      await tester.tap(find.text(AppStrings.locationAllow));
      await tester.pumpAndSettle();
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.locationDeniedForeverTitle), findsOneWidget);
      expect(find.text(AppStrings.locationOpenSettings), findsOneWidget);
      expect(find.text(AppStrings.locationAllow), findsNothing);
    });

    testWidgets('services off: the button opens the location settings', (
      WidgetTester tester,
    ) async {
      final FakeLocationPlatform location = FakeLocationPlatform(
        servicesOn: false,
      );
      await pumpMap(tester, FakeMapRepository(), location: location);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.locationServicesOffTitle), findsOneWidget);
      expect(find.text(AppStrings.locationServicesOffBody), findsOneWidget);

      await tester.tap(find.text(AppStrings.locationTurnOn));
      await tester.pumpAndSettle();
      expect(location.opened, <String>['location']);
    });

    testWidgets('back from the settings, the resume rechecks and the map '
        'locates', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform location = FakeLocationPlatform(
        permission: LocationPermission.deniedForever,
      );
      await pumpMap(tester, repository, location: location);
      await tester.pumpAndSettle();

      location.permission = LocationPermission.whileInUse;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.locationDeniedForeverTitle), findsNothing);
      expect(shownCenter, device);
      expect(repository.centers, <LatLng>[device]);
    });

    testWidgets('after a failed fix, a resume with nothing changed keeps the '
        'error card and asks for no new position', (WidgetTester tester) async {
      final FakeLocationPlatform location = FakeLocationPlatform(fix: null);
      await pumpMap(tester, FakeMapRepository(), location: location);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text(AppStrings.errorLocationUnavailable), findsOneWidget);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(location.fixes, 1);
      expect(find.text(AppStrings.errorLocationUnavailable), findsOneWidget);
      expect(find.text(AppStrings.locationLocating), findsNothing);
    });

    testWidgets('the lifecycle listener goes with the screen', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester, FakeMapRepository());
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a position that never comes: after 10 s the error with retry, '
        'and a tap still works', (WidgetTester tester) async {
      final FakeMapRepository repository = FakeMapRepository();
      final FakeLocationPlatform location = FakeLocationPlatform(fix: null);
      await pumpMap(tester, repository, location: location);
      await tester.pump();

      await tester.pump(const Duration(seconds: 9));
      expect(find.text(AppStrings.locationLocating), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text(AppStrings.locationLocating), findsNothing);
      expect(find.text(AppStrings.errorLocationUnavailable), findsOneWidget);
      expect(find.text(AppStrings.errorNoConnection), findsNothing);
      expect(retry, findsOneWidget);
      expect(repository.calls, 0);

      location.fix = device;
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errorLocationUnavailable), findsNothing);
      expect(shownCenter, device);
      expect(repository.centers, <LatLng>[device]);
    });
  });
}
