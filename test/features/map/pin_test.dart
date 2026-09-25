import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/features/map/data/pin.dart';

import 'fake_map_repository.dart';

void main() {
  group('Pin.fromJson', () {
    test('parses a fixed pin of a business', () {
      final Pin pin = Pin.fromJson(pinRow());

      expect(pin.adId, 'ad1');
      expect(pin.locationId, 'la1');
      expect(pin.key, 'ad1:la1');
      expect(pin.lat, 24.7226);
      expect(pin.lng, 46.6753);
      expect(pin.isLive, isFalse);
      expect(pin.isBusiness, isTrue);
    });

    test('parses a live pin of an individual', () {
      final Pin pin = Pin.fromJson(pinRow(isLive: true, isBusiness: false));

      expect(pin.isLive, isTrue);
      expect(pin.isBusiness, isFalse);
    });

    test('ignores the other nearby_ads columns', () {
      final Map<String, dynamic> row = <String, dynamic>{
        for (final MapEntry<String, dynamic> entry in pinRow().entries)
          if (const <String>{
            'ad_id',
            'location_id',
            'lat',
            'lng',
            'is_live',
            'is_business',
          }.contains(entry.key))
            entry.key: entry.value,
      };

      expect(Pin.fromJson(row).key, Pin.fromJson(pinRow()).key);
      expect(Pin.fromJson(pinRow()..['display_name'] = null).adId, 'ad1');
    });

    group('rejects', () {
      final Map<String, Map<String, dynamic>> bad =
          <String, Map<String, dynamic>>{
            'a missing ad_id': pinRow()..remove('ad_id'),
            'lat as a string': pinRow()..['lat'] = '24.7',
            'is_live as null': pinRow()..['is_live'] = null,
            'a missing is_business': pinRow()..remove('is_business'),
          };
      bad.forEach((String name, Map<String, dynamic> row) {
        test(name, () {
          expect(() => Pin.fromJson(row), throwsFormatException);
        });
      });
    });
  });

  group('Pin.listFromJson', () {
    test('parses every row in order', () {
      final List<Pin> pins = Pin.listFromJson(<Object?>[
        pinRow(adId: 'ad1'),
        pinRow(adId: 'ad8', isBusiness: false),
      ]);

      expect(pins.map((Pin p) => p.adId), <String>['ad1', 'ad8']);
    });

    test('returns no pins for an empty result', () {
      expect(Pin.listFromJson(<Object?>[]), isEmpty);
    });

    test('fails the whole list on one bad row', () {
      expect(
        () => Pin.listFromJson(<Object?>[pinRow(), pinRow()..remove('lng')]),
        throwsFormatException,
      );
    });

    test('rejects a result that is not a list, or a non-object row', () {
      expect(() => Pin.listFromJson(null), throwsFormatException);
      expect(() => Pin.listFromJson(pinRow()), throwsFormatException);
      expect(() => Pin.listFromJson(<Object?>['row']), throwsFormatException);
    });
  });
}
