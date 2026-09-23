import 'package:flutter/material.dart';

/// 图表统一语言。
///
/// 统计页 18 类卡片里有 8 类含图表，它们的「现代感」几乎完全由样式决定。
/// 之前每个图表各写一套参数（有的圆角 4、有的没有圆角、有的纯色、都没有入场
/// 动画），放在这里统一，后续新增图表也只引用这一份。
class MoneyChartStyle {
  const MoneyChartStyle._();

  /// 首次入场动画：统一 320ms，避免每张卡节奏不同。
  static const animationDuration = Duration(milliseconds: 320);
  static const animationCurve = Curves.easeOutCubic;

  /// 柱状图：顶部圆角 + 纵向渐变（实色 → 30% 透明）。
  static const barRadius = BorderRadius.vertical(top: Radius.circular(8));
  static const barMinWidth = 6.0;

  static LinearGradient barGradient(Color color) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color, color.withValues(alpha: 0.34)],
    );
  }

  /// 折线图下方的填充：主色 → 透明。
  static LinearGradient areaGradient(Color color) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
    );
  }

  /// 折线：略粗一点，触摸时显示圆点。
  static const lineWidth = 2.6;

  /// 饼图：扇区间距 + 圆角，观感更柔和。
  static const pieSectionsSpace = 3.0;
  static const pieCornerRadius = 6.0;
  static const pieStartDegreeOffset = -90.0;
}
