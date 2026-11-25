import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// نفس الشاشة للإضافة والتعديل: إذا أرسلنا product تفتح للتعديل
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, this.product});

  final Map<String, dynamic>? product; // null = إضافة منتج جديد

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _db = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');

  bool _isService = false;
  bool _saving = false;
  int? _categoryId;
  Uint8List? _imageBytes; // الصورة الجديدة المختارة قبل رفعها
  String? _oldImagePath; // صورة المنتج الحالية (في التعديل فقط)
  List<Map<String, dynamic>> _categories = []; // الأقسام الفرعية فقط
  List<Map<String, dynamic>> _branches = []; // فروع البائع
  bool _allBranches = true; // متوفر في كل الفروع
  final Set<int> _branchIds = {}; // الفروع المختارة عند إطفاء "كل الفروع"
  bool _showBranchError = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBranches();
    // في التعديل: نعبّي الحقول ببيانات المنتج
    final p = widget.product;
    if (p != null) {
      _name.text = p['name'];
      _price.text = '${p['price']}';
      _quantity.text = '${p['quantity'] ?? 0}';
      _isService = p['is_service'];
      _categoryId = p['category_id'];
      _oldImagePath = p['image_path'];
      for (final row in p['product_locations']) {
        _branchIds.add(row['location_id']);
      }
      _allBranches = _branchIds.isEmpty; // لا صفوف = كل الفروع
    }
  }

  // مثال لاسم القسم في القائمة: "إلكترونيات وأجهزة › جوالات"
  Future<void> _loadCategories() async {
    final rows = await _db
        .from('categories')
        .select()
        .order('id', ascending: true);
    final names = {for (final c in rows) c['id']: c['name']};
    setState(() {
      _categories = [
        for (final c in rows)
          if (c['parent_id'] != null)
            {'id': c['id'], 'label': '${names[c['parent_id']]} › ${c['name']}'},
      ];
    });
  }

  // فروع البائع لاختيار أين يتوفر المنتج
  Future<void> _loadBranches() async {
    final rows = await _db
        .from('locations')
        .select('id, name')
        .eq('owner', _db.auth.currentUser!.id)
        .order('created_at');
    if (!mounted) return;
    setState(() => _branches = rows);
  }

  Future<void> _pickImage() async {
    // نسأل: من الاستوديو أو من الكاميرا
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('اختيار من الاستوديو'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    // تصغير الصورة حتى يكون الرفع سريعاً
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 75,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _save() async {
    final fieldsOk = _formKey.currentState!.validate();
    setState(() => _showBranchError = !_allBranches && _branchIds.isEmpty);
    if (!fieldsOk || _showBranchError) return;
    setState(() => _saving = true);
    try {
      // 1) رفع الصورة الجديدة داخل مجلد باسم البائع
      String? imagePath = _oldImagePath;
      if (_imageBytes != null) {
        imagePath =
            '${_db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _db.storage.from('images').uploadBinary(imagePath, _imageBytes!);
      }
      // 2) حفظ المنتج: إضافة جديد أو تعديل الموجود
      final data = {
        'name': _name.text.trim(),
        'price': num.parse(_price.text.trim()),
        'category_id': _categoryId,
        'is_service': _isService,
        'quantity': _isService ? null : int.parse(_quantity.text.trim()),
        'image_path': imagePath,
      };
      int productId;
      if (widget.product == null) {
        final row = await _db
            .from('products')
            .insert(data)
            .select('id')
            .single();
        productId = row['id'];
      } else {
        productId = widget.product!['id'];
        await _db.from('products').update(data).eq('id', productId);
        // 3) إذا تغيّرت الصورة نحذف القديمة
        if (_imageBytes != null && _oldImagePath != null) {
          await _db.storage.from('images').remove([_oldImagePath!]);
        }
      }
      // 4) الفروع: نحذف القديم ونكتب المختار (لا صفوف = كل الفروع)
      await _db.from('product_locations').delete().eq('product_id', productId);
      if (!_allBranches) {
        await _db.from('product_locations').insert([
          for (final id in _branchIds)
            {'product_id': productId, 'location_id': id},
        ]);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
      }
    }
  }

  // شكل الحقل: إطار حوله وعنوان
  InputDecoration _box(String label, {String? suffix}) => InputDecoration(
    labelText: label,
    suffixText: suffix,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 16);
    // الصورة المعروضة: الجديدة إن وجدت، وإلا صورة المنتج الحالية
    final ImageProvider? image = _imageBytes != null
        ? MemoryImage(_imageBytes!)
        : _oldImagePath != null
        ? NetworkImage(_db.storage.from('images').getPublicUrl(_oldImagePath!))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل المنتج'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // مكان الصورة: اضغط لاختيار صورة أو تغييرها
            InkWell(
              onTap: _saving ? null : _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  image: image == null
                      ? null
                      : DecorationImage(image: image, fit: BoxFit.cover),
                ),
                child: image != null
                    ? Align(
                        alignment: AlignmentDirectional.bottomEnd,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: FilledButton.tonalIcon(
                            onPressed: _saving ? null : _pickImage,
                            icon: const Icon(Icons.edit),
                            label: const Text('تغيير'),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 48,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 8),
                          const Text('أضف صورة'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // منتج أو خدمة
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('منتج'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('خدمة'),
                  icon: Icon(Icons.handyman_outlined),
                ),
              ],
              selected: {_isService},
              onSelectionChanged: (s) => setState(() => _isService = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: _box('الاسم'),
              textInputAction: TextInputAction.next,
              validator: (v) => v!.trim().isEmpty ? 'اكتب الاسم' : null,
            ),
            gap,
            TextFormField(
              controller: _price,
              decoration: _box('السعر', suffix: 'ر.س'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => (num.tryParse(v!.trim()) ?? -1) < 0
                  ? 'اكتب سعراً صحيحاً'
                  : null,
            ),
            gap,
            // عدد القطع: للمنتج فقط، ويختفي بنعومة عند اختيار خدمة
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _isService
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _quantity,
                        decoration: _box('عدد القطع'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v!.trim()) ?? -1) < 0
                            ? 'اكتب عدداً صحيحاً'
                            : null,
                      ),
                    ),
            ),
            DropdownButtonFormField<int>(
              // يُبنى من جديد بعد تحميل الأقسام حتى يظهر قسم المنتج
              key: ValueKey(_categories.length),
              initialValue: _categories.any((c) => c['id'] == _categoryId)
                  ? _categoryId
                  : null,
              isExpanded: true,
              decoration: _box('القسم'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(
                    value: c['id'] as int,
                    child: Text(c['label'] as String),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'اختر القسم' : null,
            ),
            // أين يتوفر المنتج: يظهر فقط إذا كان للبائع فروع
            if (_branches.isNotEmpty) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('متوفر في كل الفروع'),
                value: _allBranches,
                onChanged: (v) => setState(() {
                  _allBranches = v;
                  _showBranchError = false;
                }),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _allBranches
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final b in _branches)
                                FilterChip(
                                  label: Text(b['name'] ?? ''),
                                  selected: _branchIds.contains(b['id']),
                                  onSelected: (on) => setState(() {
                                    if (on) {
                                      _branchIds.add(b['id']);
                                    } else {
                                      _branchIds.remove(b['id']);
                                    }
                                    _showBranchError = false;
                                  }),
                                ),
                            ],
                          ),
                          if (_showBranchError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'اختر فرعاً واحداً على الأقل',
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
