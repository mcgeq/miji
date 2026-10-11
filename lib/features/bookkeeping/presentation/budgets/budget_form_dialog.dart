import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_color_picker.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/suggestion_autocomplete_field.dart';

class BudgetFormDialog extends ConsumerStatefulWidget {
  const BudgetFormDialog({
    super.key,
    this.budget,
    this.initialScopeType,
    this.initialCategoryId,
    this.initialSubCategoryId,
    this.initialAccountId,
    this.initialTag,
    this.initialTrackingType,
  });

  final MoneyBudgetEntity? budget;

  /// 从统计下钻 / 流水筛选直接建预算时的预填值。
  ///
  /// 「看完发现这个分类花超了」到「给它设个预算」之间原本要回到预算页、
  /// 重新选分类，这一步经常就懒得走了。传这些值进来，表单直接落在正确位置。
  final MoneyBudgetScopeType? initialScopeType;
  final String? initialCategoryId;
  final String? initialSubCategoryId;
  final String? initialAccountId;
  final String? initialTag;
  final MoneyBudgetTrackingType? initialTrackingType;

  @override
  ConsumerState<BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<BudgetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late final TextEditingController _amountController;
  late final TextEditingController _alertThresholdController;
  late final TextEditingController _repeatIntervalController;
  late final TextEditingController _tagController;
  MoneyBudgetTrackingType _trackingType = MoneyBudgetTrackingType.expenseLimit;
  MoneyBudgetPeriodType _periodType = MoneyBudgetPeriodType.monthly;
  MoneyBudgetScopeType _scopeType = MoneyBudgetScopeType.all;
  String? _ledgerId;
  String? _categoryId;
  String? _subCategoryId;
  String? _accountId;
  String? _categoryErrorText;
  String? _scopeErrorText;
  String? _periodErrorText;
  bool _alertEnabled = false;
  bool _autoRollover = false;
  bool _isLoadingReference = false;
  String? _referenceHint;
  String _selectedColor = '#F97316';
  DateTime? _startDate;
  DateTime? _endDate;

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
    _repeatIntervalController = TextEditingController(
      text: (budget?.repeatInterval ?? 1).toString(),
    );
    _categoryId = budget?.categoryId ?? widget.initialCategoryId;
    _subCategoryId = budget?.subCategoryId ?? widget.initialSubCategoryId;
    _accountId = budget?.accountId ?? widget.initialAccountId;
    _ledgerId = budget?.ledgerId;
    _trackingType =
        budget?.trackingType ??
        widget.initialTrackingType ??
        MoneyBudgetTrackingType.expenseLimit;
    _periodType = budget?.periodType ?? MoneyBudgetPeriodType.monthly;
    _scopeType =
        budget?.scopeType ??
        widget.initialScopeType ??
        MoneyBudgetScopeType.all;
    _tagController = TextEditingController(
      text: budget?.tag ?? widget.initialTag ?? '',
    );
    if (_scopeType == MoneyBudgetScopeType.all) {
      _categoryId = null;
      _subCategoryId = null;
      _accountId = null;
    } else if (_scopeType == MoneyBudgetScopeType.category) {
      _accountId = null;
    } else if (_scopeType == MoneyBudgetScopeType.account) {
      _categoryId = null;
      _subCategoryId = null;
    } else if (_scopeType == MoneyBudgetScopeType.tag) {
      _categoryId = null;
      _subCategoryId = null;
      _accountId = null;
    }
    _alertEnabled = budget?.alertEnabled ?? false;
    _autoRollover = budget?.autoRollover ?? false;
    _selectedColor = budget?.color ?? '#F97316';
    if (budget?.periodType == MoneyBudgetPeriodType.oneTime) {
      // periodEnd 是 exclusive 次日 - 1ms（含最后一天），取 y/m/d 得含当天；
      // 依赖 entity 层 periodEnd 的 inclusive 契约，改动需同步此处。
      final start = budget!.periodStart;
      final end = budget.periodEnd;
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _alertThresholdController.dispose();
    _repeatIntervalController.dispose();
    _tagController.dispose();
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
    final usesTagScope = _scopeType == MoneyBudgetScopeType.tag;
    final usesOneTimePeriod = _periodType == MoneyBudgetPeriodType.oneTime;
    final startDate = _startDate;
    final endDate = _endDate;
    final periodMissingRange =
        usesOneTimePeriod && (startDate == null || endDate == null);
    final periodInvalidRange =
        usesOneTimePeriod &&
        startDate != null &&
        endDate != null &&
        endDate.isBefore(startDate);
    final tagCandidates = ref
        .watch(currentUserTagCandidatesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String>[]);
    final tagText = _tagController.text.trim();
    final tagMissingMatch =
        usesTagScope && tagText.isNotEmpty && !tagCandidates.contains(tagText);
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
              minSegmentWidth: 72,
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
                AppSlidingSegment(value: MoneyBudgetScopeType.tag, label: '标签'),
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
                    _tagController.clear();
                  } else if (value == MoneyBudgetScopeType.account) {
                    _categoryId = null;
                    _subCategoryId = null;
                    _tagController.clear();
                  } else if (value == MoneyBudgetScopeType.categoryAccount) {
                    _tagController.clear();
                  } else if (value == MoneyBudgetScopeType.tag) {
                    _categoryId = null;
                    _subCategoryId = null;
                    _accountId = null;
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
            if (usesTagScope) ...[
              SuggestionAutocompleteField(
                controller: _tagController,
                suggestions: tagCandidates,
                labelText: '标签',
                hintText: '如：南京旅游、云南旅游',
                prefixIcon: const Icon(Icons.local_offer_rounded),
              ),
              if (tagMissingMatch)
                AppFormHint(
                  text: '该标签暂无匹配交易，请检查拼写（可从候选中选择已有标签）',
                  icon: Icons.warning_amber_rounded,
                ),
            ],
            FormDropdown<MoneyBudgetPeriodType>(
              initialSelection: _periodType,
              label: '预算周期',
              leadingIcon: const Icon(Icons.event_repeat_rounded),
              width: double.infinity,
              onSelected: (value) {
                if (value == null) return;
                setState(() {
                  _periodType = value;
                  _periodErrorText = null;
                  if (value == MoneyBudgetPeriodType.oneTime) {
                    if (_startDate == null || _endDate == null) {
                      final now = DateTime.now();
                      _startDate = DateTime(now.year, now.month);
                      _endDate = DateTime(now.year, now.month + 1, 0);
                    }
                  } else {
                    _startDate = null;
                    _endDate = null;
                  }
                });
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
                    DropdownMenuEntry(
                      value: MoneyBudgetPeriodType.oneTime,
                      label: '一次性',
                    ),
                  ].where((entry) {
                    return entry.value != MoneyBudgetPeriodType.billingCycle ||
                        billingCycleAvailable ||
                        _periodType == MoneyBudgetPeriodType.billingCycle;
                  }).toList(),
            ),
            if (usesOneTimePeriod) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: DateTimePicker(
                      selectedDate: _startDate ?? DateTime.now(),
                      onChanged: (date) {
                        setState(() {
                          _startDate = date;
                          _periodErrorText = null;
                        });
                      },
                      showTime: false,
                      labelText: '开始日期',
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DateTimePicker(
                      selectedDate: _endDate ?? _startDate ?? DateTime.now(),
                      onChanged: (date) {
                        setState(() {
                          _endDate = date;
                          _periodErrorText = null;
                        });
                      },
                      showTime: false,
                      labelText: '结束日期',
                      firstDate: _startDate ?? DateTime(2000),
                      lastDate: DateTime(2100),
                    ),
                  ),
                ],
              ),
              if (periodMissingRange)
                AppFormHint(
                  text: '请选择一次性预算的起止日期',
                  icon: Icons.warning_amber_rounded,
                ),
              if (periodInvalidRange)
                AppFormHint(
                  text: '结束日期不能早于开始日期',
                  icon: Icons.warning_amber_rounded,
                ),
              if (_periodErrorText != null)
                AppFormHint(
                  text: _periodErrorText!,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
            if (!usesOneTimePeriod)
              AppTextFormField(
                controller: _repeatIntervalController,
                keyboardType: TextInputType.number,
                labelText: '重复间隔',
                prefixIcon: const Icon(Icons.repeat_rounded),
                suffixText: '个周期',
                validator: _validateRepeatInterval,
              ),
            AppAmountField(
              controller: _amountController,
              labelText: amountLabel,
              validator: _validateAmount,
            ),
            // 设预算最大的痛点是不知道该填多少，而近几个月的实际支出就是
            // 最靠谱的锚点。按当前 scope 与收支方向统计，避免「全部分类的
            // 月均」被填进「餐饮预算」里。
            _BudgetHistoryReference(
              busy: _isLoadingReference,
              hint: _referenceHint,
              onFill: _fillAmountFromHistory,
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
            if (_trackingType == MoneyBudgetTrackingType.expenseLimit &&
                _periodType.supportsAutoRollover)
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
      MoneyBudgetScopeType.tag =>
        _tagController.text.trim().isEmpty ? '请输入或选择标签' : null,
    };
    if (scopeErrorText != null) {
      setState(() => _scopeErrorText = scopeErrorText);
      return;
    }
    if (_periodType == MoneyBudgetPeriodType.oneTime) {
      final start = _startDate;
      final end = _endDate;
      if (start == null || end == null) {
        setState(() => _periodErrorText = '请选择一次性预算的起止日期');
        return;
      }
      if (DateTime(
        end.year,
        end.month,
        end.day,
      ).isBefore(DateTime(start.year, start.month, start.day))) {
        setState(() => _periodErrorText = '结束日期不能早于开始日期');
        return;
      }
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
      MoneyBudgetScopeType.tag => null,
    };
    final effectiveSubCategoryId = switch (_scopeType) {
      MoneyBudgetScopeType.all => null,
      MoneyBudgetScopeType.account => null,
      MoneyBudgetScopeType.category =>
        _categoryId == null ? null : _subCategoryId,
      MoneyBudgetScopeType.categoryAccount =>
        _categoryId == null ? null : _subCategoryId,
      MoneyBudgetScopeType.tag => null,
    };
    final effectiveAccountId = switch (_scopeType) {
      MoneyBudgetScopeType.all => null,
      MoneyBudgetScopeType.category => null,
      MoneyBudgetScopeType.account => _accountId,
      MoneyBudgetScopeType.categoryAccount => _accountId,
      MoneyBudgetScopeType.tag => null,
    };
    final effectiveTag = switch (_scopeType) {
      MoneyBudgetScopeType.tag => _tagController.text.trim(),
      _ => null,
    };
    final effectiveStartDate = _periodType == MoneyBudgetPeriodType.oneTime
        ? _startDate
        : null;
    final effectiveEndDate = _periodType == MoneyBudgetPeriodType.oneTime
        ? _endDate
        : null;

    Navigator.of(context).pop(
      budget == null
          ? MoneyBudgetDraft(
              name: name,
              description: description.isEmpty ? null : description,
              ledgerId: _ledgerId,
              trackingType: _trackingType,
              periodType: _periodType,
              repeatInterval: _repeatInterval,
              scopeType: _scopeType,
              amountMinor: amountMinor,
              categoryId: effectiveCategoryId,
              subCategoryId: effectiveSubCategoryId,
              accountId: effectiveAccountId,
              tag: effectiveTag,
              startDate: effectiveStartDate,
              endDate: effectiveEndDate,
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
              repeatInterval: _repeatInterval,
              scopeType: _scopeType,
              amountMinor: amountMinor,
              currencyCode: budget.currencyCode,
              categoryId: effectiveCategoryId,
              subCategoryId: effectiveSubCategoryId,
              accountId: effectiveAccountId,
              tag: effectiveTag,
              startDate: effectiveStartDate,
              endDate: effectiveEndDate,
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

  /// 按近 3 个**完整自然月**的实际发生额填充预算额度。
  ///
  /// 只取完整月：当月还没过完，算进来会把月均拉低，用户照着填必然不够花。
  /// 统计口径与预算「已用」保持一致（只算已入账、排除转账）。
  Future<void> _fillAmountFromHistory() async {
    if (_isLoadingReference) {
      return;
    }
    setState(() {
      _isLoadingReference = true;
      _referenceHint = null;
    });
    try {
      final session = ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) {
        setState(() => _referenceHint = '暂无法读取历史数据');
        return;
      }
      final isIncome = _trackingType == MoneyBudgetTrackingType.incomeTarget;
      final type = isIncome
          ? MoneyTransactionType.income
          : MoneyTransactionType.expense;
      final tag = _scopeType == MoneyBudgetScopeType.tag
          ? _tagController.text.trim()
          : '';
      final ledgerId =
          _ledgerId ?? ref.read(currentUserCurrentLedgerValueProvider)?.id;

      const months = 3;
      final now = DateTime.now();
      final repository = ref.read(moneyRepositoryProvider);
      final monthly = <int>[];
      for (var offset = months; offset >= 1; offset--) {
        // DateTime 的月份会自动借位，11 - 3 = 8 月这类跨年不需要特殊处理。
        final start = DateTime(now.year, now.month - offset, 1);
        final end = DateTime(now.year, now.month - offset + 1, 1);
        final summary = await repository.summarizeTransactions(
          userId,
          MoneyTransactionQuery(
            page: 1,
            pageSize: 1,
            ledgerId: ledgerId,
            type: type,
            status: MoneyTransactionStatus.completed,
            accountId: _accountId,
            categoryId: _categoryId,
            subCategoryId: _subCategoryId,
            tags: tag.isEmpty ? const <String>[] : <String>[tag],
            dateStart: start,
            dateEnd: end.subtract(const Duration(milliseconds: 1)),
          ),
        );
        monthly.add(isIncome ? summary.incomeMinor : summary.expenseMinor);
      }

      var total = 0;
      for (final amount in monthly) {
        total += amount;
      }
      final average = total ~/ months;
      if (average <= 0) {
        setState(() => _referenceHint = '近 $months 个月没有可参考的流水');
        return;
      }
      _amountController.text = (average / 100).toStringAsFixed(2);
      final labels = <String>[];
      for (var index = 0; index < monthly.length; index++) {
        final month = DateTime(now.year, now.month - months + index, 1);
        labels.add('${month.month}月 ${_compactMoney(monthly[index])}');
      }
      setState(
        () => _referenceHint =
            '已按近 $months 个月均值 ${_compactMoney(average)} 填充：${labels.join(' / ')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingReference = false);
      }
    }
  }

  String _compactMoney(int amountMinor) {
    // 预算表单本身没有币种字段，币种由账本决定；这里只用于展示参考值，
    // 取当前账本的基准币种足够。
    final ledger = ref.read(currentUserCurrentLedgerValueProvider);
    return formatMoneyMinor(amountMinor, ledger?.baseCurrencyCode ?? 'CNY');
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

  int get _repeatInterval {
    final parsed = int.tryParse(_repeatIntervalController.text.trim());
    if (parsed == null || parsed < 1) {
      return 1;
    }
    return parsed > 99 ? 99 : parsed;
  }

  String? _validateRepeatInterval(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 1 || parsed > 99) {
      return '请输入 1 到 99 之间的整数';
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

/// 「按历史均值填充」入口。
///
/// 放在金额框下面而不是塞进弹窗：用户最可能在填金额时犹豫，
/// 这时旁边就有一个能算数的按钮，比记住历史数字强得多。
class _BudgetHistoryReference extends StatelessWidget {
  const _BudgetHistoryReference({
    required this.busy,
    required this.hint,
    required this.onFill,
  });

  final bool busy;
  final String? hint;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: busy ? null : onFill,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history_rounded, size: 16),
            label: const Text('按近 3 个月均值填充'),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        if (hint case final text?) ...[
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}
