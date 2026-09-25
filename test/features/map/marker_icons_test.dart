import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/theme.dart';
import 'package:geo_ad/features/map/ui/marker_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<({int width, int height, Color color})> _probe(
  Uint8List png,
  Offset point,
  double pixelRatio,
) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData rgba = (await image.toByteData())!;
  final int x = (point.dx * pixelRatio).round();
  final int y = (point.dy * pixelRatio).round();
  final int offset = (y * image.width + x) * 4;
  final Color color = Color.fromARGB(
    rgba.getUint8(offset + 3),
    rgba.getUint8(offset),
    rgba.getUint8(offset + 1),
    rgba.getUint8(offset + 2),
  );
  final int width = image.width;
  final int height = image.height;
  image.dispose();
  return (width: width, height: height, color: color);
}

Future<({int width, Uint8List rgba})> _pixels(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData rgba = (await image.toByteData())!;
  final int width = image.width;
  image.dispose();
  return (width: width, rgba: rgba.buffer.asUint8List());
}

int _differingPixels(
  ({int width, Uint8List rgba}) a,
  ({int width, Uint8List rgba}) b,
  Rect area,
  double pixelRatio,
) {
  int count = 0;
  final int top = (area.top * pixelRatio).round();
  final int bottom = (area.bottom * pixelRatio).round();
  final int left = (area.left * pixelRatio).round();
  final int right = (area.right * pixelRatio).round();
  for (int y = top; y < bottom; y++) {
    for (int x = left; x < right; x++) {
      final int offset = (y * a.width + x) * 4;
      for (int channel = 0; channel < 4; channel++) {
        if (a.rgba[offset + channel] != b.rgba[offset + channel]) {
          count++;
          break;
        }
      }
    }
  }
  return count;
}

void main() {
  const Offset body = Offset(18, 6);

  for (final (String name, Color fill, bool store) in <(String, Color, bool)>[
    ('fixed', AppMarkerColors.fixed, false),
    ('live', AppMarkerColors.live, false),
    ('fixed store', AppMarkerColors.fixed, true),
    ('live store', AppMarkerColors.live, true),
  ]) {
    testWidgets('the $name pin is filled with its AppMarkerColors colour', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Uint8List png = await drawPinPng(
          fill: fill,
          outline: const Color(0xFFFFFFFF),
          pixelRatio: 2,
          store: store,
        );
        final ({int width, int height, Color color}) probe = await _probe(
          png,
          body,
          2,
        );

        expect(probe.width, markerIconSize.width * 2);
        expect(probe.height, markerIconSize.height * 2);
        expect(probe.color, fill);
      });
    });
  }

  for (final bool store in <bool>[false, true]) {
    testWidgets('the corners are transparent (store: $store)', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Uint8List png = await drawPinPng(
          fill: AppMarkerColors.fixed,
          outline: const Color(0xFFFFFFFF),
          pixelRatio: 1,
          store: store,
        );
        final ({int width, int height, Color color}) probe = await _probe(
          png,
          Offset.zero,
          1,
        );

        expect(probe.color.a, 0);
      });
    });
  }

  testWidgets('a store pin differs from the plain one in the head only', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      const double pixelRatio = 2;
      Future<({int width, Uint8List rgba})> draw({required bool store}) async =>
          _pixels(
            await drawPinPng(
              fill: AppMarkerColors.live,
              outline: const Color(0xFFFFFFFF),
              pixelRatio: pixelRatio,
              store: store,
            ),
          );
      final ({int width, Uint8List rgba}) plain = await draw(store: false);
      final ({int width, Uint8List rgba}) store = await draw(store: true);

      final double width = markerIconSize.width;
      final Rect head = Rect.fromLTWH(0, 0, width, width);
      final Rect tail = Rect.fromLTRB(0, width, width, markerIconSize.height);
      expect(_differingPixels(plain, store, head, pixelRatio), greaterThan(0));
      expect(_differingPixels(plain, store, tail, pixelRatio), 0);

      final Rect glyphArea = Rect.fromCenter(
        center: Offset(width / 2, width / 2),
        width: markerStoreGlyphSize,
        height: markerStoreGlyphSize,
      );
      final ({int width, Uint8List rgba}) bare = (
        width: store.width,
        rgba: Uint8List.fromList(<int>[
          for (int i = 0; i < store.rgba.length; i += 4) ...<int>[
            (AppMarkerColors.live.r * 255).round(),
            (AppMarkerColors.live.g * 255).round(),
            (AppMarkerColors.live.b * 255).round(),
            255,
          ],
        ]),
      );
      expect(
        _differingPixels(bare, store, glyphArea, pixelRatio),
        greaterThan(0),
      );
    });
  });

  testWidgets('markerIconsProvider draws four icons, the store ones distinct', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final MarkerIcons icons = await container.read(
        markerIconsProvider((pixelRatio: 2, outline: const Color(0xFFFFFFFF)))
            .future,
      );

      final List<Uint8List> bytes = <Uint8List>[
        for (final BitmapDescriptor icon in <BitmapDescriptor>[
          icons.fixed,
          icons.live,
          icons.fixedStore,
          icons.liveStore,
        ])
          (icon as BytesMapBitmap).byteData,
      ];
      for (int i = 0; i < bytes.length; i++) {
        for (int j = i + 1; j < bytes.length; j++) {
          expect(bytes[i], isNot(equals(bytes[j])), reason: 'icons $i and $j');
        }
      }
    });
  });
}
