import 'package:flutter/material.dart';

/// 表单里统一的单选 / 多选胶囊。
///
/// 记录表与各个「单一字段专注弹窗」共用，避免每个入口各写一份。
class HealthChoicePill extends StatelessWidget {
  const HealthChoicePill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    super.key,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : colorScheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent
                  : colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accent : colorScheme.onSurface,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹窗 / 表单里的字段小标题。
class HealthFieldLabel extends StatelessWidget {
  const HealthFieldLabel({required this.text, super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
