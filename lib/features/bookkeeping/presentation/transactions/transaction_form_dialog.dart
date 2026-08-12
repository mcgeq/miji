import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_toast.dart';
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
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_entry_suggestions.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/features/bookkeeping/presentation/installments/money_installments_section.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/suggestion_autocomplete_field.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_split_dialog.dart';

class TransactionCreateFormResult {
  const TransactionCreateFormResult({required this.draft, this.splitConfig});

  final MoneyTransactionDraft draft;
  final MoneySplitConfigDraft? splitConfig;
}

class TransactionFormDialog extends ConsumerStatefulWidget {
  const TransactionFormDialog({
    super.key,
    required this.type,
    this.ledger,
    this.transaction,
    this.categoryId,
    this.subCategoryId,
    this.showCategorySelector = true,
  });

  final MoneyTransactionType type;
  final MoneyLedgerEntity? ledger;
  final MoneyTransactionEntity? transaction;
  final String? categoryId;
  final String? subCategoryId;
  final bool showCategorySelector;

  @override
  ConsumerState<TransactionFormDialog> createState() =>
      _TransactionFormDialogState();
}

class _TransactionFormDialogState extends ConsumerState<TransactionFormDialog> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _customPaymentNameCtrl = TextEditingController();
  final _tagController = TextEditingController();
  DateTime _transactionAt = DateTime.now();
  String? _accountId;
  String? _categoryId;
  String? _subCategoryId;
  String? _ledgerId;
  MoneyPaymentMethod _paymentMethod = MoneyPaymentMethod.cash;
  MoneySplitConfigDraft? _splitConfig;
  int? _splitConfigAmountMinor;
  String? _errorText;
  bool _defaultsLoaded = false;
  bool _advancedExpanded = false;

  bool get _isEditing => widget.transaction != null;

  bool _canConfigureSplit(int ledgerMemberCount) {
    return !_isEditing &&
        widget.type == MoneyTransactionType.expense &&
        ledgerMemberCount >= 2;
  }

  bool get _isSplitConfigStale {
    if (_splitConfig == null || _splitConfigAmountMinor == null) {
      return false;
    }
    try {
      return parseMoneyAmountToMinor(_amountController.text) !=
          _splitConfigAmountMinor;
    } on MoneyAmountParseException {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final initialLedger = widget.ledger;
    _ledgerId = initialLedger != null && initialLedger.isFamily
        ? initialLedger.id
        : null;
    if (transaction == null) {
      _categoryId = widget.categoryId;
      _subCategoryId = widget.subCategoryId;
      return;
    }

    _amountController.text = (transaction.amountMinor / 100).toStringAsFixed(2);
    _merchantController.text = transaction.merchant ?? '';
    _locationController.text = transaction.location ?? '';
    _notesController.text = transaction.notes ?? '';
    _advancedExpanded =
        (transaction.merchant?.trim().isNotEmpty ?? false) ||
        (transaction.location?.trim().isNotEmpty ?? false) ||
        (transaction.notes?.trim().isNotEmpty ?? false);
    _transactionAt = transaction.transactionAt.toLocal();
    _accountId = transaction.accountId;
    _categoryId = transaction.categoryId;
    _subCategoryId = transaction.subCategoryId;
    _paymentMethod = transaction.paymentMethod;
    _customPaymentNameCtrl.text = transaction.customPaymentMethodName ?? '';
    _tagController.text = transaction.tags.isEmpty
        ? ''
        : transaction.tags.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _customPaymentNameCtrl.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledgers = ref.watch(currentUserMoneyLedgersProvider);
    final selectedLedger = _isEditing
        ? null
        : ledgers.maybeWhen(
            data: _selectedLedgerFrom,
            orElse: () {
              final initialLedger = widget.ledger;
              return initialLedger != null && initialLedger.isFamily
                  ? initialLedger
                  : null;
            },
          );
    final accounts = _isEditing || selectedLedger == null
        ? ref.watch(currentUserVisibleAccountsProvider)
        : ref.watch(currentUserMoneyLedgerAccountsProvider(selectedLedger.id));
    final internalAccounts = ref
        .watch(currentUserMoneyInternalAccountsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <MoneyAccountEntity>[],
        );
    final accountRows = accounts.maybeWhen(
      data: (value) => [
        ...value.where((account) => account.isActive),
        ...internalAccounts.where((account) => account.isActive),
      ],
      orElse: () => internalAccounts
          .where((account) => account.isActive)
          .toList(growable: false),
    );
    final selectableAccounts = _selectableAccountsForType(accountRows);
    final selectedAccount = _selectedAccountFrom(selectableAccounts);
    final accountRuleHint = _accountRuleHint(selectedAccount);
    final lockedPaymentMethod = _lockedPaymentMethodForAccount(selectedAccount);
    final availablePaymentMethods = _availablePaymentMethodsForAccount(
      selectedAccount,
    );
    final paymentMethodUsageRanks = ref
        .watch(currentUserPaymentMethodUsageRanksProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <MoneyPaymentMethod, int>{},
        );
    final entrySuggestions = ref
        .watch(currentUserEntrySuggestionsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyEntrySuggestions.empty(),
        );
    final sortedPaymentMethods = _sortPaymentMethodsByUsage(
      availablePaymentMethods,
      paymentMethodUsageRanks,
    );
    final effectivePaymentMethod = _effectivePaymentMethodForAccount(
      selectedAccount,
    );
    final selectedLedgerMembers = _isEditing || selectedLedger == null
        ? const <MoneyMemberEntity>[]
        : selectedLedger.isFamily
        ? ref
              .watch(currentUserMoneyLedgerMembersProvider(selectedLedger.id))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <MoneyMemberEntity>[],
              )
        : const <MoneyMemberEntity>[];
    final ledgerMemberCount = selectedLedgerMembers.length;
    final isFamilyLedger = selectedLedger?.isFamily ?? false;
    final canConfigureSplit =
        isFamilyLedger && _canConfigureSplit(ledgerMemberCount);
    final showSplitConfig =
        !_isEditing &&
        widget.type == MoneyTransactionType.expense &&
        isFamilyLedger;
    final kind = widget.type == MoneyTransactionType.income
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
    final catalog = ref.watch(currentUserCategoryCatalogProvider(kind));
    final tagCandidates = ref
        .watch(currentUserTagCandidatesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String>[]);
    final hasMultipleLegacyTags =
        _isEditing && (widget.transaction?.tags.length ?? 0) > 1;
    final installmentAmountMinor = _installmentEntryAmountMinor;
    final showInstallmentEntry =
        installmentAmountMinor != null &&
        installmentAmountMinor > 0 &&
        selectedAccount?.type.isCreditLike == true;
    _loadRememberedDefaultsOnce(selectedLedger?.id);

    return AppDialogScaffold(
      title: _dialogTitle,
      maxWidth: 460,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: AppFormColumn(
        gap: 12,
        children: [
          if (!_isEditing)
            ledgers.when(
              data: (items) => FormDropdown<String?>(
                initialSelection: selectedLedger?.id,
                label: '家庭账本',
                leadingIcon: const Icon(Icons.menu_book_rounded),
                width: double.infinity,
                enableFilter: true,
                entries: [
                  const DropdownMenuEntry<String?>(
                    value: null,
                    label: '不加入家庭账本',
                  ),
                  for (final ledger in items.where((ledger) => ledger.isFamily))
                    DropdownMenuEntry<String?>(
                      value: ledger.id,
                      label: ledger.name,
                      labelWidget: _TransactionLedgerMenuItem(ledger: ledger),
                    ),
                ],
                onSelected: (value) {
                  if (value == _ledgerId) {
                    return;
                  }
                  setState(() {
                    _ledgerId = value;
                  });
                },
              ),
              loading: () => const AppFormHint(text: '家庭账本加载中...'),
              error: (error, stackTrace) => const Text('家庭账本读取失败'),
            ),
          AppAmountField(
            controller: _amountController,
            labelText: '金额',
            currencyCode: defaultMoneyCurrencyCode,
            autofocus: !_isEditing,
            prominent: true,
            onChanged: _isEditing
                ? null
                : (_) {
                    setState(() {});
                  },
          ),
          accounts.when(
            data: (value) => AccountSelector(
              accounts: _selectableAccountsForType(
                value.where((account) => account.isActive).toList(),
              ),
              selectedAccountId: _accountId,
              emptyText: widget.type == MoneyTransactionType.income
                  ? '暂无可用于收入的账户'
                  : '暂无可选账户',
              showQuickSelect: true,
              quickSelectCount: 2,
              onChanged: (account) {
                setState(() {
                  _accountId = account?.id;
                  final lockedMethod = _lockedPaymentMethodForAccount(account);
                  if (lockedMethod != null) {
                    _paymentMethod = lockedMethod;
                  } else {
                    final methods = _availablePaymentMethodsForAccount(account);
                    if (!methods.contains(_paymentMethod)) {
                      _paymentMethod = methods.first;
                    }
                  }
                });
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text('账户读取失败'),
          ),
          if (accountRuleHint != null) AppFormHint(text: accountRuleHint),
          if (showInstallmentEntry)
            _InstallmentPaymentEntry(
              onTap: () => _openInstallmentFromExpense(
                accountRows: accountRows,
                catalog: catalog.maybeWhen(
                  data: (value) => value,
                  orElse: () => const MoneyCategoryCatalog.empty(),
                ),
              ),
            ),
          catalog.when(
            data: (value) => widget.showCategorySelector
                ? CategorySelector(
                    catalog: value,
                    selectedCategoryId: _categoryId,
                    selectedSubCategoryId: _subCategoryId,
                    onChanged: (selection) {
                      final nextCategoryId = selection.category?.id;
                      final nextSubCategoryId = selection.subCategory?.id;
                      setState(() {
                        _categoryId = nextCategoryId;
                        _subCategoryId = nextSubCategoryId;
                      });
                      if (nextCategoryId != null && nextSubCategoryId == null) {
                        unawaited(_fillRememberedSubCategory(nextCategoryId));
                      }
                    },
                  )
                : _CategorySelectionSummary(
                    catalog: value,
                    categoryId: _categoryId,
                    subCategoryId: _subCategoryId,
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text('分类读取失败'),
          ),
          DateTimePicker(
            selectedDate: _transactionAt,
            showQuickOptions: !_isEditing,
            onChanged: (value) {
              setState(() => _transactionAt = value);
            },
          ),
          FormDropdown<MoneyPaymentMethod>(
            initialSelection: effectivePaymentMethod,
            label: '支付方式',
            leadingIcon: const Icon(Icons.credit_card_rounded),
            enabled: lockedPaymentMethod == null,
            enableFilter: true,
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                _paymentMethod = value;
              });
            },
            entries: sortedPaymentMethods
                .map(
                  (method) =>
                      DropdownMenuEntry(value: method, label: method.label),
                )
                .toList(),
          ),
          if (effectivePaymentMethod == MoneyPaymentMethod.other)
            SuggestionAutocompleteField(
              controller: _customPaymentNameCtrl,
              suggestions: entrySuggestions.customPaymentMethods,
              labelText: '支付方式名称',
              hintText: '如：美团月付、抖音月付、京东支付',
              prefixIcon: const Icon(Icons.payment_rounded),
              textInputAction: TextInputAction.done,
            ),
          SuggestionAutocompleteField(
            controller: _tagController,
            suggestions: tagCandidates,
            labelText: '标签',
            hintText: '可选，如：南京旅游（建预算后自动计入对应标签预算）',
            prefixIcon: const Icon(Icons.local_offer_rounded),
            textInputAction: TextInputAction.done,
          ),
          if (hasMultipleLegacyTags)
            const AppFormHint(
              text: '该笔历史交易含多个标签，保存后将仅保留一个',
              icon: Icons.info_outline_rounded,
            ),
          _AdvancedTransactionFields(
            initiallyExpanded: _advancedExpanded,
            merchantController: _merchantController,
            merchantSuggestions: entrySuggestions.merchants,
            locationController: _locationController,
            notesController: _notesController,
            onExpansionChanged: (value) {
              setState(() {
                _advancedExpanded = value;
              });
            },
          ),
          if (showSplitConfig)
            _SplitConfigSummary(
              config: _splitConfig,
              isStale: _isSplitConfigStale,
              enabled: canConfigureSplit,
              unavailableText: '添加至少两位成员后可分摊',
              onConfigure: () =>
                  _openSplitConfigDialog(selectedLedger, selectedLedgerMembers),
              onClear: _splitConfig == null
                  ? null
                  : () => setState(() {
                      _splitConfig = null;
                      _splitConfigAmountMinor = null;
                    }),
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

  String get _dialogTitle {
    final action = _isEditing ? '编辑' : '记';
    return '$action${widget.type.label}';
  }

  int? get _installmentEntryAmountMinor {
    if (_isEditing || widget.type != MoneyTransactionType.expense) {
      return null;
    }
    try {
      return parseMoneyAmountToMinor(_amountController.text);
    } on MoneyAmountParseException {
      return null;
    }
  }

  Future<void> _openInstallmentFromExpense({
    required List<MoneyAccountEntity> accountRows,
    required MoneyCategoryCatalog catalog,
  }) async {
    final amountMinor = _installmentEntryAmountMinor;
    final accountId = _accountId;
    if (amountMinor == null || accountId == null || !mounted) {
      return;
    }

    final category = catalog.categoryById(_categoryId);
    final subCategory = catalog.subCategoryById(_subCategoryId);
    final initialName = switch ((category, subCategory)) {
      (null, _) => null,
      (_, null) => category!.name,
      _ => '${category!.name}/${subCategory!.name}',
    };

    final result = await showAppResponsiveDialog<MoneyInstallmentPlanDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => InstallmentPlanFormDialog(
        accounts: accountRows,
        categoryCatalog: catalog,
        initialAccountId: accountId,
        initialCategoryId: _categoryId,
        initialSubCategoryId: _subCategoryId,
        initialPrincipalMinor: amountMinor,
        initialName: initialName,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .createInstallmentPlan(result);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分期计划已创建');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _installmentErrorText(error));
    }
  }

  FToast? _toast;

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  String _installmentErrorText(Object error) {
    if (error is MoneyRepositoryException) {
      return switch (error.code) {
        MoneyRepositoryErrorCode.invalidInstallmentAmount => '请检查分期金额和期数',
        MoneyRepositoryErrorCode.invalidInstallmentAccount => '请选择信用账户',
        MoneyRepositoryErrorCode.installmentPlanNotFound => '分期计划不可用',
        MoneyRepositoryErrorCode.invalidInstallmentStatus => '当前分期状态不可操作',
        MoneyRepositoryErrorCode.creditCardLimitExceeded => '信用账户占用额度不能超过信用额度',
        MoneyRepositoryErrorCode.accountNotFound => '账户不可用',
        MoneyRepositoryErrorCode.databaseReadFailed => '读取失败',
        MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
        _ => '操作失败',
      };
    }
    return '操作失败';
  }

  void _loadRememberedDefaultsOnce(String? selectedLedgerId) {
    if (_defaultsLoaded || _isEditing) {
      return;
    }
    _defaultsLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final session = ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (!session.isUnlocked || userId == null) {
        return;
      }
      final defaults = await ref
          .read(transactionEntryDefaultsStoreProvider)
          .readDefaults(
            userId: userId,
            ledgerId: selectedLedgerId,
            type: widget.type,
          );
      if (!mounted || defaults == null) {
        return;
      }
      setState(() {
        _accountId ??= defaults.accountId;
        if (widget.showCategorySelector) {
          _categoryId ??= defaults.categoryId;
          _subCategoryId ??= defaults.subCategoryId;
        } else {
          _categoryId ??= widget.categoryId;
          _subCategoryId ??= widget.subCategoryId;
        }
        final paymentMethod = defaults.paymentMethod;
        if (paymentMethod != null) {
          _paymentMethod = paymentMethod;
        }
      });
    });
  }

  Future<void> _fillRememberedSubCategory(String categoryId) async {
    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      return;
    }
    final subCategoryId = await ref
        .read(transactionEntryDefaultsStoreProvider)
        .readSubCategoryForCategory(
          userId: userId,
          ledgerId: _ledgerId,
          type: widget.type,
          categoryId: categoryId,
        );
    if (!mounted ||
        subCategoryId == null ||
        _subCategoryId != null ||
        _categoryId != categoryId) {
      return;
    }
    setState(() {
      _subCategoryId = subCategoryId;
    });
  }

  Future<void> _submit() async {
    try {
      final amountMinor = parseMoneyAmountToMinor(_amountController.text);
      if (amountMinor <= 0) {
        setState(() => _errorText = '请输入大于 0 的金额');
        return;
      }
      if (_accountId == null) {
        setState(() => _errorText = '请选择账户');
        return;
      }
      final transaction = widget.transaction;
      final ledger = transaction == null ? _selectedLedgerForSubmit() : null;
      final accounts = transaction != null || ledger == null
          ? ref.read(currentUserVisibleAccountsProvider)
          : ref.read(currentUserMoneyLedgerAccountsProvider(ledger.id));
      final internalAccounts = ref
          .read(currentUserMoneyInternalAccountsProvider)
          .maybeWhen(
            data: (value) => value,
            orElse: () => const <MoneyAccountEntity>[],
          );
      final selectedAccount = _selectedAccountFrom(
        _selectableAccountsForType([
          ...accounts.maybeWhen(
            data: (value) =>
                value.where((account) => account.isActive).toList(),
            orElse: () => const <MoneyAccountEntity>[],
          ),
          ...internalAccounts.where((account) => account.isActive),
        ]),
      );
      if (selectedAccount == null) {
        setState(
          () => _errorText = widget.type == MoneyTransactionType.income
              ? '收入不能选择信用账户'
              : '请选择可用账户',
        );
        return;
      }
      final ruleError = _transactionRuleError(
        account: selectedAccount,
        amountMinor: amountMinor,
      );
      if (ruleError != null) {
        setState(() => _errorText = ruleError);
        return;
      }
      final categoryId = _categoryId;
      if (categoryId == null) {
        setState(() => _errorText = '请选择分类');
        return;
      }

      final notes = _notesController.text.trim();
      final merchant = _merchantController.text.trim();
      final location = _locationController.text.trim();
      final tagText = _tagController.text.trim();
      final tags = tagText.isEmpty ? const <String>[] : <String>[tagText];
      final effectivePaymentMethod = _effectivePaymentMethodForAccount(
        selectedAccount,
      );
      if (_isSplitConfigStale) {
        setState(() => _errorText = '金额变化后请重新设置分摊');
        return;
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        transaction == null
            ? TransactionCreateFormResult(
                draft: MoneyTransactionDraft(
                  type: widget.type,
                  transactionAt: _transactionAt,
                  amountMinor: amountMinor,
                  currencyCode: selectedAccount.currencyCode,
                  description: widget.type.label,
                  notes: notes,
                  merchant: merchant,
                  location: location,
                  accountId: _accountId!,
                  categoryId: categoryId,
                  subCategoryId: _subCategoryId,
                  paymentMethod: effectivePaymentMethod,
                  customPaymentMethodName:
                      _customPaymentNameCtrl.text.trim().isEmpty
                      ? null
                      : _customPaymentNameCtrl.text.trim(),
                  tags: tags,
                  ledgerId: ledger?.id,
                ),
                splitConfig: widget.type == MoneyTransactionType.expense
                    ? _splitConfig
                    : null,
              )
            : MoneyTransactionUpdate(
                id: transaction.id,
                type: widget.type,
                transactionAt: _transactionAt,
                amountMinor: amountMinor,
                currencyCode: transaction.currencyCode,
                notes: notes,
                merchant: merchant,
                location: location,
                accountId: _accountId!,
                categoryId: categoryId,
                subCategoryId: _subCategoryId,
                paymentMethod: effectivePaymentMethod,
                customPaymentMethodName:
                    _customPaymentNameCtrl.text.trim().isEmpty
                    ? null
                    : _customPaymentNameCtrl.text.trim(),
                tags: tags,
              ),
      );
    } on MoneyAmountParseException {
      setState(() => _errorText = '金额格式不正确');
    }
  }

  MoneyAccountEntity? _selectedAccountFrom(List<MoneyAccountEntity> accounts) {
    final accountId = _accountId;
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

  String? _transactionRuleError({
    required MoneyAccountEntity account,
    required int amountMinor,
  }) {
    if (widget.type == MoneyTransactionType.income) {
      if (!account.type.isAssetLike || account.type.isDebtLike) {
        return '收入不能选择信用账户';
      }
      return null;
    }

    if (widget.type != MoneyTransactionType.expense) {
      return null;
    }

    if (account.type.isCreditLike) {
      final availableMinor =
          account.availableCreditMinor +
          (_isEditing && widget.transaction?.accountId == account.id
              ? widget.transaction!.amountMinor
              : 0);
      if (amountMinor > availableMinor) {
        return '信用账户可用额度不足，可用 ${formatMoneyMinor(availableMinor, account.currencyCode)}';
      }
      return null;
    }

    final availableMinor =
        account.balanceMinor +
        (_isEditing && widget.transaction?.accountId == account.id
            ? widget.transaction!.amountMinor
            : 0);
    if (!account.isVirtual && amountMinor > availableMinor) {
      return '账户余额不足，可用 ${formatMoneyMinor(availableMinor, account.currencyCode)}';
    }
    return null;
  }

  List<MoneyAccountEntity> _selectableAccountsForType(
    List<MoneyAccountEntity> accounts,
  ) {
    if (widget.type == MoneyTransactionType.income) {
      return accounts
          .where(
            (account) => account.type.isAssetLike && !account.type.isDebtLike,
          )
          .toList();
    }
    if (widget.type == MoneyTransactionType.expense) {
      return accounts
          .where(
            (account) =>
                account.type.isAssetLike ||
                account.type.isCreditLike ||
                account.type.isInternal,
          )
          .toList();
    }
    return accounts;
  }

  MoneyPaymentMethod? _lockedPaymentMethodForAccount(
    MoneyAccountEntity? account,
  ) {
    return switch (account?.type) {
      MoneyAccountType.cash => MoneyPaymentMethod.cash,
      MoneyAccountType.huabei => MoneyPaymentMethod.huabei,
      MoneyAccountType.baitiao => MoneyPaymentMethod.baitiao,
      MoneyAccountType.alipay => MoneyPaymentMethod.alipay,
      MoneyAccountType.wechat => MoneyPaymentMethod.wechatPay,
      MoneyAccountType.cloudQuickPass => MoneyPaymentMethod.unionPay,
      _ => null,
    };
  }

  List<MoneyPaymentMethod> _availablePaymentMethodsForAccount(
    MoneyAccountEntity? account,
  ) {
    final lockedMethod = _lockedPaymentMethodForAccount(account);
    if (lockedMethod != null) {
      return [lockedMethod];
    }
    return switch (account?.type) {
      MoneyAccountType.creditCard => const [
        MoneyPaymentMethod.creditCard,
        MoneyPaymentMethod.bankTransfer,
        MoneyPaymentMethod.alipay,
        MoneyPaymentMethod.wechatPay,
        MoneyPaymentMethod.unionPay,
        MoneyPaymentMethod.onlinePayment,
        MoneyPaymentMethod.thirdParty,
        MoneyPaymentMethod.other,
      ],
      MoneyAccountType.meituanCredit || MoneyAccountType.otherCredit => const [
        MoneyPaymentMethod.onlinePayment,
        MoneyPaymentMethod.thirdParty,
        MoneyPaymentMethod.alipay,
        MoneyPaymentMethod.wechatPay,
        MoneyPaymentMethod.bankTransfer,
        MoneyPaymentMethod.other,
      ],
      _ => MoneyPaymentMethod.values,
    };
  }

  MoneyPaymentMethod _effectivePaymentMethodForAccount(
    MoneyAccountEntity? account,
  ) {
    final lockedMethod = _lockedPaymentMethodForAccount(account);
    if (lockedMethod != null) {
      return lockedMethod;
    }
    final methods = _availablePaymentMethodsForAccount(account);
    if (methods.contains(_paymentMethod)) {
      return _paymentMethod;
    }
    return methods.first;
  }

  List<MoneyPaymentMethod> _sortPaymentMethodsByUsage(
    List<MoneyPaymentMethod> methods,
    Map<MoneyPaymentMethod, int> usageRanks,
  ) {
    final sorted = [...methods];
    sorted.sort((left, right) {
      final usageCompare = (usageRanks[right] ?? 0).compareTo(
        usageRanks[left] ?? 0,
      );
      if (usageCompare != 0) {
        return usageCompare;
      }
      return left.index.compareTo(right.index);
    });
    return sorted;
  }

  String? _accountRuleHint(MoneyAccountEntity? account) {
    if (widget.type == MoneyTransactionType.income) {
      return '收入只可进入现金、银行、支付宝、微信等资产账户';
    }
    if (widget.type != MoneyTransactionType.expense || account == null) {
      return null;
    }
    if (account.type.isCreditLike) {
      return '信用账户支出会增加已入账负债，并占用可用额度';
    }
    return '支出会从所选账户余额中扣减';
  }

  Future<void> _openSplitConfigDialog(
    MoneyLedgerEntity? ledger,
    List<MoneyMemberEntity> ledgerMembers,
  ) async {
    try {
      if (ledger == null) {
        setState(() => _errorText = '请先选择家庭账本');
        return;
      }
      final amountMinor = parseMoneyAmountToMinor(_amountController.text);
      if (amountMinor <= 0) {
        setState(() => _errorText = '请先输入大于 0 的金额');
        return;
      }

      final result = await showAppResponsiveDialog<MoneySplitConfigDraft>(
        context: context,
        expandCompactSheet: true,
        builder: (context) => TransactionSplitDialog(
          ledgerId: ledger.id,
          initialMembers: ledgerMembers,
          amountMinor: amountMinor,
          currencyCode: defaultMoneyCurrencyCode,
          title: '设置支出分摊',
          confirmLabel: '使用此分摊',
        ),
      );
      if (result == null || !mounted) {
        return;
      }
      setState(() {
        _splitConfig = result;
        _splitConfigAmountMinor = amountMinor;
        _errorText = null;
      });
    } on MoneyAmountParseException {
      setState(() => _errorText = '金额格式不正确');
    }
  }

  MoneyLedgerEntity? _selectedLedgerForSubmit() {
    return ref
        .read(currentUserMoneyLedgersProvider)
        .maybeWhen(
          data: _selectedLedgerFrom,
          orElse: () {
            final initialLedger = widget.ledger;
            return initialLedger != null && initialLedger.isFamily
                ? initialLedger
                : null;
          },
        );
  }

  MoneyLedgerEntity? _selectedLedgerFrom(List<MoneyLedgerEntity> ledgers) {
    final selectedLedgerId = _ledgerId;
    if (selectedLedgerId == null) {
      return null;
    }
    for (final ledger in ledgers) {
      if (ledger.id == selectedLedgerId && ledger.isFamily) {
        return ledger;
      }
    }
    return null;
  }
}

class _AdvancedTransactionFields extends StatelessWidget {
  const _AdvancedTransactionFields({
    required this.initiallyExpanded,
    required this.merchantController,
    this.merchantSuggestions = const <String>[],
    required this.locationController,
    required this.notesController,
    required this.onExpansionChanged,
  });

  final bool initiallyExpanded;
  final TextEditingController merchantController;
  final List<String> merchantSuggestions;
  final TextEditingController locationController;
  final TextEditingController notesController;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: Text(
            '更多信息',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          onExpansionChanged: onExpansionChanged,
          children: [
            SuggestionAutocompleteField(
              controller: merchantController,
              suggestions: merchantSuggestions,
              labelText: '商家',
              hintText: '例如 京东、盒马、星巴克',
              prefixIcon: const Icon(Icons.storefront_rounded),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: locationController,
              labelText: '地点',
              hintText: '例如 上海、公司楼下',
              prefixIcon: const Icon(Icons.location_on_rounded),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: notesController,
              minLines: 2,
              maxLines: 3,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySelectionSummary extends StatelessWidget {
  const _CategorySelectionSummary({
    required this.catalog,
    required this.categoryId,
    required this.subCategoryId,
  });

  final MoneyCategoryCatalog catalog;
  final String? categoryId;
  final String? subCategoryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = catalog.categoryById(categoryId);
    final subCategory = catalog.subCategoryById(subCategoryId);
    final primaryText = category == null
        ? '未选择分类'
        : subCategory == null
        ? category.name
        : '${category.name} / ${subCategory.name}';

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.sell_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _TransactionLedgerMenuItem extends StatelessWidget {
  const _TransactionLedgerMenuItem({required this.ledger});

  final MoneyLedgerEntity ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFamily = ledger.isFamily;

    return Row(
      children: [
        Icon(
          isFamily ? Icons.diversity_3_rounded : Icons.person_outline_rounded,
          size: 18,
          color: isFamily ? colorScheme.tertiary : colorScheme.secondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ledger.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isFamily ? '家庭' : '个人',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SplitConfigSummary extends StatelessWidget {
  const _SplitConfigSummary({
    required this.config,
    required this.isStale,
    required this.enabled,
    required this.unavailableText,
    required this.onConfigure,
    required this.onClear,
  });

  final MoneySplitConfigDraft? config;
  final bool isStale;
  final bool enabled;
  final String unavailableText;
  final VoidCallback onConfigure;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = this.config;
    final title = config == null
        ? '分摊'
        : isStale
        ? '分摊需重新设置'
        : '${config.splitType.label}分摊';
    final subtitle = !enabled
        ? unavailableText
        : config == null
        ? '可选，适合聚餐、共同支出、代付'
        : isStale
        ? '金额已变化，请重新设置分摊'
        : '已选择 ${config.participants.length} 位成员';
    final subtitleColor = isStale
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.call_split_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isStale ? colorScheme.error : null,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            AppIconActionButton(
              tooltip: '清除分摊',
              onPressed: onClear,
              icon: Icons.close_rounded,
            ),
          AppIconActionButton(
            tooltip: '设置分摊',
            onPressed: enabled ? onConfigure : null,
            icon: Icons.tune_rounded,
            variant: AppIconActionVariant.outlined,
          ),
        ],
      ),
    );
  }
}

class _InstallmentPaymentEntry extends StatelessWidget {
  const _InstallmentPaymentEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分期支付',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '转为分期计划，首期到期自动入账',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          AppIconActionButton(
            tooltip: '转为分期支付',
            onPressed: onTap,
            icon: Icons.arrow_forward_rounded,
            variant: AppIconActionVariant.outlined,
          ),
        ],
      ),
    );
  }
}
