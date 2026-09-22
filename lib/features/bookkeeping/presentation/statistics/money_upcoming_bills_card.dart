import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';

/// 未来 7 / 30 / 90 天待付金额。
///
/// 口径统一：
/// * 到期日走 [effectiveBillReminderDueDate]（重复提醒会推到下一次），
///   原来直接用 `dueDate`，按月/周重复的提醒会算错窗口；
/// * 已逾期的提醒不进这个卡片（由「提醒中心」负责），原来一条两个月前的旧提醒
///   会一直占着「最近待付」首位并显示「今天」；
/// * 金额币种按提醒自身的 `currencyCode`，多币种时不展示分档合计。
class MoneyUpcomingBillsCard extends StatelessWidget {
  const MoneyUpcomingBillsCard({
    super.key,
    required this.bills,
    this.accountsById = const {},
  });

  final List<MoneyBillReminderEntity> bills;
  final Map<String, MoneyAccountEntity> accountsById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = <_UpcomingBill>[];
    for (final bill in bills) {
      if (!bill.isActive) {
        continue;
      }
      final amountMinor = _effectiveAmountMinor(bill);
      if (amountMinor <= 0) {
        continue;
      }
      final dueDate = effectiveBillReminderDueDate(bill, today);
      if (dueDate.isBefore(today)) {
        continue;
      }
      upcoming.add(
        _UpcomingBill(bill: bill, dueDate: dueDate, amountMinor: amountMinor),
      );
    }

    if (upcoming.isEmpty) {
      return AppContentPanel(
        title: '待付账单',
        subtitle: '未来 7/30/90 天待付金额',
        child: const AppEmptyState(
          title: '暂无待付账单',
          message: '添加账单提醒后，这里会显示未来待付金额预测。',
        ),
      );
    }

    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final currencies = upcoming.map((item) => item.bill.currencyCode).toSet();
    // 多币种下「7 天合计」没有意义，只列明细。
    final currencyCode = currencies.length == 1 ? currencies.first : null;
    final top = upcoming.take(5).toList();

    return AppContentPanel(
      title: '待付账单',
      subtitle: '未来 7/30/90 天待付金额',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currencyCode != null)
            Row(
              children: [
                _Bucket(
                  label: '7 天',
                  amountMinor: _sumInWindow(upcoming, today, 7),
                  currencyCode: currencyCode,
                ),
                const SizedBox(width: 12),
                _Bucket(
                  label: '30 天',
                  amountMinor: _sumInWindow(upcoming, today, 30),
                  currencyCode: currencyCode,
                ),
                const SizedBox(width: 12),
                _Bucket(
                  label: '90 天',
                  amountMinor: _sumInWindow(upcoming, today, 90),
                  currencyCode: currencyCode,
                ),
              ],
            ),
          if (top.isNotEmpty) ...[
            if (currencyCode != null) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 10),
            ],
            Text(
              '最近待付',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in top) _BillRow(item: item, today: today),
          ],
        ],
      ),
    );
  }

  int _sumInWindow(List<_UpcomingBill> items, DateTime from, int days) {
    final end = from.add(Duration(days: days));
    return items
        .where(
          (item) => !item.dueDate.isBefore(from) && item.dueDate.isBefore(end),
        )
        .fold<int>(0, (sum, item) => sum + item.amountMinor);
  }

  int _effectiveAmountMinor(MoneyBillReminderEntity reminder) {
    if (reminder.amountSource ==
        MoneyBillReminderAmountSource.creditAccountDebt) {
      final account = accountsById[reminder.accountId];
      return account?.effectivePostedDebtMinor ?? 0;
    }
    return reminder.amountMinor;
  }
}

class _UpcomingBill {
  const _UpcomingBill({
    required this.bill,
    required this.dueDate,
    required this.amountMinor,
  });

  final MoneyBillReminderEntity bill;
  final DateTime dueDate;
  final int amountMinor;
}

class _Bucket extends StatelessWidget {
  const _Bucket({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              formatMoneyMinor(amountMinor, currencyCode),
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.item, required this.today});

  final _UpcomingBill item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final daysLeft = item.dueDate.difference(today).inDays;
    final dueLabel = switch (daysLeft) {
      <= 0 => '今天',
      1 => '明天',
      _ => '$daysLeft 天后',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.bill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  dueLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: daysLeft <= 3
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoneyMinor(item.amountMinor, item.bill.currencyCode),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
