import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'branch_status.dart';
import 'map_filters.dart';

// The mobile pin's color. The theme has no second color that stands out
// next to its teal on a map, so we choose one here, once.
const mobilePinColor = Color(0xFFE65100);

// The pins drawn so far, by key like 'fixed-3' or 'mobile-10' (10 = "٩+").
final _pins = <String, BitmapDescriptor>{};

// The keys being drawn right now, so the same pin is never drawn twice.
final _drawing = <String>{};

// The cache key: the type and the count (everything above 9 looks the same).
String _key(bool isFixed, int count) {
  return '${isFixed ? 'fixed' : 'mobile'}-${min(count, 10)}';
}

// The drawn pin for this branch (its type and its number of matching
// offers), or null when it is not drawn yet.
BitmapDescriptor? readyPin(Map branch, MapFilters filters) {
  final isFixed = branch['type'] == 'fixed';
  return _pins[_key(isFixed, filters.adsAt(branch).length)];
}

// Draws the pins these branches need that are not drawn yet.
// Returns true when it drew at least one, so the map should rebuild.
Future<bool> preparePins(
  List<Map<String, dynamic>> branches,
  MapFilters filters,
  ColorScheme colors,
) async {
  var drewAny = false;
  for (final branch in branches) {
    final isFixed = branch['type'] == 'fixed';
    final count = filters.adsAt(branch).length;
    final key = _key(isFixed, count);
    if (_pins.containsKey(key) || _drawing.contains(key)) continue;
    _drawing.add(key);
    _pins[key] = await pinIcon(isFixed: isFixed, count: count, colors: colors);
    _drawing.remove(key);
    drewAny = true;
  }
  return drewAny;
}

// Draws one pin with code: a round pin with a white border and a soft
// shadow, the branch type's icon in the middle, and a badge with the
// number of offers on the top-left corner (the "end" corner in Arabic).
Future<BitmapDescriptor> pinIcon({
  required bool isFixed,
  required int count,
  required ColorScheme colors,
}) async {
  // 1. Draw at the screen's pixel ratio so the pin is sharp. We then work
  //    in normal (logical) sizes: the picture is 56 × 56.
  final ratio = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  const size = 56.0;
  const center = Offset(28, 28);

  // 2. A soft shadow a little under the pin.
  final shadow = Paint()
    ..color = Colors.black26
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  canvas.drawCircle(center + const Offset(0, 1.5), 20, shadow);

  // 3. The white border, then the colored circle on top of it.
  canvas.drawCircle(center, 20, Paint()..color = Colors.white);
  final color = isFixed ? colors.primary : mobilePinColor;
  canvas.drawCircle(center, 18, Paint()..color = color);

  // 4. The icon. An icon is a letter of the icon font, so we write it.
  final icon = isFixed ? Icons.storefront : Icons.local_shipping;
  final iconStyle = TextStyle(
    fontFamily: icon.fontFamily,
    package: icon.fontPackage,
    fontSize: 22,
    color: Colors.white,
  );
  drawText(canvas, String.fromCharCode(icon.codePoint), center, iconStyle);

  // 5. The badge: white digits on the theme's error color, with a white ring.
  const badge = Offset(12, 12);
  canvas.drawCircle(badge, 11, Paint()..color = Colors.white);
  canvas.drawCircle(badge, 9.5, Paint()..color = colors.error);
  final number = count > 9 ? '٩+' : arabicDigits('$count');
  const numberStyle = TextStyle(
    fontFamily: 'IBMPlexSansArabic',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1,
    color: Colors.white,
  );
  drawText(canvas, number, badge, numberStyle);

  // 6. Turn the drawing into a PNG and give it to Google Maps.
  final pixels = (size * ratio).round();
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    png!.buffer.asUint8List(),
    imagePixelRatio: ratio,
  );
}

// Writes [text] on the canvas, centered on [center].
void drawText(Canvas canvas, String text, Offset center, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr, // keeps "٩+" in this order
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}
