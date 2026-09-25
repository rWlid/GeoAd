import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/auth/ui/code_screen.dart';
import '../features/auth/ui/name_screen.dart';
import '../features/auth/ui/phone_screen.dart';
import '../features/auth/ui/start_screen.dart';
import '../features/map/ui/map_screen.dart';
import '../features/my_ads/my_ads_screen.dart';
import '../features/profile/data/profile.dart';
import '../features/profile/ui/account_screen.dart';
import 'strings_ar.dart';

abstract final class Routes {
  static const String start = '/start';

  static const String login = '/login';
  static const String loginCode = '/login/code';

  static const String name = '/name';

  static const String map = '/map';
  static const String myAds = '/my-ads';
  static const String account = '/account';
}

String? authRedirect(AuthGate gate, String location) {
  final bool onStart = location == Routes.start;
  final bool onLogin =
      location == Routes.login || location.startsWith('${Routes.login}/');
  final bool onName = location == Routes.name;

  return switch (gate) {
    AuthGate.loading => onStart || onLogin ? null : Routes.start,
    AuthGate.error => onStart ? null : Routes.start,
    AuthGate.signedOut => onLogin ? null : Routes.login,
    AuthGate.needsName => onName ? null : Routes.name,
    AuthGate.ready => onStart || onLogin || onName ? Routes.map : null,
  };
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>(buildRouter);

GoRouter buildRouter(Ref ref, {Widget mapTab = const MapScreen()}) {
  final ValueNotifier<AuthGate> gate = ValueNotifier<AuthGate>(
    ref.read(authGateProvider),
  );
  ref.listen<AuthGate>(
    authGateProvider,
    (AuthGate? previous, AuthGate next) => gate.value = next,
  );

  final GoRouter router = GoRouter(
    initialLocation: Routes.start,
    refreshListenable: gate,
    redirect: (BuildContext context, GoRouterState state) =>
        authRedirect(gate.value, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(path: Routes.start, builder: (_, _) => const StartScreen()),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const PhoneScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'code',
            redirect: (BuildContext context, GoRouterState state) =>
                state.extra is String ? null : Routes.login,
            builder: (_, GoRouterState state) =>
                CodeScreen(phone12: state.extra! as String),
          ),
        ],
      ),
      GoRoute(path: Routes.name, builder: (_, _) => const NameScreen()),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return _TabsShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: Routes.map, builder: (_, _) => mapTab),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.myAds,
                builder: (_, _) => const MyAdsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.account,
                builder: (_, _) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    gate.dispose();
  });
  return router;
}

class _TabsShell extends ConsumerWidget {
  const _TabsShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const int _mapBranch = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isBusiness = ref.watch(
      profileProvider.select(
        (AsyncValue<Profile?> profile) => profile.value?.isBusiness ?? false,
      ),
    );

    return Scaffold(
      body: navigationShell,
      resizeToAvoidBottomInset: navigationShell.currentIndex != _mapBranch,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: AppStrings.tabMap,
          ),
          const NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: AppStrings.tabMyAds,
          ),
          if (isBusiness)
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: AppStrings.tabStore,
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: AppStrings.tabAccount,
            ),
        ],
      ),
    );
  }
}
