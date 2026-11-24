import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _nameTitle = 'إكمال التسجيل';
const String _nameHeading = 'ما اسمك؟';
const String _nameBody =
    'يظهر اسمك للمشترين في إعلاناتك، إلا في حساب المتجر فيظهر اسم النشاط التجاري.';
const String _nameLabel = 'الاسم';
const String _accountTypeLabel = 'نوع الحساب';
const String _accountTypeIndividual = 'فرد';
const String _accountTypeStore = 'متجر';
const String _accountTypeHint = 'لا يمكنك تغيير نوع الحساب لاحقا';
const String _saveButton = 'حفظ';
const String _businessNameLabel = 'اسم النشاط';
const String _businessLogoLabel = 'الشعار (اختياري)';
const String _businessNoLogo = 'بدون شعار';
const String _businessPickLogo = 'اختيار شعار';
const String _businessChangeLogo = 'تغيير الشعار';
const String _businessRemoveLogo = 'إزالة الشعار';
const String _businessLogoPreparing = 'جار تجهيز الشعار…';

const String _invalidNameError = 'الاسم يجب أن يكون من حرفان إلى 40 حرف';
const String _invalidBusinessNameError = 'اسم النشاط يجب أن يكون من حرفين إلى 50 حرف';
const String _accountTypeRequiredError = 'اختر نوع الحساب';
const String _logoTooLargeError =
    'حجم الشعار أكبر من 5 ميجابايت، اختر صورة أصغر';
const String _logoUnsupportedError = 'الصيغة غير مدعومة، اختر صورة JPEG أو PNG';
const String _logoReadError =
    'حاول اختيار صورة أخرى، لم نتمكن من قراءة الصورة التي اخترتها';
const String _permissionError = 'ليست لديك صلاحية لتنفيذ هذا الإجراء';
const String _validationError = 'بعض البيانات غير صحيحة، راجعها وحاول مرة أخرى';
const String _unknownError = 'حدث خطأ غير متوقع، حاول مرة أخرى';

const int _maxLogoBytes = 5 * 1024 * 1024;

