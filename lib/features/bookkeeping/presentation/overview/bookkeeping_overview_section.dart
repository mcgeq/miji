import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_overview_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class BookkeepingOverviewSection extends ConsumerWidget {
  const BookkeepingOverviewSection({
    super.key,
    required this.onShowAccounts,
    required this.onShowTransactions,
    required this.onShowBudgets,
  });

  final VoidCallback onShowAccounts;
  final VoidCallback onShowTransactions;
  final VoidCallback onShowBudgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(currentUserBookkeepingOverviewProvider);
    final expenseCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    final incomeCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );
    final expenseCatalogValue = expenseCatalog.maybeWhen(
      data: (value) => value,
      orElse: () => const MoneyCategoryCatalog.empty(),
    );
    final incomeCatalogValue = incomeCatalog.maybeWhen(
      data: (value) => value,
      orElse: () => const MoneyCategoryCatalog.empty(),
    );

    return overview.when(
      data: (value) => _BookkeepingOverviewContent(
        overview: value,
        expenseCatalog: expenseCatalogValue,
        incomeCatalog: incomeCatalogValue,
        onShowAccounts: onShowAccounts,
        onShowTransactions: onShowTransactions,
        onShowBudgets: onShowBudgets,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AppErrorState(
        title: '读取记账概览失败',
        onRetry: () => ref.invalidate(currentUserBookkeepingOverviewProvider),
      ),
    );
  }
}

class _BookkeepingOverviewContent extends StatelessWidget {
  const _BookkeepingOverviewContent({
    required this.overview,
    required this.expenseCatalog,
    required this.incomeCatalog,
    required this.onShowAccounts,
    required this.onShowTransactions,
    required this.onShowBudgets,
  });

  final MoneyOverviewEntity overview;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;
  final VoidCallback onShowAccounts;
  final VoidCallback onShowTransactions;
  final VoidCallback onShowBudgets;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        _OverviewMetricGrid(
          summaries: overview.currencySummaries,
          activeAccountCount: overview.activeAccountCount,
        ),
        const SizedBox(height: 12),
        _BudgetWarningPanel(overview: overview, onShowBudgets: onShowBudgets),
        const SizedBox(height: 12),
        _RecentTransactionsPanel(
          transactions: overview.recentTransactions,
          expenseCatalog: expenseCatalog,
          incomeCatalog: incomeCatalog,
          onShowTransactions: onShowTransactions,
        ),
      ],
    );
  }
}

class _OverviewMetricGrid extends StatelessWidget {
  const _OverviewMetricGrid({
    required this.summaries,
    required this.activeAccountCount,
  });

