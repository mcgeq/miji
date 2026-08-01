import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';

class HomeUrgentRemindersPanel extends StatelessWidget {
  const HomeUrgentRemindersPanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpenAll,
  });

  final List<MoneyReminderCenterItem> items;
  final bool isLoading;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && items.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppContentPanel(
      title: '紧急提醒',
      leadingIcon: Icons.notifications_active_rounded,
      trailing: TextButton(onPressed: onOpenAll, child: const Text('全部')),
      keepTrailingInlineOnCompact: true,
      child: isLoading && items.isEmpty
          ? const SizedBox(height: 72, child: LinearProgressIndicator())
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _UrgentReminderRow(item: items[index]),
                  if (index != items.length - 1)
                    Divider(
                      height: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.36),
                    ),
                ],
              ],
            ),
    );
  }
}

class _UrgentReminderRow extends StatelessWidget {
  const _UrgentReminderRow({required this.item});

  final MoneyReminderCenterItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor(
      theme.colorScheme,
      item.priority(today: DateTime.now()),
    );

    return Row(
      children: [
        Icon(_sourceIcon(item.sourceType), size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '到期 ${DateFormat('MM-dd').format(item.dueDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatMoneyMinor(item.amountMinor, item.currencyCode),
          style: theme.textTheme.bodyMedium?.copyWith(
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
