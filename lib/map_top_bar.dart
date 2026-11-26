import 'dart:math';

import 'package:flutter/material.dart';

import 'branch_status.dart';
import 'distance_knob.dart';
import 'map_filters.dart';

// The controls floating at the top of the map:
// 1. the search box and "تصفية";
// 2. the "turn on location" line, only when we have no position;
// 3. the distance knob, and next to it the result line (or a "nothing
//    here" card) and the chosen category.
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    super.key,
    required this.radiusKm,
    required this.hasPosition,
    required this.findingMe,
    required this.adCount,
    required this.onRadius,
    required this.onAskLocation,
    required this.filters,
    required this.categories,
    required this.search,
    required this.onSearch,
    required this.onOpenFilters,
    required this.onClearCategory,
    required this.onClearFilters,
  });

  final int radiusKm;
  final bool hasPosition; // false = location off, so no circle
  final bool findingMe; // still waiting for the first position
  final int adCount;
  final void Function(int km) onRadius;
  final VoidCallback onAskLocation;
  final MapFilters filters;
  final List categories; // for the chosen category's name
  final TextEditingController search;
  final void Function(String text) onSearch;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearCategory;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final categoryId = filters.subId ?? filters.mainId;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: searchBox()),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onOpenFilters,
                icon: Badge(
                  isLabelVisible: filters.count > 0,
                  label: Text(arabicDigits('${filters.count}')),
                  child: const Icon(Icons.tune),
                ),
                label: const Text('تصفية'),
              ),
            ],
          ),
          if (!hasPosition && !findingMe) ...[
            const SizedBox(height: 8),
            _Pill(child: locationOffLine()),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasPosition) ...[
                _Pill(
                  child: DistanceKnob(km: radiusKm, onChanged: onRadius),
                ),
                const SizedBox(width: 8),
              ],
              // The other side: result (or "nothing here"), then category.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (adCount > 0)
                      _Pill(child: Text(resultText()))
                    else
                      _Pill(child: nothingHere()),
                    if (categoryId != null) ...[
                      const SizedBox(height: 8),
                      InputChip(
                        label: Text(
                          categoryName(categories, categoryId),
                          overflow: TextOverflow.ellipsis,
                        ),
                        elevation: 3,
                        onDeleted: onClearCategory,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // The search box; the ✕ shows only when there is text.
  Widget searchBox() {
    return _Pill(
      padding: EdgeInsets.zero,
      child: TextField(
        controller: search,
        onChanged: onSearch,
        textInputAction: TextInputAction.search,
        // Tapping the map closes the keyboard.
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج أو متجر',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح البحث',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    search.clear();
                    onSearch('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // Shown when we have no position: why, and a button to ask again.
  Widget locationOffLine() {
    return Row(
      children: [
        const Icon(Icons.location_off, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('فعّل الموقع لعرض الإعلانات القريبة')),
        TextButton(onPressed: onAskLocation, child: const Text('تفعيل')),
      ],
    );
  }

  // "٤ إعلانات ضمن ٢ كم", or just "٤ إعلانات" without a circle.
  String resultText() {
    final count = adsCountText(adCount);
    if (!hasPosition) return count;
    return '$count ضمن ${arabicDigits('$radiusKm')} كم';
  }

  // The friendly card when no ad matches, with quick ways out.
  Widget nothingHere() {
    return Column(
      children: [
        const Text('لا توجد إعلانات هنا'),
        if (hasPosition && radiusKm < maxRadiusKm)
          TextButton(
            onPressed: () => onRadius(min(radiusKm * 2, maxRadiusKm)),
            child: const Text('وسّع المسافة'),
          ),
        if (filters.count > 0 || filters.search.isNotEmpty)
          TextButton(
            onPressed: onClearFilters,
            child: const Text('مسح الفلاتر'),
          ),
      ],
    );
  }
}

// A rounded box with a soft shadow that floats over the map.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: padding, child: child),
    );
  }
}
