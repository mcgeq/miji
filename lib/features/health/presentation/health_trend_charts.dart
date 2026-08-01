import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';

class HealthTrendLineChart extends StatelessWidget {
  const HealthTrendLineChart({
    required this.points,
    required this.emptyLabel,
    super.key,
  });

  final List<HealthTrendPoint> points;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _EmptyChart(label: emptyLabel);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final values = points.map((point) => point.value).toList();
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final yPadding = math.max(2, ((maxValue - minValue) * 0.18).round());

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: math.max(0, minValue - yPadding),
          maxY: maxValue + yPadding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.42),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) => Text(
                  value.round().toString(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[index].label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i += 1)
                  FlSpot(i.toDouble(), points[i].value.toDouble()),
              ],
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthTrendBucketBars<T> extends StatelessWidget {
  const HealthTrendBucketBars({
    required this.buckets,
    required this.labelFor,
    required this.emptyLabel,
    super.key,
  });

  final List<HealthTrendBucket<T>> buckets;
  final String Function(T value) labelFor;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return _EmptyChart(label: emptyLabel);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxCount = buckets
        .map((bucket) => bucket.count)
        .fold<int>(0, math.max)
        .clamp(1, 1 << 30);

    return Column(
      children: [
        for (final bucket in buckets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Text(
                    labelFor(bucket.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: bucket.count / maxCount,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${bucket.count} 天',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
