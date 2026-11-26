import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branch_status.dart';
import 'branch_sheet.dart';
import 'filter_sheet.dart';
import 'map_filters.dart';
import 'map_top_bar.dart';
import 'my_position.dart';

// Riyadh, where the camera starts before we know the customer's position.
const riyadh = LatLng(24.7136, 46.6753);

// The ads map: a pin for every branch with an active ad inside the
// distance circle around the customer (mobile branches only while they
// share their location). Reloads every 30 seconds so mobile branches move.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>>? _branches; // null = still loading
  bool _loadFailed = false;
  LatLng? _myPosition; // null = location off or not allowed
  bool _findingMe = true; // true until the first position answer
  int _radiusKm = 2;
  MapFilters _filters = MapFilters();
  List _categories = []; // all categories, loaded once
  final _search = TextEditingController();
  GoogleMapController? _map;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadBranches();
    findMe();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => loadBranches());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Loads every branch with everything the map needs, in one query:
  // hours, store name and logo, and the ads (through ad_locations) with
  // their products (through ad_products), each product's main category
  // and its stock per branch. The category names are loaded once.
  Future<void> loadBranches() async {
    try {
      if (_categories.isEmpty) {
        _categories = await _db
            .from('categories')
            .select()
            .order('id', ascending: true); // same as the add-product screen
      }
      final rows = await _db
          .from('locations')
          .select(
            '*, branch_hours(*), stores(business_name, business_logo), '
            'ads(id, title, description, is_active, '
            'products(id, name, price, is_service, image_path, category_id, categories(parent_id), '
            'product_locations(location_id, quantity)))',
          );
      if (!mounted) return;
      setState(() {
        _branches = rows;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Keep showing the last pins; only an empty first load shows the error.
      setState(() => _loadFailed = true);
    }
  }

  // Shows the spinner again and reloads.
  void retry() {
    setState(() => _loadFailed = false);
    loadBranches();
  }

  // Finds the customer's position and fits the circle on screen.
  Future<void> findMe() async {
    final position = await getMyPosition();
    if (!mounted) return;
    setState(() {
      _findingMe = false;
      if (position != null) {
        _myPosition = LatLng(position.latitude, position.longitude);
      }
    });
    fitCircle();
  }

  // Asks for the location again; if it is still off, opens Settings.
  Future<void> askLocation() async {
    await findMe();
    if (_myPosition == null) await Geolocator.openAppSettings();
  }

  // The map is ready: if we already know where the customer is, go there.
  void onMapCreated(GoogleMapController controller) {
    _map = controller;
    fitCircle();
  }

  // Moves the camera smoothly so the whole circle fits on screen.
  void fitCircle() {
    if (_myPosition == null) return;
    final bounds = boundsAround(_myPosition!, _radiusKm);
    _map?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 16));
  }

  // The customer picked another circle size.
  void setRadius(int km) {
    setState(() => _radiusKm = km);
    fitCircle();
  }

  // Opens the branch's sheet and moves the camera smoothly so the pin sits
  // in the top half of the map, above the sheet.
  Future<void> openBranch(Map<String, dynamic> branch) async {
    showBranchSheet(context, branch, _filters.adsAt(branch), _myPosition);
    final map = _map;
    if (map == null) return;
    final region = await map.getVisibleRegion();
    final latSpan = region.northeast.latitude - region.southwest.latitude;
    final pin = positionOf(branch);
    final target = LatLng(pin.latitude - latSpan / 4, pin.longitude);
    map.animateCamera(CameraUpdate.newLatLng(target));
  }

  // The branches to show: a mobile one is sharing now, it has an ad that
  // passes the filters, and (when we know the customer's position) it is
  // inside the circle.
  List<Map<String, dynamic>> visibleBranches(MapFilters filters) {
    final result = <Map<String, dynamic>>[];
    for (final branch in _branches!) {
      if (branch['type'] != 'fixed' && !isVisibleNow(branch)) continue;
      if (filters.adsAt(branch).isEmpty) continue;
      if (_myPosition != null) {
        final meters = metersBetween(_myPosition!, positionOf(branch));
        if (meters > _radiusKm * 1000) continue;
      }
      result.add(branch);
    }
    return result;
  }

  // Opens the filter sheet; "عرض النتائج" applies what was picked.
  Future<void> openFilters() async {
    final picked = await showModalBottomSheet<MapFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(
        filters: _filters,
        categories: _categories,
        countFor: (filters) => filters.countAds(visibleBranches(filters)),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _filters = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_branches == null && _loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('تعذّر تحميل الإعلانات، تحقق من الاتصال'),
            const SizedBox(height: 16),
            FilledButton(onPressed: retry, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    if (_branches == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final branches = visibleBranches(_filters);
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: riyadh,
              zoom: 11,
            ),
            onMapCreated: onMapCreated,
            // Keeps the circle and the camera clear of the top controls.
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 192,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // we have our own "موقعي"
            markers: {
              for (final branch in branches)
                branchPin(branch, () => openBranch(branch)),
            },
            circles: {
              if (_myPosition != null)
                rangeCircle(_myPosition!, _radiusKm, Theme.of(context)),
            },
          ),
          SafeArea(
            child: MapTopBar(
              radiusKm: _radiusKm,
              hasPosition: _myPosition != null,
              findingMe: _findingMe,
              adCount: _filters.countAds(branches),
              onRadius: setRadius,
              onAskLocation: askLocation,
              filters: _filters,
              categories: _categories,
              search: _search,
              onSearch: (text) => setState(() => _filters.search = text),
              onOpenFilters: openFilters,
              onClearCategory: () => setState(() {
                _filters.mainId = null;
                _filters.subId = null;
              }),
              onClearFilters: () => setState(() {
                _filters = MapFilters();
                _search.clear();
              }),
            ),
          ),
          // Bottom start corner (right in Arabic), away from the Google logo.
          PositionedDirectional(
            start: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: null, // the إعلاناتي tab has its own button
              onPressed: findMe,
              icon: const Icon(Icons.my_location),
              label: const Text('موقعي'),
            ),
          ),
        ],
      ),
    );
  }
}
