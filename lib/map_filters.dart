import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'branch_status.dart';

// The price choices in the filter sheet, in ر.س (null = any price).
const priceChoices = [null, 100, 500, 1000, 5000];

// What the customer filters the map by. null / false = that filter is off.
class MapFilters {
  int? mainId; // main category, e.g. "إلكترونيات وأجهزة"
  int? subId; // sub-category under mainId, e.g. "جوالات"
  bool? isService; // true = services only, false = products only
  int? maxPrice;
  bool inStockOnly = false; // only what the branch has now
  String? branchType; // 'fixed' or 'mobile'
  String search = ''; // the search box text ('' = no search)

  // A separate copy, so the sheet can change it without touching the map.
  MapFilters copy() {
    return MapFilters()
      ..mainId = mainId
      ..subId = subId
      ..isService = isService
      ..maxPrice = maxPrice
      ..inStockOnly = inStockOnly
      ..branchType = branchType
      ..search = search;
  }

  // How many sheet filters are on (the badge on "تصفية"; not the search).
  int get count {
    var total = 0;
    if (mainId != null) total++;
    if (isService != null) total++;
    if (maxPrice != null) total++;
    if (inStockOnly) total++;
    if (branchType != null) total++;
    return total;
  }

  // True when this ad, at this branch, matches every filter that is on.
  // The product filters need one product that matches all of them.
  bool passes(Map ad, Map branch) {
    if (ad['is_active'] != true) return false;
    if (branchType != null && branch['type'] != branchType) return false;
    if (!matchesSearch(ad, branch)) return false;
    if (productFiltersOff) return true;
    return matchingProducts(ad, branch['id']).isNotEmpty;
  }

  // True when no product filter (category, type, price, stock) is on.
  bool get productFiltersOff =>
      mainId == null && isService == null && maxPrice == null && !inStockOnly;

  // The ad's products that pass the product filters at this branch
  // (all of them when no product filter is on).
  List matchingProducts(Map ad, int branchId) => [
    for (final product in ad['products'])
      if (productFiltersOff || productMatches(product, branchId)) product,
  ];

  // True when the product passes the category, type, price and stock
  // filters at this branch.
  bool productMatches(Map product, int branchId) {
    if (subId != null && product['category_id'] != subId) return false;
    if (subId == null &&
        mainId != null &&
        product['categories']?['parent_id'] != mainId) {
      return false;
    }
    if (isService != null && product['is_service'] != isService) return false;
    if (maxPrice != null && product['price'] > maxPrice!) return false;
    if (inStockOnly && !inStockAt(product, branchId)) return false;
    return true;
  }

  // True when the search is empty, or the store name, the ad's title or
  // description, or one of its product names contains the search text.
  bool matchesSearch(Map ad, Map branch) {
    final wanted = simplify(search.trim());
    if (wanted.isEmpty) return true;
    final texts = [
      branch['stores']?['business_name'],
      ad['title'],
      ad['description'],
      for (final product in ad['products']) product['name'],
    ];
    for (final text in texts) {
      if (text != null && simplify(text).contains(wanted)) return true;
    }
    return false;
  }

  // The ads at this branch that pass the filters.
  List adsAt(Map branch) => [
    for (final ad in branch['ads'])
      if (passes(ad, branch)) ad,
  ];

  // The branches to put on the map: a mobile one is sharing now, it has
  // an ad that passes the filters, and (when we know the customer's
  // position) it is inside the circle of [radiusKm].
  List<Map<String, dynamic>> branchesToShow(
    List<Map<String, dynamic>> branches,
    LatLng? myPosition,
    int radiusKm,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final branch in branches) {
      if (branch['type'] != 'fixed' && !isVisibleNow(branch)) continue;
      if (adsAt(branch).isEmpty) continue;
      if (myPosition != null) {
        final meters = metersBetween(myPosition, positionOf(branch));
        if (meters > radiusKm * 1000) continue;
      }
      result.add(branch);
    }
    return result;
  }

  // How many different ads these branches show (an ad can be at many).
  int countAds(List<Map<String, dynamic>> branches) {
    final ids = <Object>{};
    for (final branch in branches) {
      for (final ad in adsAt(branch)) {
        ids.add(ad['id']);
      }
    }
    return ids.length;
  }
}

// Makes the search forgiving: lowercase, and "أ إ آ" → "ا", "ة" → "ه",
// "ى" → "ي", so "ايفون" finds "آيفون".
String simplify(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
}

// A category's name written like the add-product screen:
// "إلكترونيات وأجهزة › جوالات" for a sub-category, the name for a main one.
String categoryName(List categories, int id) {
  for (final category in categories) {
    if (category['id'] != id) continue;
    if (category['parent_id'] == null) return category['name'];
    final main = categoryName(categories, category['parent_id']);
    return '$main › ${category['name']}';
  }
  return '';
}
