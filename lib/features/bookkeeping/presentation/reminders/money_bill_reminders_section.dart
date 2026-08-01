import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

class MoneyBillRemindersSection extends ConsumerStatefulWidget {
  const MoneyBillRemindersSection({super.key});

  @override
  ConsumerState<MoneyBillRemindersSection> createState() =>
      _MoneyBillRemindersSectionState();
}

class _MoneyBillRemindersSectionState
    extends ConsumerState<MoneyBillRemindersSection> {
  FToast? _toast;

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(currentUserBillRemindersProvider);
    final accounts = ref.watch(currentUserVisibleAccountsProvider);
    final accountsById = {
      for (final account
          in accounts.asData?.value ?? const <MoneyAccountEntity>[])
        account.id: account,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: AppIconActionButton(
            tooltip: '新增提醒',
            onPressed: () => _openReminderDialog(),
            icon: Icons.add_alert_rounded,
            variant: AppIconActionVariant.filled,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: reminders.when(
            data: (items) => items.isEmpty
                ? AppEmptyState(
                    title: '暂无提醒',
                    message: '可以添加账单、还款或其他需要到期提示的事项。',
                    icon: Icons.notifications_none_rounded,
                    action: AppIconActionButton(
                      tooltip: '新增提醒',
                      onPressed: () => _openReminderDialog(),
                      icon: Icons.add_alert_rounded,
                      variant: AppIconActionVariant.filled,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final reminder = items[index];
                      return _ReminderCard(
                        reminder: reminder,
                        account: accountsById[reminder.accountId],
                        onEdit: () => _openReminderDialog(reminder),
                        onToggleDone: () => _toggleDone(reminder),
                        onDelete: () => _confirmDelete(reminder),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => AppErrorState(
              title: '读取提醒失败',
              onRetry: () => ref.invalidate(currentUserBillRemindersProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openReminderDialog([MoneyBillReminderEntity? reminder]) async {
    final result = await showAppResponsiveDialog<_ReminderFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (_) => _ReminderFormDialog(reminder: reminder),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      final actions = ref.read(currentUserMoneyBillReminderActionsProvider);
      if (reminder == null) {
        await actions.createReminder(result.toDraft());
        _showSuccess('提醒已创建');
      } else {
        await actions.updateReminder(result.toUpdate(reminder));
        _showSuccess('提醒已更新');
      }
    } catch (_) {
      _showError('保存提醒失败');
    }
  }

  Future<void> _toggleDone(MoneyBillReminderEntity reminder) async {
    final nextStatus = reminder.status == MoneyBillReminderStatus.done
        ? MoneyBillReminderStatus.pending
        : MoneyBillReminderStatus.done;
    try {
      await ref
          .read(currentUserMoneyBillReminderActionsProvider)
          .setReminderStatus(reminder.id, nextStatus);
    } catch (_) {
      _showError('更新提醒状态失败');
    }
  }

  Future<void> _confirmDelete(MoneyBillReminderEntity reminder) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除提醒',
      message: '确认删除“${reminder.name}”？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyBillReminderActionsProvider)
          .deleteReminder(reminder.id);
      _showSuccess('提醒已删除');
    } catch (_) {
      _showError('删除提醒失败');
    }
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  void _showSuccess(String message) {
    if (!mounted) {
      return;
    }
    AppToast.success(_ensureToast(), context, message);
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    AppToast.error(_ensureToast(), context, message);
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.account,
    required this.onEdit,
    required this.onToggleDone,
    required this.onDelete,
  });

  final MoneyBillReminderEntity reminder;
  final MoneyAccountEntity? account;
  final VoidCallback onEdit;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final done = reminder.status == MoneyBillReminderStatus.done;

    return AppSwipeActionTile(
      actions: [
        AppSwipeAction(
          tooltip: done ? '重新打开' : '标记完成',
          icon: done ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: onToggleDone,
        ),
        AppSwipeAction(
          tooltip: '编辑',
          icon: Icons.edit_rounded,
          foreground: colorScheme.onPrimaryContainer,
          background: colorScheme.primaryContainer,
          onPressed: onEdit,
        ),
        AppSwipeAction(
          tooltip: '删除',
          icon: Icons.delete_outline_rounded,
          foreground: colorScheme.onErrorContainer,
          background: colorScheme.errorContainer,
          onPressed: onDelete,
        ),
      ],
      child: _ReminderCardContent(reminder: reminder, account: account),
    );
  }
}

class _ReminderCardContent extends StatelessWidget {
  const _ReminderCardContent({required this.reminder, required this.account});

  final MoneyBillReminderEntity reminder;
  final MoneyAccountEntity? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = reminder.status == MoneyBillReminderStatus.done;
    final dueText = DateFormat(
      'MM-dd',
    ).format(_effectiveReminderDueDate(reminder, DateTime.now()));
    final amountMinor = _reminderAmountMinor(reminder, account);
    final amount =
        reminder.amountSource ==
                MoneyBillReminderAmountSource.creditAccountDebt &&
            amountMinor <= 0
        ? '暂无应还'
        : formatMoneyMinor(amountMinor, reminder.currencyCode);

    return AppListItemPanel(
      padding: const EdgeInsets.all(12),
      backgroundColor: done
          ? colorScheme.surfaceContainerLowest
          : colorScheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppListItemIcon(
            icon: done
                ? Icons.task_alt_rounded
                : Icons.notifications_active_rounded,
            color: done ? colorScheme.secondary : colorScheme.primary,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: done
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _reminderSubtitle(reminder, dueText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                if (reminder.notes != null &&
                    reminder.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                if (reminder.isCreditRepayment) ...[
                  const SizedBox(height: 4),
                  Text(
                    '自动还款提醒',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderFormDialog extends ConsumerStatefulWidget {
  const _ReminderFormDialog({this.reminder});

  final MoneyBillReminderEntity? reminder;

  @override
  ConsumerState<_ReminderFormDialog> createState() =>
      _ReminderFormDialogState();
}

class _ReminderFormDialogState extends ConsumerState<_ReminderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _remindBeforeController;
  late final TextEditingController _repeatIntervalController;
  late final TextEditingController _notesController;
  late DateTime _dueDate;
  String? _accountId;
  String? _categoryId;
  MoneyBillReminderRepeatPeriodType? _repeatPeriodType;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _nameController = TextEditingController(text: reminder?.name ?? '');
    _amountController = TextEditingController(
      text: reminder == null
          ? ''
          : (reminder.amountMinor / 100).toStringAsFixed(2),
    );
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
    _amountController.dispose();
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

    return AppDialogScaffold(
      title: editing ? '编辑提醒' : '新增提醒',
      titleTextAlign: TextAlign.center,
      maxWidth: 520,
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
            AppAmountField(
              controller: _amountController,
              labelText: '金额',
              validator: (value) {
                final normalized = value?.trim().replaceAll(',', '') ?? '';
                final amount = double.tryParse(normalized);
                if (amount == null || amount <= 0) {
                  return '请输入有效金额';
                }
                return null;
              },
            ),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ReminderFormResult(
        name: _nameController.text.trim(),
        amountMinor: parseMoneyAmountToMinor(_amountController.text),
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

class _ReminderFormResult {
  const _ReminderFormResult({
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

int _reminderAmountMinor(
  MoneyBillReminderEntity reminder,
  MoneyAccountEntity? account,
) {
  if (reminder.amountSource ==
      MoneyBillReminderAmountSource.creditAccountDebt) {
    return account?.effectivePostedDebtMinor ?? 0;
  }
  return reminder.amountMinor;
}

DateTime _effectiveReminderDueDate(
  MoneyBillReminderEntity reminder,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(
    reminder.dueDate.year,
    reminder.dueDate.month,
    reminder.dueDate.day,
  );
  final repeatType = reminder.repeatPeriodType;
  final interval = reminder.repeatInterval ?? 1;
  if (repeatType == null || interval <= 0 || !dueDate.isBefore(today)) {
    return dueDate;
  }
  return switch (repeatType) {
    MoneyBillReminderRepeatPeriodType.daily => dueDate.add(
      Duration(
        days: (today.difference(dueDate).inDays / interval).ceil() * interval,
      ),
    ),
    MoneyBillReminderRepeatPeriodType.weekly => dueDate.add(
      Duration(
        days:
            (today.difference(dueDate).inDays / (interval * 7)).ceil() *
            interval *
            7,
      ),
    ),
    MoneyBillReminderRepeatPeriodType.monthly => _nextMonthlyDueDate(
      dueDate,
      today,
      interval,
    ),
    MoneyBillReminderRepeatPeriodType.yearly => _nextYearlyDueDate(
      dueDate,
      today,
      interval,
    ),
  };
}

DateTime _nextMonthlyDueDate(DateTime start, DateTime today, int interval) {
  var cursor = DateTime(start.year, start.month, start.day);
  while (cursor.isBefore(today)) {
    cursor = _dayInMonth(cursor.year, cursor.month + interval, start.day);
  }
  return cursor;
}

DateTime _nextYearlyDueDate(DateTime start, DateTime today, int interval) {
  var cursor = DateTime(start.year, start.month, start.day);
  while (cursor.isBefore(today)) {
    cursor = _dayInMonth(cursor.year + interval, cursor.month, start.day);
  }
  return cursor;
}

DateTime _dayInMonth(int year, int month, int day) {
  final monthStart = DateTime(year, month);
  final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  return DateTime(
    monthStart.year,
    monthStart.month,
    day > lastDay ? lastDay : day,
  );
}

String _reminderSubtitle(MoneyBillReminderEntity reminder, String dueText) {
  final parts = <String>['到期 $dueText', '提前 ${reminder.remindBeforeDays} 天提醒'];
  final repeatText = _repeatPeriodText(
    reminder.repeatPeriodType,
    reminder.repeatInterval,
  );
  if (repeatText != null) {
    parts.add(repeatText);
  }
  return parts.join(' · ');
}

String? _repeatPeriodText(
  MoneyBillReminderRepeatPeriodType? repeatType,
  int? repeatInterval,
) {
  if (repeatType == null) {
    return null;
  }
  if (repeatInterval == null || repeatInterval <= 1) {
    return _repeatPeriodLabel(repeatType);
  }
  return '每 $repeatInterval ${_repeatPeriodUnit(repeatType)}';
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
