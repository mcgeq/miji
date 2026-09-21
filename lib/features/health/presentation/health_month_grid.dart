import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_theme.dart';

/// 月历网格。
///
/// 取代 `TableCalendar` 的「3 个 6px 圆点」：经期实心、预计经期虚线描边、
/// 易孕/经前浅色底，今天加 outline、选中加高亮。颜色全部走 [HealthPalette]。
class HealthMonthGrid extends StatelessWidget {
  const HealthMonthGrid({
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.markersByDay,
    required this.onDaySelected,
    super.key,
    this.periodTrackingEnabled = true,
  });

  /// 月份中的任意一天。
  final DateTime month;
  final DateTime selectedDay;
  final DateTime today;
  final Map<int, List<HealthCalendarMarker>> markersByDay;
  final ValueChanged<DateTime> onDaySelected;
  final bool periodTrackingEnabled;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final firstOfMonth = DateTime.utc(month.year, month.month, 1);
    final leading = firstOfMonth.weekday - 1;
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final cellCount = ((leading + daysInMonth) / 7).ceil() * 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leading));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final day = gridStart.add(Duration(days: index));
            return _DayCell(
              day: day,
              inMonth: day.month == month.month,
              selected: _isSameDay(day, selectedDay),
              isToday: _isSameDay(day, today),
              markers:
                  markersByDay[HealthDate.dayKey(day)] ??
                  const <HealthCalendarMarker>[],
              periodTrackingEnabled: periodTrackingEnabled,
              onTap: () => onDaySelected(day),
            );
          },
        ),
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.isToday,
    required this.markers,
    required this.periodTrackingEnabled,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool isToday;
  final List<HealthCalendarMarker> markers;
  final bool periodTrackingEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = HealthPalette.of(context);

    final hasActual = _has(HealthCalendarMarkerKind.actualPeriod);
    final hasPredicted = _has(HealthCalendarMarkerKind.predictedPeriod);
    final hasFertile = _has(HealthCalendarMarkerKind.fertileWindow);
    final hasPms = _has(HealthCalendarMarkerKind.pms);
    final hasOvulation = _has(HealthCalendarMarkerKind.ovulationTest);
    final hasLog =
        _has(HealthCalendarMarkerKind.dailyLog) ||
        _has(HealthCalendarMarkerKind.medication);

    final trackable = periodTrackingEnabled;
    final actual = trackable && hasActual;
    final predicted = trackable && !actual && hasPredicted;
    final fertile = trackable && !actual && !predicted && hasFertile;
    final pms = trackable && !actual && !predicted && !fertile && hasPms;

    Color background = Colors.transparent;
    Color foreground = inMonth
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.34);
    Border? border;
    if (actual) {
      background = palette.period;
      foreground = palette.onPhase(HealthCyclePhase.period);
    } else if (fertile) {
      background = palette.phaseSurface(HealthCyclePhase.fertile);
      foreground = palette.fertile;
    } else if (pms) {
      background = palette.phaseSurface(HealthCyclePhase.pms);
      foreground = palette.pms;
    }
    if (predicted) {
      border = Border.all(color: palette.period, width: 1.4);
      foreground = palette.period;
    }

    final decorated = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 12.5,
            fontWeight: actual || predicted || selected
                ? FontWeight.w800
                : FontWeight.w600,
            color: foreground,
            letterSpacing: 0,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${day.month}月${day.day}日',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: CustomPaint(
          painter: predicted
              ? _DashedBorderPainter(color: palette.period)
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : isToday
                        ? Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.55),
                            width: 1.6,
                          )
                        : border,
                  ),
                ),
              ),
              Positioned.fill(child: decorated),
              if (hasOvulation && !actual)
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.ovulation,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              if (hasLog)
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _has(HealthCalendarMarkerKind kind) {
    return markers.any((marker) => marker.kind == kind);
  }
}

/// 虚线圆角边框，用于「预计经期」。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final radius = Radius.circular(math.min(12, size.shortestSide / 2));
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
          radius,
        ),
      );
    canvas.drawPath(_dashPath(path), paint);
  }

  Path _dashPath(Path source, {double dashWidth = 4, double dashSpace = 3}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        result.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + dashSpace;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
