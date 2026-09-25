import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../data/auth_repository.dart';
import '../providers/auth_providers.dart';

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key, required this.phone12});

  final String phone12;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  static final List<TextInputFormatter> _codeFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
    LengthLimitingTextInputFormatter(4),
  ];

  final TextEditingController _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final String code = _code.text;
    if (!isValidMockCode(code)) {
      setState(() => _error = AppStrings.errorInvalidCode);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithMockOtp(phone: widget.phone12, code: code);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.codeTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(AppStrings.codeHeading, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        displaySaudiPhone(widget.phone12),
                        style: textTheme.titleLarge,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => context.go(Routes.login),
                    child: const Text(AppStrings.changeNumber),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: _codeFormatters,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: AppStrings.codeLabel,
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
              BusyButton(
                label: AppStrings.signInButton,
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
