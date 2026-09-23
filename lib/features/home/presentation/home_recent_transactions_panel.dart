import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_text.dart';

/// 最近账单：按日期分组，整行可点开详情弹窗。
class HomeRecentTransactionsPanel extends StatelessWidget {
  const HomeRecentTransactionsPanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpenAll,
    required this.onOpenItem,
    this.onRecordTransaction,
  });

  final List<HomeRecentTransactionItem> items;
  final bool isLoading;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenItem;
  final VoidCallback? onRecordTransaction;

  @override
  Widget build(BuildContext context) {
    return AppContentPanel(
      title: '最近账单',
      leadingIcon: Icons.receipt_long_rounded,
      trailing: TextButton(onPressed: onOpenAll, child: const Text('全部')),
      keepTrailingInlineOnCompact: true,
      child: isLoading && items.isEmpty
          ? const SizedBox(height: 140, child: LinearProgressIndicator())
          : items.isEmpty
          ? _EmptyState(onRecordTransaction: onRecordTransaction)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildRows(context),
            ),
    );
  }

  List<Widget> _buildRows(BuildContext context) {
    final rows = <Widget>[];
    String? lastGroup;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final date = DateTime(
        item.transactionAt.year,
        item.transactionAt.month,
        item.transactionAt.day,
      );
      final group = _groupLabel(date, today);

      if (group != lastGroup) {
        if (lastGroup != null) {
          rows.add(const SizedBox(height: 6));
        }
        rows.add(_DaySeparator(label: group));
        lastGroup = group;
      }

      rows.add(_RecentRow(item: item, onTap: () => onOpenItem(item.id)));
      if (index != items.length - 1) {
        final next = items[index + 1];
        final nextDate = DateTime(
          next.transactionAt.year,
          next.transactionAt.month,
          next.transactionAt.day,
        );
        if (_groupLabel(nextDate, today) == group) {
          rows.add(const Divider(height: 1));
        }
      }
    }

    return rows;
  }

  String _groupLabel(DateTime date, DateTime today) {
    final diff = today.difference(date).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${date.month}月${date.day}日';
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4, left: 2),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRecordTransaction});

  final VoidCallback? onRecordTransaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '这个月还没有账单',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            if (onRecordTransaction != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRecordTransaction,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('记一笔'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item, required this.onTap});

  final HomeRecentTransactionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = switch (item.type) {
      HomeRecentTransactionType.expense => MoneyAmountTone.expense,
      HomeRecentTransactionType.income => MoneyAmountTone.income,
      HomeRecentTransactionType.transfer => MoneyAmountTone.transfer,
    };
    final color = switch (item.type) {
      HomeRecentTransactionType.expense => theme.moneyColors.expense,
      HomeRecentTransactionType.income => theme.moneyColors.income,
      HomeRecentTransactionType.transfer => theme.moneyColors.transfer,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(item.type), size: 16, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (item.isUnusual) ...[
                        const SizedBox(width: 6),
                        _UnusualBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.categoryName} · ${item.accountName} · '
                    '${_timeLabel(item.transactionAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
              tone: tone,
              showSign: item.type == HomeRecentTransactionType.income,
              textStyle: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(HomeRecentTransactionType type) {
    return switch (type) {
      HomeRecentTransactionType.expense => Icons.remove_rounded,
      HomeRecentTransactionType.income => Icons.add_rounded,
      HomeRecentTransactionType.transfer => Icons.swap_horiz_rounded,
    };
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _UnusualBadge extends ConsumerWidget {
  const _UnusualBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 隐私模式下不暴露「异常」判断，避免侧面泄露金额信息。
    if (ref.watch(moneyAmountsMaskedProvider)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final warning = theme.moneyColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '偏高',
        style: theme.textTheme.labelSmall?.copyWith(
          color: warning,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
