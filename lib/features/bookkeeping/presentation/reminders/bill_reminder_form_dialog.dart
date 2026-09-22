import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/money_amount_input.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

/// 账单提醒表单。
///
/// 从已废弃的 `money_bill_reminders_section.dart` 抽出，让「提醒中心」可以新建/编辑
/// 账单提醒——此前唯一的入口是那个没人引用的旧页面。
class BillReminderFormDialog extends ConsumerStatefulWidget {
  const BillReminderFormDialog({super.key, this.reminder});

  final MoneyBillReminderEntity? reminder;

  @override
  ConsumerState<BillReminderFormDialog> createState() =>
      _BillReminderFormDialogState();
}

class _BillReminderFormDialogState
    extends ConsumerState<BillReminderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  /// 移动端用底部停靠的数字键盘，宽屏用系统键盘。
  final MoneyAmountInput _amount = MoneyAmountInput();
  late final TextEditingController _remindBeforeController;
  late final TextEditingController _repeatIntervalController;
  late final TextEditingController _notesController;
  late DateTime _dueDate;
  String? _accountId;
  String? _categoryId;
  MoneyBillReminderRepeatPeriodType? _repeatPeriodType;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _nameController = TextEditingController(text: reminder?.name ?? '');
    if (reminder != null) {
      _amount.seed(reminder.amountMinor);
    }
    _remindBeforeController = TextEditingController(
      text: (reminder?.remindBeforeDays ?? 1).toString(),
    );
    _repeatIntervalController = TextEditingController(
      text: (reminder?.repeatInterval ?? 1).toString(),
    );
    _notesController = TextEditingController(text: reminder?.notes ?? '');
    _dueDate = reminder?.dueDate ?? DateTime.now();
    _accountId = reminder?.accountId;
    _categoryId = reminder?.categoryId;
    _repeatPeriodType = reminder?.repeatPeriodType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amount.dispose();
    _remindBeforeController.dispose();
    _repeatIntervalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.reminder != null;
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final categories = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );

    final showKeypad = _amount.shouldDock(context);

    return AppDialogScaffold(
      title: editing ? '编辑提醒' : '新增提醒',
      bottomDock: showKeypad
          ? _amount.buildDock(context, onChanged: () => setState(() {}))
          : null,
      titleTextAlign: TextAlign.center,
      maxWidth: 520,
      errorText: _errorText,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            AppTextFormField(
              controller: _nameController,
              labelText: '提醒名称',
              prefixIcon: const Icon(Icons.notifications_active_rounded),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入提醒名称' : null,
            ),
            if (!showKeypad) _amount.buildField(),
            _DatePickerField(
              label: '到期日期',
              date: _dueDate,
              onChanged: (value) => setState(() => _dueDate = value),
            ),
            FormDropdown<MoneyBillReminderRepeatPeriodType?>(
              initialSelection: _repeatPeriodType,
              label: '重复周期',
              leadingIcon: const Icon(Icons.event_repeat_rounded),
              width: double.infinity,
              onSelected: (value) {
                setState(() {
                  _repeatPeriodType = value;
                  if (value == null) {
                    _repeatIntervalController.text = '1';
                  }
                });
              },
              entries: [
                const DropdownMenuEntry<MoneyBillReminderRepeatPeriodType?>(
                  value: null,
                  label: '不重复',
                ),
                ...MoneyBillReminderRepeatPeriodType.values.map(
                  (type) =>
                      DropdownMenuEntry<MoneyBillReminderRepeatPeriodType?>(
                        value: type,
                        label: _repeatPeriodLabel(type),
                      ),
                ),
              ],
            ),
            if (_repeatPeriodType != null)
              AppTextFormField(
                controller: _repeatIntervalController,
                labelText: '重复间隔',
                suffixText: _repeatPeriodUnit(_repeatPeriodType),
                prefixIcon: const Icon(Icons.repeat_rounded),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final interval = int.tryParse(value?.trim() ?? '');
                  if (interval == null || interval <= 0 || interval > 99) {
                    return '请输入 1-99';
                  }
                  return null;
                },
              ),
            AppTextFormField(
              controller: _remindBeforeController,
              labelText: '提前提醒',
              suffixText: '天',
              prefixIcon: const Icon(Icons.schedule_rounded),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final days = int.tryParse(value?.trim() ?? '');
                if (days == null || days < 0 || days > 365) {
                  return '请输入 0-365 天';
                }
                return null;
              },
            ),
            accounts.when(
              data: (value) => AccountSelector(
                accounts: value,
                selectedAccountId: _accountId,
                labelText: '关联账户',
                emptyText: '暂无可选账户',
                allowClear: true,
                clearLabel: '不关联账户',
                onChanged: (account) {
                  setState(() => _accountId = account?.id);
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('账户读取失败'),
            ),
            categories.when(
              data: (value) => CategorySelector(
                catalog: value,
                selectedCategoryId: _categoryId,
                selectedSubCategoryId: null,
                showSubCategory: false,
                allowClear: true,
                clearCategoryLabel: '不关联分类',
                categoryLabelText: '关联支出分类',
                onChanged: (selection) {
                  setState(() => _categoryId = selection.category?.id);
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('分类读取失败'),
            ),
            AppTextFormField(
              controller: _notesController,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actionsAlignment: WrapAlignment.center,
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        cancelTooltip: '取消',
        confirmTooltip: editing ? '保存' : '创建',
      ),
    );
  }

  /// 金额（分）。键盘模式下没有 validator，这里统一兜底校验。
  int get _amountAmountMinor {
    try {
      return parseMoneyAmountToMinor(_amount.controller.text);
    } on MoneyAmountParseException {
      return 0;
    }
  }

  void _submit() {
    if (_amountAmountMinor <= 0) {
      setState(() => _errorText = '请输入有效金额');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      BillReminderFormResult(
        name: _nameController.text.trim(),
        amountMinor: _amountAmountMinor,
        dueDate: _dueDate,
        remindBeforeDays: int.parse(_remindBeforeController.text.trim()),
        repeatPeriodType: _repeatPeriodType,
        repeatInterval: _repeatPeriodType == null
            ? null
            : int.parse(_repeatIntervalController.text.trim()),
        accountId: _accountId,
        categoryId: _categoryId,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: appInputDecoration(
          context,
          labelText: label,
          prefixIcon: const Icon(Icons.event_rounded),
          enabled: true,
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(date),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// 表单提交结果，负责转换成仓储层需要的 draft / update。
class BillReminderFormResult {
  const BillReminderFormResult({
    required this.name,
    required this.amountMinor,
    required this.dueDate,
    required this.remindBeforeDays,
    required this.repeatPeriodType,
    required this.repeatInterval,
    required this.accountId,
    required this.categoryId,
    this.notes,
  });

  final String name;
  final int amountMinor;
  final DateTime dueDate;
  final int remindBeforeDays;
  final MoneyBillReminderRepeatPeriodType? repeatPeriodType;
  final int? repeatInterval;
  final String? accountId;
  final String? categoryId;
  final String? notes;

  MoneyBillReminderDraft toDraft() {
    return MoneyBillReminderDraft(
      name: name,
      amountMinor: amountMinor,
      dueDate: dueDate,
      remindBeforeDays: remindBeforeDays,
      repeatPeriodType: repeatPeriodType,
      repeatInterval: repeatInterval,
      accountId: accountId,
      categoryId: categoryId,
      notes: notes,
    );
  }

  MoneyBillReminderUpdate toUpdate(MoneyBillReminderEntity reminder) {
    return MoneyBillReminderUpdate(
      id: reminder.id,
      name: name,
      amountMinor: amountMinor,
      dueDate: dueDate,
      remindBeforeDays: remindBeforeDays,
      ledgerId: reminder.ledgerId,
      repeatPeriodType: repeatPeriodType,
      repeatInterval: repeatInterval,
      accountId: accountId,
      categoryId: categoryId,
      sourceType: reminder.sourceType,
      sourceKey: reminder.sourceKey,
      amountSource: reminder.amountSource,
      autoManaged: reminder.autoManaged,
      status: reminder.status,
      notes: notes,
    );
  }
}

String _repeatPeriodLabel(MoneyBillReminderRepeatPeriodType type) {
  return switch (type) {
    MoneyBillReminderRepeatPeriodType.daily => '每天',
    MoneyBillReminderRepeatPeriodType.weekly => '每周',
    MoneyBillReminderRepeatPeriodType.monthly => '每月',
    MoneyBillReminderRepeatPeriodType.yearly => '每年',
  };
}

String _repeatPeriodUnit(MoneyBillReminderRepeatPeriodType? type) {
  return switch (type) {
    MoneyBillReminderRepeatPeriodType.daily => '天',
    MoneyBillReminderRepeatPeriodType.weekly => '周',
    MoneyBillReminderRepeatPeriodType.monthly => '月',
    MoneyBillReminderRepeatPeriodType.yearly => '年',
    null => '次',
  };
}
