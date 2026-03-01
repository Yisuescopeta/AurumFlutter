import 'package:flutter/material.dart';
import 'aurum_loader.dart';

enum AurumButtonVariant { primary, secondary, ghost }

class AurumButton extends StatelessWidget {
  const AurumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AurumButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AurumButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: AurumLoader(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (icon != null || isLoading) const SizedBox(width: 8),
        Text(label),
      ],
    );

    switch (variant) {
      case AurumButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
      case AurumButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
      case AurumButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
    }
  }
}
