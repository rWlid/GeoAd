import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/distance_format.dart';
import '../../../core/widgets/offline_banner.dart';
import '../data/pin.dart';
import '../providers/buyer_location_providers.dart';
import '../providers/map_providers.dart';
import 'location_card.dart';
import 'pin_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.mapBuilder = PinMap.new});

  final PinMapBuilder mapBuilder;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final AppLifecycleListener _lifecycle;

  bool _foreground = true;

  bool _tabShown = true;

  @override
  void initState() {
    super.initState();
    final AppLifecycleState? appState = WidgetsBinding.instance.lifecycleState;
    _foreground =
        appState == null ||
        appState == AppLifecycleState.resumed ||
        appState == AppLifecycleState.inactive;
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(buyerLocationProvider.notifier).recheck(),
      onShow: () => _setForeground(true),
      onHide: () => _setForeground(false),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabShown = TickerMode.valuesOf(context).enabled;
    scheduleMicrotask(_syncPolling);
  }

  void _setForeground(bool foreground) {
    _foreground = foreground;
    _syncPolling();
  }

  void _syncPolling() {
    if (mounted) {
      ref.read(mapVisibleProvider.notifier).set(_foreground && _tabShown);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onMapTap(LatLng point) {
    if (ref.read(buyerLocationProvider) is! BuyerLocated) {
      ref.read(manualCenterProvider.notifier).set(point);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NearbyPins result = ref.watch(nearbyPinsProvider);
    final List<Pin> pins = result.pins ?? const <Pin>[];
    final LatLng? center = ref.watch(mapCenterProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: widget.mapBuilder(
              center: center,
              centerFromDevice:
                  ref.watch(buyerLocationProvider) is BuyerLocated,
              pins: pins,
              onMapTap: _onMapTap,
              topPadding: MediaQuery.paddingOf(context).top,
            ),
          ),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md,
                  top: AppSpacing.sm,
                  end: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    const LocationCard(),
                    if (center != null) ..._status(result),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        tooltip: AppStrings.searchRadius,
        onPressed: () {},
        icon: const Icon(Icons.radar),
        label: Text(formatKilometers(defaultSearchRadiusMeters)),
      ),
    );
  }

  List<Widget> _status(NearbyPins result) {
    final List<Pin>? pins = result.pins;
    if (pins == null) {
      return <Widget>[
        if (result.loading)
          const _LoadingCard()
        else if (result.error case final AppException error)
          _ErrorCard(
            message: error.message,
            onRetry: ref.read(nearbyPinsProvider.notifier).retry,
          ),
      ];
    }
    return <Widget>[
      if (result.error case final AppException error)
        OfflineBanner(message: error.message),
      if (pins.isEmpty) const _EmptyCard(),
    ];
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox.square(
              dimension: AppSpacing.lg,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                AppStrings.mapLoading,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                AppStrings.mapEmpty,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.mapErrorTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
