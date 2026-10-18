import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';

/// 今日健康记录：心情 / 睡眠 / 饮水 / 体重，点任意项原地补记。
class HomeHealthTodayCard extends StatelessWidget {
  const HomeHealthTodayCard({
    super.key,
    required this.metrics,
    required this.onTapMetric,
    this.onEdit,
  });

  final List<HomeHealthMetric> metrics;
  final ValueChanged<HomeHealthMetricKind> onTapMetric;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '📝 今日记录',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('编辑'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    metric: metrics[i],
                    onTap: () => onTapMetric(metrics[i].kind),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.onTap});

  final HomeHealthMetric metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(metric.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              metric.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: metric.logged
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
