import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors.dart';
import 'pin.dart';

class MapRepository {
  MapRepository(this._client);

  final SupabaseClient _client;

  Future<List<Pin>> nearbyAds({
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Object? rows;
    try {
      rows = await _client
          .rpc<Object?>(
            'nearby_ads',
            params: <String, dynamic>{
              'p_lat': lat,
              'p_lng': lng,
              'p_radius_m': radiusMeters,
            },
          )
          .timeout(requestTimeout);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }

    final List<Pin> pins;
    try {
      pins = Pin.listFromJson(rows);
    } catch (error, stackTrace) {
      throw AppException.from(error, stackTrace);
    }
    debugPrint(
      'nearby_ads: ${pins.length} pins in ${stopwatch.elapsedMilliseconds} ms',
    );
    return pins;
  }
}
