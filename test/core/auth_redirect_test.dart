import 'package:flutter_test/flutter_test.dart';
import 'package:geo_ad/core/router.dart';
import 'package:geo_ad/features/auth/providers/auth_providers.dart';

void main() {
  const List<String> tabs = <String>[Routes.map, Routes.myAds, Routes.account];
  const List<String> login = <String>[Routes.login, Routes.loginCode];

  const Map<AuthGate, Map<String, String>> expected =
      <AuthGate, Map<String, String>>{
        AuthGate.loading: <String, String>{
          Routes.name: Routes.start,
          Routes.map: Routes.start,
          Routes.myAds: Routes.start,
          Routes.account: Routes.start,
        },
        AuthGate.error: <String, String>{
          Routes.login: Routes.start,
          Routes.loginCode: Routes.start,
          Routes.name: Routes.start,
          Routes.map: Routes.start,
          Routes.myAds: Routes.start,
          Routes.account: Routes.start,
        },
        AuthGate.signedOut: <String, String>{
          Routes.start: Routes.login,
          Routes.name: Routes.login,
          Routes.map: Routes.login,
          Routes.myAds: Routes.login,
          Routes.account: Routes.login,
        },
        AuthGate.needsName: <String, String>{
          Routes.start: Routes.name,
          Routes.login: Routes.name,
          Routes.loginCode: Routes.name,
          Routes.map: Routes.name,
          Routes.myAds: Routes.name,
          Routes.account: Routes.name,
        },
        AuthGate.ready: <String, String>{
          Routes.start: Routes.map,
          Routes.login: Routes.map,
          Routes.loginCode: Routes.map,
          Routes.name: Routes.map,
        },
      };

  const List<String> locations = <String>[
    Routes.start,
    ...login,
    Routes.name,
    ...tabs,
  ];

  for (final AuthGate gate in AuthGate.values) {
    group('authRedirect(${gate.name})', () {
      for (final String location in locations) {
        final String? target = expected[gate]![location];
        test('$location → ${target ?? 'stay'}', () {
          expect(authRedirect(gate, location), target);
        });
      }
    });
  }

  test('a path that only starts with /login is not a login screen', () {
    expect(authRedirect(AuthGate.signedOut, '/loginx'), Routes.login);
    expect(authRedirect(AuthGate.ready, '/loginx'), isNull);
  });
}
