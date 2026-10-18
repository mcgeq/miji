import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 今日行右侧那枚「进度环」：既是进度，也是「打卡」按钮。
///
/// 为什么把进度和按钮合成一个东西：原来进度是行尾一条 4px 的细条，而打卡要
/// 进详情页 —— 用户在两个位置各找一半。合起来之后，看一眼就知道走到哪，
/// 按一下就走一步，不需要第二枚控件。
class HabitCheckinRing extends StatelessWidget {
  const HabitCheckinRing({
    super.key,
    required this.rate,
    required this.label,
    required this.color,
    required this.completed,
    this.onTap,
    this.semanticLabel,
    this.size = 38,
  });

  /// 0～1 的完成度。
  final double rate;

  /// 环里的数字。null 表示不留字（目标为 1 的计划：只在达标时画勾）。
  final String? label;

  /// 未达标时的环色（计划颜色）。
  final Color color;

  final bool completed;
  final VoidCallback? onTap;

  /// 无障碍/测试用的说明，例如「喝水，今天 3 / 8 杯」。
  final String? semanticLabel;

  /// 环的直径。点击区域固定 44，手指不用瞄准。
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.colorScheme.surfaceContainerHighest;
    final activeColor = completed ? _doneColor : color;

    final ring = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: rate.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: activeColor,
              track: trackColor,
            ),
            child: Center(
              child: Container(
                width: size - 8,
                height: size - 8,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? activeColor : theme.colorScheme.surface,
                ),
                child: completed
                    ? Icon(
                        Icons.check_rounded,
                        size: size * 0.42,
                        color: Colors.white,
                      )
                    : Text(
                        label ?? '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          height: 1,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: label == null
                              ? Colors.transparent
                              : theme.colorScheme.onSurface,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: math.max(size + 6, 44),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: InkResponse(
              onTap: onTap,
              radius: math.max(size, 44) / 2,
              containedInkWell: false,
              child: ring,
            ),
          ),
        ),
      ),
    );
  }

  /// 达标用的绿色。
  ///
  /// 不走主题的 primary：完成态要在两种种子色下都能被认成「绿」，用固定的
  /// 语义色比跟随品牌色更稳（记账模块的收入色也是这套语义）。
  static Color get _doneColor => const Color(0xFF0E7A48);
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  static const double _stroke = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - _stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
  }
}
