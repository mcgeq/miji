import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );

    final primaryActions = primaryAction == null
        ? null
        : <Widget>[primaryAction!];
    final actions = <Widget>[...secondaryActions, ...?primaryActions];

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AppResponsive.of(
          context,
          width: constraints.maxWidth,
        );
        if (responsive.isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              if (actions.isNotEmpty) ...[
                SizedBox(height: spacing.fieldGap),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            if (actions.isNotEmpty) ...[
              SizedBox(width: spacing.sectionGap),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        );
      },
    );
  }
}
