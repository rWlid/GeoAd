import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<Map<String, dynamic>>> _ads = _loadAds();

  // The whole "get ads from the database" step. RLS only lets
  // signed-in users read the ads table.
  Future<List<Map<String, dynamic>>> _loadAds() {
    return Supabase.instance.client.from('ads').select();
  }

  Set<Marker> _markers(List<Map<String, dynamic>> ads) {
    return {
      for (final ad in ads)
        Marker(
          markerId: MarkerId(ad['id'].toString()),
          position: LatLng(
            (ad['lat'] as num).toDouble(),
            (ad['lng'] as num).toDouble(),
          ),
          infoWindow: InfoWindow(
            title: ad['title'] as String,
            snippet: ad['description'] as String?,
          ),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ads'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _ads = _loadAds()),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            // main.dart hears the sign out and shows the sign in screen.
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ads,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(24.7136, 46.6753), // Riyadh
              zoom: 11,
            ),
            markers: _markers(snapshot.data!),
          );
        },
      ),
    );
  }
}
