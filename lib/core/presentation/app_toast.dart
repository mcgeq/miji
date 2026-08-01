import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AppToast {
  AppToast._();

  static void success(FToast toast, BuildContext context, String message) {
    final color = Theme.of(context).colorScheme.secondary;
    _show(
      toast,
      icon: Icons.check_circle_outline_rounded,
      color: color,
      message: message,
    );
  }

  static void error(FToast toast, BuildContext context, String message) {
    final color = Theme.of(context).colorScheme.error;
    _show(
      toast,
      icon: Icons.error_outline_rounded,
      color: color,
      message: message,
    );
  }

  static void errorWithColor(FToast toast, Color errorColor, String message) {
    _show(
      toast,
      icon: Icons.error_outline_rounded,
      color: errorColor,
      message: message,
    );
  }

  static void _show(
    FToast toast, {
    required IconData icon,
    required Color color,
    required String message,
  }) {
    toast.removeQueuedCustomToasts();
    toast.showToast(
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
      child: _AppToastContent(icon: icon, color: color, message: message),
    );
  }
}

class _AppToastContent extends StatelessWidget {
  const _AppToastContent({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
