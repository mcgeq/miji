import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

class HomeRecentTransactionsPanel extends StatelessWidget {
  const HomeRecentTransactionsPanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpenAll,
    required this.onOpenItem,
  });

  final List<HomeRecentTransactionItem> items;
  final bool isLoading;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return AppContentPanel(
      title: '最近账单',
      leadingIcon: Icons.receipt_long_rounded,
      trailing: TextButton(onPressed: onOpenAll, child: const Text('全部')),
      keepTrailingInlineOnCompact: true,
      child: isLoading && items.isEmpty
          ? const SizedBox(height: 96, child: LinearProgressIndicator())
          : items.isEmpty
          ? const _EmptyRecentState()
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _RecentTransactionRow(
                    item: items[index],
                    onTap: () => onOpenItem(items[index].id),
                  ),
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

class _EmptyRecentState extends StatelessWidget {
  const _EmptyRecentState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: Center(
        child: Text(
          '这个月还没有账单',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({required this.item, required this.onTap});

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

    return InkWell(
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              _iconFor(item.type),
              size: 20,
              color: _colorFor(theme, item.type),
            ),
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
                    '${item.categoryName} · ${item.accountName} · ${_dateLabel(item.transactionAt)}',
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
            MoneyAmountText(
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
      HomeRecentTransactionType.expense => Icons.remove_circle_outline_rounded,
      HomeRecentTransactionType.income => Icons.add_circle_outline_rounded,
      HomeRecentTransactionType.transfer => Icons.swap_horiz_rounded,
    };
  }

  Color _colorFor(ThemeData theme, HomeRecentTransactionType type) {
    return switch (type) {
      HomeRecentTransactionType.expense => theme.moneyColors.expense,
      HomeRecentTransactionType.income => theme.moneyColors.income,
      HomeRecentTransactionType.transfer => theme.moneyColors.transfer,
    };
  }
}

String _dateLabel(DateTime value) {
  return '${value.month}月${value.day}日';
}
