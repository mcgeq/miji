import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 清单顶部的汇总：「5 件 · 合计 ¥10,277 · 22.0 个工作日」。
///
/// 为什么不逐行加总金额就完事：五个数字相加的回答是「一共多少钱」，而这里要
/// 回答的是「如果全买下来，要付出多少生命」。一个小额高频的清单加起来可能只是
/// 几百块，换成天数却是一个月工资的大半 —— 那才是能改变决定的那个数字。
@immutable
class WishlistInsight {
  const WishlistInsight({
    required this.activeCount,
    required this.totalAmountMinor,
    required this.totalWorkdays,
    required this.waitingCount,
    required this.readyCount,
    required this.daysKnown,
  });

  /// 还没结束（冷却中 + 可以决定）的件数。
  final int activeCount;

  final int totalAmountMinor;

  /// 折成的工作日合计。档案没配好时是 0，用 [daysKnown] 区分「真的是 0 天」。
  final double totalWorkdays;

  /// 是否有可用的换算（档案已配置）。false 时界面不显示天数。
  final bool daysKnown;

  final int waitingCount;
  final int readyCount;

  factory WishlistInsight.from({
    required List<WishlistEntry> entries,
    required WorkProfile? profile,
    required DateTime now,
  }) {
    var activeCount = 0;
    var totalAmountMinor = 0;
    var totalWorkdays = 0.0;
    var waitingCount = 0;
    var readyCount = 0;
    var daysKnown = profile?.isConfigured ?? false;

    for (final entry in entries) {
      final status = entry.statusAt(now);
      if (status.isSettled) {
        continue;
      }
      activeCount++;
      totalAmountMinor += entry.targetAmountMinor;
      if (status == WishlistItemStatus.waiting) {
        waitingCount++;
      } else {
        readyCount++;
      }
      final days = entry.daysFor(profile ?? WorkProfile.blank(entry.userId));
      if (days != null) {
        totalWorkdays += days;
      } else {
        daysKnown = false;
      }
    }

    return WishlistInsight(
      activeCount: activeCount,
      totalAmountMinor: totalAmountMinor,
      totalWorkdays: totalWorkdays,
      waitingCount: waitingCount,
      readyCount: readyCount,
      daysKnown: daysKnown,
    );
  }
}
