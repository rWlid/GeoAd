import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_form_screen.dart' show priceText;
import 'add_product_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>>? _products; // null = still loading
  List<Map<String, dynamic>> _branches = []; // فروع البائع
  final Set<String> _savingNow = {}; // "منتج-فرع" التي يُحفظ عددها الآن
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = _db.auth.currentUser!.id;
      final rows = await _db
          .from('products')
          .select(
            'id, name, price, is_service, image_path, category_id, '
            'product_locations(location_id, quantity, locations(name))',
          )
          .eq('owner', me)
          .order('created_at', ascending: false);
      final branches = await _db
          .from('locations')
          .select('id, name')
          .eq('owner', me)
          .order('created_at');
      // لكل منتج نجهّز "stock": رقم الفرع ← عدد القطع فيه
      // مثال: {2: 5, 7: 4} يعني فرع 2 فيه 5 وفرع 7 فيه 4
      for (final p in rows) {
        p['stock'] = <int, int>{
          for (final row in p['product_locations'])
            row['location_id']: row['quantity'] ?? 0,
        };
      }
      setState(() {
        _products = rows;
        _branches = branches;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _showMessage(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  // تغيير عدد القطع في فرع: نحدّث الشاشة فوراً ثم نحفظ
  Future<void> _changeQuantity(
    Map<String, dynamic> p,
    int branchId,
    int? newQuantity,
  ) async {
    if (newQuantity == null || newQuantity < 0) return;
    setState(() => p['stock'][branchId] = newQuantity);

    // إذا فيه حفظ شغّال لنفس الفرع، هو بيحفظ آخر رقم لما يخلص.
    // كذا الطلبات تروح بالترتيب، وما يسبق رقم قديم رقماً جديداً.
    final key = '${p['id']}-$branchId';
    if (_savingNow.contains(key)) return;
    _savingNow.add(key);
    try {
      int saved;
      do {
        saved = p['stock'][branchId];
        // upsert = يضيف صف الفرع إذا ما كان موجوداً، أو يعدّل عدده إذا موجود
        await _db.from('product_locations').upsert({
          'product_id': p['id'],
          'location_id': branchId,
          'quantity': saved,
        });
      } while (p['stock'][branchId] !=
          saved); // تغيّر الرقم أثناء الحفظ؟ نحفظ مرة ثانية
    } catch (e) {
      _showMessage('تعذّر حفظ الكمية');
      _load(); // نرجع الأرقام كما هي في قاعدة البيانات
    } finally {
      _savingNow.remove(key);
    }
  }

  // الضغط على الرقم: كتابة الكمية مباشرة
  Future<void> _typeQuantity(Map<String, dynamic> p, int branchId) async {
    final controller = TextEditingController(
      text: '${p['stock'][branchId] ?? 0}',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عدد القطع'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    _changeQuantity(p, branchId, value);
  }

  Future<bool> _confirmDelete(Map<String, dynamic> p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${p['name']}"؟'),
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

  // حذف المنتج ثم صورته من Storage
  Future<void> _delete(Map<String, dynamic> p) async {
    setState(() => _products!.remove(p));
    try {
      await _db.from('products').delete().eq('id', p['id']);
      if (p['image_path'] != null) {
        await _db.storage.from('images').remove([p['image_path']]);
      }
      _showMessage('تم حذف "${p['name']}"');
    } catch (e) {
      _showMessage('تعذّر الحذف');
      _load();
    }
  }

  // فتح شاشة المنتج: بدون p للإضافة، ومع p للتعديل
  Future<void> _openForm([Map<String, dynamic>? p]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddProductScreen(product: p)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('منتجاتي'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج'),
        onPressed: () => _openForm(),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final grey = Theme.of(context).colorScheme.outline;
    if (_error != null) return Center(child: Text('حدث خطأ: $_error'));
    if (_products == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: grey),
            const SizedBox(height: 12),
            const Text('لا توجد منتجات بعد'),
            const SizedBox(height: 4),
            const Text('اضغط "إضافة منتج" للبدء'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        // مسافة في الأسفل حتى لا يغطي زر الإضافة آخر منتج
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [for (final p in _products!) _productCard(p)],
      ),
    );
  }

  // الخلفية الملونة التي تظهر تحت البطاقة أثناء السحب
  Widget _swipeBackground(Color color, IconData icon, bool atStart) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: atStart
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final colors = Theme.of(context).colorScheme;
    final isService = p['is_service'] as bool;
    final imagePath = p['image_path'] as String?;
    final branchRows = p['product_locations'] as List; // لا صفوف = كل الفروع

    // السحب من اليمين = حذف (بعد التأكيد)، السحب من اليسار = تعديل
    return Dismissible(
      key: ValueKey(p['id']),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) return _confirmDelete(p);
        _openForm(p);
        return false; // التعديل لا يحذف البطاقة
      },
      onDismissed: (_) => _delete(p),
      background: _swipeBackground(colors.error, Icons.delete, true),
      secondaryBackground: _swipeBackground(colors.primary, Icons.edit, false),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // صورة المنتج
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 72,
                      height: 72,
                      color: colors.surfaceContainerHighest,
                      child: imagePath == null
                          ? Icon(
                              isService ? Icons.handyman : Icons.image_outlined,
                              color: colors.outline,
                            )
                          : Image.network(
                              _db.storage
                                  .from('images')
                                  .getPublicUrl(imagePath),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // الاسم والسعر
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          priceText(p['price']),
                          style: TextStyle(color: colors.primary),
                        ),
                        // الخدمة: أين تتوفر
                        if (isService)
                          Text(
                            branchRows.isEmpty
                                ? 'كل الفروع'
                                : [
                                    for (final row in branchRows)
                                      row['locations']?['name'] ?? '',
                                  ].join('، '),
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isService) const Chip(label: Text('خدمة')),
                ],
              ),
              // المنتج: سطر لكل فرع فيه عدد القطع
              if (!isService) ...[
                if (_branches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('أضف فرعاً من حسابي لتحديد عدد القطع'),
                  ),
                for (final b in _branches) _branchStock(p, b),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // سطر فرع واحد: اسم الفرع، وعلامة نفاد الكمية، و − العدد +
  Widget _branchStock(Map<String, dynamic> p, Map<String, dynamic> b) {
    final colors = Theme.of(context).colorScheme;
    final int quantity = p['stock'][b['id']] ?? 0; // لا يوجد = 0
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              quantity == 0
                  ? '${b['name'] ?? ''} · نفدت الكمية'
                  : '${b['name'] ?? ''}',
              style: TextStyle(color: quantity == 0 ? colors.error : null),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeQuantity(p, b['id'], quantity + 1),
                ),
                InkWell(
                  onTap: () => _typeQuantity(p, b['id']),
                  child: SizedBox(
                    width: 32,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  visualDensity: VisualDensity.compact,
                  onPressed: quantity == 0
                      ? null
                      : () => _changeQuantity(p, b['id'], quantity - 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
