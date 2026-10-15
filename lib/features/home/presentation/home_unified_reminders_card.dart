import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_unified_reminders_providers.dart';

/// 统一提醒卡：记账 / 待办 / 打卡 / 健康四类待处理事项汇到一处。
///
/// 无内容时整体不渲染（与旧提醒条一致）。
class HomeUnifiedRemindersCard extends StatelessWidget {
  const HomeUnifiedRemindersCard({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpenAll,
    required this.onTapItem,
    this.maxItems = 3,
  });

  final List<HomeReminderItem> items;
  final bool isLoading;
  final VoidCallback onOpenAll;
  final ValueChanged<HomeReminderItem> onTapItem;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final moneyColors = theme.moneyColors;
    // 卡片是「需要关注」，所以整块的前景都用深版（12px 小字守 4.5:1），
    // 淡底用实色容器；只有描边还留着半透明——那条线是用来划边界的，不是承载信息的。
    final accent = moneyColors.warningStrong;
    final visible = items.take(maxItems).toList(growable: false);

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      borderColor: moneyColors.warning.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: accent),
              const SizedBox(width: 7),
              Text(
                '需要关注',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: moneyColors.warningContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: accent,
                ),
                child: const Text('全部'),
              ),
            ],
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            for (var index = 0; index < visible.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.34,
                  ),
                ),
              _ReminderRow(
                item: visible[index],
                onTap: () => onTapItem(visible[index]),
              ),
            ],
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.item, required this.onTap});

  final HomeReminderItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(theme, item.severity);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_sourceIcon(item.source), size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      _SourceChip(label: _sourceLabel(item.source)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (item.amountMinor != null) ...[
              const SizedBox(width: 10),
              MoneyText(
                amountMinor: item.amountMinor!,
                currencyCode: item.currencyCode ?? 'CNY',
                tone: item.isIncome
                    ? MoneyAmountTone.income
                    : MoneyAmountTone.neutral,
                color: color,
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ] else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.outline,
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

IconData _sourceIcon(HomeReminderSource source) => switch (source) {
  HomeReminderSource.money => Icons.credit_card_rounded,
  HomeReminderSource.todo => Icons.task_alt_rounded,
  HomeReminderSource.habit => Icons.local_fire_department_rounded,
  HomeReminderSource.health => Icons.favorite_rounded,
};

String _sourceLabel(HomeReminderSource source) => switch (source) {
  HomeReminderSource.money => '记账',
  HomeReminderSource.todo => '待办',
  HomeReminderSource.habit => '打卡',
  HomeReminderSource.health => '健康',
};

Color _severityColor(ThemeData theme, HomeReminderSeverity severity) {
  return switch (severity) {
    HomeReminderSeverity.overdue => theme.colorScheme.error,
    HomeReminderSeverity.dueToday => theme.moneyColors.warning,
    HomeReminderSeverity.dueSoon => theme.colorScheme.primary,
    HomeReminderSeverity.normal => theme.colorScheme.secondary,
  };
}
