import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_form_screen.dart';
import 'branch_status.dart';

// The store owner's ads, newest first. Each card has an on/off switch
// that shows or hides the ad on the map. Tap or swipe left to edit,
// swipe right to delete.
class MyAdsScreen extends StatefulWidget {
  const MyAdsScreen({super.key});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>>? _ads; // null = still loading
  bool _isBusiness = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    loadMyAds();
  }

  // Checks the account is a store, then loads my ads with their
  // product ids and their branches (the edit screen starts from these).
  Future<void> loadMyAds() async {
    try {
      final userId = _db.auth.currentUser!.id;
      final profile = await _db
          .from('profiles')
          .select('is_business')
          .eq('id', userId)
          .single();
      final rows = await _db
          .from('ads')
          .select(
            'id, title, description, is_active, ad_products(product_id), '
            'locations(id, name, type, is_sharing, shared_at)',
          )
          .eq('owner', userId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _isBusiness = profile['is_business'] as bool;
        _ads = rows;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تحميل الإعلانات، تحقق من الاتصال');
    }
  }

  // Shows the spinner again and reloads.
  void retry() {
    setState(() => _error = null);
    loadMyAds();
  }

  // Flips the switch right away, then saves. If saving fails,
  // flips it back and says so.
  Future<void> setActive(Map<String, dynamic> ad, bool isActive) async {
    setState(() => ad['is_active'] = isActive);
    try {
      await _db.from('ads').update({'is_active': isActive}).eq('id', ad['id']);
    } catch (_) {
      if (!mounted) return;
      setState(() => ad['is_active'] = !isActive);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ التغيير، حاول مرة ثانية')),
      );
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Opens the form: no ad = create a new one, with an ad = edit it.
  // After saving, says so and reloads.
  Future<void> openForm([Map<String, dynamic>? ad]) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => AdFormScreen(ad: ad)));
    if (saved != true || !mounted) return;
    showMessage(ad == null ? 'تم نشر الإعلان' : 'تم حفظ التعديلات');
    loadMyAds();
  }

  // Asks before deleting. Returns true to let the card slide away.
  Future<bool> confirmDelete(Map<String, dynamic> ad) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text('هل تريد حذف "${ad['title']}"؟ سيختفي من الخريطة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  // Removes the card right away, then deletes the ad (its product and
  // branch links go with it). If that fails, says so and reloads the list.
  Future<void> deleteAd(Map<String, dynamic> ad) async {
    setState(() => _ads!.remove(ad));
    try {
      await _db.from('ads').delete().eq('id', ad['id']);
      if (!mounted) return;
      showMessage('تم حذف الإعلان');
    } catch (_) {
      if (!mounted) return;
      showMessage('تعذّر حذف الإعلان، حاول مرة ثانية');
      loadMyAds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAds = _isBusiness && (_ads?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي'), centerTitle: true),
      floatingActionButton: hasAds
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('إعلان جديد'),
              onPressed: openForm,
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: buildBody(),
      ),
    );
  }

  // Error, loading, not a store, empty, or the list. Each has a key so
  // AnimatedSwitcher fades between them.
  Widget buildBody() {
    if (_error != null) {
      return _Message(
        key: const ValueKey('error'),
        icon: Icons.cloud_off,
        text: _error!,
        buttonLabel: 'إعادة المحاولة',
        onPressed: retry,
      );
    }
    if (_ads == null) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (!_isBusiness) {
      return const _Message(
        key: ValueKey('not-business'),
        icon: Icons.storefront_outlined,
        text: 'الإعلانات لحسابات المتاجر فقط',
      );
    }
    if (_ads!.isEmpty) {
      return _Message(
        key: const ValueKey('empty'),
        icon: Icons.campaign_outlined,
        text: 'لا توجد إعلانات بعد',
        buttonLabel: 'أنشئ أول إعلان',
        onPressed: openForm,
      );
    }
    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: loadMyAds,
      child: ListView(
        // Room at the bottom so the add button never covers the last card.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final ad in _ads!)
            // Swipe from the right = delete (after asking),
            // swipe from the left = edit (the card stays).
            Dismissible(
              key: ValueKey(ad['id']),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  return confirmDelete(ad);
                }
                openForm(ad);
                return false;
              },
              onDismissed: (_) => deleteAd(ad),
              background: const _SwipeBackground(isDelete: true),
              secondaryBackground: const _SwipeBackground(isDelete: false),
              child: _AdCard(
                ad: ad,
                onTap: () => openForm(ad),
                onChanged: (value) => setActive(ad, value),
              ),
            ),
        ],
      ),
    );
  }
}

// One ad: title, product count, branch names (tap to edit), and the on/off
// switch with a line saying whether customers can see it right now.
class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.onTap,
    required this.onChanged,
  });

  final Map<String, dynamic> ad;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = ad['is_active'] as bool;
    final branches = ad['locations'] as List;
    final productCount = (ad['ad_products'] as List).length;

    // Fixed branches always show; mobile ones only while sharing.
    var visibleCount = 0;
    for (final branch in branches) {
      if (branch['type'] == 'fixed' || isVisibleNow(branch)) visibleCount++;
    }

    final String status;
    if (!isActive) {
      status = 'متوقف';
    } else if (visibleCount == 0) {
      status = 'غير ظاهر الآن: الفرع المتنقل لا يشارك موقعه';
    } else if (visibleCount == 1) {
      status = 'ظاهر الآن في فرع واحد';
    } else if (visibleCount == 2) {
      status = 'ظاهر الآن في فرعين';
    } else {
      status = 'ظاهر الآن في $visibleCount فروع';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.campaign),
              title: Text(ad['title'], style: theme.textTheme.titleMedium),
              subtitle: Text(
                '${productCount == 1 ? 'منتج واحد' : '$productCount منتجات'}'
                ' · ${[for (final b in branches) b['name']].join('، ')}',
              ),
              // chevron_right flips in Arabic, so it points left (forward).
              trailing: const Icon(Icons.chevron_right),
              onTap: onTap,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              title: const Text('ظاهر على الخريطة'),
              subtitle: StatusLabel(
                isActive: isActive && visibleCount > 0,
                text: status,
              ),
              value: isActive,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// The color behind a card while swiping: red with a bin (delete, from the
// right) or the main color with a pen (edit, from the left).
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.isDelete});

  final bool isDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: isDelete
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      decoration: BoxDecoration(
        color: isDelete ? colors.error : colors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isDelete ? Icons.delete_outline : Icons.edit_outlined,
        color: isDelete ? colors.onError : colors.onPrimary,
      ),
    );
  }
}

// A centered icon, a message, and an optional button (empty, error, not a store).
class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.text,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String text;
  final String? buttonLabel;
  final VoidCallback? onPressed;

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
            if (buttonLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
