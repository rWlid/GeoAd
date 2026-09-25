import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings_ar.dart';
import '../../../core/theme.dart';
import '../../../core/utils/image_compress.dart';
import '../providers/profile_providers.dart';

Future<CompressedImage?> pickCompressedLogo(WidgetRef ref) async {
  final Uint8List? bytes = await ref.read(logoPickerProvider).pick();
  if (bytes == null) {
    return null;
  }
  return ref.read(logoCompressorProvider).compress(bytes);
}

class LogoField extends StatelessWidget {
  const LogoField({
    super.key,
    required this.picked,
    required this.preparing,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final CompressedImage? picked;
  final bool preparing;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get _hasLogo => picked != null;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool active = enabled && !preparing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.businessLogoLabel,
          style: textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: _LogoPreview(bytes: picked?.bytes, busy: preparing),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          preparing
              ? AppStrings.businessLogoPreparing
              : _hasLogo
              ? ''
              : AppStrings.businessNoLogo,
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: <Widget>[
            TextButton.icon(
              onPressed: active ? onPick : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _hasLogo
                    ? AppStrings.businessChangeLogo
                    : AppStrings.businessPickLogo,
              ),
            ),
            if (_hasLogo)
              TextButton.icon(
                onPressed: active ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text(AppStrings.businessRemoveLogo),
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
    final Uint8List? picked = bytes;

    final Widget child;
    if (busy) {
      child = const Center(child: CircularProgressIndicator());
    } else if (picked != null) {
      child = Image.memory(
        picked,
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
