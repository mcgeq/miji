import 'package:flutter/material.dart';

/// 账户卡 / 账户弹窗共用的细进度条。
///
/// 两处都要画「已用额度」「已还本金」这类比例，之前各写一份
/// `ClipRRect + LinearProgressIndicator`，圆角与最小高度很容易走偏。
class AccountProgressBar extends StatelessWidget {
  const AccountProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.trackColor,
    this.height = 8,
  });

  /// 0~1，超出会被夹到 1（条画满，文案另行说明超出多少）。
  final double value;
  final Color color;

  /// 轨道色；不传则用 [color] 的 14% 淡染。
  final Color? trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color,
        backgroundColor: trackColor ?? color.withValues(alpha: 0.14),
      ),
    );
  }
}
