import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';

import 'package:miji/features/bookkeeping/application/money_amount_expression.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_leaf_selector.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/amount_calculator_sheet.dart';

/// 表单提交回调：返回错误文案（null = 成功）。
///
/// 传入时表单不再把结果 pop 给调用方，而是自己调用 [onSubmit] 完成写入 ——
/// 这是「保存并继续」的前提：对话框得留在屏幕上，才有「继续」这一说。
/// 与记一笔表单（`TransactionFormSubmit`）保持同一套契约。
typedef TransferFormSubmit = Future<String?> Function(MoneyTransferDraft draft);

class TransferFormDialog extends ConsumerStatefulWidget {
  const TransferFormDialog({
    super.key,
    this.transaction,
    this.initialToAccountId,
    this.initialAmountMinor,
    this.initialNotes,
    this.onSubmit,
  });

  final MoneyTransactionEntity? transaction;
  final String? initialToAccountId;
  final int? initialAmountMinor;
  final String? initialNotes;
  final TransferFormSubmit? onSubmit;

  @override
  ConsumerState<TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends ConsumerState<TransferFormDialog> {
  static const _transferCategoryId = 'system_transfer';

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _transactionAt = DateTime.now();
  String? _fromAccountId;
  String? _toAccountId;
  String? _subCategoryId;
  String? _errorText;
  bool _submitting = false;

  bool get _isEditing => widget.transaction != null;

  /// 金额框里是算式时给一行实时结果（与记一笔表单保持同一套规则）。
  String? get _amountPreviewText {
    final text = _amountController.text;
    if (!MoneyAmountExpression.isExpression(text)) {
      return null;
    }
    final minor = MoneyAmountExpression.tryEvaluateToMinor(text);
    if (minor == null) {
      return null;
    }
    return '= ${formatMoneyMinor(minor, defaultMoneyCurrencyCode)}';
  }

  Future<void> _openAmountCalculator() async {
    final result = await showAmountCalculatorSheet(
      context,
      initialText: _amountController.text,
      currencyCode: defaultMoneyCurrencyCode,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _amountController.text = result;
      _errorText = null;
    });
  }

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    if (transaction == null) {
      final initialAmountMinor = widget.initialAmountMinor;
      if (initialAmountMinor != null && initialAmountMinor > 0) {
        _amountController.text = (initialAmountMinor / 100).toStringAsFixed(2);
      }
      _notesController.text = widget.initialNotes ?? '';
      _toAccountId = widget.initialToAccountId;
      return;
    }

