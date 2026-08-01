import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';

class MoneyUpcomingBillsCard extends StatelessWidget {
  const MoneyUpcomingBillsCard({super.key, required this.bills});

  final List<MoneyBillReminderEntity> bills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final pending = bills.where((b) => b.isActive).toList();
    if (pending.isEmpty) {
      return AppContentPanel(
        title: '待付账单',
        subtitle: '未来 7/30/90 天待付金额',
        child: const AppEmptyState(
          title: '暂无待付账单',
          message: '添加账单提醒后，这里会显示未来待付金额预测。',
        ),
      );
    }

    final now = DateTime.now();
    final next7 = _sumInWindow(pending, now, 7);
    final next30 = _sumInWindow(pending, now, 30);
    final next90 = _sumInWindow(pending, now, 90);

    // Top 5 upcoming by dueDate
    pending.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final top = pending.take(5).toList();

    return AppContentPanel(
      title: '待付账单',
      subtitle: '未来 7/30/90 天待付金额',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Bucket(label: '7 天', amountMinor: next7),
              const SizedBox(width: 12),
              _Bucket(label: '30 天', amountMinor: next30),
              const SizedBox(width: 12),
              _Bucket(label: '90 天', amountMinor: next90),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 10),
            Text(
              '最近待付',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            for (final bill in top) _BillRow(bill: bill),
          ],
        ],
      ),
    );
  }

  static int _sumInWindow(
    List<MoneyBillReminderEntity> bills,
    DateTime from,
    int days,
  ) {
    final end = from.add(Duration(days: days));
    return bills
        .where((b) => b.dueDate.isAfter(from) && b.dueDate.isBefore(end))
        .fold<int>(0, (sum, b) => sum + b.amountMinor);
  }
}

class _Bucket extends StatelessWidget {
  const _Bucket({required this.label, required this.amountMinor});

  final String label;
  final int amountMinor;

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
              formatMoneyMinor(amountMinor, 'CNY'),
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
  const _BillRow({required this.bill});

  final MoneyBillReminderEntity bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final daysLeft = bill.dueDate.difference(DateTime.now()).inDays;
    final dueLabel = daysLeft <= 0
        ? '今天'
        : daysLeft == 1
        ? '明天'
        : '$daysLeft 天后';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
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
            formatMoneyMinor(bill.amountMinor, bill.currencyCode),
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
