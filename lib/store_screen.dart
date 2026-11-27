import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'ad_details_screen.dart';
import 'ad_row.dart';
import 'branch_sheet.dart';
import 'branch_status.dart';

// The full store page for one branch: the same header as the sheet, the
// address, every active offer here (no filters), then the opening hours
// for a fixed branch. Uses the data the map already loaded.
class StoreScreen extends StatelessWidget {
  const StoreScreen({
    super.key,
    required this.branch,
    required this.myPosition,
  });

  final Map branch;
  final LatLng? myPosition; // null = location off, so no distance

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = branch['address'] as String?;
    final ads = [
      for (final ad in branch['ads'])
        if (ad['is_active'] == true) ad,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(branch['stores']?['business_name'] ?? '')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BranchHeader(branch: branch, myPosition: myPosition),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(address),
          ],
          const SizedBox(height: 24),
          Text(
            'العروض (${arabicDigits('${ads.length}')})',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final ad in ads)
            AdRow(
              ad: ad,
              products: ad['products'],
              onTap: () => openAd(context, ad),
            ),
          if (branch['type'] == 'fixed') ...[
            const SizedBox(height: 24),
            Text('أوقات العمل', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var day = 0; day < 7; day++) hoursLine(context, day),
          ],
        ],
      ),
    );
  }

  // Opens the offer details page; back returns to this page.
  void openAd(BuildContext context, Map ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdDetailsScreen(ad: ad, branch: branch),
      ),
    );
  }

  // One day's line: "الأحد      ١٠:٠٠ ص – ١١:٠٠ م" or "مغلق".
  Widget hoursLine(BuildContext context, int day) {
    final hours = branch['branch_hours'] as List;
    final rows = [
      for (final row in hours)
        if (row['day_of_week'] == day) row,
    ];
    final String text;
    if (rows.isEmpty) {
      text = 'مغلق';
    } else {
      final opens = parseTime(rows.first['opens_at']).format(context);
      final closes = parseTime(rows.first['closes_at']).format(context);
      text = arabicDigits('$opens – $closes'); // "١٠:٠٠ ص – ١١:٠٠ م"
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(dayNames[day])),
          Text(text),
        ],
      ),
    );
  }
}
