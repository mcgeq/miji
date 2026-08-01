import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';

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

enum _MoneyQuickAction {
  expense,
  income,
  transfer,
  account,
  installment,
  budget,
}

enum MoneyQuickActionFabPlacement { bottomRight, centerDocked }

class MoneyQuickActionFab extends ConsumerStatefulWidget {
  const MoneyQuickActionFab({
    super.key,
    this.placement = MoneyQuickActionFabPlacement.bottomRight,
  });

  final MoneyQuickActionFabPlacement placement;

  @override
  ConsumerState<MoneyQuickActionFab> createState() =>
      _MoneyQuickActionFabState();
}

class _MoneyQuickActionFabState extends ConsumerState<MoneyQuickActionFab> {
  FToast? _toast;
  OverlayEntry? _actionsOverlay;

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  @override
  void dispose() {
    _hideActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDocked =
        widget.placement == MoneyQuickActionFabPlacement.centerDocked;

    return SafeArea(
      minimum: isDocked
          ? EdgeInsets.zero
          : const EdgeInsets.only(right: 18, bottom: 18),
      child: Tooltip(
        message: '快速新增',
        child: FloatingActionButton.small(
          heroTag: 'money_quick_action_fab',
          elevation: 6,
          shape: const CircleBorder(),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: _toggleActions,
          child: const Icon(Icons.add_rounded, size: 22),
        ),
      ),
    );
  }

  void _toggleActions() {
    if (_actionsOverlay != null) {
      _hideActions();
      return;
    }
    _showActions();
  }

  void _showActions() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final isDocked =
        widget.placement == MoneyQuickActionFabPlacement.centerDocked;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: _MoneyQuickActionSheet(
          onAction: _handleAction,
          onDismiss: _hideActions,
          docked: isDocked,
          alignment: isDocked ? Alignment.bottomCenter : Alignment.bottomRight,
          padding: isDocked
              ? const EdgeInsets.only(bottom: 68)
              : const EdgeInsets.only(right: 18, bottom: 68),
        ),
      ),
    );
    overlay.insert(entry);
    _actionsOverlay = entry;
  }

  void _hideActions() {
    _actionsOverlay?.remove();
    _actionsOverlay = null;
  }

  void _handleAction(_MoneyQuickAction action) {
    _hideActions();
    unawaited(_runAction(action));
  }

  Future<void> _runAction(_MoneyQuickAction action) async {
    switch (action) {
      case _MoneyQuickAction.expense:
        await _openTransactionDialog(MoneyTransactionType.expense);
      case _MoneyQuickAction.income:
        await _openTransactionDialog(MoneyTransactionType.income);
      case _MoneyQuickAction.transfer:
        await _openTransferDialog();
      case _MoneyQuickAction.account:
        await _openAccountDialog();
      case _MoneyQuickAction.installment:
        await _openInstallmentDialog();
      case _MoneyQuickAction.budget:
        await _openBudgetDialog();
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
    if (!mounted || result?.draft == null) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .createAccount(result!.draft!);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '账户已创建');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error, '创建账户失败'));
    }
  }

  Future<void> _openTransactionDialog(MoneyTransactionType type) async {
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);

    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(type: type, ledger: ledger),
    );
    if (!mounted || result is! TransactionCreateFormResult) {
      return;
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
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '${type.label}已记录');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error, '记录失败'));
    }
  }

  Future<void> _openTransferDialog() async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const TransferFormDialog(),
    );
    if (!mounted || result is! MoneyTransferDraft) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(result);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '转账已记录');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error, '转账失败'));
    }
  }

  Future<void> _openBudgetDialog() async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const BudgetFormDialog(),
    );
    if (!mounted || result == null) {
      return;
    }

    try {
      if (result is MoneyBudgetDraft) {
        await ref
            .read(currentUserMoneyBudgetActionsProvider)
            .createBudget(result);
        if (!mounted) return;
        AppToast.success(_ensureToast(), context, '预算已创建');
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error, '创建预算失败'));
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
    if (!mounted) {
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
    if (!mounted || result == null) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .createInstallmentPlan(result);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分期计划已创建');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error, '创建分期失败'));
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

class _MoneyQuickActionSheet extends StatelessWidget {
  const _MoneyQuickActionSheet({
    required this.onAction,
    required this.onDismiss,
    required this.docked,
    required this.alignment,
    required this.padding,
  });

  final ValueChanged<_MoneyQuickAction> onAction;
  final VoidCallback onDismiss;
  final bool docked;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;

  static const _fabBottomInset = 18.0;
  static const _fabSize = 40.0;
  static const _panelGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actions = const [
      _ActionItem(
        action: _MoneyQuickAction.expense,
        icon: Icons.remove_rounded,
        label: '支出',
      ),
      _ActionItem(
        action: _MoneyQuickAction.income,
        icon: Icons.add_rounded,
        label: '收入',
      ),
      _ActionItem(
        action: _MoneyQuickAction.transfer,
        icon: Icons.swap_horiz_rounded,
        label: '转账',
      ),
      _ActionItem(
        action: _MoneyQuickAction.account,
        icon: Icons.account_balance_wallet_rounded,
        label: '账户',
      ),
      _ActionItem(
        action: _MoneyQuickAction.installment,
        icon: Icons.calendar_month_rounded,
        label: '分期',
      ),
      _ActionItem(
        action: _MoneyQuickAction.budget,
        icon: Icons.flag_rounded,
        label: '预算',
      ),
    ];

    if (docked) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 92),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 12),
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    color: colorScheme.surface,
                    elevation: 18,
                    shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.12,
                          children: [
                            for (final item in actions)
                              _QuickActionGridTile(
                                item: item,
                                onTap: () => onAction(item.action),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    const bottomInset = _fabBottomInset + _fabSize + _panelGap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - bottomInset - 24;
        final maxPanelHeight = availableHeight > 0
            ? availableHeight
            : constraints.maxHeight;

        return SafeArea(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: padding,
              child: Material(
                color: colorScheme.surface,
                elevation: 12,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanelHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in actions) ...[
                          _QuickActionTile(
                            item: item,
                            onTap: () => onAction(item.action),
                          ),
                          if (item != actions.last) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.action,
    required this.icon,
    required this.label,
  });

  final _MoneyQuickAction action;
  final IconData icon;
  final String label;
}

class _QuickActionGridTile extends StatelessWidget {
  const _QuickActionGridTile({required this.item, required this.onTap});

  final _ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: item.label,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: item.label,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      item.icon,
                      color: colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.item, required this.onTap});

  final _ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Semantics(
            button: true,
            label: item.label,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    item.icon,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
