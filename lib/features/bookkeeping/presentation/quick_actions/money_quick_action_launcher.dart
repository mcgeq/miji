import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/installments/money_installments_section.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transfer_form_dialog.dart';
import 'package:miji/features/todo/presentation/todo_quick_create_sheet.dart';

/// 记账模块的快捷动作。首页快捷入口与悬浮按钮共用同一份定义，
/// 避免两处各写一遍动作列表而逐渐分叉。
enum MoneyQuickAction {
  expense,
  income,
  transfer,
  task,
  account,
  installment,
  budget,
  plan,
}

extension MoneyQuickActionX on MoneyQuickAction {
  String get label {
    return switch (this) {
      MoneyQuickAction.expense => '支出',
      MoneyQuickAction.income => '收入',
      MoneyQuickAction.transfer => '转账',
      MoneyQuickAction.task => '任务',
      MoneyQuickAction.account => '账户',
      MoneyQuickAction.installment => '分期',
      MoneyQuickAction.budget => '预算',
      MoneyQuickAction.plan => '计划',
    };
  }

  IconData get icon {
    return switch (this) {
      MoneyQuickAction.expense => Icons.remove_rounded,
      MoneyQuickAction.income => Icons.add_rounded,
      MoneyQuickAction.transfer => Icons.swap_horiz_rounded,
      MoneyQuickAction.task => Icons.task_alt_rounded,
      MoneyQuickAction.account => Icons.account_balance_wallet_rounded,
      MoneyQuickAction.installment => Icons.calendar_month_rounded,
      MoneyQuickAction.budget => Icons.flag_rounded,
      MoneyQuickAction.plan => Icons.check_circle_outline_rounded,
    };
  }
}

/// 执行记账快捷动作的唯一入口。
///
/// 由调用方提供 [context]、[ref] 与 toast 工厂，动作本身负责打开表单、
/// 提交数据、提示结果，并在控件销毁后停止后续操作。
class MoneyQuickActionLauncher {
  MoneyQuickActionLauncher({
    required this.context,
    required this.ref,
    required this.ensureToast,
  });

  final BuildContext context;
  final WidgetRef ref;
  final FToast Function() ensureToast;

  Future<void> run(MoneyQuickAction action) async {
    switch (action) {
      case MoneyQuickAction.expense:
        await _openTransactionDialog(MoneyTransactionType.expense);
      case MoneyQuickAction.income:
        await _openTransactionDialog(MoneyTransactionType.income);
      case MoneyQuickAction.transfer:
        await _openTransferDialog();
      case MoneyQuickAction.task:
        await _openTaskSheet();
      case MoneyQuickAction.account:
        await _openAccountDialog();
      case MoneyQuickAction.installment:
        await _openInstallmentDialog();
      case MoneyQuickAction.budget:
        await _openBudgetDialog();
      case MoneyQuickAction.plan:
        if (context.mounted) {
          await context.push(AppRoutes.gtdPlansCreate);
        }
    }
  }

