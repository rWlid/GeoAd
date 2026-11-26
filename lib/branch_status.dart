import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Day names in database order: day_of_week 0 = Sunday … 6 = Saturday.
const dayNames = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

// Turns a database time like "16:00:00" into a TimeOfDay.
TimeOfDay parseTime(String text) {
  return TimeOfDay(
    hour: int.parse(text.substring(0, 2)),
    minute: int.parse(text.substring(3, 5)),
  );
}

// True when a branch with these branch_hours rows is open right now.
bool isOpenNow(List hours) {
  final now = DateTime.now();
  final today = now.weekday % 7; // Dart: Monday = 1 … Sunday = 7 → Sunday = 0
  final yesterday = (today + 6) % 7;
  final nowMinutes = now.hour * 60 + now.minute;

  for (final row in hours) {
    final opens = _minutes(row['opens_at']);
    final closes = _minutes(row['closes_at']);
    final closesAfterMidnight = closes <= opens; // e.g. 16:00 → 01:00
    final day = row['day_of_week'];

    if (day == today &&
        nowMinutes >= opens &&
        (closesAfterMidnight || nowMinutes < closes)) {
      return true;
    }
    // After midnight, yesterday's late shift may still be running.
    if (day == yesterday && closesAfterMidnight && nowMinutes < closes) {
      return true;
    }
  }
  return false;
}

// Minutes since midnight for a database time: "16:30:00" → 990.
int _minutes(String text) {
  final time = parseTime(text);
  return time.hour * 60 + time.minute;
}

// True when a mobile branch is sharing and sent its position in the last
// 10 minutes. Older than that (e.g. the app was closed) = hidden.
bool isVisibleNow(Map branch) {
  if (branch['is_sharing'] != true || branch['shared_at'] == null) return false;
  final sharedAt = DateTime.parse(branch['shared_at']);
  return DateTime.now().difference(sharedAt) < const Duration(minutes: 10);
}

// A small colored dot with a status text, e.g. "● مفتوح الآن".
class StatusLabel extends StatelessWidget {
  const StatusLabel({super.key, required this.isActive, required this.text});

  final bool isActive; // colored dot when true, grey when false
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 8,
          color: isActive ? colors.primary : colors.outline,
        ),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}

// Turns 0-9 into Arabic digits: "12" → "١٢".
String arabicDigits(String text) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  var result = '';
  for (final char in text.split('')) {
    final index = int.tryParse(char);
    result += index == null ? char : digits[index];
  }
  return result;
}

// A branch's place on the map.
LatLng positionOf(Map branch) => LatLng(
  (branch['lat'] as num).toDouble(),
  (branch['lng'] as num).toDouble(),
);

// The distance between two places on the map, in meters.
double metersBetween(LatLng a, LatLng b) {
  return Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
}

// A box around a circle of [km] around [center], for fitting the camera.
LatLngBounds boundsAround(LatLng center, int km) {
  final latDelta = km / 111; // 1° of latitude ≈ 111 km
  final lngDelta = km / (111 * cos(center.latitude * pi / 180));
  return LatLngBounds(
    southwest: LatLng(center.latitude - latDelta, center.longitude - lngDelta),
    northeast: LatLng(center.latitude + latDelta, center.longitude + lngDelta),
  );
}

// A branch's pin. Fixed and mobile have different colors; a closed fixed
// branch is faded. The markerId is the branch id, so on every reload a
// moving branch's pin is updated in place.
Marker branchPin(Map branch, VoidCallback onTap) {
  final isFixed = branch['type'] == 'fixed';
  return Marker(
    markerId: MarkerId('${branch['id']}'),
    position: positionOf(branch),
    icon: BitmapDescriptor.defaultMarkerWithHue(
      isFixed ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
    ),
    alpha: isFixed && !isOpenNow(branch['branch_hours']) ? 0.5 : 1,
    onTap: onTap,
  );
}

// The light circle of [km] around the customer, in the theme's main color.
Circle rangeCircle(LatLng center, int km, ThemeData theme) {
  final color = theme.colorScheme.primary;
  return Circle(
    circleId: const CircleId('range'),
    center: center,
    radius: km * 1000.0,
    fillColor: color.withValues(alpha: 0.08),
    strokeColor: color.withValues(alpha: 0.6),
    strokeWidth: 1,
  );
}

// The ad count with the right Arabic word: "إعلان واحد"، "إعلانان"،
// "٤ إعلانات" (3 to 10), "١٢ إعلان" (11 and up).
String adsCountText(int count) {
  if (count == 1) return 'إعلان واحد';
  if (count == 2) return 'إعلانان';
  if (count <= 10) return '${arabicDigits('$count')} إعلانات';
  return '${arabicDigits('$count')} إعلان';
}

// True when this branch has the product now, the same rule as the
// add-product screen: a product needs a quantity above zero here; a
// service with no branch rows is at every branch, otherwise only at the
// branches it lists.
bool inStockAt(Map product, int branchId) {
  final rows = product['product_locations'] as List;
  if (product['is_service'] == true && rows.isEmpty) return true;
  for (final row in rows) {
    if (row['location_id'] == branchId) {
      return product['is_service'] == true || (row['quantity'] ?? 0) > 0;
    }
  }
  return false;
}
