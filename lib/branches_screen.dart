import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'branch_form_screen.dart';
import 'branch_status.dart';

// The store owner's branches: tap a card to edit, swipe it to delete.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>>? _branches; // null = still loading
  String? _error;

  @override
  void initState() {
    super.initState();
    loadBranches();
  }

  // Loads my branches, each with its working hours.
  Future<void> loadBranches() async {
    try {
      final rows = await _db
          .from('locations')
          .select('*, branch_hours(*)')
          .eq('owner', _db.auth.currentUser!.id)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _branches = rows;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تحميل الفروع، تحقق من الاتصال');
    }
  }

  // Shows the spinner again and reloads.
  void retry() {
    setState(() => _error = null);
    loadBranches();
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Opens the form: no branch = add a new one of [type], with a branch = edit it.
  Future<void> openForm([
    Map<String, dynamic>? branch,
    String type = 'fixed',
  ]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(branch: branch, type: type),
      ),
    );
    if (saved != true || !mounted) return;
    showMessage('تم حفظ الفرع');
    loadBranches();
  }

  // Asks fixed or mobile, then opens the form for that kind.
  Future<void> addBranch() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('فرع ثابت'),
              subtitle: const Text('محل في مكان واحد وله أوقات عمل'),
              onTap: () => Navigator.pop(context, 'fixed'),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('فرع متنقل'),
              subtitle: const Text('عربة أو بائع يتنقل، موقعه من جوال السائق'),
              onTap: () => Navigator.pop(context, 'mobile'),
            ),
          ],
        ),
      ),
    );
    if (type == null) return;
    openForm(null, type);
  }

  // Asks before deleting, because the branch also leaves its ads.
  Future<bool> confirmDelete(Map<String, dynamic> branch) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفرع'),
        content: Text(
          'سيُحذف "${branch['name']}" ولن يظهر في إعلاناتك. هل أنت متأكد؟',
        ),
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

  // Removes the card at once, then deletes; brings it back if that fails.
  Future<void> deleteBranch(Map<String, dynamic> branch) async {
    setState(() => _branches!.remove(branch));
    try {
      await _db.from('locations').delete().eq('id', branch['id']);
      if (!mounted) return;
      showMessage('تم حذف "${branch['name']}"');
    } catch (_) {
      if (!mounted) return;
      showMessage('تعذّر حذف الفرع');
      loadBranches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBranches = _branches?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('فروعي'), centerTitle: true),
      floatingActionButton: hasBranches
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('إضافة فرع'),
              onPressed: addBranch,
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: buildBody(),
      ),
    );
  }

  // Error, loading, empty or the list. Each has a key so AnimatedSwitcher
  // fades between them.
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
    if (_branches == null) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_branches!.isEmpty) {
      return _Message(
        key: const ValueKey('empty'),
        icon: Icons.storefront_outlined,
        text: 'لا توجد فروع بعد',
        buttonLabel: 'إضافة فرع',
        onPressed: addBranch,
      );
    }
    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: loadBranches,
      child: ListView(
        // Room at the bottom so the add button never covers the last card.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final branch in _branches!)
            Dismissible(
              key: ValueKey(branch['id']),
              direction: DismissDirection.startToEnd,
              confirmDismiss: (_) => confirmDelete(branch),
              onDismissed: (_) => deleteBranch(branch),
              background: const _DeleteBackground(),
              child: _BranchCard(branch: branch, onTap: () => openForm(branch)),
            ),
        ],
      ),
    );
  }
}

// One branch: icon, name, address or kind, and its status
// (fixed: open/closed now, mobile: visible to customers now or not).
class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.onTap});

  final Map<String, dynamic> branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFixed = branch['type'] == 'fixed';
    final isActive = isFixed
        ? isOpenNow(branch['branch_hours'])
        : isVisibleNow(branch);
    final String status;
    if (isFixed) {
      status = isActive ? 'مفتوح الآن' : 'مغلق الآن';
    } else {
      status = isActive ? 'ظاهر الآن' : 'غير ظاهر';
    }
    final address = branch['address'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(isFixed ? Icons.storefront : Icons.local_shipping),
        ),
        title: Text(branch['name'] ?? ''),
        subtitle: Text(
          address == null || address.isEmpty
              ? (isFixed ? 'فرع ثابت' : 'فرع متنقل')
              : address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StatusLabel(isActive: isActive, text: status),
      ),
    );
  }
}

// The red strip with a trash icon shown under a card while swiping.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: colors.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete, color: colors.onError),
    );
  }
}

// A centered icon, a message and one button (used for empty and error).
class _Message extends StatelessWidget {
  const _Message({
    super.key,
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
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
