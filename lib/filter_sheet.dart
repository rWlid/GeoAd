import 'package:flutter/material.dart';

import 'branch_status.dart';
import 'map_filters.dart';

// The filter bottom sheet. Works on a copy of the filters and shows the
// live result count; "عرض النتائج" returns the copy to the map.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.filters,
    required this.categories,
    required this.countFor,
  });

  final MapFilters filters;
  final List categories; // all rows of the categories table
  final int Function(MapFilters filters) countFor;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final MapFilters _f = widget.filters.copy();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          // Like the add-product screen: the main category first, then a
          // second list with only its sub-categories. Empty = "الكل".
          DropdownButtonFormField<int?>(
            initialValue: _f.mainId,
            isExpanded: true,
            decoration: _box('القسم'),
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              for (final c in widget.categories)
                if (c['parent_id'] == null)
                  DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['name']),
                  ),
            ],
            // A new main category clears the sub-category.
            onChanged: (id) => setState(() {
              _f.mainId = id;
              _f.subId = null;
            }),
          ),
          if (_f.mainId != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              key: ValueKey(_f.mainId), // starts empty for each main
              initialValue: _f.subId,
              isExpanded: true,
              decoration: _box('القسم الفرعي'),
              items: [
                const DropdownMenuItem(value: null, child: Text('الكل')),
                for (final c in widget.categories)
                  if (c['parent_id'] == _f.mainId)
                    DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(c['name']),
                    ),
              ],
              onChanged: (id) => setState(() => _f.subId = id),
            ),
          ],
          const SizedBox(height: 16),
          Text('النوع', style: titleStyle),
          _Chips([
            chip('الكل', _f.isService == null, () => _f.isService = null),
            chip('منتج', _f.isService == false, () => _f.isService = false),
            chip('خدمة', _f.isService == true, () => _f.isService = true),
          ]),
          const SizedBox(height: 16),
          Text('السعر', style: titleStyle),
          _Chips([
            for (final price in priceChoices)
              chip(
                price == null ? 'الكل' : 'حتى ${arabicDigits('$price')} ر.س',
                _f.maxPrice == price,
                () => _f.maxPrice = price,
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('المتوفر فقط', style: titleStyle),
            subtitle: const Text('المنتجات الموجودة في الفرع الآن، والخدمات'),
            value: _f.inStockOnly,
            onChanged: (on) => setState(() => _f.inStockOnly = on),
          ),
          const SizedBox(height: 8),
          Text('نوع الفرع', style: titleStyle),
          _Chips([
            chip('الكل', _f.branchType == null, () => _f.branchType = null),
            chip('ثابت', _f.branchType == 'fixed', () {
              _f.branchType = 'fixed';
            }),
            chip('متنقل', _f.branchType == 'mobile', () {
              _f.branchType = 'mobile';
            }),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                // Clears the sheet's filters but keeps the search box text.
                onPressed: () =>
                    Navigator.pop(context, MapFilters()..search = _f.search),
                child: const Text('مسح الكل'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _f),
                  child: Text(
                    'عرض النتائج (${arabicDigits('${widget.countFor(_f)}')})',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // One choice chip; tapping it runs [change] and redraws the sheet.
  Widget chip(String label, bool selected, VoidCallback change) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(change),
    );
  }

  // The outlined box of a dropdown, with its title on the border.
  InputDecoration _box(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(), // same as the add-product screen
    );
  }
}

// A wrapping row of chips with even spacing.
class _Chips extends StatelessWidget {
  const _Chips(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}
