import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/checkin_plan_style.dart';

/// 计划的小图标（一枚圆角底 + emoji）。
///
/// 为什么不直接 `Text(plan.icon, fontSize: 24)`：
/// - `icon` 的默认值是「📌」，于是每个没挑过图标的计划前面都挂着一枚图钉，
///   比计划名还抢眼，且不传达任何信息；
/// - 同一个 emoji 曾在 20 / 22 / 24 / 28px 四处各画一次，字号与基线都不一致。
///
/// 统一成 26px 圆角底之后：图钉（历史默认值）按分类换成默认 emoji，用户真正
/// 挑过的 emoji 原样保留、缩到 14px，底色统一。
class CheckinPlanIcon extends StatelessWidget {
  const CheckinPlanIcon({
    super.key,
    required this.icon,
    required this.category,
    this.colorHex,
    this.size = 26,
  });

  CheckinPlanIcon.forPlan(CheckinPlan? plan, {Key? key, double size = 26})
    : this(
        key: key,
        icon: plan?.icon ?? legacyDefaultPlanIcon,
        category: plan?.category ?? CheckinPlanCategory.other,
        colorHex: plan?.color,
        size: size,
      );

  final String icon;
  final CheckinPlanCategory category;

  /// 计划颜色（`#RRGGBB`）。null / 坏值 → 按分类的默认色。
  ///
  /// 底色跟着计划颜色走，是因为计划列表里一水的灰底会让「哪个是哪个」全靠
  /// emoji 分辨；旧计划没有颜色也不需要迁移，渲染时给分类默认色即可。
  final String? colorHex;

  /// 圆角底边长。emoji 按它的 0.55 缩放。
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emoji = resolvePlanEmoji(icon: icon, category: category);
    final tint = planColorValue(
      planVisualFor(icon: icon, category: category, color: colorHex).colorHex,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.7)
            : Color(tint).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.55, height: 1)),
    );
  }
}
