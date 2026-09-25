import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../providers/buyer_location_providers.dart';
import '../providers/map_providers.dart';

class LocationCard extends ConsumerWidget {
  const LocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuyerLocation location = ref.watch(buyerLocationProvider);
    final BuyerLocationNotifier notifier = ref.read(
      buyerLocationProvider.notifier,
    );
    final bool hasManualCenter = ref.watch(manualCenterProvider) != null;

    final _Prompt? prompt = switch (location) {
      BuyerLocated() || LocatingBuyer() => null,
      BuyerLocationDenied(forever: false) => _Prompt(
        icon: Icons.location_off,
        title: AppStrings.locationDeniedTitle,
        body: AppStrings.locationTapHint,
        action: AppStrings.locationAllow,
        onAction: notifier.askAgain,
      ),
      BuyerLocationDenied(forever: true) => _Prompt(
        icon: Icons.location_disabled,
        title: AppStrings.locationDeniedForeverTitle,
        body: AppStrings.locationDeniedForeverBody,
        action: AppStrings.locationOpenSettings,
        onAction: notifier.openAppSettings,
      ),
      BuyerLocationServicesOff() => _Prompt(
        icon: Icons.gps_off,
        title: AppStrings.locationServicesOffTitle,
        body: AppStrings.locationServicesOffBody,
        action: AppStrings.locationTurnOn,
        onAction: notifier.openLocationSettings,
      ),
      BuyerLocationFailed(:final error) => _Prompt(
        icon: Icons.gps_not_fixed,
        title: error.message,
        body: AppStrings.locationTapHint,
        action: AppStrings.retry,
        onAction: notifier.retry,
      ),
    };

    if (location is LocatingBuyer) {
      return const _LocatingCard();
    }
    if (prompt == null) {
      return const SizedBox.shrink();
    }
    return hasManualCenter
        ? _ManualCenterCard(prompt: prompt)
        : _PromptCard(prompt: prompt);
  }
}

class _Prompt {
  const _Prompt({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
}

class _LocatingCard extends StatelessWidget {
  const _LocatingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox.square(
              dimension: AppSpacing.lg,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                AppStrings.locationLocating,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.prompt});

  final _Prompt prompt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(prompt.icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              prompt.title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              prompt.body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: prompt.onAction,
              child: Text(prompt.action),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualCenterCard extends StatelessWidget {
  const _ManualCenterCard({required this.prompt});

  final _Prompt prompt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.touch_app, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                AppStrings.locationManualCenter,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: prompt.onAction, child: Text(prompt.action)),
          ],
        ),
      ),
    );
  }
}
