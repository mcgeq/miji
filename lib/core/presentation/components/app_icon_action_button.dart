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
    this.size,
    this.padding,
  }) : assert(icon != null || child != null, 'icon or child must be provided');

  final String tooltip;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final AppIconActionVariant variant;
  final VisualDensity visualDensity;
  final double? iconSize;
  final double? size;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final iconWidget = child ?? Icon(icon, size: iconSize);

    final customStyle = ButtonStyle(
      minimumSize: size != null
          ? WidgetStateProperty.all(Size(size!, size!))
          : null,
      padding: padding != null ? WidgetStateProperty.all(padding) : null,
    );

    // 使用 switch 表达式（无 default）
    final baseStyle = switch (variant) {
      AppIconActionVariant.outlined => IconButton.styleFrom(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Colors.grey),
      ),
      AppIconActionVariant.filled => IconButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      AppIconActionVariant.filledTonal => IconButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        foregroundColor: Theme.of(context).primaryColor,
      ),
      AppIconActionVariant.plain => IconButton.styleFrom(),
    };

    final mergedStyle = baseStyle.copyWith(
      minimumSize: customStyle.minimumSize,
      padding: customStyle.padding,
    );

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: visualDensity,
      icon: iconWidget,
      style: mergedStyle,
    );
  }
}
