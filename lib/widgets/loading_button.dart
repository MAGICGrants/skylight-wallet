import 'package:flutter/material.dart';

/// Filled action button with a consistent loading state: while [isLoading] a
/// left-aligned spinner takes the leading-icon slot and the button is
/// disabled; the [label] stays visible throughout.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

  /// Optional leading icon shown when not loading.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spinnerColor = isDark ? Theme.of(context).colorScheme.onPrimary : Colors.white;

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
            )
          else if (icon != null)
            Icon(icon),
          Text(label),
        ],
      ),
    );
  }
}
