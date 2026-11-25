import 'package:geolocator/geolocator.dart';

// Returns the phone's current position, or null when location is off,
// not allowed, or takes too long. Asks for permission the first time.
Future<Position?> getMyPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    return null;
  }
}
