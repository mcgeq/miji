import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_color_picker.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_presentation_helpers.dart';

class AccountFormResult {
  const AccountFormResult.create(this.draft) : update = null;

  const AccountFormResult.update(this.update) : draft = null;

  final MoneyAccountDraft? draft;
  final MoneyAccountUpdate? update;
}

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({super.key, this.account, this.defaultCurrencyCode});

  final MoneyAccountEntity? account;
  final String? defaultCurrencyCode;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _initialBalanceController;
  late MoneyAccountType _type;
  late String _currencyCode;
  late String _selectedColor;
  late int _statementDay;
  late int _budgetCycleStartDay;
  late int _repaymentDay;
  late bool _autoRepaymentReminderEnabled;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _descriptionController = TextEditingController(
      text: account?.description ?? '',
    );
    _initialBalanceController = TextEditingController(
      text: account == null
          ? '0'
          : ((account.type.isCreditLike
                        ? account.effectiveCreditLimitMinor
                        : account.initialBalanceMinor) /
                    100)
                .toStringAsFixed(2),
    );
    _type = account?.type == MoneyAccountType.internal
        ? MoneyAccountType.cash
        : account?.type ?? MoneyAccountType.cash;
    _currencyCode = account?.currencyCode ?? _normalizedDefaultCurrencyCode;
    _selectedColor = account?.color ?? defaultAccountColorForType(_type);
    _statementDay = account?.statementDay ?? 1;
    _budgetCycleStartDay =
        account?.budgetCycleStartDay ?? account?.statementDay ?? 1;
    _repaymentDay = account?.repaymentDay ?? 10;
    _autoRepaymentReminderEnabled =
        account?.autoRepaymentReminderEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: _isEditing ? '编辑账户' : '新增账户',
      maxWidth: 440,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            AppTextFormField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              labelText: '账户名称',
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              validator: _validateName,
            ),
            FormDropdown<MoneyAccountType>(
              initialSelection: _type,
              label: '账户类型',
              width: double.infinity,
              leadingIcon: const Icon(Icons.category_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() {
                  final previousType = _type;
                  final shouldUseTypeColor =
                      _selectedColor ==
                      defaultAccountColorForType(previousType);
                  if (shouldUseTypeColor) {
                    _selectedColor = defaultAccountColorForType(value);
                  }
                  if (!previousType.isCreditLike && value.isCreditLike) {
                    _budgetCycleStartDay = _statementDay;
                  }
                  _type = value;
                });
              },
              entries: visibleMoneyAccountTypes
                  .map(
                    (type) => DropdownMenuEntry(
                      value: type,
                      leadingIcon: Icon(accountIconDataForType(type), size: 18),
                      label: type.label,
                    ),
                  )
                  .toList(),
            ),
            AppAmountField(
              controller: _initialBalanceController,
              labelText: _balanceFieldLabel,
              currencyCode: _currencyCode,
              helperText: _balanceFieldHelperText,
              textInputAction: TextInputAction.next,
              validator: _validateAmount,
            ),
            if (_type.isCreditLike) ...[
              _buildBillingCycleFields(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoRepaymentReminderEnabled,
                onChanged: (value) {
                  setState(() => _autoRepaymentReminderEnabled = value);
                },
                title: const Text('自动还款提醒'),
                subtitle: const Text('根据还款日每月提醒，欠款为 0 时不弹系统通知'),
              ),
            ],
            AppTextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
            AppColorPickerField(
              title: '账户颜色',
              selectedColor: _selectedColor,
              onSelected: (color) {
                setState(() => _selectedColor = color);
              },
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

    final account = widget.account;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (account == null) {
      Navigator.of(context).pop(
        AccountFormResult.create(
          MoneyAccountDraft(
            name: name,
            description: description.isEmpty ? null : description,
            type: _type,
            initialBalanceMinor: parseMoneyAmountToMinor(
              _initialBalanceController.text,
            ),
            currencyCode: _currencyCode,
            color: _selectedColor,
            icon: defaultAccountIconForType(_type),
            statementDay: _type.isCreditLike ? _statementDay : null,
            budgetCycleStartDay: _type.isCreditLike
                ? _budgetCycleStartDay
                : null,
            repaymentDay: _type.isCreditLike ? _repaymentDay : null,
            autoRepaymentReminderEnabled:
                _type.isCreditLike && _autoRepaymentReminderEnabled,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      AccountFormResult.update(
        MoneyAccountUpdate(
          id: account.id,
          name: name,
          description: description.isEmpty ? null : description,
          type: _type,
          currencyCode: _currencyCode,
          initialBalanceMinor: parseMoneyAmountToMinor(
            _initialBalanceController.text,
          ),
          color: _selectedColor,
          icon: account.icon ?? defaultAccountIconForType(_type),
          statementDay: _type.isCreditLike ? _statementDay : null,
          budgetCycleStartDay: _type.isCreditLike ? _budgetCycleStartDay : null,
          repaymentDay: _type.isCreditLike ? _repaymentDay : null,
          autoRepaymentReminderEnabled:
              _type.isCreditLike && _autoRepaymentReminderEnabled,
        ),
      ),
    );
  }

  Widget _buildBillingCycleFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = <Widget>[
          _buildBillingCycleField(
            label: '账单日',
            child: FormDropdown<int>(
              initialSelection: _statementDay,
              label: '账单日',
              width: double.infinity,
              leadingIcon: const Icon(Icons.receipt_long_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() {
                  final shouldFollowStatementDay =
                      _budgetCycleStartDay == _statementDay;
                  _statementDay = value;
                  if (shouldFollowStatementDay) {
                    _budgetCycleStartDay = value;
                  }
                });
              },
              entries: _billingDayEntries,
            ),
          ),
          _buildBillingCycleField(
            label: '预算周期起始日',
            child: FormDropdown<int>(
              initialSelection: _budgetCycleStartDay,
              label: '预算周期起始日',
              width: double.infinity,
              leadingIcon: const Icon(Icons.date_range_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() => _budgetCycleStartDay = value);
              },
              entries: _billingDayEntries,
            ),
          ),
          _buildBillingCycleField(
            label: '还款日',
            child: FormDropdown<int>(
              initialSelection: _repaymentDay,
              label: '还款日',
              width: double.infinity,
              leadingIcon: const Icon(Icons.event_available_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() => _repaymentDay = value);
              },
              entries: _billingDayEntries,
            ),
          ),
        ];

        if (constraints.maxWidth < 520) {
          return AppFormColumn(children: fields);
        }

        final rowChildren = <Widget>[];
        for (var index = 0; index < fields.length; index += 1) {
          if (index > 0) {
            rowChildren.add(const SizedBox(width: 12));
          }
          rowChildren.add(Expanded(child: fields[index]));
        }
        return Row(children: rowChildren);
      },
    );
  }

  Widget _buildBillingCycleField({
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
        child,
      ],
    );
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入账户名称';
    }
    if (text.length > 30) {
      return '账户名称最多30个字符';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    try {
      final amountMinor = parseMoneyAmountToMinor(value ?? '');
      if (amountMinor < 0) {
        return '$_balanceFieldLabel不能小于0';
      }

      final account = widget.account;
      if (account == null) {
        return null;
      }

      if (_type.isCreditLike) {
        final usedCreditMinor = account.type.isCreditLike
            ? account.usedCreditMinor
            : 0;
        if (amountMinor < usedCreditMinor) {
          return '信用额度不能小于已占用额度';
        }
        return null;
      }

      final newBalanceMinor = account.type.isCreditLike
          ? amountMinor
          : account.balanceMinor + (amountMinor - account.initialBalanceMinor);
      if (newBalanceMinor < 0) {
        return '$_balanceFieldLabel调整过低，账户余额不能小于0';
      }

      return null;
    } catch (_) {
      return '请输入有效金额';
    }
  }

  String get _balanceFieldLabel {
    return _type.isCreditLike ? '信用额度' : '初始余额';
  }

  String? get _balanceFieldHelperText {
    if (_type.isCreditLike) {
      return _isEditing ? '不能低于已占用额度' : '创建后已入账负债和冻结额度为 0';
    }
    return _isEditing ? '修改后会按差额同步调整当前余额' : null;
  }

  String get _normalizedDefaultCurrencyCode {
    final value = widget.defaultCurrencyCode?.trim().toUpperCase();
    if (value != null && supportedMoneyCurrencyCodes.contains(value)) {
      return value;
    }
    return defaultMoneyCurrencyCode;
  }

  List<DropdownMenuEntry<int>> get _billingDayEntries {
    return List.generate(31, (index) {
      final day = index + 1;
      return DropdownMenuEntry(value: day, label: '$day 日');
    });
  }
}
