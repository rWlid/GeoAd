import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme.dart';

const Size markerIconSize = Size(36, 48);

const Offset markerIconAnchor = Offset(0.5, 1);

typedef MarkerIcons = ({
  BitmapDescriptor fixed,
  BitmapDescriptor live,
  BitmapDescriptor fixedStore,
  BitmapDescriptor liveStore,
});

const IconData markerStoreGlyph = Icons.storefront;

const double markerStoreGlyphSize = 20;

typedef MarkerIconStyle = ({double pixelRatio, Color outline});

final FutureProviderFamily<MarkerIcons, MarkerIconStyle> markerIconsProvider =
    FutureProvider.family<MarkerIcons, MarkerIconStyle>((
      Ref ref,
      MarkerIconStyle style,
    ) async {
      Future<BitmapDescriptor> icon(Color fill, {bool store = false}) async =>
          BitmapDescriptor.bytes(
            await drawPinPng(
              fill: fill,
              outline: style.outline,
              pixelRatio: style.pixelRatio,
              store: store,
            ),
            imagePixelRatio: style.pixelRatio,
          );
      return (
        fixed: await icon(AppMarkerColors.fixed),
        live: await icon(AppMarkerColors.live),
        fixedStore: await icon(AppMarkerColors.fixed, store: true),
        liveStore: await icon(AppMarkerColors.live, store: true),
      );
    });

Future<Uint8List> drawPinPng({
  required Color fill,
  required Color outline,
  required double pixelRatio,
  bool store = false,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)..scale(pixelRatio);

  const double stroke = 2;
  final double width = markerIconSize.width;
  final double height = markerIconSize.height;
  final double radius = width / 2 - stroke;
  final Offset centre = Offset(width / 2, radius + stroke);

  const double tangentAngle = 50 * math.pi / 180;
  final Path tail = Path()
    ..moveTo(
      centre.dx - radius * math.sin(tangentAngle),
      centre.dy + radius * math.cos(tangentAngle),
    )
    ..lineTo(width / 2, height - stroke)
    ..lineTo(
      centre.dx + radius * math.sin(tangentAngle),
      centre.dy + radius * math.cos(tangentAngle),
    )
    ..close();
  final Path pin = Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
    tail,
  );

  canvas
    ..drawPath(pin, Paint()..color = fill)
    ..drawPath(
      pin,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  if (store) {
    _drawGlyph(canvas, markerStoreGlyph, centre, outline);
  } else {
    canvas.drawCircle(centre, radius * 0.38, Paint()..color = outline);
  }

  final ui.Image image = await recorder.endRecording().toImage(
    (width * pixelRatio).round(),
    (height * pixelRatio).round(),
  );
  try {
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void _drawGlyph(Canvas canvas, IconData icon, Offset centre, Color color) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: markerStoreGlyphSize,
        height: 1,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}
