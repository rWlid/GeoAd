import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'ad_details_screen.dart';
import 'ad_row.dart';
import 'branch_status.dart';
import 'map_filters.dart';
import 'store_screen.dart';

// Opens a branch's quick-look sheet at 45% height; drag it up to 90%.
// [filters] are the map's filters, to pick the matching offers.
void showBranchSheet(
  BuildContext context,
  Map branch,
  MapFilters filters,
  LatLng? myPosition,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      maxChildSize: 0.9,
      builder: (_, scroll) => BranchSheet(
        branch: branch,
        filters: filters,
        myPosition: myPosition,
        scroll: scroll,
      ),
    ),
  );
}

// The quick look at one branch: the store, "زيارة المتجر", then the
// matching offers, and on demand the store's other offers.
class BranchSheet extends StatefulWidget {
  const BranchSheet({
    super.key,
    required this.branch,
    required this.filters,
    required this.myPosition,
    required this.scroll,
  });

  final Map branch;
  final MapFilters filters;
  final LatLng? myPosition; // null = location off, so no distance
  final ScrollController scroll; // lets the list drag the sheet

  @override
  State<BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends State<BranchSheet> {
  bool _showAll = false; // true after "عرض كل عروض المتجر"

  // The active offers at this branch that the filters hide.
  List hiddenAds(List matchingAds) => [
    for (final ad in widget.branch['ads'])
      if (ad['is_active'] == true && !matchingAds.contains(ad)) ad,
  ];

  // Opens the store page on top of the sheet; back returns here.
  void openStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StoreScreen(branch: widget.branch, myPosition: widget.myPosition),
      ),
    );
  }

  // Opens the offer details page on top of the sheet; back returns here.
  void openAd(Map ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdDetailsScreen(ad: ad, branch: widget.branch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchingAds = widget.filters.adsAt(widget.branch);
    final hidden = hiddenAds(matchingAds);
    final total = matchingAds.length + hidden.length;
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        BranchHeader(branch: widget.branch, myPosition: widget.myPosition),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: openStore,
          icon: const Icon(Icons.storefront),
          label: const Text('زيارة المتجر'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        const SizedBox(height: 24),
        Text(
          'العروض (${arabicDigits('${matchingAds.length}')})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Each row sums up only the products that match the filters.
        for (final ad in matchingAds)
          AdRow(
            ad: ad,
            products: widget.filters.matchingProducts(ad, widget.branch['id']),
            onTap: () => openAd(ad),
          ),
        if (hidden.isNotEmpty && !_showAll)
          TextButton(
            onPressed: () => setState(() => _showAll = true),
            child: Text('عرض كل عروض المتجر (${arabicDigits('$total')})'),
          ),
        if (_showAll) ...[
          const Divider(height: 32),
          Text('عروض أخرى في المتجر', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final ad in hidden)
            AdRow(ad: ad, products: ad['products'], onTap: () => openAd(ad)),
        ],
      ],
    );
  }
}

// The top of the sheet and of the store page: logo, store name, branch
// name, then one line of facts: type · open or last update · distance.
class BranchHeader extends StatelessWidget {
  const BranchHeader({
    super.key,
    required this.branch,
    required this.myPosition,
  });

  final Map branch;
  final LatLng? myPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFixed = branch['type'] == 'fixed';
    final store = branch['stores'] as Map?;
    final logo = store?['business_logo'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: logo == null
                  ? null
                  : NetworkImage(imageUrl(logo)),
              child: logo == null ? const Icon(Icons.storefront) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store?['business_name'] ?? '',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(branch['name'] ?? ''),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFixed ? Icons.storefront : Icons.local_shipping,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(isFixed ? 'فرع ثابت' : 'فرع متنقل'),
              ],
            ),
            statusLabel(),
            if (myPosition != null) Text(distanceText()),
          ],
        ),
      ],
    );
  }

  // "مفتوح الآن" / "مغلق الآن" for a fixed branch, or "آخر تحديث قبل ٣ د"
  // for a mobile one (on the map it is always visible, so its dot is colored).
  Widget statusLabel() {
    if (branch['type'] == 'fixed') {
      final isOpen = isOpenNow(branch['branch_hours']);
      return StatusLabel(
        isActive: isOpen,
        text: isOpen ? 'مفتوح الآن' : 'مغلق الآن',
      );
    }
    final minutes = DateTime.now()
        .difference(DateTime.parse(branch['shared_at']))
        .inMinutes;
    final text = minutes < 1
        ? 'آخر تحديث الآن'
        : 'آخر تحديث قبل ${arabicDigits('$minutes')} د';
    return StatusLabel(isActive: true, text: text);
  }

  // "على بعد ١٫٢ كم".
  String distanceText() {
    final km = metersBetween(myPosition!, positionOf(branch)) / 1000;
    final number = arabicDigits(km.toStringAsFixed(1)).replaceAll('.', '٫');
    return 'على بعد $number كم';
  }
}
