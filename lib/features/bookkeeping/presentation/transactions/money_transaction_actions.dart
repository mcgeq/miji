import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transfer_form_dialog.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class MoneyTransactionActions {
  const MoneyTransactionActions({
    required this.context,
    required this.ref,
    required this.ensureToast,
    required this.isMounted,
    required this.onChanged,
  });

  final BuildContext context;
  final WidgetRef ref;
  final FToast Function() ensureToast;
  final bool Function() isMounted;
  final Future<void> Function() onChanged;

  Future<void> edit(MoneyTransactionEntity transaction) async {
    if (transaction.isInstallmentPosting) {
      AppToast.error(ensureToast(), context, '分期入账流水只能查看');
      return;
    }

    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) {
        if (transaction.type == MoneyTransactionType.transfer) {
          return TransferFormDialog(transaction: transaction);
        }
        return TransactionFormDialog(
          type: transaction.type,
          transaction: transaction,
        );
      },
    );
    if (result == null || !context.mounted || !isMounted()) {
      return;
    }

    try {
      final successText = await _saveEdit(result);
      if (successText == null || !context.mounted || !isMounted()) {
        return;
      }
      await onChanged();
      if (!context.mounted || !isMounted()) return;
      AppToast.success(ensureToast(), context, successText);
    } catch (error) {
      if (!context.mounted || !isMounted()) return;
      AppToast.error(
        ensureToast(),
        context,
        moneyTransactionActionErrorText(error),
      );
    }
  }

  Future<void> delete(MoneyTransactionEntity transaction) async {
    if (transaction.isInstallmentPosting) {
      AppToast.error(ensureToast(), context, '分期入账流水只能查看');
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除流水',
      message: '删除后会同步回滚账户余额，确认继续？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted || !isMounted()) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .deleteTransaction(transaction.id);
      if (!context.mounted || !isMounted()) return;
      await onChanged();
      if (!context.mounted || !isMounted()) return;
      AppToast.success(ensureToast(), context, '流水已删除');
    } catch (error) {
      if (!context.mounted || !isMounted()) return;
      AppToast.error(
        ensureToast(),
        context,
        moneyTransactionActionErrorText(error),
      );
    }
  }

  Future<void> refund(MoneyTransactionEntity transaction) async {
    if (transaction.type != MoneyTransactionType.expense ||
        transaction.status != MoneyTransactionStatus.completed) {
      AppToast.error(ensureToast(), context, '只有已完成的支出流水可以退款');
      return;
    }
    if (transaction.amountMinor <= transaction.refundAmountMinor) {
      AppToast.error(ensureToast(), context, '该流水已无可退款金额');
      return;
    }

    final result = await showAppResponsiveDialog<int>(
      context: context,
      builder: (context) {
        return _TransactionRefundDialog(
          currencyCode: transaction.currencyCode,
          totalAmountMinor: transaction.amountMinor,
          refundedAmountMinor: transaction.refundAmountMinor,
          maxAmountMinor:
              transaction.amountMinor - transaction.refundAmountMinor,
        );
      },
    );
    if (result == null || !context.mounted || !isMounted()) {
      return;
    }

    try {
      final totalRefundAmountMinor = transaction.refundAmountMinor + result;
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .recordTransactionRefund(transaction.id, totalRefundAmountMinor);
      if (!context.mounted || !isMounted()) {
        return;
      }
      await onChanged();
      if (!context.mounted || !isMounted()) {
        return;
      }
      AppToast.success(ensureToast(), context, '退款已记录');
    } catch (error) {
      if (!context.mounted || !isMounted()) {
        return;
      }
      AppToast.error(
        ensureToast(),
        context,
        moneyTransactionActionErrorText(error),
      );
    }
  }

  Future<String?> _saveEdit(Object result) async {
    if (result is MoneyTransferUpdate) {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .updateTransfer(result);
      return '转账已更新';
    }
    if (result is MoneyTransactionUpdate) {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .updateTransaction(result);
      return '流水已更新';
    }
    return null;
  }
}

class _TransactionRefundDialog extends StatefulWidget {
  const _TransactionRefundDialog({
    required this.currencyCode,
    required this.totalAmountMinor,
    required this.refundedAmountMinor,
    required this.maxAmountMinor,
  });

  final String currencyCode;
  final int totalAmountMinor;
  final int refundedAmountMinor;
  final int maxAmountMinor;

  @override
  State<_TransactionRefundDialog> createState() =>
      _TransactionRefundDialogState();
}

