import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

enum AppSurfaceTone { plain, subtle, elevated, tinted, accent, inset }

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.tone = AppSurfaceTone.plain,
    this.onTap,
    this.selected = false,
    this.bordered = true,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final AppSurfaceTone tone;
  final VoidCallback? onTap;
  final bool selected;
  final bool bordered;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final spacing = theme.spacingTokens;
    final borderRadius = BorderRadius.circular(radius.md);

    final content = Padding(
      padding: padding ?? EdgeInsets.all(spacing.cardPadding),
      child: child,
    );

    return Material(
      color: backgroundColor ?? _backgroundColor(colorScheme),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: bordered
            ? BorderSide(color: borderColor ?? _borderColor(colorScheme))
            : BorderSide.none,
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    if (selected) {
      return colorScheme.primaryContainer.withValues(alpha: 0.35);
    }
    return switch (tone) {
      AppSurfaceTone.plain => colorScheme.surfaceContainerLow,
      AppSurfaceTone.subtle => colorScheme.surfaceContainerLowest,
      AppSurfaceTone.elevated => colorScheme.surfaceContainer,
      AppSurfaceTone.tinted => colorScheme.secondaryContainer.withValues(
        alpha: 0.28,
      ),
      AppSurfaceTone.accent => colorScheme.primaryContainer.withValues(
        alpha: 0.28,
      ),
      AppSurfaceTone.inset => colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.52,
      ),
    };
  }

  Color _borderColor(ColorScheme colorScheme) {
    if (selected) {
      return colorScheme.primary.withValues(alpha: 0.42);
    }
    return switch (tone) {
      AppSurfaceTone.accent => colorScheme.primary.withValues(alpha: 0.24),
      AppSurfaceTone.tinted => colorScheme.secondary.withValues(alpha: 0.22),
      AppSurfaceTone.elevated => colorScheme.outlineVariant.withValues(
        alpha: 0.34,
      ),
      AppSurfaceTone.inset => colorScheme.outlineVariant.withValues(
        alpha: 0.26,
      ),
      AppSurfaceTone.plain || AppSurfaceTone.subtle =>
        colorScheme.outlineVariant.withValues(alpha: 0.42),
    };
  }
}
