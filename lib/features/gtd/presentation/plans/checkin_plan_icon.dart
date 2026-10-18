import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';

/// 计划的小图标。
///
/// 为什么不再直接画 emoji：`icon` 的默认值一直是「📌」，于是每个没挑过图标的
/// 计划前面都挂着一枚图钉 —— 24px 的彩色 emoji 在列表里比标题还抢眼，而它
/// 传达的信息是零（图钉不是任何人的习惯）。
///
/// 现在分两种情况：
/// - `icon` 是旧默认值（`📌`）、空值：按**分类**给一个 Material 图标；
/// - 用户自己挑过 emoji：照常显示，但缩到 14px 放进同一枚圆角底里。
///
/// 旧数据不迁移：把「📌」当成「没选过」在渲染层处理，比改库安全 —— 用户真的
/// 想要图钉时，表单里仍然能选回来（那时它会被当成用户的选择）。
class CheckinPlanIcon extends StatelessWidget {
  const CheckinPlanIcon({super.key, required this.plan, this.size = 26});

  final CheckinPlan? plan;

  /// 圆角底边长。图标按它的 0.6 缩放。
  final double size;

  /// 历史默认值，等同「没选过图标」。
  static const legacyDefaultIcon = '📌';

  static IconData iconForCategory(String category) {
    return switch (category) {
      '健康习惯' => Icons.local_drink_outlined,
      '学习成长' => Icons.menu_book_outlined,
      '运动' => Icons.directions_run_rounded,
      '生活记录' => Icons.photo_camera_outlined,
      '纪念日' => Icons.cake_outlined,
      _ => Icons.check_circle_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // `icon` 本身是非空的（默认就是「📌」），所以只有 `plan` 可空。
    final raw = plan?.icon.trim() ?? '';
    final chosen = raw.isNotEmpty && raw != legacyDefaultIcon;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      ),
      child: chosen
          ? Text(
              raw,
              style: TextStyle(fontSize: size * 0.55, height: 1),
            )
          : Icon(
              iconForCategory(plan?.category ?? ''),
              size: size * 0.62,
              color: scheme.onSurfaceVariant,
            ),
    );
  }
}
