import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';

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

  @override
  Widget build(BuildContext context) {
    final visibleMarkers = periodTrackingEnabled
        ? markers
        : markers.where((marker) {
            return marker.kind != HealthCalendarMarkerKind.actualPeriod &&
                marker.kind != HealthCalendarMarkerKind.predictedPeriod &&
                marker.kind != HealthCalendarMarkerKind.pms &&
                marker.kind != HealthCalendarMarkerKind.fertileWindow;
          }).toList();
    final grouped = _groupMarkers(visibleMarkers);
    final selectedMarkers =
        grouped[_dayKey(selectedDay)] ?? const <HealthCalendarMarker>[];
    final firstDay = DateTime.utc(focusedDay.year - 1, 1);
    final lastDay = DateTime.utc(focusedDay.year + 1, 12, 31);
    final hasOpenPeriod = visibleMarkers.any(
      (m) => m.kind == HealthCalendarMarkerKind.actualPeriod,
    );
    final isPregnant = todaySnapshot?.activePregnancy != null;
    final phaseMap = _buildPhaseMap(visibleMarkers);
    final isTodaySelected = isSameDay(selectedDay, DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCalendar(context, firstDay, lastDay, grouped, phaseMap),
        const SizedBox(height: 16),
        if (isTodaySelected && todaySnapshot != null)
          _TodayPredictionPanel(snapshot: todaySnapshot!),
        if (isTodaySelected && todaySnapshot != null)
          const SizedBox(height: 12),
        _SelectedDayPanel(
          selectedDay: selectedDay,
          markers: selectedMarkers,
          hasOpenPeriod: hasOpenPeriod,
          isPregnant: isPregnant,
          onQuickAction: onQuickAction,
          onEditDailyLog: onEditDailyLog,
          periodTrackingEnabled: periodTrackingEnabled,
          dailyLog: isTodaySelected && todaySnapshot != null
              ? todaySnapshot!.dailyLog
              : null,
        ),
      ],
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    DateTime firstDay,
    DateTime lastDay,
    Map<DateTime, List<HealthCalendarMarker>> grouped,
    Map<DateTime, _PhaseColor> phaseMap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TableCalendar<HealthCalendarMarker>(
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(day, selectedDay),
          eventLoader: (day) =>
              grouped[_dayKey(day)] ?? const <HealthCalendarMarker>[],
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) =>
                '${date.year}年${date.month.toString().padLeft(2, '0')}月',
            titleTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: 0,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
            todayTextStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
            defaultTextStyle: TextStyle(
              color: colorScheme.onSurface,
              letterSpacing: 0,
            ),
            weekendTextStyle: TextStyle(
              color: colorScheme.onSurface,
              letterSpacing: 0,
            ),
            cellMargin: const EdgeInsets.all(2),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            dowTextFormatter: (date, locale) {
              const labels = ['', '一', '二', '三', '四', '五', '六', '日'];
              return labels[date.weekday];
            },
            weekdayStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            weekendStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          calendarBuilders: CalendarBuilders<HealthCalendarMarker>(
            markerBuilder: (context, day, dayMarkers) {
              if (dayMarkers.isEmpty) return const SizedBox.shrink();
              return Positioned(
                bottom: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final marker in dayMarkers.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: markerColor(
                            marker.kind,
                            Theme.of(context).colorScheme,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            defaultBuilder: (context, day, focusedDay) {
              final key = _dayKey(day);
              final phase = phaseMap[key];
              if (phase == null) return null;
              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: phase.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<DateTime, _PhaseColor> _buildPhaseMap(List<HealthCalendarMarker> source) {
    final map = <DateTime, _PhaseColor>{};
    for (final marker in source) {
      final key = _dayKey(marker.date);
      final existing = map[key];
      if (existing != null &&
          existing.priority <= _phasePriority(marker.kind)) {
        continue;
      }
      map[key] = _PhaseColor(
        color: _phaseColor(marker.kind),
        priority: _phasePriority(marker.kind),
      );
    }
    return map;
  }

  Color _phaseColor(HealthCalendarMarkerKind kind) {
    return switch (kind) {
      HealthCalendarMarkerKind.actualPeriod => const Color(0xFFE57373),
      HealthCalendarMarkerKind.predictedPeriod => const Color(0xFFEF9A9A),
      HealthCalendarMarkerKind.fertileWindow => const Color(0xFF81C784),
      HealthCalendarMarkerKind.pms => const Color(0xFFCE93D8),
      HealthCalendarMarkerKind.ovulationTest => const Color(0xFF64B5F6),
      HealthCalendarMarkerKind.medication => const Color(0xFFA1887F),
      HealthCalendarMarkerKind.dailyLog => const Color(0xFFBDBDBD),
    };
  }

  int _phasePriority(HealthCalendarMarkerKind kind) {
    return switch (kind) {
      HealthCalendarMarkerKind.actualPeriod => 0,
      HealthCalendarMarkerKind.predictedPeriod => 1,
      HealthCalendarMarkerKind.fertileWindow => 2,
      HealthCalendarMarkerKind.pms => 3,
      HealthCalendarMarkerKind.ovulationTest => 4,
      HealthCalendarMarkerKind.medication => 5,
      HealthCalendarMarkerKind.dailyLog => 6,
    };
  }

  Map<DateTime, List<HealthCalendarMarker>> _groupMarkers(
    List<HealthCalendarMarker> source,
  ) {
    final grouped = <DateTime, List<HealthCalendarMarker>>{};
    for (final marker in source) {
      (grouped[_dayKey(marker.date)] ??= <HealthCalendarMarker>[]).add(marker);
    }
    return grouped;
  }

  DateTime _dayKey(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}

class _PhaseColor {
  const _PhaseColor({required this.color, required this.priority});
  final Color color;
  final int priority;
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.selectedDay,
    required this.markers,
    required this.hasOpenPeriod,
    required this.isPregnant,
    required this.onQuickAction,
    required this.onEditDailyLog,
    this.dailyLog,
    this.periodTrackingEnabled = true,
  });

  final DateTime selectedDay;
  final List<HealthCalendarMarker> markers;
  final bool periodTrackingEnabled;
  final bool hasOpenPeriod;
  final bool isPregnant;
  final ValueChanged<HealthQuickAction> onQuickAction;
  final VoidCallback onEditDailyLog;
  final HealthDailyLog? dailyLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthDay = '${selectedDay.month}月${selectedDay.day}日';
    final weekday = _weekdayLabel(selectedDay.weekday);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, colorScheme, monthDay, weekday),
          const Divider(height: 1),
          if (markers.isEmpty && dailyLog == null)
            _buildEmptyState(theme, colorScheme)
          else ...[
            if (markers.isNotEmpty) _buildMarkerList(context),
            if (dailyLog != null && dailyLog!.visibleRecordCount > 0)
              _buildSummary(context, theme, colorScheme),
          ],
          const Divider(height: 1),
          _buildQuickActions(context, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    String monthDay,
    String weekday,
  ) {
    final isToday = isSameDay(selectedDay, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            monthDay,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '周$weekday',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '今天',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 28,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              '暂无记录',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final marker in markers)
            _MarkerChip(kind: marker.kind, label: marker.label),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final action in HealthQuickAction.values)
            if (_actionVisible(action))
              _CalendarQuickChip(
                action: action,
                label: quickActionLabel(action, hasOpenPeriod),
                onPressed: () {
                  if (action == HealthQuickAction.more) {
                    onEditDailyLog();
                  }
                  onQuickAction(action);
                },
              ),
        ],
      ),
    );
  }

  bool _actionVisible(HealthQuickAction action) {
    if (!periodTrackingEnabled && action == HealthQuickAction.period) {
      return false;
    }
    if (!isPregnant) return true;
    return switch (action) {
      HealthQuickAction.period => false,
      HealthQuickAction.flow => false,
      HealthQuickAction.ovulationTest => false,
      _ => true,
    };
  }

  Widget _buildSummary(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final log = dailyLog!;
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

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Container(
              constraints: const BoxConstraints(minWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.54),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
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
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['', '一', '二', '三', '四', '五', '六', '日'];
    return labels[weekday];
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _TodayPredictionPanel extends StatelessWidget {
  const _TodayPredictionPanel({required this.snapshot});

  final HealthTodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.today_rounded, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final indicator in snapshot.prediction.indicators)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      indicator,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.kind, required this.label});

  final HealthCalendarMarkerKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = markerColor(kind, colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_markerIcon(kind), size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  IconData _markerIcon(HealthCalendarMarkerKind kind) {
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

class _CalendarQuickChip extends StatelessWidget {
  const _CalendarQuickChip({
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

    return Material(
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
    );
  }
}
