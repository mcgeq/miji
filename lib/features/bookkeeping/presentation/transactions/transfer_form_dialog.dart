import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';

class TransferFormDialog extends ConsumerStatefulWidget {
  const TransferFormDialog({
    super.key,
    this.transaction,
    this.initialToAccountId,
    this.initialAmountMinor,
    this.initialNotes,
  });

  final MoneyTransactionEntity? transaction;
  final String? initialToAccountId;
  final int? initialAmountMinor;
  final String? initialNotes;

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

  bool get _isEditing => widget.transaction != null;

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
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: _isEditing ? '保存' : '创建',
      ),
    );
  }

  void _submit() {
    try {
      final amountMinor = parseMoneyAmountToMinor(_amountController.text);
      if (amountMinor <= 0) {
        setState(() => _errorText = '请输入大于 0 的金额');
        return;
      }
      if (_fromAccountId == null) {
        setState(() => _errorText = '请选择转出账户');
        return;
      }
      if (_toAccountId == null) {
        setState(() => _errorText = '请选择转入账户');
        return;
      }
      if (_fromAccountId == _toAccountId) {
        setState(() => _errorText = '转出账户和转入账户不能相同');
        return;
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
        return;
      }
      if (toAccount == null || !_canTransferTo(toAccount, fromAccount)) {
        setState(() => _errorText = '请选择可转入的账户');
        return;
      }
      final ruleError = _transferRuleError(
        fromAccount: fromAccount,
        toAccount: toAccount,
        amountMinor: amountMinor,
      );
      if (ruleError != null) {
        setState(() => _errorText = ruleError);
        return;
      }

      final notes = _notesController.text.trim();
      final transaction = widget.transaction;
      final paymentMethod = _transferPaymentMethod(
        fromAccount: fromAccount,
        toAccount: toAccount,
      );
      Navigator.of(context).pop(
        transaction == null
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
              ),
      );
    } on MoneyAmountParseException {
      setState(() => _errorText = '金额格式不正确');
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

  Widget _buildTransferCategoryFields(MoneyCategoryCatalog catalog) {
    final transferCategory = catalog.categoryById(_transferCategoryId);
    final subCategories = transferCategory == null
        ? const <MoneySubCategoryEntity>[]
        : catalog.subCategoriesFor(transferCategory.id);
    final selectedSubCategory = _selectedSubCategory(
      subCategories,
      _subCategoryId,
    );

    return AppFormColumn(
      gap: 12,
      children: [
        FormDropdown<String>(
          initialSelection: transferCategory?.id,
          onSelected: (_) {},
          label: '分类',
          leadingIcon: const Icon(Icons.swap_horiz_rounded),
          enabled: false,
          entries: [
            DropdownMenuEntry<String>(
              value: transferCategory?.id ?? _transferCategoryId,
              label: transferCategory?.name ?? '转账',
            ),
          ],
        ),
        FormDropdown<String>(
          initialSelection: selectedSubCategory?.id ?? '',
          label: '子分类',
          helperText: transferCategory == null
              ? '未找到转账分类'
              : subCategories.isEmpty
              ? '暂无转账子分类'
              : null,
          leadingIcon: const Icon(Icons.sell_rounded),
          enabled: transferCategory != null && subCategories.isNotEmpty,
          enableFilter: true,
          onSelected: (subCategoryId) {
            setState(() {
              _subCategoryId = subCategoryId == null || subCategoryId.isEmpty
                  ? null
                  : subCategoryId;
            });
          },
          entries: [
            const DropdownMenuEntry<String>(value: '', label: '不选择子分类'),
            ...subCategories.map(
              (subCategory) => DropdownMenuEntry<String>(
                value: subCategory.id,
                label: subCategory.name,
                labelWidget: _TransferSubCategoryMenuItem(
                  subCategory: subCategory,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  MoneySubCategoryEntity? _selectedSubCategory(
    List<MoneySubCategoryEntity> subCategories,
    String? subCategoryId,
  ) {
    if (subCategoryId == null) {
      return null;
    }
    for (final subCategory in subCategories) {
      if (subCategory.id == subCategoryId) {
        return subCategory;
      }
    }
    return null;
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

class _TransferSubCategoryMenuItem extends StatelessWidget {
  const _TransferSubCategoryMenuItem({required this.subCategory});

  final MoneySubCategoryEntity subCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconText = subCategory.icon?.trim();

    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Center(
            child: iconText == null || iconText.isEmpty
                ? Icon(Icons.sell_rounded, size: 18, color: colorScheme.primary)
                : Text(
                    iconText,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subCategory.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}
