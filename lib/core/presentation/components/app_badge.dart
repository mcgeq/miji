import 'package:flutter/material.dart';

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
    final colorScheme = theme.colorScheme;
    final defaultColors = _colors(colorScheme);
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
    ColorScheme colorScheme,
  ) {
    if (selected) {
      final foreground = colorScheme.onPrimaryContainer;
      return (
        background: foreground.withValues(alpha: 0.10),
        border: foreground.withValues(alpha: 0.16),
        foreground: foreground,
      );
    }

    return switch (tone) {
      AppBadgeTone.primary => (
        background: colorScheme.primaryContainer.withValues(alpha: 0.46),
        border: colorScheme.primary.withValues(alpha: 0.20),
        foreground: colorScheme.primary,
      ),
      AppBadgeTone.secondary => (
        background: colorScheme.secondaryContainer.withValues(alpha: 0.52),
        border: colorScheme.secondary.withValues(alpha: 0.22),
        foreground: colorScheme.onSecondaryContainer,
      ),
      AppBadgeTone.tertiary => (
        background: colorScheme.tertiaryContainer.withValues(alpha: 0.58),
        border: colorScheme.tertiary.withValues(alpha: 0.24),
        foreground: colorScheme.onTertiaryContainer,
      ),
      AppBadgeTone.error => (
        background: colorScheme.errorContainer.withValues(alpha: 0.60),
        border: colorScheme.error.withValues(alpha: 0.22),
        foreground: colorScheme.onErrorContainer,
      ),
      AppBadgeTone.neutral => (
        background: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        border: colorScheme.outlineVariant.withValues(alpha: 0.28),
        foreground: colorScheme.onSurfaceVariant,
      ),
    };
  }
}
