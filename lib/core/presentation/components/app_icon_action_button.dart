import 'package:flutter/material.dart';

enum AppIconActionVariant { plain, outlined, filled, filledTonal }

class AppIconActionButton extends StatelessWidget {
  const AppIconActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.child,
    this.variant = AppIconActionVariant.plain,
    this.visualDensity = VisualDensity.compact,
    this.iconSize,
  }) : assert(icon != null || child != null, 'icon or child must be provided');

  final String tooltip;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final AppIconActionVariant variant;
  final VisualDensity visualDensity;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final iconWidget = child ?? Icon(icon, size: iconSize);
    return switch (variant) {
      AppIconActionVariant.outlined => IconButton.outlined(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: visualDensity,
        icon: iconWidget,
      ),
      AppIconActionVariant.filled => IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: visualDensity,
        icon: iconWidget,
      ),
      AppIconActionVariant.filledTonal => IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: visualDensity,
        icon: iconWidget,
      ),
      AppIconActionVariant.plain => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: visualDensity,
        icon: iconWidget,
      ),
    };
  }
}
