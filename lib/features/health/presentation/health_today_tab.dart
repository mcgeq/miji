import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';

class HealthTodayTab extends StatelessWidget {
  const HealthTodayTab({
    required this.snapshot,
    required this.onEditDailyLog,
    super.key,
    this.onQuickAction,
    this.periodTrackingEnabled,
  });

  final HealthTodaySnapshot snapshot;
  final VoidCallback onEditDailyLog;
  final ValueChanged<HealthQuickAction>? onQuickAction;
  final bool? periodTrackingEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasOpenPeriod =
        snapshot.activePeriod?.endDate == null && snapshot.activePeriod != null;

    final effectivePeriodTrackingEnabled =
        periodTrackingEnabled ?? snapshot.settings.periodTrackingEnabled;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (snapshot.prediction.mainStatus.trim().isNotEmpty) ...[
          Text(
            snapshot.prediction.mainStatus,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final indicator in snapshot.prediction.indicators)
              Chip(
                label: Text(indicator),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.46),
                ),
              ),
          ],
        ),
        if (snapshot.prediction.indicators.isNotEmpty)
          const SizedBox(height: 14),
        _QuickActionGrid(
          hasOpenPeriod: hasOpenPeriod,
          onEditDailyLog: onEditDailyLog,
          onQuickAction: onQuickAction,
          periodTrackingEnabled: effectivePeriodTrackingEnabled,
        ),
        const SizedBox(height: 14),
        _DailySummary(log: snapshot.dailyLog),
        const SizedBox(height: 18),
        Text(
          healthTodayRecordCountLabel(snapshot.dailyLog.visibleRecordCount),
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.hasOpenPeriod,
    required this.onEditDailyLog,
    required this.onQuickAction,
    required this.periodTrackingEnabled,
  });

  final bool hasOpenPeriod;
  final VoidCallback onEditDailyLog;
  final ValueChanged<HealthQuickAction>? onQuickAction;
  final bool periodTrackingEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final action in HealthQuickAction.values)
          if (periodTrackingEnabled || action != HealthQuickAction.period)
            _QuickActionChip(
              action: action,
              label: quickActionLabel(action, hasOpenPeriod),
              onPressed: () {
                if (action == HealthQuickAction.more) {
                  onEditDailyLog();
                }
                onQuickAction?.call(action);
              },
            ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.action,
    required this.label,
    required this.onPressed,
  });

  final HealthQuickAction action;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = quickActionColor(action, colorScheme);

    return Tooltip(
      message: label,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(quickActionIcon(action), size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    fontSize: 11,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.log});

  final HealthDailyLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = <_SummaryItem>[
      if (log.flowLevel != null)
        _SummaryItem('经量', flowLabel(log.flowLevel!), Icons.invert_colors),
      if (log.mood != null)
        _SummaryItem('情绪', moodLabel(log.mood!), Icons.mood),
      if (log.sleepMinutes != null)
        _SummaryItem(
          '睡眠',
          '${(log.sleepMinutes! / 60).toStringAsFixed(1)} 小时',
          Icons.bedtime_outlined,
        ),
      if (log.symptoms.isNotEmpty)
        _SummaryItem('症状', '${log.symptoms.length}', Icons.healing),
      if (log.medications.isNotEmpty)
        _SummaryItem('用药', '${log.medications.length}', Icons.medication),
    ];

    if (items.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            '暂无常规记录',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            constraints: const BoxConstraints(minWidth: 118),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.54),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}
