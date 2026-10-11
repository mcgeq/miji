import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_surface.dart';

class AppInfoSection extends StatelessWidget {
  const AppInfoSection({
    super.key,
    required this.title,
    required this.children,
    this.childSpacing = 0,
  });

  final String title;
  final List<Widget> children;
  final double childSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < children.length; index += 1) ...[
            children[index],
            if (childSpacing > 0 && index != children.length - 1)
              SizedBox(height: childSpacing),
          ],
        ],
      ),
    );
  }
}

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 72,
  });

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          );
          final valueText = Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          );

          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 2), valueText],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: labelWidth, child: labelText),
              const SizedBox(width: 10),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}
