import 'package:flutter/material.dart';

import '../../core/strings_ar.dart';

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text(AppStrings.tabMyAds)));
  }
}
