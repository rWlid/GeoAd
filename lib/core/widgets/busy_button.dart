import 'package:flutter/material.dart';

import '../theme.dart';

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? action = busy ? null : onPressed;
    final Widget child = busy
        ? Semantics(
            label: label,
            child: const SizedBox.square(
              dimension: AppSpacing.lg,
              child: CircularProgressIndicator(),
            ),
          )
        : Text(label);

    return filled
        ? FilledButton(onPressed: action, child: child)
        : TextButton(onPressed: action, child: child);
  }
}
