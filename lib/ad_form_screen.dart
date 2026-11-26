import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_product_screen.dart';
import 'branch_form_screen.dart';
import 'branches_screen.dart';

// One screen to create or edit an ad, in 3 steps: details → products →
// branches, then a summary. No ad = create a new one, with an ad = edit it.
// Returns true when the ad was saved.
class AdFormScreen extends StatefulWidget {
  const AdFormScreen({super.key, this.ad});

  final Map<String, dynamic>? ad;

  @override
  State<AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends State<AdFormScreen> {
  final _db = Supabase.instance.client;
  late final bool _isEdit = widget.ad != null;
  final _title = TextEditingController();
  final _description = TextEditingController();
  // 0 details, 1 products, 2 branches, 3 summary. Editing opens on the summary.
  late int _step = _isEdit ? 3 : 0;
  List<Map<String, dynamic>>? _products; // null = still loading
  List<Map<String, dynamic>>? _branches;
  String? _loadError;
  final selectedProductIds = <int>{};
  final selectedBranchIds = <int>{};
  bool _changed = false; // anything changed? then back asks first
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Editing: start from what the ad already has.
    final ad = widget.ad;
    if (ad != null) {
      _title.text = ad['title'];
      _description.text = ad['description'] ?? '';
      for (final row in ad['ad_products']) {
        selectedProductIds.add(row['product_id']);
      }
      for (final branch in ad['locations']) {
        selectedBranchIds.add(branch['id']);
      }
    }
    loadChoices();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // Loads my products and branches. Ticks anything that is new since the
  // last load (just added from here), and ticks the only one if there is one.
  Future<void> loadChoices() async {
    try {
      final userId = _db.auth.currentUser!.id;
      final products = await _db
          .from('products')
          .select('id, name, price, is_available')
          .eq('owner', userId)
          .order('created_at');
      final branches = await _db
          .from('locations')
          .select('id, name, type')
          .eq('owner', userId)
          .order('created_at');
      if (!mounted) return;

      final oldProductIds = {for (final p in _products ?? []) p['id']};
      final oldBranchIds = {for (final b in _branches ?? []) b['id']};
      setState(() {
        for (final p in products) {
          final isNew = _products != null && !oldProductIds.contains(p['id']);
          if (p['is_available'] == true && (isNew || products.length == 1)) {
            selectedProductIds.add(p['id']);
          }
        }
        for (final b in branches) {
          final isNew = _branches != null && !oldBranchIds.contains(b['id']);
          if (isNew || branches.length == 1) selectedBranchIds.add(b['id']);
        }
        _products = products;
        _branches = branches;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError = 'تعذّر تحميل منتجاتك وفروعك، تحقق من الاتصال',
      );
    }
  }

  // Ticks or unticks one product or branch.
  void toggle(Set<int> ids, int id) {
    setState(() {
      if (ids.contains(id)) {
        ids.remove(id);
      } else {
        ids.add(id);
      }
      _changed = true;
    });
  }

  // Opens the existing add-product screen; reloads when a product was saved.
  Future<void> addProduct() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddProductScreen()));
    if (saved != true) return;
    _changed = true;
    loadChoices();
  }

  // Asks fixed or mobile, opens the existing branch form, reloads after saving.
  Future<void> addBranch() async {
    final type = await askBranchType(context);
    if (type == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BranchFormScreen(type: type)),
    );
    if (saved != true) return;
    _changed = true;
    loadChoices();
  }

  // Why the main button is disabled on this step, or null when it's fine.
  String? stepProblem() {
    if (_step == 0 && _title.text.trim().length < 2) {
      return 'اكتب عنواناً من حرفين على الأقل';
    }
    if (_step == 1 && selectedProductIds.isEmpty) {
      return 'اختر منتجاً واحداً على الأقل';
    }
    if (_step == 2 && selectedBranchIds.isEmpty) {
      return 'اختر فرعاً واحداً على الأقل';
    }
    return null;
  }

  // Closes the keyboard and goes to [step].
  void goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  // The main button: next step (editing: back to the summary), or save.
  void next() {
    if (_step == 3) {
      saveAd();
    } else {
      goTo(_isEdit ? 3 : _step + 1);
    }
  }

  // New ad: insert it, then its products and branches; if a later part
  // fails, delete the new ad so nothing half-saved stays.
  // Edit: update it, then replace its products and branches.
  Future<void> saveAd() async {
    setState(() => _saving = true);
    final description = _description.text.trim();
    final details = {
      'title': _title.text.trim(),
      'description': description.isEmpty ? null : description,
    };
    int? newAdId;
    try {
      final int adId;
      if (_isEdit) {
        adId = widget.ad!['id'];
        await _db.from('ads').update(details).eq('id', adId);
        await _db.from('ad_products').delete().eq('ad_id', adId);
        await _db.from('ad_locations').delete().eq('ad_id', adId);
      } else {
        final ad = await _db.from('ads').insert(details).select('id').single();
        adId = newAdId = ad['id'];
      }
      await _db.from('ad_products').insert([
        for (final id in selectedProductIds) {'ad_id': adId, 'product_id': id},
      ]);
      await _db.from('ad_locations').insert([
        for (final id in selectedBranchIds) {'ad_id': adId, 'location_id': id},
      ]);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (newAdId != null) {
        try {
          await _db.from('ads').delete().eq('id', newAdId);
        } catch (_) {
          // Offline: nothing more we can do here.
        }
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر حفظ الإعلان، تحقق من الاتصال وحاول مرة ثانية'),
        ),
      );
    }
  }

  // Back after changing something: ask once before throwing it away.
  Future<void> confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEdit ? 'تجاهل التعديلات؟' : 'تجاهل الإعلان؟'),
        content: const Text('ستفقد ما غيّرته في هذا الإعلان.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تجاهل'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_changed,
      // While saving, back does nothing.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'تعديل الإعلان' : 'إعلان جديد'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _StepHeader(step: _step, onTap: _isEdit ? goTo : null),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey('$_step ${_products == null} $_loadError'),
                  child: buildStep(),
                ),
              ),
            ),
            buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // The content of the current step (with loading / error for the lists).
  Widget buildStep() {
    if (_step == 0) return buildDetailsStep();
    if (_loadError != null) {
      return _Empty(
        icon: Icons.cloud_off,
        text: _loadError!,
        buttonLabel: 'إعادة المحاولة',
        onPressed: () {
          setState(() => _loadError = null);
          loadChoices();
        },
      );
    }
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_step == 1) return buildProductsStep();
    if (_step == 2) return buildBranchesStep();
    return buildSummary();
  }

  // Step 1: title (required) and a short description (optional).
  Widget buildDetailsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          autofocus: !_isEdit,
          maxLength: 60,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'عنوان الإعلان',
            hintText: 'مثال: خصم 20% على العطور',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _changed = true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLength: 500,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'وصف قصير (اختياري)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _changed = true),
        ),
      ],
    );
  }

  // Step 2: tick my products. Unavailable ones are greyed out
  // (unless the ad already has them, so they can still be unticked).
  Widget buildProductsStep() {
    if (_products!.isEmpty) {
      return _Empty(
        icon: Icons.inventory_2_outlined,
        text: 'ما عندك منتجات بعد',
        buttonLabel: '+ إضافة منتج',
        onPressed: addProduct,
      );
    }
    final count = selectedProductIds.length;
    var countText = 'تم اختيار $count منتجات';
    if (count == 0) countText = 'لم تختر أي منتج بعد';
    if (count == 1) countText = 'تم اختيار منتج واحد';
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _ListTop(addLabel: '+ إضافة منتج', onAdd: addProduct, count: countText),
        for (final p in _products!)
          CheckboxListTile(
            title: Text(p['name']),
            subtitle: Text(
              p['is_available'] == true ? priceText(p['price']) : 'غير متوفر',
            ),
            value: selectedProductIds.contains(p['id']),
            enabled:
                p['is_available'] == true ||
                selectedProductIds.contains(p['id']),
            onChanged: (_) => toggle(selectedProductIds, p['id']),
          ),
      ],
    );
  }

  // Step 3: tick my branches. Mobile ones get a hint.
  Widget buildBranchesStep() {
    if (_branches!.isEmpty) {
      return _Empty(
        icon: Icons.storefront_outlined,
        text: 'ما عندك فروع بعد',
        buttonLabel: '+ إضافة فرع',
        onPressed: addBranch,
      );
    }
    final count = selectedBranchIds.length;
    var countText = 'تم اختيار $count فروع';
    if (count == 0) countText = 'لم تختر أي فرع بعد';
    if (count == 1) countText = 'تم اختيار فرع واحد';
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _ListTop(addLabel: '+ إضافة فرع', onAdd: addBranch, count: countText),
        for (final b in _branches!)
          CheckboxListTile(
            secondary: Icon(
              b['type'] == 'fixed' ? Icons.storefront : Icons.local_shipping,
            ),
            title: Text(b['name'] ?? ''),
            subtitle: b['type'] == 'fixed'
                ? null
                : const Text('يظهر الإعلان فقط أثناء مشاركة الموقع'),
            value: selectedBranchIds.contains(b['id']),
            onChanged: (_) => toggle(selectedBranchIds, b['id']),
          ),
      ],
    );
  }

  // Last: what was picked. Tap a row to change that part.
  Widget buildSummary() {
    final description = _description.text.trim();
    final productNames = [
      for (final p in _products!)
        if (selectedProductIds.contains(p['id'])) p['name'],
    ];
    final branchNames = [
      for (final b in _branches!)
        if (selectedBranchIds.contains(b['id'])) b['name'],
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SummaryRow(
                icon: Icons.campaign,
                title: _title.text.trim(),
                text: description,
                onTap: () => goTo(0),
              ),
              const Divider(height: 1),
              _SummaryRow(
                icon: Icons.inventory_2,
                title: 'المنتجات',
                text: productNames.join('، '),
                onTap: () => goTo(1),
              ),
              const Divider(height: 1),
              _SummaryRow(
                icon: Icons.storefront,
                title: 'الفروع',
                text: branchNames.join('، '),
                onTap: () => goTo(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'اضغط على أي جزء لتغييره',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // Why the step isn't done yet (if needed), then the buttons.
  Widget buildBottomBar() {
    final problem = stepProblem();
    final String label;
    if (_step < 3) {
      label = _isEdit ? 'تم' : 'التالي';
    } else {
      label = _isEdit ? 'حفظ التعديلات' : 'نشر الإعلان';
    }
    // Creating: "السابق" walks back. Editing: steps go back to the summary.
    final showBack = !_isEdit && _step > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem != null) ...[
              Text(problem, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (showBack) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _saving ? null : () => goTo(_step - 1),
                      child: const Text('السابق'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: problem == null && !_saving ? next : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(label),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// "4299 ر.س" for whole prices, "79.5 ر.س" otherwise.
String priceText(num price) {
  final number = price == price.roundToDouble() ? price.toInt() : price;
  return '$number ر.س';
}

// The 3 numbered steps at the top: done steps show a tick, the current one
// is filled, later ones are grey. When editing, tapping a step opens it.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, this.onTap});

  final int step;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = ['التفاصيل', 'المنتجات', 'الفروع'];
    const numbers = ['١', '٢', '٣'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const Expanded(child: Divider(indent: 8, endIndent: 8)),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap == null ? null : () => onTap!(i),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: i <= step
                          ? colors.primary
                          : colors.outlineVariant,
                      foregroundColor: colors.onPrimary,
                      child: i < step
                          ? const Icon(Icons.check, size: 16)
                          : Text(numbers[i]),
                    ),
                    const SizedBox(width: 4),
                    Text(labels[i]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// The top of a checklist: the full-width "+ إضافة …" button and the count.
class _ListTop extends StatelessWidget {
  const _ListTop({
    required this.addLabel,
    required this.onAdd,
    required this.count,
  });

  final String addLabel;
  final VoidCallback onAdd;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onAdd,
            child: Text(addLabel),
          ),
          const SizedBox(height: 12),
          Text(count, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

// One tappable row of the summary, with a small edit icon.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: text.isEmpty ? null : Text(text),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: onTap,
    );
  }
}

// A centered icon, a message and one big button (no products, no branches, error).
class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
