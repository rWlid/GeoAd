import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branch_status.dart';

// Opens a branch's sheet at half height; drag it up to see more.
// [ads] are the branch's ads that pass the map's filters.
void showBranchSheet(
  BuildContext context,
  Map branch,
  List ads,
  LatLng? myPosition,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, scroll) => BranchSheet(
        branch: branch,
        ads: ads,
        myPosition: myPosition,
        scroll: scroll,
      ),
    ),
  );
}

// The sheet for one branch: the store, then its ads with their products
// and this branch's stock, then the opening hours (folded).
class BranchSheet extends StatelessWidget {
  const BranchSheet({
    super.key,
    required this.branch,
    required this.ads,
    required this.myPosition,
    required this.scroll,
  });

  final Map branch;
  final List ads;
  final LatLng? myPosition; // null = location off, so no distance
  final ScrollController scroll; // lets the list drag the sheet

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFixed = branch['type'] == 'fixed';
    final store = branch['stores'] as Map?;
    final address = branch['address'] as String?;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: store?['business_logo'] == null
                  ? null
                  : NetworkImage(imageUrl(store!['business_logo'])),
              child: store?['business_logo'] == null
                  ? const Icon(Icons.storefront)
                  : null,
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
        if (address != null && address.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(address),
        ],
        const SizedBox(height: 24),
        Text('الإعلانات', style: theme.textTheme.titleMedium),
        for (final ad in ads) _AdCard(ad: ad, branchId: branch['id']),
        if (isFixed)
          ExpansionTile(
            title: const Text('أوقات العمل'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              for (var day = 0; day < 7; day++) hoursLine(context, day),
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
      text = '$opens – $closes';
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

// One ad: title, description, then its products with price and whether
// this branch has them in stock.
class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad, required this.branchId});

  final Map ad;
  final int branchId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ad['title'], style: theme.textTheme.titleMedium),
            if (ad['description'] != null) ...[
              const SizedBox(height: 4),
              Text(ad['description']),
            ],
            for (final product in ad['products'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product['image_path'] == null
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.inventory_2_outlined),
                        )
                      : Image.network(
                          imageUrl(product['image_path']),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                ),
                title: Text(product['name']),
                subtitle: Text('${priceText(product['price'])} ر.س'),
                trailing: StatusLabel(
                  isActive: inStockAt(product, branchId),
                  text: inStockAt(product, branchId) ? 'متوفر' : 'غير متوفر',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 45.0 → "٤٥", 12.5 → "١٢٫٥".
  String priceText(num price) {
    final text = price == price.roundToDouble()
        ? '${price.toInt()}'
        : price.toStringAsFixed(2);
    return arabicDigits(text).replaceAll('.', '٫');
  }
}

// The public web address of a photo in the "images" storage bucket.
String imageUrl(String path) {
  return Supabase.instance.client.storage.from('images').getPublicUrl(path);
}
