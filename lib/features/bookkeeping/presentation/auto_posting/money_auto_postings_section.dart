import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_field_style.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

class MoneyAutoPostingsSection extends ConsumerStatefulWidget {
  const MoneyAutoPostingsSection({super.key});

  @override
  ConsumerState<MoneyAutoPostingsSection> createState() =>
      _MoneyAutoPostingsSectionState();
}

class _MoneyAutoPostingsSectionState
    extends ConsumerState<MoneyAutoPostingsSection> {
  FToast? _toast;

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(currentUserAutoPostingTemplatesProvider);
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final expenseCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    final incomeCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );
    final accountRows = accounts.asData?.value ?? const <MoneyAccountEntity>[];
    final expenseCategories =
        expenseCatalog.asData?.value ?? const MoneyCategoryCatalog.empty();
    final incomeCategories =
        incomeCatalog.asData?.value ?? const MoneyCategoryCatalog.empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: AppIconActionButton(
            tooltip: '新增自动记账',
            onPressed: currentLedger == null
                ? null
                : () => _openTemplateDialog(),
            icon: Icons.event_repeat_rounded,
            variant: AppIconActionVariant.filled,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: templates.when(
            data: (items) {
              if (currentLedger == null) {
                return const AppEmptyState(
                  title: '请先选择账本',
                  message: '自动记账模板会保存到当前账本。',
                  icon: Icons.menu_book_rounded,
                );
              }
              if (items.isEmpty) {
                return AppEmptyState(
                  title: '暂无自动记账模板',
                  message: '可以添加房贷、车贷、会员订阅等固定流水。',
                  icon: Icons.event_repeat_rounded,
                  action: AppIconActionButton(
                    tooltip: '新增自动记账',
                    onPressed: () => _openTemplateDialog(),
                    icon: Icons.add_rounded,
                    variant: AppIconActionVariant.filled,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final template = items[index];
                  return _AutoPostingTemplateCard(
                    template: template,
                    account: _accountById(accountRows, template.accountId),
                    categoryText: _categoryText(
                      template,
                      expenseCategories,
                      incomeCategories,
                    ),
                    onEdit: () => _openTemplateDialog(template),
                    onDelete: () => _confirmDelete(template),
                    onRunNow: () => _runTemplateNow(template),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => AppErrorState(
              title: '读取自动记账失败',
              onRetry: () =>
                  ref.invalidate(currentUserAutoPostingTemplatesProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTemplateDialog([
    MoneyAutoPostingTemplateEntity? template,
  ]) async {
    final result = await showAppResponsiveDialog<_AutoPostingFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _AutoPostingFormDialog(template: template),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      final actions = ref.read(currentUserMoneyAutoPostingActionsProvider);
      if (template == null) {
        await actions.createTemplate(result.toDraft());
        if (!mounted) return;
        AppToast.success(_ensureToast(), context, '自动记账模板已创建');
      } else {
        await actions.updateTemplate(result.toUpdate(template));
        if (!mounted) return;
        AppToast.success(_ensureToast(), context, '自动记账模板已更新');
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _runTemplateNow(MoneyAutoPostingTemplateEntity template) async {
    try {
      final summary = await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .runTemplateNow(template.id);
      if (!mounted) return;
      final parts = <String>[
        if (summary.postedCount > 0) '入账 ${summary.postedCount} 笔',
        if (summary.skippedCount > 0) '跳过 ${summary.skippedCount} 个未到期',
        if (summary.blockedCount > 0) '拦截 ${summary.blockedCount} 笔',
        if (summary.failedCount > 0) '失败 ${summary.failedCount} 笔',
      ];
      if (parts.isEmpty) {
        AppToast.success(_ensureToast(), context, '${template.name}：当前没有待执行条目');
      } else {
        AppToast.success(
          _ensureToast(),
          context,
          '${template.name}：${parts.join('，')}',
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _confirmDelete(MoneyAutoPostingTemplateEntity template) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除自动记账',
      message: '确认删除“${template.name}”？已经生成的流水不会被删除。',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .deleteTemplate(template.id);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '自动记账模板已删除');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  String _errorText(Object error) {
    if (error is MoneyRepositoryException) {
      return switch (error.code) {
        MoneyRepositoryErrorCode.invalidTransactionAmount => '金额必须大于 0',
        MoneyRepositoryErrorCode.accountNotFound => '账户不可用',
        MoneyRepositoryErrorCode.categoryNotFound => '分类不可用',
        MoneyRepositoryErrorCode.ledgerNotFound => '账本不可用',
        MoneyRepositoryErrorCode.autoPostingTemplateNotFound => '模板不可用',
        MoneyRepositoryErrorCode.invalidTransferAccounts => '自动记账仅支持收入或支出',
        MoneyRepositoryErrorCode.databaseReadFailed => '读取失败',
        MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
        _ => '操作失败',
      };
    }
    return '操作失败';
  }
}

class _AutoPostingTemplateCard extends ConsumerWidget {
  const _AutoPostingTemplateCard({
    required this.template,
    required this.account,
    required this.categoryText,
    required this.onEdit,
    required this.onDelete,
    required this.onRunNow,
  });

  final MoneyAutoPostingTemplateEntity template;
  final MoneyAccountEntity? account;
  final String categoryText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final runs = ref.watch(currentUserAutoPostingRunsProvider(template.id));

    return AppSwipeActionTile(
      actions: [
        AppSwipeAction(
          tooltip: '立即执行',
          icon: Icons.play_arrow_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: onRunNow,
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
      child: AppListItemPanel(
        padding: const EdgeInsets.all(12),
        backgroundColor: template.isActive
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerLowest,
        child: _AutoPostingTemplateCardContent(
          template: template,
          account: account,
          categoryText: categoryText,
          runs: runs.maybeWhen(
            data: (items) => items,
            orElse: () => const <MoneyAutoPostingRunEntity>[],
          ),
        ),
      ),
    );
  }
}

class _AutoPostingTemplateCardContent extends StatelessWidget {
  const _AutoPostingTemplateCardContent({
    required this.template,
    required this.account,
    required this.categoryText,
    this.runs = const <MoneyAutoPostingRunEntity>[],
  });

  final MoneyAutoPostingTemplateEntity template;
  final MoneyAccountEntity? account;
  final String categoryText;
  final List<MoneyAutoPostingRunEntity> runs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = template.isActive
        ? template.type == MoneyTransactionType.income
              ? colorScheme.tertiary
              : colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final amountText = formatMoneyMinor(
      template.amountMinor,
      template.currencyCode,
    );
    final subtitle = [
      _scheduleText(template),
      '从 ${_dateText(template.startsOn)} 起',
      if (template.endsOn != null) '至 ${_dateText(template.endsOn!)}',
    ].join(' · ');
    final relationText =
        '${account?.name ?? '账户不可用'} · $categoryText · ${template.paymentMethod.label}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppListItemIcon(
          icon: template.type == MoneyTransactionType.income
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
          color: iconColor,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AutoPostingStatusPill(active: template.isActive),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${template.type.label} · $amountText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                relationText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              if (template.notes != null &&
                  template.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  template.notes!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (runs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 6),
                for (final run in runs.take(2)) _AutoPostingRunRow(run: run),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoPostingRunRow extends StatelessWidget {
  const _AutoPostingRunRow({required this.run});

  final MoneyAutoPostingRunEntity run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (label, icon, color) = switch (run.status) {
      MoneyAutoPostingRunStatus.posted => (
        '已入账',
        Icons.check_circle_outline_rounded,
        colorScheme.primary,
      ),
      MoneyAutoPostingRunStatus.pending => (
        '待执行',
        Icons.schedule_rounded,
        colorScheme.tertiary,
      ),
      MoneyAutoPostingRunStatus.duplicateIgnored => (
        '重复已跳过',
        Icons.help_outline_rounded,
        colorScheme.onSurfaceVariant,
      ),
      MoneyAutoPostingRunStatus.blocked => (
        '已拦截',
        Icons.block_rounded,
        colorScheme.error,
      ),
      MoneyAutoPostingRunStatus.retryableFailed => (
        '执行失败',
        Icons.error_outline_rounded,
        colorScheme.error,
      ),
      MoneyAutoPostingRunStatus.userDeleted => (
        '已删除',
        Icons.delete_outline_rounded,
        colorScheme.onSurfaceVariant,
      ),
    };
    final detail = switch (run.status) {
      MoneyAutoPostingRunStatus.retryableFailed ||
      MoneyAutoPostingRunStatus.blocked => [
        if (run.errorMessage != null && run.errorMessage!.trim().isNotEmpty)
          run.errorMessage!,
      ],
      _ => const <String>[],
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    label,
                    ' ${_runDateTimeText(run.scheduledFor)}'
                        '${run.postedAt == null ? '' : ' · ${_runDateTimeText(run.postedAt!)}'}',
                  ].join(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.error,
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

class _AutoPostingStatusPill extends StatelessWidget {
  const _AutoPostingStatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = active
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final background = active
        ? colorScheme.primaryContainer.withValues(alpha: 0.52)
        : colorScheme.surfaceContainerHighest;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          active ? '启用' : '停用',
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AutoPostingFormDialog extends ConsumerStatefulWidget {
  const _AutoPostingFormDialog({this.template});

  final MoneyAutoPostingTemplateEntity? template;

  @override
  ConsumerState<_AutoPostingFormDialog> createState() =>
      _AutoPostingFormDialogState();
}

class _AutoPostingFormDialogState
    extends ConsumerState<_AutoPostingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;
  final _customPaymentNameCtrl = TextEditingController();
  late MoneyTransactionType _type;
  late MoneyPaymentMethod _paymentMethod;
  late MoneyAutoPostingFrequency _frequency;
  late int _dayOfMonth;
  late int _weekday;
  late int _timeOfDayMinutes;
  late DateTime _startsOn;
  DateTime? _endsOn;
  late bool _isActive;
  String? _accountId;
  String? _categoryId;
  String? _subCategoryId;
  String? _formError;

  bool get _editing => widget.template != null;

  MoneyCategoryKind get _categoryKind {
    return _type == MoneyTransactionType.income
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
  }

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _amountController = TextEditingController(
      text: template == null
          ? ''
          : (template.amountMinor / 100).toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _merchantController = TextEditingController(text: template?.merchant ?? '');
    _notesController = TextEditingController(text: template?.notes ?? '');
    _customPaymentNameCtrl.text = template?.customPaymentMethodName ?? '';
    _type = template?.type == MoneyTransactionType.income
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;
    _paymentMethod = template?.paymentMethod ?? MoneyPaymentMethod.cash;
    _frequency = template?.frequency ?? MoneyAutoPostingFrequency.monthly;
    final now = DateTime.now();
    _dayOfMonth = template?.dayOfMonth ?? now.day.clamp(1, 31);
    _weekday = template?.weekday ?? now.weekday;
    _timeOfDayMinutes = template?.timeOfDayMinutes ?? 8 * 60;
    _startsOn = _dateOnly(template?.startsOn ?? now);
    _endsOn = template?.endsOn == null ? null : _dateOnly(template!.endsOn!);
    _isActive = template?.isActive ?? true;
    _accountId = template?.accountId;
    _categoryId = template?.categoryId;
    _subCategoryId = template?.subCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _customPaymentNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final catalog = ref.watch(
      currentUserCategoryCatalogProvider(_categoryKind),
    );

    return AppDialogScaffold(
      title: _editing ? '编辑自动记账' : '新增自动记账',
      titleTextAlign: TextAlign.center,
      maxWidth: 560,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            AppTextFormField(
              controller: _nameController,
              labelText: '模板名称',
              prefixIcon: const Icon(Icons.event_repeat_rounded),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入模板名称' : null,
            ),
            FormDropdown<MoneyTransactionType>(
              initialSelection: _type,
              label: '流水类型',
              leadingIcon: const Icon(Icons.swap_vert_rounded),
              width: double.infinity,
              onSelected: (value) {
                if (value == null || value == _type) {
                  return;
                }
                setState(() {
                  _type = value;
                  _accountId = null;
                  _categoryId = null;
                  _subCategoryId = null;
                  _formError = null;
                });
              },
              entries: const [
                DropdownMenuEntry(
                  value: MoneyTransactionType.expense,
                  label: '支出',
                ),
                DropdownMenuEntry(
                  value: MoneyTransactionType.income,
                  label: '收入',
                ),
              ],
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
            AppTextFormField(
              controller: _descriptionController,
              labelText: '流水描述',
              prefixIcon: const Icon(Icons.subject_rounded),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入流水描述' : null,
            ),
            accounts.when(
              data: (value) {
                final selectableAccounts = _selectableAccountsForType(
                  value.where((account) => account.isActive).toList(),
                  _type,
                );
                return AccountSelector(
                  accounts: selectableAccounts,
                  selectedAccountId: _accountId,
                  emptyText: _type == MoneyTransactionType.income
                      ? '暂无可用于收入的账户'
                      : '暂无可选账户',
                  onChanged: (account) {
                    setState(() {
                      _accountId = account?.id;
                      final methods = _availablePaymentMethodsForAccount(
                        account,
                      );
                      if (!methods.contains(_paymentMethod)) {
                        _paymentMethod = methods.first;
                      }
                      _formError = null;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('账户读取失败'),
            ),
            catalog.when(
              data: (value) => CategorySelector(
                catalog: value,
                selectedCategoryId: _categoryId,
                selectedSubCategoryId: _subCategoryId,
                categoryLabelText: '${_categoryKind.label}分类',
                onChanged: (selection) {
                  setState(() {
                    _categoryId = selection.category?.id;
                    _subCategoryId = selection.subCategory?.id;
                    _formError = null;
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('分类读取失败'),
            ),
            accounts.when(
              data: (value) {
                final selectedAccount = _accountById(value, _accountId);
                final lockedMethod = _lockedPaymentMethodForAccount(
                  selectedAccount,
                );
                final methods = _availablePaymentMethodsForAccount(
                  selectedAccount,
                );
                final effectivePaymentMethod =
                    _effectivePaymentMethodForAccount(selectedAccount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormDropdown<MoneyPaymentMethod>(
                      key: ValueKey(
                        'auto-posting-payment-${selectedAccount?.id ?? 'none'}-${effectivePaymentMethod.storageValue}',
                      ),
                      initialSelection: effectivePaymentMethod,
                      label: '支付方式',
                      leadingIcon: const Icon(Icons.credit_card_rounded),
                      width: double.infinity,
                      enabled: lockedMethod == null,
                      enableFilter: true,
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _paymentMethod = value;
                        });
                      },
                      entries: methods
                          .map(
                            (method) => DropdownMenuEntry(
                              value: method,
                              label: method.label,
                            ),
                          )
                          .toList(),
                    ),
                    if (effectivePaymentMethod == MoneyPaymentMethod.other)
                      TextFormField(
                        controller: _customPaymentNameCtrl,
                        decoration: const InputDecoration(
                          labelText: '支付方式名称',
                          hintText: '如：美团月付、抖音月付、京东支付',
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('支付方式读取失败'),
            ),
            AppTextFormField(
              controller: _merchantController,
              labelText: '商户',
              prefixIcon: const Icon(Icons.storefront_rounded),
            ),
            FormDropdown<MoneyAutoPostingFrequency>(
              initialSelection: _frequency,
              label: '记账周期',
              leadingIcon: const Icon(Icons.repeat_rounded),
              width: double.infinity,
              onSelected: (value) {
                if (value == null) return;
                setState(() => _frequency = value);
              },
              entries: MoneyAutoPostingFrequency.values
                  .map(
                    (frequency) => DropdownMenuEntry(
                      value: frequency,
                      label: _frequencyLabel(frequency),
                    ),
                  )
                  .toList(),
            ),
            if (_frequency == MoneyAutoPostingFrequency.weekly)
              FormDropdown<int>(
                initialSelection: _weekday,
                label: '每周日期',
                leadingIcon: const Icon(Icons.view_week_rounded),
                width: double.infinity,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() => _weekday = value);
                },
                entries: [
                  for (
                    var day = DateTime.monday;
                    day <= DateTime.sunday;
                    day += 1
                  )
                    DropdownMenuEntry(value: day, label: _weekdayLabel(day)),
                ],
              ),
            if (_frequency == MoneyAutoPostingFrequency.monthly)
              FormDropdown<int>(
                initialSelection: _dayOfMonth,
                label: '每月日期',
                leadingIcon: const Icon(Icons.calendar_view_month_rounded),
                width: double.infinity,
                menuHeight: 320,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() => _dayOfMonth = value);
                },
                entries: [
                  for (var day = 1; day <= 31; day += 1)
                    DropdownMenuEntry(value: day, label: '$day 日'),
                ],
              ),
            _TimePickerField(
              minutes: _timeOfDayMinutes,
              onChanged: (value) {
                setState(() => _timeOfDayMinutes = value);
              },
            ),
            DateTimePicker(
              selectedDate: _startsOn,
              showTime: false,
              label: '开始日期：${_dateText(_startsOn)}',
              onChanged: (value) {
                setState(() {
                  _startsOn = _dateOnly(value);
                  _formError = null;
                });
              },
            ),
            _EndDateField(
              date: _endsOn,
              fallbackDate: _startsOn,
              onChanged: (value) {
                setState(() {
                  _endsOn = value == null ? null : _dateOnly(value);
                  _formError = null;
                });
              },
            ),
            SwitchListTile.adaptive(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('启用模板'),
              subtitle: const Text('启用后到达指定时间会自动生成已完成流水'),
            ),
            AppTextFormField(
              controller: _notesController,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
              minLines: 2,
              maxLines: 3,
            ),
            if (_formError != null) AppFormHint(text: _formError!),
          ],
        ),
      ),
      actionsAlignment: WrapAlignment.center,
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        cancelTooltip: '取消',
        confirmTooltip: _editing ? '保存' : '创建',
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_accountId == null) {
      setState(() => _formError = '请选择账户');
      return;
    }
    if (_categoryId == null) {
      setState(() => _formError = '请选择分类');
      return;
    }
    final endsOn = _endsOn;
    if (endsOn != null && _dateOnly(endsOn).isBefore(_dateOnly(_startsOn))) {
      setState(() => _formError = '结束日期不能早于开始日期');
      return;
    }

    final currentLedger = ref.read(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const <MoneyAccountEntity>[]
        : ref
              .read(currentUserMoneyLedgerAccountsProvider(currentLedger.id))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <MoneyAccountEntity>[],
              );
    final selectedAccount = _accountById(accounts, _accountId);
    final currencyCode =
        selectedAccount?.currencyCode ??
        (widget.template?.currencyCode ?? 'CNY');

    Navigator.of(context).pop(
      _AutoPostingFormResult(
        name: _nameController.text.trim(),
        type: _type,
        amountMinor: parseMoneyAmountToMinor(_amountController.text),
        currencyCode: currencyCode,
        description: _descriptionController.text.trim(),
        notes: _blankToNull(_notesController.text),
        merchant: _blankToNull(_merchantController.text),
        accountId: _accountId!,
        categoryId: _categoryId!,
        subCategoryId: _subCategoryId,
        paymentMethod: _paymentMethod,
        customPaymentMethodName: _customPaymentNameCtrl.text.trim().isEmpty
            ? null
            : _customPaymentNameCtrl.text.trim(),
        frequency: _frequency,
        dayOfMonth: _frequency == MoneyAutoPostingFrequency.monthly
            ? _dayOfMonth
            : null,
        weekday: _frequency == MoneyAutoPostingFrequency.weekly
            ? _weekday
            : null,
        timeOfDayMinutes: _timeOfDayMinutes,
        startsOn: _startsOn,
        endsOn: _endsOn,
        isActive: _isActive,
      ),
    );
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
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final controls = theme.controlTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickTime(context),
        borderRadius: BorderRadius.circular(radius.md),
        child: Container(
          constraints: BoxConstraints(minHeight: controls.compactFieldHeight),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: appFieldFillColor(colorScheme, enabled: true),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(
              color: appFieldBorderColor(colorScheme, enabled: true),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '记账时间：${_timeText(minutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) {
      return;
    }
    onChanged(picked.hour * 60 + picked.minute);
  }
}

class _EndDateField extends StatelessWidget {
  const _EndDateField({
    required this.date,
    required this.fallbackDate,
    required this.onChanged,
  });

  final DateTime? date;
  final DateTime fallbackDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DateTimePicker(
            selectedDate: date ?? fallbackDate,
            showTime: false,
            label: date == null ? '结束日期：无结束日期' : '结束日期：${_dateText(date!)}',
            onChanged: (value) => onChanged(value),
          ),
        ),
        const SizedBox(width: 8),
        AppIconActionButton(
          tooltip: '清除结束日期',
          onPressed: date == null ? null : () => onChanged(null),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }
}

class _AutoPostingFormResult {
  const _AutoPostingFormResult({
    required this.name,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    required this.accountId,
    required this.categoryId,
    required this.paymentMethod,
    this.customPaymentMethodName,
    required this.frequency,
    required this.timeOfDayMinutes,
    required this.startsOn,
    required this.isActive,
    this.notes,
    this.merchant,
    this.subCategoryId,
    this.dayOfMonth,
    this.weekday,
    this.endsOn,
  });

  final String name;
  final MoneyTransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final MoneyAutoPostingFrequency frequency;
  final int? dayOfMonth;
  final int? weekday;
  final int timeOfDayMinutes;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool isActive;

  MoneyAutoPostingTemplateDraft toDraft() {
    return MoneyAutoPostingTemplateDraft(
      name: name,
      type: type,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      description: description,
      notes: notes,
      merchant: merchant,
      accountId: accountId,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      paymentMethod: paymentMethod,
      customPaymentMethodName: customPaymentMethodName,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      weekday: weekday,
      timeOfDayMinutes: timeOfDayMinutes,
      startsOn: startsOn,
      endsOn: endsOn,
      isActive: isActive,
    );
  }

  MoneyAutoPostingTemplateUpdate toUpdate(
    MoneyAutoPostingTemplateEntity template,
  ) {
    return MoneyAutoPostingTemplateUpdate(
      id: template.id,
      name: name,
      type: type,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      description: description,
      notes: notes,
      merchant: merchant,
      accountId: accountId,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      paymentMethod: paymentMethod,
      customPaymentMethodName: customPaymentMethodName,
      ledgerId: template.ledgerId,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      weekday: weekday,
      timeOfDayMinutes: timeOfDayMinutes,
      startsOn: startsOn,
      endsOn: endsOn,
      isActive: isActive,
    );
  }
}

MoneyAccountEntity? _accountById(
  List<MoneyAccountEntity> accounts,
  String? id,
) {
  if (id == null) {
    return null;
  }
  for (final account in accounts) {
    if (account.id == id) {
      return account;
    }
  }
  return null;
}

List<MoneyAccountEntity> _selectableAccountsForType(
  List<MoneyAccountEntity> accounts,
  MoneyTransactionType type,
) {
  if (type == MoneyTransactionType.income) {
    return accounts
        .where(
          (account) => account.type.isAssetLike && !account.type.isDebtLike,
        )
        .toList();
  }
  return accounts
      .where(
        (account) =>
            account.type.isAssetLike ||
            account.type.isCreditLike ||
            account.type.isInternal,
      )
      .toList();
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

String _categoryText(
  MoneyAutoPostingTemplateEntity template,
  MoneyCategoryCatalog expenseCatalog,
  MoneyCategoryCatalog incomeCatalog,
) {
  final catalog = template.type == MoneyTransactionType.income
      ? incomeCatalog
      : expenseCatalog;
  final category = catalog.categoryById(template.categoryId);
  final subCategory = catalog.subCategoryById(template.subCategoryId);
  if (category == null) {
    return '分类不可用';
  }
  if (subCategory == null) {
    return category.name;
  }
  return '${category.name}/${subCategory.name}';
}

String _scheduleText(MoneyAutoPostingTemplateEntity template) {
  final time = _timeText(template.timeOfDayMinutes);
  return switch (template.frequency) {
    MoneyAutoPostingFrequency.daily => '每天 $time',
    MoneyAutoPostingFrequency.weekly =>
      '每周${_weekdayLabel(template.weekday ?? template.startsOn.weekday)} $time',
    MoneyAutoPostingFrequency.monthly =>
      '每月 ${template.dayOfMonth ?? template.startsOn.day} 日 $time',
  };
}

String _frequencyLabel(MoneyAutoPostingFrequency frequency) {
  return switch (frequency) {
    MoneyAutoPostingFrequency.daily => '每天',
    MoneyAutoPostingFrequency.weekly => '每周',
    MoneyAutoPostingFrequency.monthly => '每月',
  };
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    DateTime.sunday => '周日',
    _ => '周一',
  };
}

String _dateText(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _timeText(int minutes) {
  final clampedMinutes = minutes.clamp(0, 24 * 60 - 1);
  final hour = (clampedMinutes ~/ 60).toString().padLeft(2, '0');
  final minute = (clampedMinutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _runDateTimeText(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

DateTime _dateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
