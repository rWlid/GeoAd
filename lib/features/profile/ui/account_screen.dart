import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/profile.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  Future<void> _logout() async {
    if (_signingOut) {
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: AppStrings.logoutConfirmTitle,
      body: AppStrings.logoutConfirmBody,
      confirmLabel: AppStrings.logoutConfirmAction,
    );
    if (!confirmed || !mounted) {
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
    final AsyncValue<Profile?> profile = ref.watch(profileProvider);
    final bool isBusiness = profile.value?.isBusiness ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isBusiness ? AppStrings.tabStore : AppStrings.tabAccount),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: _header(profile),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.lg),
                    BusyButton(
                      label: AppStrings.logoutButton,
                      busy: _signingOut,
                      onPressed: _logout,
                      filled: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AsyncValue<Profile?> profile) {
    if (profile.isLoading) {
      return const _HeaderLoading();
    }
    if (profile.hasError) {
      return _HeaderError(
        message: AppException.from(profile.error!).message,
        onRetry: () => ref.invalidate(profileProvider),
      );
    }
    final Profile? value = profile.value;
    if (value == null) {
      return const _HeaderLoading();
    }
    return _HeaderData(profile: value);
  }
}

class _HeaderData extends StatelessWidget {
  const _HeaderData({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Text(
          (profile.isBusiness ? profile.businessName : profile.name) ?? '',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          displaySaudiPhone(profile.phone),
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeaderLoading extends StatelessWidget {
  const _HeaderLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.accountLoading,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HeaderError extends StatelessWidget {
  const _HeaderError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.accountErrorTitle,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonal(
          onPressed: onRetry,
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}
