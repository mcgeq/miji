import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';

class CreditCardStatementReconciliationSheet extends StatelessWidget {
  const CreditCardStatementReconciliationSheet({
    super.key,
    required this.account,
    required this.statement,
    this.onRepay,
    this.onAdjust,
  });

  final MoneyAccountEntity account;
  final MoneyCreditCardStatement statement;
  final VoidCallback? onRepay;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '账单核对',
      subtitle: account.name,
      maxWidth: 520,
      titleTextAlign: TextAlign.center,
      body: AppFormColumn(
        gap: 12,
        children: [
          _StatementHeader(account: account, statement: statement),
          _StatementMetrics(statement: statement),
          if (_reconciliationDifferenceMinor > 0)
            _StatementDifferenceCard(
              amountMinor: _reconciliationDifferenceMinor,
              currencyCode: statement.currencyCode,
            ),
          if (statement.pendingReconciliationItems.isNotEmpty)
            _PendingReconciliationList(statement: statement),
          _StatementTransactionList(statement: statement),
        ],
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
        if (_reconciliationDifferenceMinor > 0)
          AppIconActionButton(
            tooltip: '补记差额',
            onPressed: onAdjust,
            icon: Icons.receipt_long_rounded,
            variant: AppIconActionVariant.filledTonal,
          ),
        if (statement.amountDueMinor > 0)
          AppIconActionButton(
            tooltip: '还款',
            onPressed: onRepay,
            icon: Icons.payments_rounded,
            variant: AppIconActionVariant.filled,
          ),
      ],
    );
  }

  int get _reconciliationDifferenceMinor {
    final diff =
        statement.purchaseAmountMinor -
        statement.repaymentAmountMinor -
        statement.amountDueMinor;
    return diff > 0 ? diff : 0;
  }
}

class _StatementHeader extends StatelessWidget {
  const _StatementHeader({required this.account, required this.statement});

  final MoneyAccountEntity account;
  final MoneyCreditCardStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.accent,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.credit_card_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(statement.periodStart)} - ${_formatDate(statement.periodEndInclusive)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(statement.repaymentDate)} 还款 · ${statement.state.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _statementStateColor(colorScheme, statement.state),
                    fontWeight: FontWeight.w700,
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

class _StatementMetrics extends StatelessWidget {
  const _StatementMetrics({required this.statement});

  final MoneyCreditCardStatement statement;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _MetricRow(
            label: '本期消费',
            value: formatMoneyMinor(
              statement.purchaseAmountMinor,
              statement.currencyCode,
            ),
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: '已还款',
            value: formatMoneyMinor(
              statement.repaymentAmountMinor,
              statement.currencyCode,
            ),
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: '本期应还',
            value: formatMoneyMinor(
              statement.amountDueMinor,
              statement.currencyCode,
            ),
            emphasized: true,
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: '可用额度',
            value: formatMoneyMinor(
              statement.availableCreditMinor,
              statement.currencyCode,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          value,
          style:
              (emphasized
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(
                    color: emphasized
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: 0,
                  ),
        ),
      ],
    );
  }
}

class _StatementDifferenceCard extends StatelessWidget {
  const _StatementDifferenceCard({
    required this.amountMinor,
    required this.currencyCode,
  });

  final int amountMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.tinted,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '待补记差额',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            formatMoneyMinor(amountMinor, currencyCode),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingReconciliationList extends StatelessWidget {
  const _PendingReconciliationList({required this.statement});

  final MoneyCreditCardStatement statement;

  @override
  Widget build(BuildContext context) {
    return _SectionSurface(
      title: '待核对',
      children: [
        for (final item in statement.pendingReconciliationItems)
          _SimpleLineItem(
            title: item.title,
            subtitle: item.notes,
            amount: formatMoneyMinor(item.amountMinor, statement.currencyCode),
          ),
      ],
    );
  }
}

class _StatementTransactionList extends StatelessWidget {
  const _StatementTransactionList({required this.statement});

  final MoneyCreditCardStatement statement;

  @override
  Widget build(BuildContext context) {
    if (statement.transactions.isEmpty) {
      return const _SectionSurface(title: '账单流水', children: [Text('暂无本期流水')]);
    }

    return _SectionSurface(
      title: '账单流水',
      children: [
        for (final transaction in statement.transactions)
          _TransactionLineItem(transaction: transaction),
      ],
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _TransactionLineItem extends StatelessWidget {
  const _TransactionLineItem({required this.transaction});

  final MoneyTransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final prefix = transaction.type == MoneyTransactionType.transfer ? '-' : '';
    final subtitle = [
      _formatDate(transaction.transactionAt),
      transaction.type.label,
      transaction.paymentMethod.label,
    ].join(' · ');

    return _SimpleLineItem(
      title: transaction.description,
      subtitle: subtitle,
      amount:
          '$prefix${formatMoneyMinor(transaction.amountMinor, transaction.currencyCode)}',
    );
  }
}

class _SimpleLineItem extends StatelessWidget {
  const _SimpleLineItem({
    required this.title,
    required this.amount,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

Color _statementStateColor(
  ColorScheme colorScheme,
  MoneyCreditCardStatementState state,
) {
  return switch (state) {
    MoneyCreditCardStatementState.overdue => colorScheme.error,
    MoneyCreditCardStatementState.dueSoon => colorScheme.tertiary,
    MoneyCreditCardStatementState.settled => colorScheme.primary,
    MoneyCreditCardStatementState.open ||
    MoneyCreditCardStatementState.pending => colorScheme.onSurfaceVariant,
  };
}

String _formatDate(DateTime date) {
  return '${date.year}.${date.month}.${date.day}';
}
