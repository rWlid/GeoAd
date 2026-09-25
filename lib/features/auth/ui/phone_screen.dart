import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/phone.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final TextEditingController _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final String? phone12 = normalizeSaudiPhone(_phone.text);
    setState(
      () => _error = phone12 == null ? AppStrings.errorInvalidPhone : null,
    );
    if (phone12 != null) {
      context.go(Routes.loginCode, extra: phone12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.loginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(AppStrings.phoneHeading, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(AppStrings.phoneBody, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.telephoneNumber],
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: AppStrings.phoneLabel,
                  hintText: AppStrings.phoneHint,
                  hintTextDirection: TextDirection.ltr,
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _submit,
                child: const Text(AppStrings.continueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
