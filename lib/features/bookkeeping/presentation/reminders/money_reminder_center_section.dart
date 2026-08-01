import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class MoneyReminderCenterSection extends ConsumerWidget {
  const MoneyReminderCenterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(currentUserPendingReminderCenterItemsProvider);
    final history = ref.watch(currentUserReminderCenterHistoryProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => AppErrorState(
        title: '读取提醒中心失败',
        onRetry: () =>
            ref.invalidate(currentUserPendingReminderCenterItemsProvider),
      ),
      data: (pendingItems) {
        return history.when(
          loading: () => _ReminderCenterList(
            pendingItems: pendingItems,
            historyItems: const <MoneyReminderCenterItem>[],
            historyLoading: true,
          ),
          error: (_, _) => _ReminderCenterList(
            pendingItems: pendingItems,
            historyItems: const <MoneyReminderCenterItem>[],
            historyError: true,
          ),
          data: (historyItems) => _ReminderCenterList(
            pendingItems: pendingItems,
            historyItems: historyItems,
          ),
        );
      },
    );
  }
}

class _ReminderCenterList extends ConsumerWidget {
  const _ReminderCenterList({
    required this.pendingItems,
    required this.historyItems,
    this.historyLoading = false,
    this.historyError = false,
  });

  final List<MoneyReminderCenterItem> pendingItems;
  final List<MoneyReminderCenterItem> historyItems;
  final bool historyLoading;
  final bool historyError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        AppContentPanel(
          title: '待处理提醒',
          subtitle: pendingItems.isEmpty ? '暂无需要处理的事项' : '按紧急程度排序',
          leadingIcon: Icons.notifications_active_rounded,
          child: pendingItems.isEmpty
              ? const AppEmptyState(title: '暂无待处理提醒')
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < pendingItems.length;
                      index++
                    ) ...[
                      _ReminderCenterCard(
                        item: pendingItems[index],
                        enabledActions: true,
                      ),
                      if (index != pendingItems.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          title: '处理历史',
          subtitle: historyLoading
              ? '正在读取'
              : historyError
              ? '读取失败'
              : historyItems.isEmpty
              ? '暂无历史记录'
              : '最近处理过的提醒',
          leadingIcon: Icons.history_rounded,
          child: historyLoading
              ? const Center(child: CircularProgressIndicator())
              : historyError
              ? AppErrorState(
                  title: '读取历史失败',
                  onRetry: () =>
                      ref.invalidate(currentUserReminderCenterHistoryProvider),
                )
              : historyItems.isEmpty
              ? const AppEmptyState(title: '暂无处理历史')
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < historyItems.length;
                      index++
                    ) ...[
                      _ReminderCenterCard(
                        item: historyItems[index],
                        enabledActions: false,
                      ),
                      if (index != historyItems.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReminderCenterCard extends ConsumerWidget {
  const _ReminderCenterCard({required this.item, required this.enabledActions});

  final MoneyReminderCenterItem item;
  final bool enabledActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.read(currentUserReminderCenterActionsProvider);
    final child = AppListItemPanel(
      padding: const EdgeInsets.all(12),
      child: _ReminderCenterCardContent(item: item),
    );
    if (!enabledActions) {
      return child;
    }

    return AppSwipeActionTile(
      actions: [
        AppSwipeAction(
          tooltip: '完成',
          icon: Icons.check_circle_outline_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: () => actions.complete(item),
        ),
        AppSwipeAction(
          tooltip: '延后一天',
          icon: Icons.schedule_rounded,
          foreground: colorScheme.onSecondaryContainer,
          background: colorScheme.secondaryContainer,
          onPressed: () => actions.snoozeOneDay(item),
        ),
        AppSwipeAction(
          tooltip: '忽略',
          icon: Icons.block_rounded,
          foreground: colorScheme.onErrorContainer,
          background: colorScheme.errorContainer,
          onPressed: () => actions.ignore(item),
        ),
      ],
      child: child,
    );
  }
}

class _ReminderCenterCardContent extends StatelessWidget {
  const _ReminderCenterCardContent({required this.item});

  final MoneyReminderCenterItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priority = item.priority(today: DateTime.now());
    final color = _priorityColor(colorScheme, priority);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppListItemIcon(icon: _sourceIcon(item.sourceType), color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_priorityLabel(priority)} · 到期 ${DateFormat('MM-dd').format(item.dueDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatMoneyMinor(item.amountMinor, item.currencyCode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

IconData _sourceIcon(MoneyReminderCenterSourceType sourceType) {
  return switch (sourceType) {
    MoneyReminderCenterSourceType.budget => Icons.flag_rounded,
    MoneyReminderCenterSourceType.creditCardBill => Icons.credit_card_rounded,
    MoneyReminderCenterSourceType.installment => Icons.calendar_month_rounded,
    MoneyReminderCenterSourceType.recurringExpense => Icons.repeat_rounded,
    MoneyReminderCenterSourceType.billReminder =>
      Icons.notifications_active_rounded,
  };
}

String _priorityLabel(MoneyReminderCenterPriority priority) {
  return switch (priority) {
    MoneyReminderCenterPriority.overdue => '已逾期',
    MoneyReminderCenterPriority.dueWithinThreeDays => '3 天内到期',
    MoneyReminderCenterPriority.budgetExceeded => '预算提醒',
    MoneyReminderCenterPriority.normal => '普通提醒',
  };
}

Color _priorityColor(
  ColorScheme colorScheme,
  MoneyReminderCenterPriority priority,
) {
  return switch (priority) {
    MoneyReminderCenterPriority.overdue => colorScheme.error,
    MoneyReminderCenterPriority.dueWithinThreeDays => colorScheme.primary,
    MoneyReminderCenterPriority.budgetExceeded => colorScheme.tertiary,
    MoneyReminderCenterPriority.normal => colorScheme.secondary,
  };
}
