import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/features/map/data/map_repository.dart';

import '../../core/never_supabase_client.dart';

void main() {
  testWidgets('nearbyAds gives up after requestTimeout with a network error', (
    WidgetTester tester,
  ) async {
    final NeverSupabaseClient client = NeverSupabaseClient();

    await expectNetworkErrorAtTimeout(
      tester,
      () =>
          MapRepository(client)
              .nearbyAds(lat: 24.7136, lng: 46.6753, radiusMeters: 2000),
    );
    expect(client.requests, <String>['rpc:nearby_ads']);
  });

  testWidgets('nearbyAds always sends the chosen radius as p_radius_m (D-32)', (
    WidgetTester tester,
  ) async {
    final NeverSupabaseClient client = NeverSupabaseClient();

    await expectNetworkErrorAtTimeout(
      tester,
      () =>
          MapRepository(client)
              .nearbyAds(lat: 24.7136, lng: 46.6753, radiusMeters: 3500),
    );
    expect(client.rpcParams, <Map<String, dynamic>>[
      <String, dynamic>{'p_lat': 24.7136, 'p_lng': 46.6753, 'p_radius_m': 3500},
    ]);
  });
}
