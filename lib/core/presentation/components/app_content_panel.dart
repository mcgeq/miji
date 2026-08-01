import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppContentPanel extends StatelessWidget {
  const AppContentPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.leadingIcon,
    this.leadingColor,
    this.padding,
    this.tone = AppSurfaceTone.plain,
    this.headerGap = 16,
    this.keepTrailingInlineOnCompact = false,
    this.leadingWidget,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final Widget? leadingWidget;
  final EdgeInsetsGeometry? padding;
  final AppSurfaceTone tone;
  final double headerGap;
  final bool keepTrailingInlineOnCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;
    final subtitle = this.subtitle?.trim();
    final leadingIcon = this.leadingIcon;
    final leadingColor = this.leadingColor;

    return AppSurface(
      tone: tone,
      padding: padding ?? EdgeInsets.all(spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final responsive = AppResponsive.of(
                context,
                width: constraints.maxWidth,
              );
              final titleBlock = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leadingWidget != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: leadingWidget,
                    )
                  else if (leadingIcon != null) ...[
                    if (leadingColor == null)
                      Icon(
                        leadingIcon,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      )
                    else
                      AppListItemIcon(
                        icon: leadingIcon,
                        color: leadingColor,
                        size: 40,
                      ),
                    SizedBox(width: leadingColor == null ? 8 : 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );

              final trailing = this.trailing;
              if (trailing == null) {
                return titleBlock;
              }
              if (responsive.isCompact && !keepTrailingInlineOnCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    SizedBox(height: spacing.fieldGap),
                    Align(alignment: Alignment.centerLeft, child: trailing),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  trailing,
                ],
              );
            },
          ),
          SizedBox(height: headerGap),
          child,
        ],
      ),
    );
  }
}
