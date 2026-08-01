import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({
    required this.child,
    super.key,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;
    final controls = theme.controlTokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AppResponsive.of(
          context,
          width: constraints.maxWidth,
        );
        final resolvedPadding =
            padding ??
            EdgeInsets.all(
              responsive.isCompact
                  ? spacing.pageCompact
                  : responsive.isMedium
                  ? 20
                  : spacing.pageRegular,
            );
        final resolvedMaxWidth = responsive.isCompact
            ? double.infinity
            : maxWidth ?? controls.contentMaxWidth;

        return Padding(
          padding: resolvedPadding,
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppAdaptivePageFrame extends StatelessWidget {
  const AppAdaptivePageFrame({
    required this.body,
    super.key,
    this.side,
    this.maxBodyWidth,
    this.sideWidth = 340,
    this.gap = 16,
    this.padding,
  });

  final Widget body;
  final Widget? side;
  final double? maxBodyWidth;
  final double sideWidth;
  final double gap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controls = theme.controlTokens;

    return AppPageFrame(
      maxWidth: maxBodyWidth == null
          ? controls.contentMaxWidth
          : maxBodyWidth! + (side == null ? 0 : sideWidth + gap),
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final responsive = AppResponsive.of(
            context,
            width: constraints.maxWidth,
          );
          final side = this.side;
          if (side == null || !responsive.isExpanded) {
            return body;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: body),
              SizedBox(width: gap),
              SizedBox(width: sideWidth, child: side),
            ],
          );
        },
      ),
    );
  }
}

class AppPlainPanel extends StatelessWidget {
  const AppPlainPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.tone = AppSurfaceTone.plain,
    this.bordered = true,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppSurfaceTone tone;
  final bool bordered;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: padding,
      tone: tone,
      bordered: bordered,
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    super.key,
    this.message,
    this.icon,
    this.action,
    this.padding = const EdgeInsets.all(24),
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: colorScheme.primary),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({required this.title, required this.onRetry, super.key});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