    _amountController.text = (transaction.amountMinor / 100).toStringAsFixed(2);
    _notesController.text = transaction.notes ?? '';
    _transactionAt = transaction.transactionAt.toLocal();
    _fromAccountId = _initialFromAccountId;
    _toAccountId = _initialToAccountId;
    _subCategoryId = transaction.subCategoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyTransferAccountsProvider(currentLedger.id));
    final catalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    return AppDialogScaffold(
      title: _isEditing ? '编辑转账' : '转账',
      maxWidth: 460,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: AppFormColumn(
        gap: 12,
        children: [
          AppAmountField(
            controller: _amountController,
            labelText: '金额',
            currencyCode: defaultMoneyCurrencyCode,
            prominent: true,
            // 与记一笔表单同一口径：新建时直接落在金额框，编辑时不抢焦点
            // （否则键盘一弹就把要核对的信息顶出视野）。
            autofocus: !_isEditing,
            previewText: _amountPreviewText,
            onCalculatorTap: _openAmountCalculator,
            onChanged: (_) => setState(() {}),
          ),
          accounts.when(
            data: (value) {
              final activeAccounts = value
                  .where((account) => account.isActive)
                  .toList();
              final fromAccounts = _transferFromAccounts(activeAccounts);
              final toAccounts = _transferToAccounts(activeAccounts);
              final fromAccount = _accountById(activeAccounts, _fromAccountId);
              final toAccount = _accountById(activeAccounts, _toAccountId);
              final hintText = _transferHintText(fromAccount, toAccount);
              return AppSurface(
                tone: AppSurfaceTone.subtle,
                padding: const EdgeInsets.all(12),
                child: AppFormColumn(
                  gap: 12,
                  children: [
                    AccountSelector(
                      accounts: fromAccounts,
                      selectedAccountId: _fromAccountId,
                      labelText: '转出账户',
                      emptyText: '暂无可转出的账户',
                      onChanged: (account) {
                        setState(() {
                          _fromAccountId = account?.id;
                          if (!_transferToAccounts(
                            activeAccounts,
                          ).any((target) => target.id == _toAccountId)) {
                            _toAccountId = null;
                          }
                        });
                      },
                    ),
                    Row(
                      children: [
                        const Expanded(child: Divider(height: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: AppIconActionButton(
                            tooltip: '交换转出与转入账户',
                            onPressed: _canSwap(fromAccount, toAccount)
                                ? _swapAccounts
                                : null,
                            icon: Icons.swap_vert_rounded,
                            variant: AppIconActionVariant.outlined,
                          ),
                        ),
                        const Expanded(child: Divider(height: 1)),
                      ],
                    ),
                    AccountSelector(
                      accounts: toAccounts,
                      selectedAccountId: _toAccountId,
                      labelText: '转入账户',
                      emptyText: '暂无可转入的账户',
                      onChanged: (account) {
                        setState(() {
                          _toAccountId = account?.id;
                        });
                      },
                    ),
                    if (hintText != null) AppFormHint(text: hintText),
                    if (_balancePreviewText(fromAccount) != null)
                      AppFormHint(
                        text: _balancePreviewText(fromAccount)!,
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                  ],
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text('账户读取失败'),
          ),
          DateTimePicker(
            selectedDate: _transactionAt,
            showQuickOptions: true,
            onChanged: (value) {
              setState(() => _transactionAt = value);
            },
          ),
          catalog.when(
            data: _buildTransferCategoryFields,
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text('分类读取失败'),
          ),
          AppTextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 3,
            labelText: '备注',
            prefixIcon: const Icon(Icons.notes_rounded),
          ),
        ],
      ),
      errorText: _errorText,
      actions: [
        ...appDialogIconActions(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _submitting ? null : () => _submit(),
          confirmTooltip: _isEditing ? '保存' : '创建',
        ),
        if (widget.onSubmit != null && !_isEditing)
          AppIconActionButton(
            tooltip: '保存并继续',
            onPressed: _submitting ? null : () => _submit(keepOpen: true),
            icon: Icons.playlist_add_rounded,
            variant: AppIconActionVariant.filledTonal,
          ),
      ],
    );
  }

  Future<void> _submit({bool keepOpen = false}) async {
    final result = _buildResult();
    if (result == null) {
      return;
    }
    final submit = widget.onSubmit;
    // 只有「新建 + 调用方提供了回调」这一种情况才自己写入：
    // 编辑态没有「再来一笔」的语义，未提供回调时保持原有的 pop 契约。
    // 这里先判 `is!`，才能让 result 在下面被提升为 MoneyTransferDraft。
    if (result is! MoneyTransferDraft) {
      Navigator.of(context).pop(result);
      return;
    }
    if (submit == null) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() => _submitting = true);
    String? error;
    try {
      error = await submit(result);
    } catch (_) {
      error = '保存失败，请稍后重试';
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _errorText = error;
    });
    if (error != null) {
      return;
    }
    if (keepOpen) {
      _resetAfterSubmit();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 提交成功后重置表单，用于「保存并继续」。
  ///
  /// 只清「这一笔特有」的金额与备注，转出 / 转入账户、日期、分类保留不动 ——
  /// 月末连着还几张信用卡时转出账户是同一个，每次都重选纯属浪费。
  void _resetAfterSubmit() {
    setState(() {
      _amountController.clear();
      _notesController.clear();
      _errorText = null;
    });
  }

  /// 校验并组装 draft / update。校验失败返回 null 并把错误写进 [_errorText]。
  Object? _buildResult() {
    try {
      final amountMinor = parseMoneyAmountToMinor(_amountController.text);
      if (amountMinor <= 0) {
        setState(() => _errorText = '请输入大于 0 的金额');
        return null;
      }
      if (_fromAccountId == null) {
        setState(() => _errorText = '请选择转出账户');
        return null;
      }
      if (_toAccountId == null) {
        setState(() => _errorText = '请选择转入账户');
        return null;
      }
      if (_fromAccountId == _toAccountId) {
        setState(() => _errorText = '转出账户和转入账户不能相同');
        return null;
      }
      final currentLedger = ref.read(currentUserCurrentLedgerValueProvider);
      final activeAccounts = currentLedger == null
          ? const <MoneyAccountEntity>[]
          : ref
                .read(
                  currentUserMoneyTransferAccountsProvider(currentLedger.id),
                )
                .maybeWhen(
                  data: (value) =>
                      value.where((account) => account.isActive).toList(),
                  orElse: () => const <MoneyAccountEntity>[],
                );
      final fromAccount = _accountById(activeAccounts, _fromAccountId);
      final toAccount = _accountById(activeAccounts, _toAccountId);
      if (fromAccount == null || !_canTransferFrom(fromAccount)) {
        setState(() => _errorText = '请选择可转出的账户');
        return null;
      }
      if (toAccount == null || !_canTransferTo(toAccount, fromAccount)) {
        setState(() => _errorText = '请选择可转入的账户');
        return null;
      }
      final ruleError = _transferRuleError(
        fromAccount: fromAccount,
        toAccount: toAccount,
        amountMinor: amountMinor,
      );
      if (ruleError != null) {
        setState(() => _errorText = ruleError);
        return null;
      }

      final notes = _notesController.text.trim();
      final transaction = widget.transaction;
      final paymentMethod = _transferPaymentMethod(
        fromAccount: fromAccount,
        toAccount: toAccount,
      );
      return transaction == null
          ? MoneyTransferDraft(
              transactionAt: _transactionAt,
              amountMinor: amountMinor,
              currencyCode: fromAccount.currencyCode,
              description: MoneyTransactionType.transfer.label,
              notes: notes,
              fromAccountId: _fromAccountId!,
              toAccountId: _toAccountId!,
              subCategoryId: _subCategoryId,
              paymentMethod: paymentMethod,
            )
          : MoneyTransferUpdate(
              id: transaction.id,
              transactionAt: _transactionAt,
              amountMinor: amountMinor,
              currencyCode: transaction.currencyCode,
              notes: notes,
              fromAccountId: _fromAccountId!,
              toAccountId: _toAccountId!,
              subCategoryId: _subCategoryId,
              paymentMethod: paymentMethod,
            );
    } on MoneyAmountParseException {
      setState(() => _errorText = '金额格式不正确');
      return null;
    }
  }

  String? get _initialFromAccountId {
    final transaction = widget.transaction;
    if (transaction == null) {
      return null;
    }
    return transaction.actualPayerAccount == 'transfer_in'
        ? transaction.toAccountId
        : transaction.accountId;
  }

  String? get _initialToAccountId {
    final transaction = widget.transaction;
    if (transaction == null) {
      return null;
    }
    return transaction.actualPayerAccount == 'transfer_in'
        ? transaction.accountId
        : transaction.toAccountId;
  }

  /// 转账的分类固定为「转账」，所以直接把它的叶子摊出来（账户间转账 /
  /// 亲友转账 / 信用卡还款），不再展示一格只读的父分类下拉。
  ///
  /// 「常用」排序与记账表单共用同一份数据，避免同一个组件两种口径。
  Widget _buildTransferCategoryFields(MoneyCategoryCatalog catalog) {
    final usage = ref
        .watch(currentUserCategoryUsageStatsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyCategoryUsage.empty(),
        );
    return CategoryLeafSelector(
      catalog: catalog,
      usage: usage,
      selectedCategoryId: _transferCategoryId,
      selectedSubCategoryId: _subCategoryId,
      fixedCategoryId: _transferCategoryId,
      frequentCount: 3,
      onChanged: (categoryId, subCategoryId) {
        setState(() => _subCategoryId = subCategoryId);
      },
    );
  }

  MoneyAccountEntity? _accountById(
    List<MoneyAccountEntity> accounts,
    String? accountId,
  ) {
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

  List<MoneyAccountEntity> _transferFromAccounts(
    List<MoneyAccountEntity> accounts,
  ) {
    return accounts.where(_canTransferFrom).toList();
  }

  List<MoneyAccountEntity> _transferToAccounts(
    List<MoneyAccountEntity> accounts,
  ) {
    final fromAccount = _accountById(accounts, _fromAccountId);
    return accounts
        .where((account) => _canTransferTo(account, fromAccount))
        .toList();
  }

  bool _canTransferFrom(MoneyAccountEntity account) {
    return account.type.isAssetLike || account.type.isInternal;
  }

  bool _canTransferTo(
    MoneyAccountEntity account,
    MoneyAccountEntity? fromAccount,
  ) {
    if (account.id == fromAccount?.id) {
      return false;
    }
    if (account.type.isCreditLike && _maxCreditRepaymentMinor(account) <= 0) {
      return false;
    }
    return account.type.isAssetLike ||
        account.type.isCreditLike ||
        account.type.isInternal;
  }

  String? _transferRuleError({
    required MoneyAccountEntity fromAccount,
    required MoneyAccountEntity toAccount,
    required int amountMinor,
  }) {
    if (fromAccount.currencyCode != toAccount.currencyCode) {
      return '暂不支持跨币种转账（${fromAccount.currencyCode} → ${toAccount.currencyCode}）';
    }
    if (!fromAccount.isVirtual && fromAccount.balanceMinor < amountMinor) {
      return '转出账户余额不足，可用 ${formatMoneyMinor(fromAccount.balanceMinor, fromAccount.currencyCode)}';
    }
    if (toAccount.type.isCreditLike) {
      final maxRepaymentMinor = _maxCreditRepaymentMinor(toAccount);
      if (amountMinor > maxRepaymentMinor) {
        return '还款金额不能超过已入账欠款 ${formatMoneyMinor(maxRepaymentMinor, toAccount.currencyCode)}';
      }
    }
    return null;
  }

  int _maxCreditRepaymentMinor(MoneyAccountEntity account) {
    var amountMinor = account.effectivePostedDebtMinor;
    if (_isEditing && account.id == _initialToAccountId) {
      amountMinor += widget.transaction!.amountMinor;
    }
    return amountMinor;
  }

  MoneyPaymentMethod _transferPaymentMethod({
    required MoneyAccountEntity fromAccount,
    required MoneyAccountEntity toAccount,
  }) {
    if (toAccount.type.isCreditLike) {
      return MoneyPaymentMethod.bankTransfer;
    }
    return switch (fromAccount.type) {
      MoneyAccountType.cash => MoneyPaymentMethod.cash,
      MoneyAccountType.alipay => MoneyPaymentMethod.alipay,
      MoneyAccountType.wechat => MoneyPaymentMethod.wechatPay,
      MoneyAccountType.cloudQuickPass => MoneyPaymentMethod.unionPay,
      _ => MoneyPaymentMethod.bankTransfer,
    };
  }

  String? _balancePreviewText(MoneyAccountEntity? fromAccount) {
    if (fromAccount == null || fromAccount.isVirtual) {
      return null;
    }
    try {
      final amountMinor = parseMoneyAmountToMinor(_amountController.text);
      final remaining = fromAccount.balanceMinor - amountMinor;
      return '转出后余额 ${formatMoneyMinor(remaining, fromAccount.currencyCode)}';
    } on MoneyAmountParseException {
      return null;
    }
  }

  bool _canSwap(
    MoneyAccountEntity? fromAccount,
    MoneyAccountEntity? toAccount,
  ) {
    if (fromAccount == null || toAccount == null) {
      return false;
    }
    return _canTransferFrom(toAccount) &&
        _canTransferTo(fromAccount, toAccount);
  }

  void _swapAccounts() {
    setState(() {
      final from = _fromAccountId;
      _fromAccountId = _toAccountId;
      _toAccountId = from;
    });
  }

  String? _transferHintText(
    MoneyAccountEntity? fromAccount,
    MoneyAccountEntity? toAccount,
  ) {
    if (toAccount?.type.isCreditLike ?? false) {
      return '转入信用账户会按还款处理，最多可还 ${formatMoneyMinor(_maxCreditRepaymentMinor(toAccount!), toAccount.currencyCode)}';
    }
    if (fromAccount != null) {
      return '转账会从转出账户扣减余额，并增加到转入账户';
    }
    return '信用账户不能作为转出账户，可作为转入账户还款';
  }
}