  Future<void> _openAccountDialog() async {
    final defaultCurrencyCode = ref
        .read(currentUserPreferencesProvider)
        .maybeWhen(
          data: (preferences) => preferences?.currencyCode,
          orElse: () => null,
        );
    final result = await showAppResponsiveDialog<AccountFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (context) =>
          AccountFormDialog(defaultCurrencyCode: defaultCurrencyCode),
    );
    if (!context.mounted || result?.draft == null) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .createAccount(result!.draft!);
      if (!context.mounted) return;
      AppToast.success(ensureToast(), context, '账户已创建');
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(ensureToast(), context, _errorText(error, '创建账户失败'));
    }
  }

  Future<void> _openTransactionDialog(MoneyTransactionType type) async {
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);

    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(
        type: type,
        ledger: ledger,
        onSubmit: (result) => _createFromForm(type, result),
      ),
    );
  }

  /// 返回错误文案（null = 成功）。
  Future<String?> _createFromForm(
    MoneyTransactionType type,
    Object result,
  ) async {
    if (result is! TransactionCreateFormResult) {
      return null;
    }
    try {
      final splitConfig = result.splitConfig;
      if (splitConfig == null) {
        await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .createTransaction(result.draft);
      } else {
        await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .createTransactionWithSplit(result.draft, splitConfig);
      }
      if (!context.mounted) return null;
      AppToast.success(ensureToast(), context, '${type.label}已记录');
      return null;
    } catch (error) {
      return _errorText(error, '记录失败');
    }
  }

  Future<void> _openTransferDialog() async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const TransferFormDialog(),
    );
    if (!context.mounted || result is! MoneyTransferDraft) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(result);
      if (!context.mounted) return;
      AppToast.success(ensureToast(), context, '转账已记录');
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(ensureToast(), context, _errorText(error, '转账失败'));
    }
  }

  Future<void> _openTaskSheet() async {
    final result = await showTodoQuickCreateSheet(context);
    if (result == true && context.mounted) {
      AppToast.success(ensureToast(), context, '任务已创建');
    }
  }

  Future<void> _openBudgetDialog() async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const BudgetFormDialog(),
    );
    if (!context.mounted || result == null) {
      return;
    }

    try {
      if (result is MoneyBudgetDraft) {
        await ref
            .read(currentUserMoneyBudgetActionsProvider)
            .createBudget(result);
        if (!context.mounted) return;
        AppToast.success(ensureToast(), context, '预算已创建');
      }
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(ensureToast(), context, _errorText(error, '创建预算失败'));
    }
  }

  Future<void> _openInstallmentDialog() async {
    final currentLedger = ref.read(currentUserCurrentLedgerValueProvider);
    final accounts = await _valueOrEmpty(
      currentLedger == null
          ? Future.value(const <MoneyAccountEntity>[])
          : ref.read(
              currentUserMoneyLedgerAccountsProvider(currentLedger.id).future,
            ),
    );
    final categoryCatalog = await _valueOrEmptyCatalog(
      ref.read(
        currentUserCategoryCatalogProvider(MoneyCategoryKind.expense).future,
      ),
    );
    if (!context.mounted) {
      return;
    }

    final result = await showAppResponsiveDialog<MoneyInstallmentPlanDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => InstallmentPlanFormDialog(
        accounts: accounts,
        categoryCatalog: categoryCatalog,
      ),
    );
    if (!context.mounted || result == null) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .createInstallmentPlan(result);
      if (!context.mounted) return;
      AppToast.success(ensureToast(), context, '分期计划已创建');
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(ensureToast(), context, _errorText(error, '创建分期失败'));
    }
  }

  Future<List<MoneyAccountEntity>> _valueOrEmpty(
    Future<List<MoneyAccountEntity>> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      return const <MoneyAccountEntity>[];
    }
  }

  Future<MoneyCategoryCatalog> _valueOrEmptyCatalog(
    Future<MoneyCategoryCatalog> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      return const MoneyCategoryCatalog.empty();
    }
  }

  String _errorText(Object error, String fallback) {
    if (error is! MoneyRepositoryException) {
      return fallback;
    }
    return switch (error.code) {
      MoneyRepositoryErrorCode.insufficientFunds => '账户余额不足',
      MoneyRepositoryErrorCode.invalidTransferAccounts => '转账账户不能相同',
      MoneyRepositoryErrorCode.invalidInstallmentAccount => '请选择信用账户',
      MoneyRepositoryErrorCode.invalidInstallmentAmount => '请检查分期金额和期数',
      MoneyRepositoryErrorCode.invalidInstallmentStatus => '当前分期状态不可操作',
      MoneyRepositoryErrorCode.ledgerNotFound => '账本不可用',
      MoneyRepositoryErrorCode.invalidSplitAmount => '请检查分摊金额',
      _ => fallback,
    };
  }
}
