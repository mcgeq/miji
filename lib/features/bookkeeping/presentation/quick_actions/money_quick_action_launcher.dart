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
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
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

  /// 把表单结果写进账本并返回新流水（不负责 toast）。
  Future<MoneyTransactionEntity> _writeTransaction(
    TransactionCreateFormResult result,
  ) {
    final actions = ref.read(currentUserMoneyTransactionActionsProvider);
    final splitConfig = result.splitConfig;
    return splitConfig == null
        ? actions.createTransaction(result.draft)
        : actions.createTransactionWithSplit(result.draft, splitConfig);
  }

  /// 提醒中心的「记账」：从账单提醒直接记一笔支出。
  ///
  /// 金额 / 账户 / 标题 / 日期全部来自提醒本身——之前这条路径打开的是空白
  /// 表单，用户记完后提醒还在待处理里，还得再点一次「完成」。现在写入成功
  /// 才返回流水 id，由调用方把它连同「完成」一起回写源头。
  /// null = 用户取消或写入失败。
  Future<String?> recordExpenseFromReminder(
    MoneyReminderCenterItem item,
  ) async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(
        type: MoneyTransactionType.expense,
        ledger: ref.read(currentUserEffectiveTransactionLedgerValueProvider),
        initialAmountMinor: item.amountMinor,
        initialAccountId: item.accountId,
        initialDescription: item.title,
        initialTransactionAt: item.dueDate,
        categoryId: item.categoryId,
      ),
    );
    if (!context.mounted || result is! TransactionCreateFormResult) {
      return null;
    }

    // 成功提示交给调用方统一处理：提醒中心要按来源给不同文案，
    // 这里再弹一次会连着冒出两条 toast。
    try {
      final transaction = await _writeTransaction(result);
      return transaction.id;
    } catch (error) {
      if (!context.mounted) {
        return null;
      }
      AppToast.error(ensureToast(), context, _errorText(error, '记录失败'));
      return null;
    }
  }

  /// 提醒中心的「还款」：资金账户 → 信用账户的转账。
  ///
  /// 金额取账单应还额、收款方锁死为提醒所指的信用账户，与账户详情页里的
  /// 「记录还款」用的是同一个表单和预填方式。返回值表示是否成功写入。
  Future<bool> recordRepaymentFromReminder(MoneyReminderCenterItem item) async {
    final creditAccountId = item.accountId;
    if (creditAccountId == null || creditAccountId.isEmpty) {
      AppToast.error(ensureToast(), context, '该提醒没有关联的信用账户');
      return false;
    }

    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransferFormDialog(
        initialToAccountId: creditAccountId,
        initialAmountMinor: item.amountMinor,
        initialNotes: '信用卡还款',
      ),
    );
    if (!context.mounted || result is! MoneyTransferDraft) {
      return false;
    }

    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(result);
      return true;
    } catch (error) {
      if (!context.mounted) {
        return false;
      }
      AppToast.error(ensureToast(), context, _errorText(error, '还款失败'));
      return false;
    }
  }

  /// 提醒中心的「分期入账」：直接过账当期明细。
  ///
  /// 分期不像普通账单那样还需要手填表单——金额、账户、分类、期数都在计划里，
  /// `postInstallmentDetail` 会一次性完成「落流水 + 明细转已入账 + 推进计划
  /// 进度 + 刷新预算」。这里不再重复 `createTransaction`，否则会出现两笔流水。
  Future<bool> postInstallmentFromReminder(MoneyReminderCenterItem item) async {
    final detailId = item.installmentDetailId;
    if (detailId == null) {
      AppToast.error(ensureToast(), context, '这条分期提醒已失效');
      return false;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .postInstallmentDetail(detailId);
      return true;
    } catch (error) {
      if (!context.mounted) {
        return false;
      }
      AppToast.error(
        ensureToast(),
        context,
        error is MoneyRepositoryException &&
                error.code == MoneyRepositoryErrorCode.invalidInstallmentStatus
            ? '该分期已入账或不可操作'
            : '入账失败',
      );
      return false;
    }
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
      await _writeTransaction(result);
      if (!context.mounted) return null;
      AppToast.success(ensureToast(), context, '${type.label}已记录');
      return null;
    } catch (error) {
      return _errorText(error, '记录失败');
    }
  }

  Future<void> _openTransferDialog() async {
    // 与流水页同一套契约：写入由表单自己完成，才能支持「保存并继续」。
    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransferFormDialog(onSubmit: _createTransfer),
    );
  }

  /// 返回错误文案（null = 成功），供转账表单回显。
  Future<String?> _createTransfer(MoneyTransferDraft draft) async {
    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(draft);
      if (context.mounted) {
        AppToast.success(ensureToast(), context, '转账已记录');
      }
      return null;
    } catch (error) {
      return _errorText(error, '转账失败');
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
      MoneyRepositoryErrorCode.ledgerNotFound => '分摊账本不可用',
      MoneyRepositoryErrorCode.memberNotFound => '分摊成员不可用，请重新设置分摊',
      MoneyRepositoryErrorCode.activeSplitAlreadyExists => '此流水已有分摊记录',
      MoneyRepositoryErrorCode.invalidSplitTransaction => '只有已完成的支出才能分摊',
      MoneyRepositoryErrorCode.invalidSplitAmount => '请检查分摊金额或比例',
      _ => fallback,
    };
  }
}
