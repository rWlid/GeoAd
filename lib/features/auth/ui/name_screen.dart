import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/image_compress.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/ui/logo_field.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';

enum _AccountType { individual, store }

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _businessName = TextEditingController();
  _AccountType? _type;

  CompressedImage? _logo;

  String? _nameError;
  String? _typeError;
  String? _businessNameError;
  bool _preparingLogo = false;
  bool _busy = false;

  bool get _isStore => _type == _AccountType.store;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (_preparingLogo || _busy) {
      return;
    }
    setState(() => _preparingLogo = true);
    try {
      final CompressedImage? image = await pickCompressedLogo(ref);
      if (image != null && mounted) {
        setState(() => _logo = image);
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _preparingLogo = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || _preparingLogo) {
      return;
    }
    final String? nameError = normalizeProfileName(_name.text) == null
        ? AppStrings.errorInvalidName
        : null;
    final String? typeError = _type == null
        ? AppStrings.errorAccountTypeRequired
        : null;
    final String? businessNameError =
        _isStore && normalizeBusinessName(_businessName.text) == null
        ? AppStrings.errorInvalidBusinessName
        : null;
    setState(() {
      _nameError = nameError;
      _typeError = typeError;
      _businessNameError = businessNameError;
    });
    if (nameError != null || typeError != null || businessNameError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .completeOnboarding(
            name: _name.text,
            isBusiness: _isStore,
            businessName: _isStore ? _businessName.text : null,
            logo: _isStore ? _logo : null,
          );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppStrings.nameTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(AppStrings.nameHeading, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(AppStrings.nameBody, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.name],
                decoration: InputDecoration(
                  labelText: AppStrings.nameLabel,
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.accountTypeLabel, style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<_AccountType>(
                segments: const <ButtonSegment<_AccountType>>[
                  ButtonSegment<_AccountType>(
                    value: _AccountType.individual,
                    icon: Icon(Icons.person_outline),
                    label: Text(AppStrings.accountTypeIndividual),
                  ),
                  ButtonSegment<_AccountType>(
                    value: _AccountType.store,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text(AppStrings.accountTypeStore),
                  ),
                ],
                selected: <_AccountType>{?_type},
                emptySelectionAllowed: true,
                onSelectionChanged: _busy
                    ? null
                    : (Set<_AccountType> selected) => setState(() {
                        _type = selected.isEmpty ? _type : selected.single;
                        _typeError = null;
                      }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _typeError ?? AppStrings.accountTypeHint,
                style: textTheme.bodySmall?.copyWith(
                  color: _typeError == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
              if (_isStore) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _businessName,
                  enabled: !_busy,
                  maxLength: 50,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: AppStrings.businessNameLabel,
                    errorText: _businessNameError,
                  ),
                  onChanged: (_) {
                    if (_businessNameError != null) {
                      setState(() => _businessNameError = null);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.md),
                LogoField(
                  picked: _logo,
                  preparing: _preparingLogo,
                  enabled: !_busy,
                  onPick: _pickLogo,
                  onRemove: () => setState(() => _logo = null),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              BusyButton(
                label: AppStrings.saveButton,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
