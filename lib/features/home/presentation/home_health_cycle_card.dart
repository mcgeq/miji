import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';

/// 健康周期卡：未开启追踪时退化成启用引导。
class HomeHealthCycleCard extends StatelessWidget {
  const HomeHealthCycleCard({
    super.key,
    required this.brief,
    required this.onOpenHealth,
  });

  final HomeHealthBrief brief;
  final VoidCallback onOpenHealth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!brief.trackingEnabled) {
      return AppSurface(
        onTap: onOpenHealth,
        child: Row(
          children: [
            const Text('🩺', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '开启健康追踪',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '记录周期、预测经期与易孕期',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '去开启 ›',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return AppSurface(
      onTap: onOpenHealth,
      child: Row(
        children: [
          _CycleRing(brief: brief),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  brief.headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                if (brief.subline.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    brief.subline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (brief.phaseLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    brief.phaseLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

class _CycleRing extends StatelessWidget {
  const _CycleRing({required this.brief});

  final HomeHealthBrief brief;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = brief.isPregnancy
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: brief.ringRatio.clamp(0.0, 1.0),
              strokeWidth: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${brief.ringDay}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '/ ${brief.ringTotal}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
