import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branch_status.dart';

// One offer in a short list (the branch sheet and the store page): a
// product photo, the title, "من ٤٥ ر.س، ٣ منتجات", and a chevron.
class AdRow extends StatelessWidget {
  const AdRow({
    super.key,
    required this.ad,
    required this.products,
    required this.onTap,
  });

  final Map ad;
  final List products; // the products to sum up (e.g. only matching ones)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ProductImage(path: firstImage(), width: 56, height: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad['title'],
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (products.isNotEmpty)
                    Text(
                      pricesLine(products),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // chevron_right flips by itself in Arabic, so it points left.
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  // The first photo of the summed-up products, else of any product in
  // the ad, else null (the placeholder shows).
  String? firstImage() {
    for (final product in [...products, ...ad['products']]) {
      if (product['image_path'] != null) return product['image_path'];
    }
    return null;
  }

  // "٤٥ ر.س" for one product; "من ٤٥ ر.س، ٣ منتجات" for more.
  // (A "·" between Arabic digits looks like the Arabic zero "٠".)
  String pricesLine(List products) {
    if (products.length == 1) return arabicPrice(products.first['price']);
    num lowest = products.first['price'];
    for (final product in products) {
      if (product['price'] < lowest) lowest = product['price'];
    }
    final count = countText(products.length, [
      'منتج واحد',
      'منتجان',
      'منتجات',
      'منتجًا',
    ]);
    return 'من ${arabicPrice(lowest)}، $count';
  }
}

// A product photo with rounded corners. While it loads, or when there is
// no photo or it fails, a calm grey box with an icon shows instead.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.path,
    required this.height,
    this.width, // null = as wide as the space
  });

  final String? path;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.inventory_2_outlined),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: path == null
          ? placeholder
          : Image.network(
              imageUrl(path!),
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (_, image, progress) =>
                  progress == null ? image : placeholder,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

// 45 → "٤٥ ر.س", 12.5 → "١٢٫٥ ر.س".
String arabicPrice(num price) {
  final text = price == price.roundToDouble()
      ? '${price.toInt()}'
      : price.toStringAsFixed(2);
  return '${arabicDigits(text).replaceAll('.', '٫')} ر.س';
}

// The public web address of a photo in the "images" storage bucket.
String imageUrl(String path) {
  return Supabase.instance.client.storage.from('images').getPublicUrl(path);
}