  final List<MoneyOverviewCurrencySummary> summaries;
  final int activeAccountCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;
        final isWide = constraints.maxWidth >= 1120;
        final crossAxisCount = isCompact
            ? 2
            : isWide
            ? 6
            : 3;
        final tileHeight = isCompact ? 106.0 : 94.0;
        final cards = [
          _MetricCard(
            label: '净资产',
            value: _summaryValues(
              summaries,
              (summary) => summary.netAssetMinor,
            ),
            helper: '活跃账户 $activeAccountCount 个',
            icon: Icons.account_balance_rounded,
          ),
          _MetricCard(
            label: '资产',
            value: _summaryValues(summaries, (summary) => summary.assetMinor),
            helper: '不含信用可用额度',
            icon: Icons.savings_rounded,
          ),
          _MetricCard(
            label: '负债',
            value: _summaryValues(
              summaries,
              (summary) => summary.liabilityMinor,
            ),
            helper: '信用账户已占用',
            icon: Icons.credit_card_rounded,
          ),
          _MetricCard(
            label: '本月收入',
            value: _summaryValues(
              summaries,
              (summary) => summary.currentIncomeMinor,
            ),
            helper: '按交易日期',
            icon: Icons.trending_up_rounded,
            valueColor: Theme.of(context).moneyColors.income,
          ),
          _MetricCard(
            label: '本月支出',
            value: _summaryValues(
              summaries,
              (summary) => summary.currentExpenseMinor,
            ),
            helper: '按交易日期',
            icon: Icons.trending_down_rounded,
            valueColor: Theme.of(context).colorScheme.error,
          ),
          _MetricCard(
            label: '本月结余',
            value: _summaryValues(
              summaries,
              (summary) => summary.currentNetMinor,
            ),
            helper: '收入减支出',
            icon: Icons.balance_rounded,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: valueColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

String _summaryValues(
  List<MoneyOverviewCurrencySummary> summaries,
  int Function(MoneyOverviewCurrencySummary summary) valueOf,
) {
  if (summaries.isEmpty) {
    return formatMoneyMinor(0, 'CNY');
  }

  return summaries
      .map(
        (summary) => formatMoneyMinor(valueOf(summary), summary.currencyCode),
      )
      .join(' / ');
}

class _BudgetWarningPanel extends StatelessWidget {
  const _BudgetWarningPanel({
    required this.overview,
    required this.onShowBudgets,
  });

  final MoneyOverviewEntity overview;
  final VoidCallback onShowBudgets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '预算与目标',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(onPressed: onShowBudgets, child: const Text('查看预算')),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;
            final cardWidth = isNarrow
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _BudgetStatusCard(
                    title: _expenseBudgetTitle,
                    subtitle: _expenseBudgetSubtitle,
                    icon: _expenseBudgetIcon,
                    color: _expenseBudgetColor(theme),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _BudgetStatusCard(
                    title: _incomeTargetTitle,
                    subtitle: _incomeTargetSubtitle,
                    icon: _incomeTargetIcon,
                    color: _incomeTargetColor(theme),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  IconData get _expenseBudgetIcon {
    if (overview.activeExpenseBudgetCount == 0) {
      return Icons.flag_outlined;
    }
    if (overview.overspentBudgetCount > 0) {
      return Icons.notification_important_rounded;
    }
    if (overview.alertExpenseBudgetCount > 0) {
      return Icons.warning_amber_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  IconData get _incomeTargetIcon {
    if (overview.activeIncomeTargetCount == 0) {
      return Icons.outlined_flag_rounded;
    }
    if (overview.completedIncomeTargetCount > 0) {
      return Icons.task_alt_rounded;
    }
    if (overview.alertIncomeTargetCount > 0) {
      return Icons.trending_up_rounded;
    }
    return Icons.timeline_rounded;
  }

  Color _expenseBudgetColor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    if (overview.overspentBudgetCount > 0) {
      return colorScheme.error;
    }
    if (overview.alertExpenseBudgetCount > 0) {
      return moneyColors.warning;
    }
    return moneyColors.income;
  }

  Color _incomeTargetColor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    if (overview.completedIncomeTargetCount > 0) {
      return moneyColors.income;
    }
    if (overview.alertIncomeTargetCount > 0) {
      return colorScheme.primary;
    }
    return colorScheme.secondary;
  }

  String get _expenseBudgetTitle {
    if (overview.activeExpenseBudgetCount == 0) {
      return '还没有支出预算';
    }
    if (overview.overspentBudgetCount > 0) {
      return '${overview.overspentBudgetCount} 个支出预算已超支';
    }
    if (overview.alertExpenseBudgetCount > 0) {
      return '${overview.alertExpenseBudgetCount} 个支出预算接近上限';
    }
    return '支出预算正常';
  }

  String get _expenseBudgetSubtitle {
    if (overview.activeExpenseBudgetCount == 0) {
      return '添加支出限额后，这里会显示超支和提醒状态';
    }
    final used = _summaryValues(
      overview.currencySummaries,
      (summary) => summary.expenseBudgetUsedMinor,
    );
    final remaining = _summaryValues(
      overview.currencySummaries,
      (summary) => summary.expenseBudgetRemainingMinor,
    );
    return '启用 ${overview.activeExpenseBudgetCount} 个 · 已支出 $used · 剩余 $remaining';
  }

  String get _incomeTargetTitle {
    if (overview.activeIncomeTargetCount == 0) {
      return '还没有收入目标';
    }
    if (overview.completedIncomeTargetCount > 0) {
      return '${overview.completedIncomeTargetCount} 个收入目标已完成';
    }
    if (overview.alertIncomeTargetCount > 0) {
      return '${overview.alertIncomeTargetCount} 个收入目标接近完成';
    }
    return '收入目标进行中';
  }

  String get _incomeTargetSubtitle {
    if (overview.activeIncomeTargetCount == 0) {
      return '添加收入目标后，这里会显示完成进度';
    }
    final earned = _summaryValues(
      overview.currencySummaries,
      (summary) => summary.incomeTargetEarnedMinor,
    );
    final remaining = _summaryValues(
      overview.currencySummaries,
      (summary) => summary.incomeTargetRemainingMinor,
    );
    return '启用 ${overview.activeIncomeTargetCount} 个 · 已收入 $earned · 待完成 $remaining';
  }
}

class _BudgetStatusCard extends StatelessWidget {
  const _BudgetStatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      backgroundColor: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.24),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsPanel extends StatelessWidget {
  const _RecentTransactionsPanel({
    required this.transactions,
    required this.expenseCatalog,
    required this.incomeCatalog,
    required this.onShowTransactions,
  });

  final List<MoneyTransactionEntity> transactions;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;
  final VoidCallback onShowTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '最近流水',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              TextButton(
                onPressed: onShowTransactions,
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Text(
              '还没有流水记录',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            )
          else
            ...transactions.map((transaction) {
              return _RecentTransactionRow(
                transaction: transaction,
                expenseCatalog: expenseCatalog,
                incomeCatalog: incomeCatalog,
              );
            }),
        ],
      ),
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({
    required this.transaction,
    required this.expenseCatalog,
    required this.incomeCatalog,
  });

  final MoneyTransactionEntity transaction;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final amountColor = _amountColor(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AppListItemIcon(icon: _icon, color: amountColor, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _primaryLine,
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
          const SizedBox(width: 12),
          Text(
            '$_amountPrefix${formatMoneyMinor(transaction.amountMinor, transaction.currencyCode)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    return switch (transaction.type) {
      MoneyTransactionType.income => Icons.trending_up_rounded,
      MoneyTransactionType.expense => Icons.trending_down_rounded,
      MoneyTransactionType.transfer => Icons.swap_horiz_rounded,
    };
  }

  String get _typeLabel {
    if (transaction.type == MoneyTransactionType.transfer) {
      return transaction.actualPayerAccount == 'transfer_in' ? '转入' : '转出';
    }
    return transaction.type.label;
  }

  String get _primaryLine {
    final description = transaction.description.trim();
    final categoryText = _categoryText;
    final parts = <String>[
      if (description.isNotEmpty) description,
      if (categoryText.isNotEmpty) categoryText,
    ];
    if (parts.isEmpty) {
      return _typeLabel;
    }
    return parts.join(' · ');
  }

  String get _categoryText {
    final catalog = transaction.type == MoneyTransactionType.income
        ? incomeCatalog
        : expenseCatalog;
    final category = catalog.categoryById(transaction.categoryId);
    final subCategory = catalog.subCategoryById(transaction.subCategoryId);
    if (category == null) {
      return '';
    }
    if (subCategory == null) {
      return category.name;
    }
    return '${category.name}/${subCategory.name}';
  }

  String get _amountPrefix {
    return switch (transaction.type) {
      MoneyTransactionType.income => '+',
      MoneyTransactionType.expense => '-',
      MoneyTransactionType.transfer =>
        transaction.actualPayerAccount == 'transfer_in' ? '+' : '-',
    };
  }

  Color _amountColor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    return switch (transaction.type) {
      MoneyTransactionType.income => moneyColors.income,
      MoneyTransactionType.expense => colorScheme.error,
      MoneyTransactionType.transfer =>
        transaction.actualPayerAccount == 'transfer_in'
            ? moneyColors.income
            : colorScheme.primary,
    };
  }
}
