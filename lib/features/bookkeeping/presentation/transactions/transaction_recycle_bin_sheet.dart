import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 回收站：最近 30 天被删除的流水，可逐条恢复。
///
/// 删除是软删除，数据一直都在，只是列表里看不见——没有这个入口，
/// 用户误删之后只能重新记一笔，而重记的流水丢失了原始备注与标签。
class TransactionRecycleBinSheet extends ConsumerWidget {
  const TransactionRecycleBinSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(currentUserDeletedTransactionsProvider);

    return AppDialogScaffold(
      title: '回收站',
      subtitle: '最近 30 天删除的流水',
      maxWidth: 560,
      body: deleted.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => const AppEmptyState(title: '回收站加载失败'),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(title: '回收站是空的');
          }
          // AppDialogScaffold 的 body 本身在滚动容器里，这里必须
          // shrinkWrap + 禁用自身滚动。
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              return _DeletedRow(transaction: items[index]);
            },
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _DeletedRow extends ConsumerWidget {
  const _DeletedRow({required this.transaction});

  final MoneyTransactionEntity transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final isIncome = transaction.type == MoneyTransactionType.income;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_dateText(transaction.transactionAt)} · ${transaction.type.label}',
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
          Text(
            maskedMoneyOr(
              formatMoneyMinor(
                transaction.amountMinor,
                transaction.currencyCode,
              ),
              MoneyPrivacy.of(context),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isIncome ? moneyColors.income : moneyColors.expense,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () => _restore(context, ref),
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: const Text('恢复'),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  String _title() {
    final description = transaction.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    final merchant = transaction.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      return merchant;
    }
    return transaction.type.label;
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .restoreTransactions(<String>[transaction.id]);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('恢复失败：$error')));
    }
  }
}

String _dateText(DateTime date) {
  return '${date.month}月${date.day}日';
}
