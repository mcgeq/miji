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

  /// 带操作按钮的提示，用于「已删除 · 撤销」这类可反悔的反馈。
  ///
  /// 停留时间比普通提示长：用户看到再点过来需要反应时间，2 秒就消失等于没有。
  static void undo({
    required FToast toast,
    required BuildContext context,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final color = Theme.of(context).colorScheme.secondary;
    _show(
      toast,
      icon: Icons.check_circle_outline_rounded,
      color: color,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 6),
    );
  }

  static void _show(
    FToast toast, {
    required IconData icon,
    required Color color,
    required String message,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    toast.removeQueuedCustomToasts();
    toast.showToast(
      gravity: ToastGravity.BOTTOM,
      toastDuration: duration,
      child: _AppToastContent(
        icon: icon,
        color: color,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }
}

class _AppToastContent extends StatelessWidget {
  const _AppToastContent({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onInverseSurface,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
