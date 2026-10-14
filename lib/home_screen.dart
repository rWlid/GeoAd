import 'package:flutter/material.dart';

import 'my_account_screen.dart';
import 'map_screen.dart';
import 'my_ads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [AccountScreen(), MapScreen(), MyAdsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'حسابي'),
          NavigationDestination(icon: Icon(Icons.map), label: 'الخريطة'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'إعلاناتي'),
        ],
      ),
    );
  }
}
