import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

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
  Uint8List? _imageBytes; // الصورة المختارة قبل رفعها
  List<Map<String, dynamic>> _categories = []; // الأقسام الفرعية فقط

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // 1) رفع الصورة داخل مجلد باسم البائع
      String? imagePath;
      if (_imageBytes != null) {
        imagePath =
            '${_db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _db.storage
            .from('images')
            .uploadBinary(imagePath, _imageBytes!);
      }
      // 2) حفظ المنتج
      await _db.from('products').insert({
        'name': _name.text.trim(),
        'price': num.parse(_price.text.trim()),
        'category_id': _categoryId,
        'is_service': _isService,
        'quantity': _isService ? null : int.parse(_quantity.text.trim()),
        'image_path': imagePath,
      });
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

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة منتج'), centerTitle: true),
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
                  image: _imageBytes == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(_imageBytes!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _imageBytes != null
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
              initialValue: _categoryId,
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