enum _AccountType { individual, store }

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _businessName = TextEditingController();

  _AccountType? _type;
  _PickedLogo? _logo;

  String? _nameError;
  String? _typeError;
  String? _businessNameError;

  bool _preparingLogo = false;
  bool _saving = false;

  bool get _isStore => _type == _AccountType.store;
  bool get _busy => _saving || _preparingLogo;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (_busy) return;
    setState(() => _preparingLogo = true);
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      final _PickedLogo? picked = _PickedLogo.fromBytes(bytes);
      if (picked == null) {
        _showError(_logoUnsupportedError);
        return;
      }
      if (bytes.lengthInBytes > _maxLogoBytes) {
        _showError(_logoTooLargeError);
        return;
      }
      if (!mounted) return;
      setState(() => _logo = picked);
    } catch (error) {
      debugPrint('Logo pick failed: $error');
      _showError(_logoReadError);
    } finally {
      if (mounted) setState(() => _preparingLogo = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    final String trimmedName = _name.text.trim();
    final int nameLength = trimmedName.runes.length;
    final String? nameError = nameLength < 2 || nameLength > 40
        ? _invalidNameError
        : null;
    final String? typeError = _type == null ? _accountTypeRequiredError : null;

    final String trimmedBusinessName = _businessName.text.trim();
    final int businessNameLength = trimmedBusinessName.runes.length;
    final String? businessNameError = _isStore &&
            (businessNameLength < 2 || businessNameLength > 50)
        ? _invalidBusinessNameError
        : null;

    setState(() {
      _nameError = nameError;
      _typeError = typeError;
      _businessNameError = businessNameError;
    });
    if (nameError != null || typeError != null || businessNameError != null) {
      return;
    }

    final SupabaseClient db = Supabase.instance.client;
    final User? user = db.auth.currentUser;
    if (user == null) {
      _showError(_unknownError);
      return;
    }

    setState(() => _saving = true);
    String? oldLogoPath;
    String? newLogoPath;
    try {
      final Map<String, dynamic> values = <String, dynamic>{
        'name': trimmedName,
        'is_business': _isStore,
      };

      if (_isStore) {
        values['business_name'] = trimmedBusinessName;

        final _PickedLogo? logo = _logo;
        if (logo != null) {
          // Read the old path first: if the update fails we must not delete a
          // logo that was already there.
          final Map<String, dynamic>? current = await db
              .from('profiles')
              .select('business_logo')
              .eq('id', user.id)
              .maybeSingle();
          oldLogoPath = current?['business_logo'] as String?;

          newLogoPath = '${user.id}/logo.${logo.extension}';
          await db.storage.from('images').uploadBinary(
                newLogoPath,
                logo.bytes,
                fileOptions: FileOptions(
                  contentType: logo.contentType,
                  upsert: true,
                  cacheControl: '0',
                ),
              );
          values['business_logo'] = newLogoPath;
        }
      }

      final List<Map<String, dynamic>> rows = await db
          .from('profiles')
          .update(values)
          .eq('id', user.id)
          .select('id');
      if (rows.isEmpty) {
        throw const _SaveFailure(_permissionError);
      }

      if (newLogoPath != null &&
          oldLogoPath != null &&
          oldLogoPath != newLogoPath) {
        await _removeLogo(oldLogoPath);
      }

      if (!mounted) return;
      widget.onSaved();
    } catch (error) {
      if (newLogoPath != null && newLogoPath != oldLogoPath) {
        await _removeLogo(newLogoPath);
      }
      _showError(_messageFor(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeLogo(String path) async {
    try {
      await Supabase.instance.client.storage.from('images').remove(<String>[
        path,
      ]);
    } catch (error) {
      debugPrint('Logo removal failed for $path: $error');
    }
  }

  String _messageFor(Object error) {
    if (error is _SaveFailure) return error.message;
    if (error is PostgrestException) {
      if (error.code == '42501') return _permissionError;
      if (error.code == '22023' || error.code == '23514') {
        return _validationError;
      }
    }
    if (error is StorageException) {
      if (error.statusCode == '401' || error.statusCode == '403') {
        return _permissionError;
      }
      if (error.statusCode == '413') return _logoTooLargeError;
      if (error.statusCode == '400' || error.statusCode == '415') {
        return _validationError;
      }
    }
    return _unknownError;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(_nameTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(_nameHeading, style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_nameBody, style: textTheme.bodyMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _nameLabel,
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              const SizedBox(height: 24),
              Text(_accountTypeLabel, style: textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<_AccountType>(
                segments: const <ButtonSegment<_AccountType>>[
                  ButtonSegment<_AccountType>(
                    value: _AccountType.individual,
                    icon: Icon(Icons.person_outline),
                    label: Text(_accountTypeIndividual),
                  ),
                  ButtonSegment<_AccountType>(
                    value: _AccountType.store,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text(_accountTypeStore),
                  ),
                ],
                selected: _type == null
                    ? const <_AccountType>{}
                    : <_AccountType>{_type!},
                emptySelectionAllowed: true,
                onSelectionChanged: _busy
                    ? null
                    : (Set<_AccountType> selected) => setState(() {
                          _type = selected.isEmpty ? _type : selected.single;
                          _typeError = null;
                        }),
              ),
              const SizedBox(height: 8),
              Text(
                _typeError ?? _accountTypeHint,
                style: textTheme.bodySmall?.copyWith(
                  color: _typeError == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
              if (_isStore) ...<Widget>[
                const SizedBox(height: 24),
                TextField(
                  controller: _businessName,
                  enabled: !_busy,
                  maxLength: 50,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _businessNameLabel,
                    errorText: _businessNameError,
                  ),
                  onChanged: (_) {
                    if (_businessNameError != null) {
                      setState(() => _businessNameError = null);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                _LogoField(
                  logo: _logo,
                  preparing: _preparingLogo,
                  enabled: !_busy,
                  onPick: _pickLogo,
                  onRemove: () => setState(() => _logo = null),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _saving
                    ? Semantics(
                        label: _saveButton,
                        child: const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const Text(_saveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoField extends StatelessWidget {
  const _LogoField({
    required this.logo,
    required this.preparing,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final _PickedLogo? logo;
  final bool preparing;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _businessLogoLabel,
          style: textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: _LogoPreview(bytes: logo?.bytes, busy: preparing),
        ),
        const SizedBox(height: 8),
        Text(
          preparing
              ? _businessLogoPreparing
              : logo != null
                  ? ''
                  : _businessNoLogo,
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: <Widget>[
            TextButton.icon(
              onPressed: enabled ? onPick : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(logo != null ? _businessChangeLogo : _businessPickLogo),
            ),
            if (logo != null)
              TextButton.icon(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text(_businessRemoveLogo),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.bytes, required this.busy});

  final Uint8List? bytes;
  final bool busy;

  static const double _radius = 40;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    const Widget placeholder = Center(
      child: Icon(Icons.storefront, size: _radius * 1.2),
    );

    final Widget child;
    if (busy) {
      child = const Center(child: CircularProgressIndicator());
    } else if (bytes != null) {
      child = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            placeholder,
      );
    } else {
      child = placeholder;
    }

    return CircleAvatar(
      radius: _radius,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      child: ClipOval(
        child: SizedBox.square(dimension: _radius * 2, child: child),
      ),
    );
  }
}

class _PickedLogo {
  const _PickedLogo({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;

  static _PickedLogo? fromBytes(Uint8List bytes) {
    if (_hasPrefix(bytes, const <int>[0xFF, 0xD8, 0xFF])) {
      return _PickedLogo(
        bytes: bytes,
        extension: 'jpg',
        contentType: 'image/jpeg',
      );
    }
    if (_hasPrefix(bytes, const <int>[0x89, 0x50, 0x4E, 0x47])) {
      return _PickedLogo(
        bytes: bytes,
        extension: 'png',
        contentType: 'image/png',
      );
    }
    return null;
  }

  static bool _hasPrefix(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }
}

class _SaveFailure implements Exception {
  const _SaveFailure(this.message);

  final String message;
}
