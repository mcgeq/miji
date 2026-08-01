import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.accounts,
    required this.expenseCatalog,
    required this.incomeCatalog,
    required this.installmentPlans,
    required this.ledgerMemberships,
    required this.currentLedger,
    this.onEdit,
    this.onDelete,
    this.onRefund,
    this.onTap,
    this.isSelected = false,
    this.swipeCloseSignal,
  });

  final MoneyTransactionEntity transaction;
  final List<MoneyAccountEntity> accounts;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;
  final List<MoneyInstallmentPlanEntity> installmentPlans;
  final List<MoneyLedgerEntity> ledgerMemberships;
  final MoneyLedgerEntity? currentLedger;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRefund;
  final VoidCallback? onTap;
  final bool isSelected;
  final Object? swipeCloseSignal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final amountColor = _amountColor(theme);
    final actions = <AppSwipeAction>[
      if (onEdit != null)
        AppSwipeAction(
          tooltip: '编辑',
          icon: Icons.edit_outlined,
          foreground: colorScheme.onPrimaryContainer,
          background: colorScheme.primaryContainer,
          onPressed: onEdit!,
        ),
      if (onRefund != null)
        AppSwipeAction(
          tooltip: '退款',
          icon: Icons.reply_rounded,
          foreground: colorScheme.onSecondaryContainer,
          background: colorScheme.secondaryContainer,
          onPressed: onRefund!,
        ),
      if (onDelete != null)
        AppSwipeAction(
          tooltip: '删除',
          icon: Icons.delete_outline_rounded,
          foreground: colorScheme.onErrorContainer,
          background: colorScheme.errorContainer,
          onPressed: onDelete!,
        ),
    ];

    return AppSwipeActionTile(
      onTap: onTap,
      actions: actions,
      closeSignal: swipeCloseSignal,
      child: AppListItemPanel(
        selected: isSelected,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final amount = MoneyAmountText(
              amountMinor: _signedDisplayAmountMinor,
              currencyCode: transaction.currencyCode,
              tone: _amountTone,
              showSign: true,
              textStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            );
            final content = Expanded(
              child: _TransactionCardContent(
                title: _categoryText,
                descLine: _descMerchantLine,
                accountPaymentLine: _accountPaymentLine,
                dateLine: _dateText(transaction.transactionAt),
                badges: _badges,
                selected: isSelected,
                amount: amount,
                compact: compact,
              ),
            );

            if (compact) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppListItemIcon(icon: _icon, color: amountColor, size: 28),
                  const SizedBox(width: 12),
                  content,
                ],
              );
            }

            return Row(
              children: [
                AppListItemIcon(icon: _icon, color: amountColor),
                const SizedBox(width: 12),
                content,
              ],
            );
          },
        ),
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

  String get _descMerchantLine {
    final description = transaction.description.trim();
    final merchant = transaction.merchant?.trim();
    // Filter out generic type labels that get auto-filled as descriptions
    final isGeneric =
        description == '支出' ||
        description == '收入' ||
        description == '转入' ||
        description == '转出';
    final parts = <String>[
      if (merchant != null && merchant.isNotEmpty) merchant,
      if (description.isNotEmpty && !isGeneric) description,
    ];
    if (parts.isEmpty) return '';
    return parts.join(' · ');
  }

  String get _accountPaymentLine {
    final parts = <String>[_accountText, _paymentMethodText];
    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  List<_TransactionBadgeData> get _badges {
    return [
      if (_installmentBadgeText != null)
        _TransactionBadgeData(
          text: _installmentBadgeText!,
          icon: Icons.event_repeat_rounded,
          tone: AppBadgeTone.tertiary,
        ),
      if (_ledgerBadgeText != null)
        _TransactionBadgeData(
          text: _ledgerBadgeText!,
          icon: Icons.diversity_3_rounded,
          tone: AppBadgeTone.primary,
        ),
      if (transaction.refundAmountMinor > 0)
        const _TransactionBadgeData(
          text: '退款',
          icon: Icons.reply_rounded,
          tone: AppBadgeTone.secondary,
        ),
      if (transaction.status == MoneyTransactionStatus.pending)
        const _TransactionBadgeData(
          text: '待确认',
          icon: Icons.schedule_rounded,
          tone: AppBadgeTone.secondary,
        ),
      if (transaction.status == MoneyTransactionStatus.voided)
        const _TransactionBadgeData(
          text: '已作废',
          icon: Icons.block_rounded,
          tone: AppBadgeTone.error,
        ),
    ];
  }

  String? get _installmentBadgeText {
    final planId = transaction.installmentPlanId;
    if (planId == null || planId.trim().isEmpty) {
      return null;
    }
    final periodNumber = _installmentPeriodNumber;
    final totalPeriods = _installmentPlan?.totalPeriods;
    if (periodNumber != null && totalPeriods != null && totalPeriods > 0) {
      return '分期 $periodNumber/$totalPeriods';
    }
    if (periodNumber != null) {
      return '分期 $periodNumber';
    }
    if (totalPeriods != null && totalPeriods > 0) {
      return '分期 $totalPeriods期';
    }
    return '分期';
  }

  int? get _installmentPeriodNumber {
    final match = RegExp(r'分期付款第(\d+)期').firstMatch(transaction.description);
    return int.tryParse(match?.group(1) ?? '');
  }

  MoneyInstallmentPlanEntity? get _installmentPlan {
    final planId = transaction.installmentPlanId;
    if (planId == null) {
      return null;
    }
    for (final plan in installmentPlans) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  String? get _ledgerBadgeText {
    final current = currentLedger;
    if (current == null || !current.isPersonal) {
      return null;
    }
    final familyLedgers = ledgerMemberships
        .where((ledger) => ledger.isFamily)
        .toList();
    if (familyLedgers.isEmpty) {
      return null;
    }
    if (familyLedgers.length == 1) {
      return '家庭账本 · ${familyLedgers.first.name}';
    }
    return '多个家庭账本';
  }

  String get _accountText {
    final account = _accountById(transaction.accountId);
    if (transaction.type == MoneyTransactionType.transfer) {
      final toAccount = _accountById(transaction.toAccountId);
      if (account != null && toAccount != null) {
        return '${account.name} -> ${toAccount.name}';
      }
    }
    return account?.name ?? '账户已不可用';
  }

  String get _paymentMethodText {
    final customName = transaction.customPaymentMethodName?.trim();
    if (customName != null && customName.isNotEmpty) {
      return customName;
    }
    return transaction.paymentMethod.label;
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

  MoneyAccountEntity? _accountById(String? accountId) {
    if (accountId == null) {
      return null;
    }
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  int get _signedDisplayAmountMinor {
    final effectiveAmountMinor =
        transaction.type == MoneyTransactionType.expense
        ? (transaction.amountMinor - transaction.refundAmountMinor)
              .clamp(0, transaction.amountMinor)
              .toInt()
        : transaction.amountMinor;
    return switch (transaction.type) {
      MoneyTransactionType.income => effectiveAmountMinor,
      MoneyTransactionType.expense => -effectiveAmountMinor,
      MoneyTransactionType.transfer =>
        transaction.actualPayerAccount == 'transfer_in'
            ? effectiveAmountMinor
            : -effectiveAmountMinor,
    };
  }

  MoneyAmountTone get _amountTone {
    return switch (transaction.type) {
      MoneyTransactionType.income => MoneyAmountTone.income,
      MoneyTransactionType.expense => MoneyAmountTone.expense,
      MoneyTransactionType.transfer => MoneyAmountTone.transfer,
    };
  }

  Color _amountColor(ThemeData theme) {
    final moneyColors = theme.moneyColors;
    return switch (_amountTone) {
      MoneyAmountTone.income => moneyColors.income,
      MoneyAmountTone.expense => moneyColors.expense,
      MoneyAmountTone.transfer => moneyColors.transfer,
      MoneyAmountTone.credit => moneyColors.credit,
      MoneyAmountTone.warning => moneyColors.warning,
      MoneyAmountTone.neutral => theme.colorScheme.onSurface,
    };
  }

  String _dateText(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _TransactionCardContent extends StatelessWidget {
  const _TransactionCardContent({
    required this.title,
    required this.descLine,
    required this.accountPaymentLine,
    required this.dateLine,
    required this.badges,
    required this.selected,
    required this.amount,
    required this.compact,
  });

  final String title;
  final String descLine;
  final String accountPaymentLine;
  final String dateLine;
  final List<_TransactionBadgeData> badges;
  final bool selected;
  final Widget amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleColor = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final secondaryColor = selected
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            amount,
          ],
        ),
        if (descLine.isNotEmpty) ...[const SizedBox(height: 4)],
        if (descLine.isNotEmpty)
          Text(
            descLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          accountPaymentLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondaryColor,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateLine,
          maxLines: 1,
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondaryColor.withValues(alpha: 0.8),
            fontSize: 11,
            letterSpacing: 0,
          ),
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final badge in badges.take(compact ? 2 : 3))
                _TransactionBadge(data: badge, selected: selected),
            ],
          ),
        ],
      ],
    );
  }
}

class _TransactionBadgeData {
  const _TransactionBadgeData({
    required this.text,
    required this.icon,
    required this.tone,
  });

  final String text;
  final IconData icon;
  final AppBadgeTone tone;
}

class _TransactionBadge extends StatelessWidget {
  const _TransactionBadge({required this.data, required this.selected});

  final _TransactionBadgeData data;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      icon: data.icon,
      label: data.text,
      tone: data.tone,
      selected: selected,
      maxWidth: 220,
    );
  }
}
