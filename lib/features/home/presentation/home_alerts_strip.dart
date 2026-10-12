import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 紧急提醒条。
///
/// 原来的「紧急提醒」整卡被压缩为条带：最多展示 [maxItems] 条 + 全部入口。
/// 无数据时整体不渲染，避免长期占据首屏。
class HomeAlertsStrip extends StatelessWidget {
  const HomeAlertsStrip({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpenAll,
    this.maxItems = 2,
  });

  final List<MoneyReminderCenterItem> items;
  final bool isLoading;
  final VoidCallback onOpenAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final warning = theme.moneyColors.warning;
    final visible = items.take(maxItems).toList(growable: false);

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      borderColor: warning.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: warning),
              const SizedBox(width: 7),
              Text(
                '需要关注',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: warning,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 7),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: warning,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: warning,
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
              const SizedBox(height: 8),
              _AlertRow(item: visible[index]),
            ],
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.item});

  final MoneyReminderCenterItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgets = ref
        .watch(currentUserBudgetsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <MoneyBudgetEntity>[],
        );
    final isIncome = item.isIncomeAmount(budgets);
    final color = _priorityColor(
      theme.colorScheme,
      item.priority(today: DateTime.now()),
    );

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(_sourceIcon(item.sourceType), size: 15, color: color),
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
              Text(
                '${DateFormat('MM-dd').format(item.dueDate)} 到期',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        MoneyText(
          amountMinor: item.amountMinor,
          currencyCode: item.currencyCode,
          tone: isIncome ? MoneyAmountTone.income : MoneyAmountTone.neutral,
          color: color,
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
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
