import 'package:flutter/material.dart';

import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';

/// 健康记录弹窗的统一外壳。
///
/// 取代原先「标题 + 内容 + 两个图标按钮」的 `AppDialogScaffold`：
///   * 顶部：圆形图标 + 标题 + 日期副标题 + 关闭按钮；
///   * 中部：可滚动内容；
///   * 底部：通栏「保存」主按钮 + 次要「取消」/「清除」。
///
/// 手机端由 `showAppResponsiveDialog` 的底部弹层承载，桌面端包一层 [Dialog]。
class HealthEntryDialog extends StatelessWidget {
  const HealthEntryDialog({
    required this.title,
    required this.child,
    required this.onSave,
    super.key,
    this.icon,
    this.accent,
    this.subtitle,
    this.saveLabel = '保存',
    this.saveEnabled = true,
    this.onClear,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accent;
  final Widget child;
  final VoidCallback onSave;
  final bool saveEnabled;
  final String saveLabel;

  /// 传入后底部左侧出现「清除」，用于取消已有值。
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedAccent = accent ?? colorScheme.primary;
    final compact = AppResponsive.of(context).isCompact;
    final radius = BorderRadius.circular(20);

    final content = Material(
      color: colorScheme.surface,
      borderRadius: compact ? BorderRadius.zero : radius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: title,
              subtitle: subtitle,
              icon: icon,
              accent: resolvedAccent,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: child,
              ),
            ),
            _Footer(
              saveLabel: saveLabel,
              saveEnabled: saveEnabled,
              onSave: onSave,
              onClear: onClear,
            ),
          ],
        ),
      ),
    );

    if (compact) {
      return content;
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: content,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saveLabel,
    required this.saveEnabled,
    required this.onSave,
    required this.onClear,
  });

  final String saveLabel;
  final bool saveEnabled;
  final VoidCallback onSave;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onClear != null) ...[
                AppIconActionButton(
                  tooltip: '清除',
                  onPressed: onClear,
                  icon: Icons.backspace_outlined,
                  variant: AppIconActionVariant.outlined,
                  size: 46,
                ),
                const SizedBox(width: 18),
              ],
              AppIconActionButton(
                tooltip: '取消',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icons.close_rounded,
                variant: AppIconActionVariant.outlined,
                size: 46,
              ),
              const SizedBox(width: 18),
              AppIconActionButton(
                tooltip: saveLabel,
                onPressed: saveEnabled ? onSave : null,
                icon: Icons.check_rounded,
                variant: AppIconActionVariant.filled,
                size: 46,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
