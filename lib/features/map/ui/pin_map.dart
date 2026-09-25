import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme.dart';
import '../data/pin.dart';
import '../providers/map_providers.dart';
import 'circle_bounds.dart';
import 'marker_icons.dart';

typedef PinMapBuilder = Widget Function({
  required LatLng? center,
  required bool centerFromDevice,
  required int radiusMeters,
  required int fitRadiusMeters,
  required List<Pin> pins,
  required ValueChanged<LatLng> onMapTap,
  required double topPadding,
});

bool cameraShouldRefit({
  required LatLng? oldCenter,
  required bool oldFromDevice,
  required int oldFitRadius,
  required LatLng? center,
  required bool fromDevice,
  required int fitRadius,
}) {
  if (center == null) {
    return false;
  }
  if (fitRadius != oldFitRadius) {
    return true;
  }
  return center != oldCenter && !(fromDevice && oldFromDevice);
}

bool markersChanged(List<Pin> old, List<Pin> pins) {
  if (old.length != pins.length) {
    return true;
  }
  final Map<String, Pin> byKey = <String, Pin>{
    for (final Pin pin in old) pin.key: pin,
  };
  for (final Pin pin in pins) {
    final Pin? before = byKey[pin.key];
    if (before == null ||
        before.lat != pin.lat ||
        before.lng != pin.lng ||
        before.isLive != pin.isLive ||
        before.isBusiness != pin.isBusiness) {
      return true;
    }
  }
  return false;
}

BitmapDescriptor markerIconFor(MarkerIcons icons, Pin pin) =>
    switch ((pin.isLive, pin.isBusiness)) {
      (false, false) => icons.fixed,
      (true, false) => icons.live,
      (false, true) => icons.fixedStore,
      (true, true) => icons.liveStore,
    };

class PinMap extends ConsumerStatefulWidget {
  const PinMap({
    super.key,
    required this.center,
    required this.centerFromDevice,
    required this.radiusMeters,
    required this.fitRadiusMeters,
    required this.pins,
    required this.onMapTap,
    required this.topPadding,
  });

  final LatLng? center;
  final bool centerFromDevice;
  final int radiusMeters;
  final int fitRadiusMeters;
  final List<Pin> pins;
  final ValueChanged<LatLng> onMapTap;
  final double topPadding;

  @override
  ConsumerState<PinMap> createState() => _PinMapState();
}

class _PinMapState extends ConsumerState<PinMap> {
  GoogleMapController? _controller;
  Set<Marker> _markers = const <Marker>{};
  List<Pin> _markerPins = const <Pin>[];
  MarkerIcons? _markerIcons;

  Set<Marker> _markersFor(List<Pin> pins, MarkerIcons icons) {
    if (identical(icons, _markerIcons) && !markersChanged(_markerPins, pins)) {
      return _markers;
    }
    _markerIcons = icons;
    _markerPins = pins;
    return _markers = <Marker>{
      for (final Pin pin in pins)
        Marker(
          markerId: MarkerId(pin.key),
          position: LatLng(pin.lat, pin.lng),
          icon: markerIconFor(icons, pin),
          anchor: markerIconAnchor,
          consumeTapEvents: true,
        ),
    };
  }

  CameraUpdate _fitCircle(LatLng center) => CameraUpdate.newLatLngBounds(
    circleBounds(center, widget.fitRadiusMeters.toDouble()),
    AppSpacing.md,
  );

  @override
  void didUpdateWidget(PinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final LatLng? center = widget.center;
    if (center != null &&
        cameraShouldRefit(
          oldCenter: oldWidget.center,
          oldFromDevice: oldWidget.centerFromDevice,
          oldFitRadius: oldWidget.fitRadiusMeters,
          center: center,
          fromDevice: widget.centerFromDevice,
          fitRadius: widget.fitRadiusMeters,
        )) {
      _controller?.animateCamera(_fitCircle(center));
    } else if (center != null &&
        oldWidget.topPadding == 0 &&
        widget.topPadding > 0) {
      _controller?.moveCamera(_fitCircle(center));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final MarkerIconStyle style = (
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      outline: colors.surface,
    );
    final MarkerIcons? icons = ref.watch(markerIconsProvider(style)).value;

    final LatLng? center = widget.center;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center ?? testPointP,
        zoom: 12,
      ),
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
        final LatLng? current = widget.center;
        if (current != null) {
          controller.moveCamera(_fitCircle(current));
        }
      },
      onTap: widget.onMapTap,
      padding: EdgeInsets.only(top: widget.topPadding),
      myLocationEnabled: widget.centerFromDevice,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      circles: <Circle>{
        if (center != null)
          Circle(
            circleId: const CircleId('search-radius'),
            center: center,
            radius: widget.radiusMeters.toDouble(),
            fillColor: colors.primary.withValues(alpha: 0.08),
            strokeColor: colors.primary,
            strokeWidth: 2,
          ),
      },
      markers: icons == null
          ? const <Marker>{}
          : _markersFor(widget.pins, icons),
    );
  }
}
