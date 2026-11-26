import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branch_status.dart';
import 'my_position.dart';

// Riyadh, where the camera starts before we know the customer's position.
const riyadh = LatLng(24.7136, 46.6753);

// The ads map: a pin for every branch that has an active ad (mobile
// branches only while they share their location), plus the customer's
// blue dot. Reloads every 30 seconds so mobile branches move.
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
    super.dispose();
  }

  // Loads every branch with everything the map needs, in one query:
  // hours, store name and logo, and the ads (through ad_locations) with
  // their products (through ad_products) and each product's branch stock.
  Future<void> loadBranches() async {
    try {
      final rows = await _db
          .from('locations')
          .select(
            '*, branch_hours(*), stores(business_name, business_logo), '
            'ads(id, title, description, is_active, '
            'products(id, name, price, image_path, category_id, '
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

  // Finds the customer's position and moves the camera there.
  Future<void> findMe() async {
    final position = await getMyPosition();
    if (!mounted || position == null) return;
    setState(() => _myPosition = LatLng(position.latitude, position.longitude));
    _map?.animateCamera(CameraUpdate.newLatLngZoom(_myPosition!, 14));
  }

  // The map is ready: if we already know where the customer is, go there.
  void onMapCreated(GoogleMapController controller) {
    _map = controller;
    if (_myPosition != null) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(_myPosition!, 14));
    }
  }

  // Moves the camera to the branch, then opens its details.
  void openBranch(Map<String, dynamic> branch, LatLng position) {
    _map?.animateCamera(CameraUpdate.newLatLng(position));
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _BranchSheet(branch: branch),
    );
  }

  // One pin per branch that has an active ad. Fixed and mobile have
  // different colors; a closed fixed branch is faded. Same markerId on
  // every reload, so a moving branch's pin is updated in place.
  Set<Marker> buildMarkers() {
    final markers = <Marker>{};
    for (final branch in _branches!) {
      final isFixed = branch['type'] == 'fixed';
      if (!isFixed && !isVisibleNow(branch)) continue;
      final hasActiveAd = (branch['ads'] as List).any(
        (ad) => ad['is_active'] == true,
      );
      if (!hasActiveAd) continue;
      final position = LatLng(
        (branch['lat'] as num).toDouble(),
        (branch['lng'] as num).toDouble(),
      );
      markers.add(
        Marker(
          markerId: MarkerId('${branch['id']}'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isFixed ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
          ),
          alpha: isFixed && !isOpenNow(branch['branch_hours']) ? 0.5 : 1,
          onTap: () => openBranch(branch, position),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_branches == null && _loadFailed) {
      body = Center(
        key: const ValueKey('error'),
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
    } else if (_branches == null) {
      body = const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    } else {
      body = Stack(
        key: const ValueKey('map'),
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: riyadh,
              zoom: 11,
            ),
            onMapCreated: onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // we have our own "موقعي"
            markers: buildMarkers(),
          ),
          // Bottom start corner (right in Arabic), away from the Google logo.
          PositionedDirectional(
            start: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: findMe,
              icon: const Icon(Icons.my_location),
              label: const Text('موقعي'),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: body,
      ),
    );
  }
}

// The bottom sheet for one branch: name, kind, status, then the hours
// (fixed) or the last update (mobile), then the branch's active ads.
class _BranchSheet extends StatelessWidget {
  const _BranchSheet({required this.branch});

  final Map<String, dynamic> branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFixed = branch['type'] == 'fixed';
    final address = branch['address'] as String?;
    final ads = [
      for (final ad in branch['ads'])
        if (ad['is_active'] == true) ad,
    ];

    // A mobile branch on the map is always visible, so its dot is colored.
    var isActive = true;
    final String status;
    if (isFixed) {
      isActive = isOpenNow(branch['branch_hours']);
      status = isActive ? 'مفتوح الآن' : 'مغلق الآن';
    } else {
      final minutes = DateTime.now()
          .difference(DateTime.parse(branch['shared_at']))
          .inMinutes;
      status = minutes < 1 ? 'آخر تحديث الآن' : 'آخر تحديث قبل $minutes د';
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(branch['name'] ?? '', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(isFixed ? Icons.storefront : Icons.local_shipping, size: 18),
              const SizedBox(width: 4),
              Text(isFixed ? 'فرع ثابت' : 'فرع متنقل'),
              const SizedBox(width: 16),
              StatusLabel(isActive: isActive, text: status),
            ],
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(address),
          ],
          if (isFixed) ...[
            const SizedBox(height: 24),
            Text('أوقات العمل', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var day = 0; day < 7; day++) _hoursLine(context, day),
          ],
          const SizedBox(height: 24),
          Text('الإعلانات', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (ads.isEmpty) const Text('لا توجد إعلانات لهذا الفرع حالياً'),
          for (final ad in ads)
            Card(
              child: ListTile(
                leading: const Icon(Icons.campaign),
                title: Text(ad['title']),
                subtitle: ad['description'] == null
                    ? null
                    : Text(ad['description']),
              ),
            ),
        ],
      ),
    );
  }

  // One day's line: "الأحد      ١٠:٠٠ ص – ١١:٠٠ م" or "مغلق".
  Widget _hoursLine(BuildContext context, int day) {
    final hours = branch['branch_hours'] as List;
    final rows = [
      for (final row in hours)
        if (row['day_of_week'] == day) row,
    ];
    final String text;
    if (rows.isEmpty) {
      text = 'مغلق';
    } else {
      final opens = parseTime(rows.first['opens_at']).format(context);
      final closes = parseTime(rows.first['closes_at']).format(context);
      text = '$opens – $closes';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(dayNames[day])),
          Text(text),
        ],
      ),
    );
  }
}
