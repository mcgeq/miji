import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_color_picker.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';

class BudgetFormDialog extends ConsumerStatefulWidget {
  const BudgetFormDialog({super.key, this.budget});

  final MoneyBudgetEntity? budget;

  @override
  ConsumerState<BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _alertThresholdController;
  MoneyBudgetTrackingType _trackingType = MoneyBudgetTrackingType.expenseLimit;
  MoneyBudgetPeriodType _periodType = MoneyBudgetPeriodType.monthly;
  MoneyBudgetScopeType _scopeType = MoneyBudgetScopeType.all;
  String? _ledgerId;
  String? _categoryId;
  String? _subCategoryId;
  String? _accountId;
  String? _categoryErrorText;
  String? _scopeErrorText;
  bool _alertEnabled = false;
  bool _autoRollover = false;
  String _selectedColor = '#F97316';

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    _nameController = TextEditingController(text: budget?.name ?? '');
    _descriptionController = TextEditingController(
      text: budget?.description ?? '',
    );
    _amountController = TextEditingController(
      text: budget == null ? '' : (budget.amountMinor / 100).toStringAsFixed(2),
    );
    _alertThresholdController = TextEditingController(
      text: budget?.alertThresholdPercent?.toString() ?? '80',
    );
    _categoryId = budget?.categoryId;
    _subCategoryId = budget?.subCategoryId;
    _accountId = budget?.accountId;
    _ledgerId = budget?.ledgerId;
    _trackingType =
        budget?.trackingType ?? MoneyBudgetTrackingType.expenseLimit;
    _periodType = budget?.periodType ?? MoneyBudgetPeriodType.monthly;
    _scopeType = budget?.scopeType ?? MoneyBudgetScopeType.all;
    if (_scopeType == MoneyBudgetScopeType.all) {
      _categoryId = null;
      _subCategoryId = null;
      _accountId = null;
    } else if (_scopeType == MoneyBudgetScopeType.category) {
      _accountId = null;
    } else if (_scopeType == MoneyBudgetScopeType.account) {
      _categoryId = null;
      _subCategoryId = null;
    }
    _alertEnabled = budget?.alertEnabled ?? false;
    _autoRollover = budget?.autoRollover ?? false;
    _selectedColor = budget?.color ?? '#F97316';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _alertThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryKind = _trackingType == MoneyBudgetTrackingType.incomeTarget
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
    final catalog = ref.watch(currentUserCategoryCatalogProvider(categoryKind));
    final ledgers = ref.watch(currentUserMoneyLedgersProvider);
    final ledgerRows = ledgers.maybeWhen(
      data: (items) => items,
      orElse: () => null,
    );
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final selectedLedger = _ledgerFrom(ledgerRows, _ledgerId) ?? currentLedger;
    final accounts = selectedLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(selectedLedger.id));
    final selectedAccount = accounts.maybeWhen(
      data: (value) => _accountById(value, _accountId),
      orElse: () => null,
    );
    final usesCategoryScope =
        _scopeType == MoneyBudgetScopeType.category ||
        _scopeType == MoneyBudgetScopeType.categoryAccount;
    final usesAccountScope =
        _scopeType == MoneyBudgetScopeType.account ||
        _scopeType == MoneyBudgetScopeType.categoryAccount;
    final billingCycleAvailable =
        usesAccountScope &&
        (selectedAccount?.hasBillingCycle == true ||
            _periodType == MoneyBudgetPeriodType.billingCycle);
    final amountLabel = _trackingType == MoneyBudgetTrackingType.incomeTarget
        ? '目标金额'
        : '预算金额';
    final canChangeLedger =
        !_isEditing || (widget.budget?.usedAmountMinor ?? 0) <= 0;

    return AppDialogScaffold(
      title: _isEditing ? '编辑预算' : '新增预算',
      maxWidth: 460,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            if (canChangeLedger)
              ledgers.when(
                data: (items) => FormDropdown<String?>(
                  initialSelection: _ledgerId,
                  label: '所属账本',
                  leadingIcon: const Icon(Icons.menu_book_rounded),
                  width: double.infinity,
                  enableFilter: true,
                  entries: [
                    for (final ledger in items)
                      DropdownMenuEntry<String?>(
                        value: ledger.id,
                        label: ledger.name,
                        labelWidget: _BudgetLedgerMenuItem(ledger: ledger),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == _ledgerId) {
                      return;
                    }
                    setState(() {
                      _ledgerId = value;
                      _categoryId = null;
                      _subCategoryId = null;
                      _accountId = null;
                      _categoryErrorText = null;
                      _scopeErrorText = null;
                      if (_periodType == MoneyBudgetPeriodType.billingCycle) {
                        _periodType = MoneyBudgetPeriodType.monthly;
                      }
                    });
                  },
                ),
                loading: () => const AppFormHint(text: '账本加载中...'),
                error: (error, stackTrace) => const Text('账本读取失败'),
              )
            else if (selectedLedger != null)
              _BudgetLedgerNotice(ledger: selectedLedger, isEditing: true),
            AppTextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              labelText: '预算名称',
              prefixIcon: const Icon(Icons.flag_rounded),
              validator: _validateName,
            ),
            AppSlidingSegmentedControl<MoneyBudgetTrackingType>(
              minSegmentWidth: 116,
              value: _trackingType,
              segments: const [
                AppSlidingSegment(
                  value: MoneyBudgetTrackingType.expenseLimit,
                  icon: Icons.trending_down_rounded,
                  label: '支出限额',
                ),
                AppSlidingSegment(
                  value: MoneyBudgetTrackingType.incomeTarget,
                  icon: Icons.trending_up_rounded,
                  label: '收入目标',
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _trackingType = value;
                  _categoryId = null;
                  _subCategoryId = null;
                  _categoryErrorText = null;
                  _scopeErrorText = null;
                });
              },
            ),
            AppSlidingSegmentedControl<MoneyBudgetScopeType>(
              minSegmentWidth: 80,
              value: _scopeType,
              segments: const [
                AppSlidingSegment(value: MoneyBudgetScopeType.all, label: '全部'),
                AppSlidingSegment(
                  value: MoneyBudgetScopeType.category,
                  label: '分类',
                ),
                AppSlidingSegment(
                  value: MoneyBudgetScopeType.account,
                  label: '账户',
                ),
                AppSlidingSegment(
                  value: MoneyBudgetScopeType.categoryAccount,
                  label: '分类+账户',
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _scopeType = value;
                  if (value == MoneyBudgetScopeType.all) {
                    _categoryId = null;
                    _subCategoryId = null;
                    _accountId = null;
                  } else if (value == MoneyBudgetScopeType.category) {
                    _accountId = null;
                  } else if (value == MoneyBudgetScopeType.account) {
                    _categoryId = null;
                    _subCategoryId = null;
                  }
                  _categoryErrorText = null;
                  _scopeErrorText = null;
                  final canKeepBillingCycle =
                      (value == MoneyBudgetScopeType.account ||
                          value == MoneyBudgetScopeType.categoryAccount) &&
                      selectedAccount?.hasBillingCycle == true;
                  if (_periodType == MoneyBudgetPeriodType.billingCycle &&
                      !canKeepBillingCycle) {
                    _periodType = MoneyBudgetPeriodType.monthly;
                  }
                });
              },
            ),
            if (usesCategoryScope)
              catalog.when(
                data: (value) => CategorySelector(
                  catalog: value,
                  selectedCategoryId: _categoryId,
                  selectedSubCategoryId: _subCategoryId,
                  allowClear: false,
                  categoryLabelText: categoryKind == MoneyCategoryKind.income
                      ? '收入分类'
                      : '支出分类',
                  onChanged: (selection) {
                    setState(() {
                      _categoryId = selection.category?.id;
                      _subCategoryId = selection.subCategory?.id;
                      _categoryErrorText = null;
                      _scopeErrorText = null;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => const Text('分类读取失败'),
              ),
            if (usesAccountScope)
              accounts.when(
                data: (value) => AccountSelector(
                  accounts: value,
                  selectedAccountId: _accountId,
                  labelText: '账户范围',
                  emptyText: '暂无可选账户',
                  allowClear: false,
                  onChanged: (account) {
                    setState(() {
                      _accountId = account?.id;
                      if (_periodType == MoneyBudgetPeriodType.billingCycle &&
                          account?.hasBillingCycle != true) {
                        _periodType = MoneyBudgetPeriodType.monthly;
                      }
                      _scopeErrorText = null;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => const Text('账户读取失败'),
              ),
            FormDropdown<MoneyBudgetPeriodType>(
              initialSelection: _periodType,
              label: '预算周期',
              leadingIcon: const Icon(Icons.event_repeat_rounded),
              width: double.infinity,
              onSelected: (value) {
                if (value == null) return;
                setState(() => _periodType = value);
              },
              entries:
                  const [
                    DropdownMenuEntry(
                      value: MoneyBudgetPeriodType.daily,
                      label: '每天',
                    ),
                    DropdownMenuEntry(
                      value: MoneyBudgetPeriodType.weekly,
                      label: '每周',
                    ),
                    DropdownMenuEntry(
                      value: MoneyBudgetPeriodType.monthly,
                      label: '每月',
                    ),
                    DropdownMenuEntry(
                      value: MoneyBudgetPeriodType.billingCycle,
                      label: '账单周期',
                    ),
                    DropdownMenuEntry(
                      value: MoneyBudgetPeriodType.yearly,
                      label: '每年',
                    ),
                  ].where((entry) {
                    return entry.value != MoneyBudgetPeriodType.billingCycle ||
                        billingCycleAvailable ||
                        _periodType == MoneyBudgetPeriodType.billingCycle;
                  }).toList(),
            ),
            AppAmountField(
              controller: _amountController,
              labelText: amountLabel,
              validator: _validateAmount,
            ),
            if (_categoryErrorText != null)
              Text(
                _categoryErrorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_scopeErrorText != null)
              Text(
                _scopeErrorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            AppTextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
            AppColorPickerField(
              title: '预算颜色',
              selectedColor: _selectedColor,
              onSelected: (color) {
                setState(() => _selectedColor = color);
              },
            ),
            AppSwitchField(
              title: '启用提醒阈值',
              icon: Icons.notifications_active_rounded,
              value: _alertEnabled,
              onChanged: (value) {
                setState(() => _alertEnabled = value);
              },
            ),
            if (_trackingType == MoneyBudgetTrackingType.expenseLimit)
              AppSwitchField(
                title: '自动结转剩余额度',
                subtitle: '周期结束时未用完的预算自动滚入下一周期',
                icon: Icons.sync_alt_rounded,
                value: _autoRollover,
                onChanged: (value) {
                  setState(() => _autoRollover = value);
                },
              ),
            if (_alertEnabled)
              AppTextFormField(
                controller: _alertThresholdController,
                keyboardType: TextInputType.number,
                labelText: '提醒阈值',
                prefixIcon: const Icon(Icons.notifications_active_rounded),
                suffixText: '%',
                validator: _validateAlertThreshold,
              ),
          ],
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: _isEditing ? '保存' : '创建',
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final scopeErrorText = switch (_scopeType) {
      MoneyBudgetScopeType.all => null,
      MoneyBudgetScopeType.category => _categoryId == null ? '请选择分类' : null,
      MoneyBudgetScopeType.account => _accountId == null ? '请选择账户' : null,
      MoneyBudgetScopeType.categoryAccount =>
        _categoryId == null || _accountId == null ? '请选择分类和账户' : null,
    };
    if (scopeErrorText != null) {
      setState(() => _scopeErrorText = scopeErrorText);
      return;
    }
    if (_periodType == MoneyBudgetPeriodType.billingCycle) {
      final ledgerRows = ref
          .read(currentUserMoneyLedgersProvider)
          .maybeWhen(data: (items) => items, orElse: () => null);
      final ledger =
          _ledgerFrom(ledgerRows, _ledgerId) ??
          ref.read(currentUserCurrentLedgerValueProvider);
      final account = ledger == null
          ? null
          : ref
                .read(currentUserMoneyLedgerAccountsProvider(ledger.id))
                .maybeWhen(
                  data: (value) => _accountById(value, _accountId),
                  orElse: () => null,
                );
      if (account?.hasBillingCycle != true) {
        setState(
          () => _scopeErrorText =
              '账单周期需要选择已配置账单日的信用账户，预算周期会跟随该账户的预算周期起始日；未设置时跟随账单日。',
        );
        return;
      }
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final amountMinor = parseMoneyAmountToMinor(_amountController.text);
    final alertThreshold = _alertEnabled
        ? int.parse(_alertThresholdController.text.trim())
        : null;
    final budget = widget.budget;
    final effectiveCategoryId = switch (_scopeType) {
      MoneyBudgetScopeType.all => null,
      MoneyBudgetScopeType.account => null,
      MoneyBudgetScopeType.category => _categoryId,
      MoneyBudgetScopeType.categoryAccount => _categoryId,
    };
    final effectiveSubCategoryId = switch (_scopeType) {
      MoneyBudgetScopeType.all => null,
      MoneyBudgetScopeType.account => null,
      MoneyBudgetScopeType.category =>
        _categoryId == null ? null : _subCategoryId,
      MoneyBudgetScopeType.categoryAccount =>
        _categoryId == null ? null : _subCategoryId,
    };
    final effectiveAccountId = switch (_scopeType) {
      MoneyBudgetScopeType.all => null,
      MoneyBudgetScopeType.category => null,
      MoneyBudgetScopeType.account => _accountId,
      MoneyBudgetScopeType.categoryAccount => _accountId,
    };

    Navigator.of(context).pop(
      budget == null
          ? MoneyBudgetDraft(
              name: name,
              description: description.isEmpty ? null : description,
              ledgerId: _ledgerId,
              trackingType: _trackingType,
              periodType: _periodType,
              repeatInterval: 1,
              scopeType: _scopeType,
              amountMinor: amountMinor,
              categoryId: effectiveCategoryId,
              subCategoryId: effectiveSubCategoryId,
              accountId: effectiveAccountId,
              alertEnabled: _alertEnabled,
              alertThresholdPercent: alertThreshold,
              autoRollover: _autoRollover,
              color: _selectedColor,
            )
          : MoneyBudgetUpdate(
              id: budget.id,
              name: name,
              ledgerId: _ledgerId ?? budget.ledgerId,
              description: description.isEmpty ? null : description,
              trackingType: _trackingType,
              periodType: _periodType,
              repeatInterval: 1,
              scopeType: _scopeType,
              amountMinor: amountMinor,
              currencyCode: budget.currencyCode,
              categoryId: effectiveCategoryId,
              subCategoryId: effectiveSubCategoryId,
              accountId: effectiveAccountId,
              isActive: budget.isActive,
              alertEnabled: _alertEnabled,
              alertThresholdPercent: alertThreshold,
              autoRollover: _autoRollover,
              color: _selectedColor,
            ),
    );
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入预算名称';
    }
    if (text.length > 30) {
      return '预算名称最多30个字符';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    try {
      final amountMinor = parseMoneyAmountToMinor(value ?? '');
      if (amountMinor <= 0) {
        return '预算金额必须大于0';
      }
      return null;
    } catch (_) {
      return '请输入有效金额';
    }
  }

  String? _validateAlertThreshold(String? value) {
    if (!_alertEnabled) {
      return null;
    }
    final threshold = int.tryParse(value?.trim() ?? '');
    if (threshold == null || threshold < 1 || threshold > 100) {
      return '请输入1到100之间的整数';
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

  MoneyLedgerEntity? _ledgerFrom(
    List<MoneyLedgerEntity>? ledgers,
    String? ledgerId,
  ) {
    if (ledgers == null || ledgerId == null) {
      return null;
    }
    for (final ledger in ledgers) {
      if (ledger.id == ledgerId) {
        return ledger;
      }
    }
    return null;
  }
}

class _BudgetLedgerMenuItem extends StatelessWidget {
  const _BudgetLedgerMenuItem({required this.ledger});

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

class _BudgetLedgerNotice extends StatelessWidget {
  const _BudgetLedgerNotice({required this.ledger, required this.isEditing});

  final MoneyLedgerEntity ledger;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFamily = ledger.isFamily;
    final accent = isFamily ? colorScheme.tertiary : colorScheme.secondary;

    return AppSurface(
      tone: AppSurfaceTone.inset,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AppListItemIcon(
            icon: isFamily
                ? Icons.diversity_3_rounded
                : Icons.account_circle_outlined,
            color: accent,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? '所属账本' : '当前账本',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFamily ? '家庭账本 · ${ledger.name}' : '个人账本',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: isEditing ? '预算已产生使用记录，账本不可更换' : '预算会自动绑定到这个账本',
            child: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
