import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_product_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>>? _products; // null = still loading
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('products')
          .select('id, name, price, is_service, quantity, image_path')
          .eq('owner', _db.auth.currentUser!.id)
          .order('created_at', ascending: false);
      setState(() {
        _products = rows;
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

  // تغيير الكمية: نحدّث الشاشة فوراً ثم نحفظ، وإذا فشل الحفظ نرجع الرقم القديم
  Future<void> _changeQuantity(Map<String, dynamic> p, int? newQuantity) async {
    if (newQuantity == null || newQuantity < 0) return;
    final old = p['quantity'];
    setState(() => p['quantity'] = newQuantity);
    try {
      await _db
          .from('products')
          .update({'quantity': newQuantity})
          .eq('id', p['id']);
    } catch (e) {
      setState(() => p['quantity'] = old);
      _showMessage('تعذّر حفظ الكمية');
    }
  }

  // الضغط على الرقم: كتابة الكمية مباشرة
  Future<void> _typeQuantity(Map<String, dynamic> p) async {
    final controller = TextEditingController(text: '${p['quantity'] ?? 0}');
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
    _changeQuantity(p, value);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('منتجاتي'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج'),
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (added == true) _load();
        },
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
        children: [
          Text(
            'اسحب المنتج إلى الجانب لحذفه',
            textAlign: TextAlign.center,
            style: TextStyle(color: grey),
          ),
          const SizedBox(height: 8),
          for (final p in _products!) _productCard(p),
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final colors = Theme.of(context).colorScheme;
    final isService = p['is_service'] as bool;
    final quantity = (p['quantity'] as int?) ?? 0;
    final imagePath = p['image_path'] as String?;

    // السحب لأي جهة يحذف المنتج بعد التأكيد
    return Dismissible(
      key: ValueKey(p['id']),
      confirmDismiss: (_) => _confirmDelete(p),
      onDismissed: (_) => _delete(p),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                      '${p['price']} ر.س',
                      style: TextStyle(color: colors.primary),
                    ),
                    if (!isService && p['quantity'] == 0)
                      Text(
                        'نفدت الكمية',
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                  ],
                ),
              ),
              // الكمية للمنتج فقط، الخدمة ليس لها كمية
              if (isService)
                const Chip(label: Text('خدمة'))
              else
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
                        onPressed: () => _changeQuantity(p, quantity + 1),
                      ),
                      InkWell(
                        onTap: () => _typeQuantity(p),
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
                            : () => _changeQuantity(p, quantity - 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
