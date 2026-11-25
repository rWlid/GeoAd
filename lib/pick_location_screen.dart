import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'my_position.dart';

// Full-screen map with a pin in the middle: the owner moves the map under
// the pin (or taps a spot) and confirms. Returns the chosen LatLng.
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key, this.start});

  final LatLng? start; // the branch's current place when editing

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  LatLng? _center; // null = still looking for the phone's position
  bool _noLocation = false; // true = we could not get the phone's position
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    findStart();
  }

  // Opens the map at the branch's place, or else at the phone's position.
  Future<void> findStart() async {
    if (widget.start != null) {
      setState(() => _center = widget.start);
      return;
    }
    final position = await getMyPosition();
    if (!mounted) return;
    setState(() {
      _noLocation = position == null;
      _center = position == null
          ? const LatLng(24.7136, 46.6753) // Riyadh
          : LatLng(position.latitude, position.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('مكان الفرع'), centerTitle: true),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _center == null
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center!,
                      zoom: 16,
                    ),
                    myLocationEnabled: !_noLocation,
                    myLocationButtonEnabled: !_noLocation,
                    onMapCreated: (controller) => _map = controller,
                    // No setState: the pin is fixed, we only remember the spot.
                    onCameraMove: (camera) => _center = camera.target,
                    onTap: (spot) =>
                        _map?.animateCamera(CameraUpdate.newLatLng(spot)),
                  ),
                  // The pin's tip sits exactly on the map's center.
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Icon(
                          Icons.location_on,
                          size: 48,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (_noLocation)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_off),
                          title: const Text(
                            'لم نصل إلى موقعك. حرّك الخريطة لاختيار المكان، أو فعّل الموقع من الإعدادات',
                          ),
                          trailing: TextButton(
                            onPressed: Geolocator.openAppSettings,
                            child: const Text('الإعدادات'),
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('تأكيد المكان'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: () => Navigator.pop(context, _center),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
