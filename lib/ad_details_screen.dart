import 'package:flutter/material.dart';

import 'ad_row.dart';
import 'branch_status.dart';

// One offer in full: the store and branch, the description, then every
// product with its photo, price and whether this branch has it now.
// Uses the data the map already loaded, so there is no new query.
class AdDetailsScreen extends StatelessWidget {
  const AdDetailsScreen({super.key, required this.ad, required this.branch});

  final Map ad;
  final Map branch; // the branch the customer opened, for its stock

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storeName = branch['stores']?['business_name'] ?? '';
    final description = ad['description'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text(ad['title'])),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$storeName، ${branch['name'] ?? ''}',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
          for (final product in ad['products'])
            ProductCard(product: product, branchId: branch['id']),
        ],
      ),
    );
  }
}

// One product: photo (if any), name, "خدمة" tag, price, and
// "متوفر" / "غير متوفر" at this branch.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.branchId});

  final Map product;
  final int branchId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inStock = inStockAt(product, branchId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (product['image_path'] != null) ...[
              ProductImage(path: product['image_path'], height: 180),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    product['name'],
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (product['is_service'] == true) serviceTag(theme),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  arabicPrice(product['price']),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                StatusLabel(
                  isActive: inStock,
                  text: inStock ? 'متوفر' : 'غير متوفر',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // The small "خدمة" tag for a service.
  Widget serviceTag(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('خدمة', style: theme.textTheme.labelMedium),
    );
  }
}
