import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';

enum AppBadgeTone { neutral, primary, secondary, tertiary, error }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppBadgeTone.neutral,
    this.selected = false,
    this.maxWidth,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final AppBadgeTone tone;
  final bool selected;
  final double? maxWidth;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColors = _colors(theme);
    final colors = (
      background: backgroundColor ?? defaultColors.background,
      border: borderColor ?? defaultColors.border,
      foreground: foregroundColor ?? defaultColors.foreground,
    );
    final resolvedMaxWidth = maxWidth;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: resolvedMaxWidth == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: colors.foreground,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: colors.foreground),
          const SizedBox(width: 4),
        ],
        if (resolvedMaxWidth == null) labelText else Flexible(child: labelText),
      ],
    );

    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: content,
      ),
    );

    if (resolvedMaxWidth == null) {
      return badge;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: badge,
    );
  }

  ({Color background, Color border, Color foreground}) _colors(
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    // 中性淡底用 sunken（凹槽灰），不是「本色叠 alpha」——
    // alpha 的实得明度取决于它压在什么上面，深色叠深面就发灰了。
    final neutralFill = colorScheme.surfaceContainerHighest;

    if (selected) {
      return (
        background: colorScheme.primaryContainer,
        border: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    }

    return switch (tone) {
      AppBadgeTone.primary => (
        background: colorScheme.primaryContainer,
        border: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
      // secondary / tertiary 的底色统一走中性凹槽、靠文字色区分，
      // 这样深色下也不会得到一块发灰的彩底。文字色取 onXxxContainer ——
      // 那一路正是 palette 里按「压在淡底/凹槽上仍 ≥4.5:1」派生的 Strong 档，
      // 换配色时自动跟着变，不用在这里按明暗分支写死两套常量。
      AppBadgeTone.secondary => (
        background: neutralFill,
        border: neutralFill,
        foreground: colorScheme.onSecondaryContainer,
      ),
      AppBadgeTone.tertiary => (
        background: neutralFill,
        border: neutralFill,
        foreground: colorScheme.onTertiaryContainer,
      ),
      // 语义红直接用记账那套「语义容器 + 语义深字」，与金额/tag 是同一族红。
      AppBadgeTone.error => (
        background: moneyColors.expenseContainer,
        border: moneyColors.expenseContainer,
        foreground: moneyColors.expenseStrong,
      ),
      AppBadgeTone.neutral => (
        background: neutralFill,
        border: neutralFill,
        foreground: colorScheme.onSurfaceVariant,
      ),
    };
  }
}
