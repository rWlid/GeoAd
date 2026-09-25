import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../providers/auth_providers.dart';

class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  bool _signingOut = false;

  void _retry() => ref.invalidate(profileProvider);

  Future<void> _useAnotherNumber() async {
    if (_signingOut) {
      return;
    }
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool failed = ref.watch(authGateProvider) == AuthGate.error;
    final Object? error = ref.watch(profileProvider).error;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: failed && error != null
                ? _ErrorView(
                    message: AppException.from(error).message,
                    signingOut: _signingOut,
                    onRetry: _retry,
                    onUseAnotherNumber: _useAnotherNumber,
                  )
                : const _LoadingView(),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.location_on, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.sm),
        Text(AppStrings.appName, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xl),
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.startLoading,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.signingOut,
    required this.onRetry,
    required this.onUseAnotherNumber,
  });

  final String message;
  final bool signingOut;
  final VoidCallback onRetry;
  final VoidCallback onUseAnotherNumber;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.startErrorTitle,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: signingOut ? null : onRetry,
          child: const Text(AppStrings.retry),
        ),
        const SizedBox(height: AppSpacing.sm),
        BusyButton(
          label: AppStrings.useAnotherNumber,
          busy: signingOut,
          onPressed: onUseAnotherNumber,
          filled: false,
        ),
      ],
    );
  }
}
