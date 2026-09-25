import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/distance_format.dart';
import '../providers/map_providers.dart';

Future<void> showRadiusSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext context) => const RadiusSheet(),
  );
  if (context.mounted) {
    ref.read(radiusPreviewProvider.notifier).clear();
  }
}

class RadiusSheet extends ConsumerStatefulWidget {
  const RadiusSheet({super.key});

  @override
  ConsumerState<RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends ConsumerState<RadiusSheet> {
  late int _meters = ref.read(searchRadiusProvider);

  void _drag(double value) {
    final int meters = snapSearchRadius(value);
    setState(() => _meters = meters);
    ref.read(radiusPreviewProvider.notifier).show(meters);
  }

  void _release(double value) {
    ref.read(searchRadiusProvider.notifier).set(snapSearchRadius(value));
    ref.read(radiusPreviewProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.searchRadius,
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatKilometers(_meters),
            key: const ValueKey<String>('radius-label'),
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Slider(
            value: _meters.toDouble(),
            min: minSearchRadiusMeters.toDouble(),
            max: maxSearchRadiusMeters.toDouble(),
            divisions:
                (maxSearchRadiusMeters - minSearchRadiusMeters) ~/
                searchRadiusStepMeters,
            semanticFormatterCallback: (double value) =>
                formatKilometers(snapSearchRadius(value)),
            onChanged: _drag,
            onChangeEnd: _release,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  formatKilometers(minSearchRadiusMeters),
                  style: textTheme.bodySmall,
                ),
                Text(
                  formatKilometers(maxSearchRadiusMeters),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
