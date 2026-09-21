import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';

/// 折线图。
///
/// 现状的问题：只有一条曲线，没有数值、没有基准、y 轴从 `min-2` 起会让波动
/// 被夸大。这里补齐：数据点数值、平均值虚线、可选的正常区间底色。
class HealthTrendLineChart extends StatelessWidget {
  const HealthTrendLineChart({
    required this.points,
    required this.emptyLabel,
    super.key,
    this.unitSuffix = '',
    this.normalRange,
  });

  final List<HealthTrendPoint> points;
  final String emptyLabel;
  final String unitSuffix;

  /// 正常区间 [min, max]，画成浅色底。
  final (int, int)? normalRange;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _EmptyChart(label: emptyLabel);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final values = points.map((point) => point.value).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 172,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              lineColor: colorScheme.primary,
              bandColor: colorScheme.secondary.withValues(alpha: 0.12),
              averageColor: colorScheme.tertiary.withValues(alpha: 0.8),
              gridColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
              labelStyle:
                  theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ) ??
                  const TextStyle(fontSize: 11),
              normalRange: normalRange,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _AxisLabels(labels: points.map((point) => point.label).toList()),
        if (unitSuffix.isNotEmpty || normalRange != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (normalRange != null)
                _LegendDot(
                  color: colorScheme.secondary.withValues(alpha: 0.5),
                  label:
                      '正常范围 ${normalRange!.$1}–${normalRange!.$2}$unitSuffix',
                ),
              _LegendDash(
                color: colorScheme.tertiary.withValues(alpha: 0.8),
                label: '平均值 ${_average(values)}$unitSuffix',
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _average(List<int> values) {
    if (values.isEmpty) {
      return '-';
    }
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final average = total / values.length;
    return average == average.roundToDouble()
        ? average.toStringAsFixed(0)
        : average.toStringAsFixed(1);
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.bandColor,
    required this.averageColor,
    required this.gridColor,
    required this.labelStyle,
    this.normalRange,
  });

  final List<int> values;
  final Color lineColor;
  final Color bandColor;
  final Color averageColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final (int, int)? normalRange;

  static const _left = 10.0;
  static const _right = 10.0;
  static const _top = 24.0;
  static const _bottom = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
    final candidates = <int>[...values];
    if (normalRange != null) {
      candidates.addAll([normalRange!.$1, normalRange!.$2]);
    }
    var minValue = candidates.reduce(math.min);
    var maxValue = candidates.reduce(math.max);
    if (minValue == maxValue) {
      minValue -= 1;
      maxValue += 1;
    }
    final padding = math.max(1, ((maxValue - minValue) * 0.25).round());
    final yMin = minValue - padding;
    final yMax = maxValue + padding;

    final chartWidth = size.width - _left - _right;
    final chartHeight = size.height - _top - _bottom;

    double yFor(num value) {
      final ratio = (value - yMin) / (yMax - yMin);
      return _top + chartHeight * (1 - ratio);
    }

    double xFor(int index) {
      if (values.length == 1) {
        return _left + chartWidth / 2;
      }
      return _left + chartWidth * index / (values.length - 1);
    }

    // 网格线
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i += 1) {
      final y = _top + chartHeight * i / 3;
      canvas.drawLine(
        Offset(_left, y),
        Offset(size.width - _right, y),
        gridPaint,
      );
    }

    // 正常区间底色
    if (normalRange != null) {
      final top = yFor(normalRange!.$2);
      final bottom = yFor(normalRange!.$1);
      canvas.drawRect(
        Rect.fromLTRB(_left, top, size.width - _right, bottom),
        Paint()..color = bandColor,
      );
    }

    // 平均线
    final average = values.reduce((a, b) => a + b) / values.length;
    _drawDashedLine(
      canvas,
      Offset(_left, yFor(average)),
      Offset(size.width - _right, yFor(average)),
      averageColor,
    );

    // 折线
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < values.length; i += 1) {
      final point = Offset(xFor(i), yFor(values[i]));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // 数据点 + 数值
    final dotPaint = Paint()..color = lineColor;
    final holePaint = Paint()..color = const Color(0xFFFFFFFF);
    for (var i = 0; i < values.length; i += 1) {
      final point = Offset(xFor(i), yFor(values[i]));
      canvas.drawCircle(point, 4.5, dotPaint);
      canvas.drawCircle(point, 2, holePaint);
      final painter = TextPainter(
        text: TextSpan(text: '${values[i]}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(point.dx - painter.width / 2, point.dy - 22),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const dash = 5.0;
    const gap = 4.0;
    final total = (end - start).distance;
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final next = math.min(distance + dash, total);
      canvas.drawLine(
        start + direction * distance,
        start + direction * next,
        paint,
      );
      distance = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.normalRange != normalRange ||
        oldDelegate.lineColor != lineColor;
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0,
    );
    // 点多的时候只显示首、中、尾，避免标签重叠。
    final List<int> indices = labels.length <= 4
        ? List.generate(labels.length, (index) => index)
        : [0, labels.length ~/ 2, labels.length - 1];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < indices.length; i += 1)
          Text(labels[indices[i]], style: style),
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
          width: 10,
          height: 10,
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
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LegendDash extends StatelessWidget {
  const _LegendDash({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 16, height: 2, child: ColoredBox(color: color)),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// 分布条形图。现状只显示「x 天」，这里补上占比。
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
    final total = buckets.fold<int>(0, (sum, bucket) => sum + bucket.count);
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
                  width: 76,
                  child: Text(
                    labelFor(bucket.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                SizedBox(
                  width: 62,
                  child: Text(
                    total == 0
                        ? '${bucket.count}'
                        : '${bucket.count} · ${(bucket.count * 100 / total).round()}%',
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
