import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';
import 'package:miji/features/health/presentation/health_cycle_hero.dart';
import 'package:miji/features/health/presentation/health_log_grid.dart';
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
    final hasOpenPeriod =
        snapshot.activePeriod?.endDate == null && snapshot.activePeriod != null;
    final effectivePeriodTrackingEnabled =
        periodTrackingEnabled ?? snapshot.settings.periodTrackingEnabled;
    final isPregnant = snapshot.activePregnancy != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        HealthCycleHero(snapshot: snapshot, date: snapshot.date),
        const SizedBox(height: 18),
        _SectionHeader(title: '快速记录', subtitle: '点一下即记录'),
        const SizedBox(height: 10),
        HealthLogGrid(
          hasOpenPeriod: hasOpenPeriod,
          log: snapshot.dailyLog,
          periodTrackingEnabled: effectivePeriodTrackingEnabled,
          isPregnant: isPregnant,
          onAction: (action) {
            if (action == HealthQuickAction.more) {
              onEditDailyLog();
              return;
            }
            onQuickAction?.call(action);
            if (onQuickAction == null && action != HealthQuickAction.period) {
              onEditDailyLog();
            }
          },
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: '今日记录',
          subtitle: healthTodayRecordCountLabel(
            snapshot.dailyLog.visibleRecordCount,
          ),
          onEdit: onEditDailyLog,
        ),
        const SizedBox(height: 10),
        _TodayRecordsCard(log: snapshot.dailyLog, onEdit: onEditDailyLog),
        const SizedBox(height: 14),
        _TodayInsight(snapshot: snapshot),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.onEdit});

  final String title;
  final String? subtitle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ] else
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
    );
  }
}

class _TodayRecordsCard extends StatelessWidget {
  const _TodayRecordsCard({required this.log, required this.onEdit});

  final HealthDailyLog log;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rows = <_RecordRow>[
      if (log.flowLevel != null)
        _RecordRow(
          icon: Icons.invert_colors,
          title: '经量 · ${flowLabel(log.flowLevel!)}',
          metadata: '经期记录',
        ),
      if (log.symptoms.isNotEmpty)
        _RecordRow(
          icon: Icons.healing,
          title:
              '症状 · ${log.symptoms.map((s) => symptomTypeLabel(s.type)).join('、')}',
          metadata: '共 ${log.symptoms.length} 项',
        ),
      if (log.mood != null)
        _RecordRow(
          icon: Icons.mood,
          title: '情绪 · ${moodLabel(log.mood!)}',
          metadata: log.exerciseIntensity == null
              ? '情绪记录'
              : '运动 · ${_exerciseLabel(log.exerciseIntensity!)}',
        ),
      if (log.temperatureCelsiusTenths != null || log.sleepMinutes != null)
        _RecordRow(
          icon: Icons.thermostat,
          title: _temperatureSleepTitle(log),
          metadata: _metricMetadata(log),
        ),
      if (log.ovulationTest != null)
        _RecordRow(
          icon: Icons.science_outlined,
          title: '排卵试纸 · ${ovulationResultLabel(log.ovulationTest!.result)}',
          metadata: '私密记录',
        ),
      if (log.medications.isNotEmpty)
        _RecordRow(
          icon: Icons.medication,
          title: '用药 · ${log.medications.map((m) => m.name).join('、')}',
          metadata: '共 ${log.medications.length} 种',
        ),
      if (log.notes != null && log.notes!.trim().isNotEmpty)
        _RecordRow(
          icon: Icons.sticky_note_2_outlined,
          title: '备注',
          metadata: log.notes!,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: rows.isEmpty
          ? _EmptyRecords(onEdit: onEdit)
          : Column(
              children: [
                for (var index = 0; index < rows.length; index += 1) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  _RecordTile(row: rows[index], onTap: onEdit),
                ],
              ],
            ),
    );
  }

  String _temperatureSleepTitle(HealthDailyLog log) {
    final parts = <String>[];
    if (log.temperatureCelsiusTenths != null) {
      parts.add(
        '体温 ${(log.temperatureCelsiusTenths! / 10).toStringAsFixed(1)}℃',
      );
    }
    if (log.sleepMinutes != null) {
      final hours = log.sleepMinutes! ~/ 60;
      final minutes = log.sleepMinutes! % 60;
      parts.add('睡眠 $hours小时$minutes分');
    }
    return parts.join(' · ');
  }

  String _metricMetadata(HealthDailyLog log) {
    final parts = <String>[];
    if (log.weightGrams != null) {
      parts.add('体重 ${(log.weightGrams! / 1000).toStringAsFixed(1)}kg');
    }
    if (log.waterIntake != null) {
      parts.add('饮水 ${log.waterIntake}ml');
    }
    if (log.stressLevel != null) {
      parts.add('压力 ${log.stressLevel}');
    }
    return parts.isEmpty ? '健康指标' : parts.join(' · ');
  }
}

class _RecordRow {
  const _RecordRow({
    required this.icon,
    required this.title,
    required this.metadata,
  });

  final IconData icon;
  final String title;
  final String metadata;
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.row, required this.onTap});

  final _RecordRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  row.icon,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 30,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '今天还没有记录',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('补记今天'),
          ),
        ],
      ),
    );
  }
}

class _TodayInsight extends StatelessWidget {
  const _TodayInsight({required this.snapshot});

  final HealthTodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prediction = snapshot.prediction;
    final text = prediction.mainStatus.trim().isEmpty
        ? '记录第一次经期后即可获得预测'
        : prediction.mainStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _exerciseLabel(HealthExerciseIntensity value) {
  return switch (value) {
    HealthExerciseIntensity.none => '未运动',
    HealthExerciseIntensity.light => '轻度',
    HealthExerciseIntensity.medium => '中度',
    HealthExerciseIntensity.heavy => '高强度',
  };
}
