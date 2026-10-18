import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';

/// 状态徽章。列表卡片和详情页共用，避免两处文案各写一套。
class WishlistStatusChip extends StatelessWidget {
  const WishlistStatusChip({
    super.key,
    required this.status,
    required this.entry,
    required this.now,
  });

  final WishlistItemStatus status;
  final WishlistEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final money = theme.moneyColors;
    final (fg, bg) = switch (status) {
      WishlistItemStatus.waiting => (
        money.warningStrong,
        money.warningContainer,
      ),
      WishlistItemStatus.ready => (money.incomeStrong, money.incomeContainer),
      WishlistItemStatus.bought || WishlistItemStatus.dropped => (
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHigh,
      ),
    };
    final text = switch (status) {
      WishlistItemStatus.waiting => '冷却中 · 还有 ${entry.cooldownDaysLeft(now)} 天',
      WishlistItemStatus.ready => '可以决定了',
      WishlistItemStatus.bought => '已买',
      WishlistItemStatus.dropped => '已放弃',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
