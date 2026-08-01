import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppPageToolbar extends StatelessWidget {
  const AppPageToolbar({
    required this.primary,
    super.key,
    this.secondary,
    this.primaryMaxWidth = 380,
    this.gap = 12,
    this.padding,
    this.showSurface = true,
  });

  final Widget primary;
  final Widget? secondary;
  final double primaryMaxWidth;
  final double gap;
  final EdgeInsetsGeometry? padding;
  final bool showSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;

    final toolbar = LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AppResponsive.of(
          context,
          width: constraints.maxWidth,
        );
        final secondary = this.secondary;

        if (secondary == null) {
          return primary;
        }

        if (!responsive.isExpanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              SizedBox(height: gap),
              secondary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: primaryMaxWidth),
              child: primary,
            ),
            SizedBox(width: gap),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: secondary),
            ),
          ],
        );
      },
    );

    if (!showSurface) {
      return Padding(padding: padding ?? EdgeInsets.zero, child: toolbar);
    }

    return AppSurface(
      tone: AppSurfaceTone.elevated,
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: spacing.cardPadding,
            vertical: spacing.fieldGap,
          ),
      child: toolbar,
    );
  }
}
