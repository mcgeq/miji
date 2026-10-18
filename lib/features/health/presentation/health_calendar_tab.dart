import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_cycle_hero.dart';
import 'package:miji/features/health/presentation/health_log_grid.dart';
import 'package:miji/features/health/presentation/health_month_grid.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/features/health/presentation/health_theme.dart';

class HealthCalendarTab extends StatelessWidget {
  const HealthCalendarTab({
    required this.focusedDay,
    required this.selectedDay,
    required this.markers,
    required this.onDaySelected,
    required this.onQuickAction,
    required this.onEditDailyLog,
    super.key,
    this.periodTrackingEnabled = true,
    this.todaySnapshot,
    this.selectedDayLog,
    this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<HealthCalendarMarker> markers;
  final bool periodTrackingEnabled;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime>? onPageChanged;
  final ValueChanged<HealthQuickAction> onQuickAction;
  final VoidCallback onEditDailyLog;
  final HealthTodaySnapshot? todaySnapshot;
  final HealthDailyLog? selectedDayLog;

  @override
  Widget build(BuildContext context) {
    final visibleMarkers = periodTrackingEnabled
        ? markers
        : markers
              .where(
                (marker) =>
                    marker.kind != HealthCalendarMarkerKind.actualPeriod &&
                    marker.kind != HealthCalendarMarkerKind.predictedPeriod &&
                    marker.kind != HealthCalendarMarkerKind.pms &&
                    marker.kind != HealthCalendarMarkerKind.fertileWindow,
              )
              .toList();
    final grouped = <int, List<HealthCalendarMarker>>{};
    for (final marker in visibleMarkers) {
      (grouped[HealthDate.dayKey(marker.date)] ??= []).add(marker);
    }
    final selectedMarkers =
        grouped[HealthDate.dayKey(selectedDay)] ??
        const <HealthCalendarMarker>[];
    final hasOpenPeriod = visibleMarkers.any(
      (marker) => marker.kind == HealthCalendarMarkerKind.actualPeriod,
    );
    final isPregnant = todaySnapshot?.activePregnancy != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        if (todaySnapshot != null) ...[
          HealthCycleHero(snapshot: todaySnapshot!, date: selectedDay),
          const SizedBox(height: 18),
        ],
        _MonthCard(
          focusedDay: focusedDay,
          selectedDay: selectedDay,
          markersByDay: grouped,
          periodTrackingEnabled: periodTrackingEnabled,
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
        ),
        const SizedBox(height: 16),
        _SelectedDayCard(
          selectedDay: selectedDay,
          markers: selectedMarkers,
          hasOpenPeriod: hasOpenPeriod,
          isPregnant: isPregnant,
          periodTrackingEnabled: periodTrackingEnabled,
          log: selectedDayLog,
          onQuickAction: onQuickAction,
          onEditDailyLog: onEditDailyLog,
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.markersByDay,
    required this.periodTrackingEnabled,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<int, List<HealthCalendarMarker>> markersByDay;
  final bool periodTrackingEnabled;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上个月',
                visualDensity: VisualDensity.compact,
                onPressed: onPageChanged == null
                    ? null
                    : () => onPageChanged!(_shift(focusedDay, -1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${focusedDay.year}年${focusedDay.month.toString().padLeft(2, '0')}月',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton(
                tooltip: '下个月',
                visualDensity: VisualDensity.compact,
                onPressed: onPageChanged == null
                    ? null
                    : () => onPageChanged!(_shift(focusedDay, 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (!_isSameMonth(focusedDay, today))
                TextButton(
                  onPressed: () {
                    onDaySelected(today, today);
                    onPageChanged?.call(today);
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('回到今天'),
                ),
            ],
          ),
          if (periodTrackingEnabled) ...[
            const SizedBox(height: 6),
            const _Legend(),
          ],
          const SizedBox(height: 8),
          HealthMonthGrid(
            month: focusedDay,
            selectedDay: selectedDay,
            today: today,
            markersByDay: markersByDay,
            periodTrackingEnabled: periodTrackingEnabled,
            onDaySelected: (day) => onDaySelected(day, day),
          ),
        ],
      ),
    );
  }

  DateTime _shift(DateTime day, int delta) {
    return DateTime.utc(day.year, day.month + delta, 1);
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HealthPalette.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendItem(color: palette.period, label: '经期', filled: true),
        _LegendItem(color: palette.period, label: '预计经期', filled: false),
        _LegendItem(color: palette.fertile, label: '易孕期', filled: false),
        _LegendItem(color: palette.pms, label: '经前期', filled: false),
        Text(
          '圆点 = 有记录',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.filled,
  });

  final Color color;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
            border: filled ? null : Border.all(color: color, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.selectedDay,
    required this.markers,
    required this.hasOpenPeriod,
    required this.isPregnant,
    required this.periodTrackingEnabled,
    required this.log,
    required this.onQuickAction,
    required this.onEditDailyLog,
  });

  final DateTime selectedDay;
  final List<HealthCalendarMarker> markers;
  final bool hasOpenPeriod;
  final bool isPregnant;
  final bool periodTrackingEnabled;
  final HealthDailyLog? log;
  final ValueChanged<HealthQuickAction> onQuickAction;
  final VoidCallback onEditDailyLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = _isSameDay(selectedDay, DateTime.now());
    final recordCount = log?.visibleRecordCount ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${selectedDay.month}月${selectedDay.day}日',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '周${_weekdayLabel(selectedDay.weekday)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '今天',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
          if (markers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final marker in markers) _MarkerChip(marker: marker),
              ],
            ),
          ],
          const SizedBox(height: 14),
          HealthLogGrid(
            hasOpenPeriod: hasOpenPeriod,
            log: log ?? HealthDailyLog.empty(selectedDay),
            periodTrackingEnabled: periodTrackingEnabled,
            isPregnant: isPregnant,
            onAction: (action) {
              if (action == HealthQuickAction.more) {
                onEditDailyLog();
                return;
              }
              onQuickAction(action);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEditDailyLog,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(
                    recordCount > 0 ? '编辑这一天（$recordCount）' : '记录这一天',
                  ),
                ),
              ),
              if (periodTrackingEnabled && !isPregnant) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onQuickAction(HealthQuickAction.period),
                    icon: const Icon(Icons.water_drop_outlined, size: 18),
                    label: Text(hasOpenPeriod ? '结束经期' : '开始经期'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _weekdayLabel(int weekday) {
    const labels = ['', '一', '二', '三', '四', '五', '六', '日'];
    return labels[weekday];
  }
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.marker});

  final HealthCalendarMarker marker;

  @override
  Widget build(BuildContext context) {
    final color = markerColor(marker.kind, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(marker.kind), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            marker.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(HealthCalendarMarkerKind kind) {
    return switch (kind) {
      HealthCalendarMarkerKind.actualPeriod => Icons.water_drop,
      HealthCalendarMarkerKind.predictedPeriod => Icons.water_drop_outlined,
      HealthCalendarMarkerKind.pms => Icons.mood_bad_outlined,
      HealthCalendarMarkerKind.fertileWindow => Icons.spa_outlined,
      HealthCalendarMarkerKind.ovulationTest => Icons.science_outlined,
      HealthCalendarMarkerKind.medication => Icons.medication_outlined,
      HealthCalendarMarkerKind.dailyLog => Icons.edit_note_rounded,
    };
  }
}