class _TransactionRefundDialogState extends State<_TransactionRefundDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.maxAmountMinor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;
    return AppDialogScaffold(
      title: '记录退款',
      subtitle:
          '最多可退 ${formatMoneyMinor(widget.maxAmountMinor, widget.currencyCode)}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RefundAmountSummary(
            currencyCode: widget.currencyCode,
            totalAmountMinor: widget.totalAmountMinor,
            refundedAmountMinor: widget.refundedAmountMinor,
            remainingAmountMinor: widget.maxAmountMinor,
          ),
          SizedBox(height: spacing.fieldGap),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '本次退款金额'),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
          if (_errorText != null) ...[
            SizedBox(height: spacing.fieldGap),
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () {
          final amountMinor = parseMoneyAmountToMinor(_controller.text);
          if (amountMinor <= 0) {
            setState(() => _errorText = '请输入大于 0 的金额');
            return;
          }
          if (amountMinor > widget.maxAmountMinor) {
            setState(() => _errorText = '退款金额不能超过剩余可退金额');
            return;
          }
          Navigator.of(context).pop(amountMinor);
        },
        confirmTooltip: '确认退款',
        confirmIcon: Icons.reply_rounded,
      ),
    );
  }
}

class _RefundAmountSummary extends StatelessWidget {
  const _RefundAmountSummary({
    required this.currencyCode,
    required this.totalAmountMinor,
    required this.refundedAmountMinor,
    required this.remainingAmountMinor,
  });

  final String currencyCode;
  final int totalAmountMinor;
  final int refundedAmountMinor;
  final int remainingAmountMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.cardPadding,
          vertical: spacing.fieldGap,
        ),
        child: Row(
          children: [
            _SummaryItem(
              label: '原金额',
              value: formatMoneyMinor(totalAmountMinor, currencyCode),
            ),
            const SizedBox(width: 12),
            _SummaryItem(
              label: '已退款',
              value: formatMoneyMinor(refundedAmountMinor, currencyCode),
            ),
            const SizedBox(width: 12),
            _SummaryItem(
              label: '剩余可退',
              value: formatMoneyMinor(remainingAmountMinor, currencyCode),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: emphasize ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

String moneyTransactionActionErrorText(Object error) {
  if (error is MoneyRepositoryException) {
    return switch (error.code) {
      MoneyRepositoryErrorCode.invalidTransactionAmount => '金额必须大于 0',
      MoneyRepositoryErrorCode.accountNotFound => '账户不可用',
      MoneyRepositoryErrorCode.categoryNotFound => '分类不可用',
      MoneyRepositoryErrorCode.budgetNotFound => '预算不存在',
      MoneyRepositoryErrorCode.invalidBudgetAmount => '预算金额必须大于 0',
      MoneyRepositoryErrorCode.invalidBudgetScope => '请选择分类或账户',
      MoneyRepositoryErrorCode.unsupportedBudgetPeriod => '预算周期不可用',
      MoneyRepositoryErrorCode.insufficientFunds => '账户余额不足',
      MoneyRepositoryErrorCode.invalidTransferAccounts => '账户选择无效',
      MoneyRepositoryErrorCode.creditCardLimitExceeded => '信用账户占用额度不能超过信用额度',
      MoneyRepositoryErrorCode.invalidInstallmentAmount => '请检查分期金额和期数',
      MoneyRepositoryErrorCode.invalidInstallmentAccount => '请选择信用账户',
      MoneyRepositoryErrorCode.installmentPlanNotFound => '分期计划不可用',
      MoneyRepositoryErrorCode.invalidInstallmentStatus => '当前分期状态不可操作',
      MoneyRepositoryErrorCode.invalidTransactionStatus => '当前流水状态不可操作',
      MoneyRepositoryErrorCode.ledgerNotFound => '分摊账本不可用',
      MoneyRepositoryErrorCode.memberNotFound => '分摊成员不可用',
      MoneyRepositoryErrorCode.activeSplitAlreadyExists => '此流水已有分摊记录',
      MoneyRepositoryErrorCode.invalidSplitAmount => '请检查分摊金额或比例',
      MoneyRepositoryErrorCode.invalidSplitTransaction => '当前流水不能重复或不支持分摊',
      MoneyRepositoryErrorCode.cannotUnlinkPersonalLedger => '个人账本不能移出',
      MoneyRepositoryErrorCode.cannotDeletePersonalLedger => '个人账本不能删除',
      MoneyRepositoryErrorCode.cannotUnlinkLedgerWithActiveSplit =>
        '请先取消分摊，再移出家庭账本',
      MoneyRepositoryErrorCode.splitRecordNotFound => '分摊记录不存在',
      MoneyRepositoryErrorCode.invalidAccountBalance => '账户余额不满足规则',
      MoneyRepositoryErrorCode.databaseReadFailed => '读取失败',
      MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
      MoneyRepositoryErrorCode.reminderNotFound => '提醒不存在',
      MoneyRepositoryErrorCode.autoPostingTemplateNotFound => '自动记账模板不可用',
      MoneyRepositoryErrorCode.invalidCategoryName => '分类名称无效',
    };
  }
  return '操作失败';
}
