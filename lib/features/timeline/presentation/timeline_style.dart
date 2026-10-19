import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';

/// 模块配色。
///
/// 时间线页与首页「接下来」共用同一套颜色：同一件事在两个地方必须是同一个颜色，
/// 否则用户会以为「接下来」里的信用卡还款和时间线里的不是一回事。
Color timelineModuleColor(ThemeData theme, TimelineModule module) {
  return switch (module) {
    TimelineModule.money => const Color(0xFF2C6E93),
    TimelineModule.health => theme.moneyColors.credit,
    TimelineModule.action => theme.moneyColors.income,
    TimelineModule.lifeEnergy => theme.moneyColors.warning,
  };
}

/// 模块图标。
///
/// 行动模块一分为二：待办是勾，打卡是火。它们都是 `TimelineModule.action`，
/// 只按 module 取图标会得到两个一模一样的勾。
IconData timelineEventIcon(TimelineEvent event) {
  return switch (event.module) {
    TimelineModule.money => switch (event.kind) {
      'commitment.installment' => Icons.credit_score_rounded,
      'commitment.autoPosting' => Icons.autorenew_rounded,
      'commitment.pendingTransaction' => Icons.schedule_rounded,
      _ => Icons.account_balance_wallet_rounded,
    },
    TimelineModule.action => switch (event.kind) {
      'todoDue' || 'todoCompleted' => Icons.task_alt_rounded,
      _ => Icons.local_fire_department_rounded,
    },
    TimelineModule.health => Icons.favorite_rounded,
    TimelineModule.lifeEnergy => Icons.bolt_rounded,
  };
}
