import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_health_forecast_providers.dart';

/// 未来 7 天预测色带：经期 / 易孕 / PMS / 普通。
class HomeHealthForecastCard extends StatelessWidget {
  const HomeHealthForecastCard({
    super.key,
    required this.forecast,
    required this.onOpenHealth,
  });

  final HomeHealthForecast forecast;
  final VoidCallback onOpenHealth;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = forecast.days;
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSurface(
      onTap: onOpenHealth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '📅 未来 7 天',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '查看健康 ›',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(child: _ForecastCell(day: days[i], today: days.first)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(
                color: _colorFor(theme, HomeForecastKind.period),
                label: '经期',
              ),
              const SizedBox(width: 12),
              _LegendDot(
                color: _colorFor(theme, HomeForecastKind.fertile),
                label: '易孕',
              ),
              const SizedBox(width: 12),
              _LegendDot(
                color: _colorFor(theme, HomeForecastKind.pms),
                label: 'PMS',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastCell extends StatelessWidget {
  const _ForecastCell({required this.day, required this.today});

  final HomeForecastDay day;
  final HomeForecastDay today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = day.date == today.date;
    final color = _colorFor(theme, day.kind);
    return Column(
      children: [
        Text(
          '周${HomeHealthForecastCard._weekdays[day.date.weekday - 1]}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${day.date.day}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: isToday ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 26,
          decoration: BoxDecoration(
            color: day.kind == HomeForecastKind.normal
                ? theme.colorScheme.surfaceContainerHighest
                : color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(7),
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

Color _colorFor(ThemeData theme, HomeForecastKind kind) => switch (kind) {
  HomeForecastKind.period => theme.colorScheme.error,
  HomeForecastKind.fertile => theme.moneyColors.success,
  HomeForecastKind.pms => theme.moneyColors.warning,
  HomeForecastKind.normal => theme.colorScheme.surfaceContainerHighest,
};
