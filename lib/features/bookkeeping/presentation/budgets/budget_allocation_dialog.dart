import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_allocation_summary.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';

class BudgetAllocationDialog extends ConsumerStatefulWidget {
  const BudgetAllocationDialog({
    super.key,
    required this.budget,
    required this.catalog,
    this.ledger,
  });

  final MoneyBudgetEntity budget;
  final MoneyCategoryCatalog catalog;
  final MoneyLedgerEntity? ledger;

  @override
  ConsumerState<BudgetAllocationDialog> createState() =>
      _BudgetAllocationDialogState();
}

class _BudgetAllocationDialogState
    extends ConsumerState<BudgetAllocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _alertThresholdController = TextEditingController(text: '80');
  final _notesController = TextEditingController();
  String? _categoryId;
  String? _memberId;
  bool _alertEnabled = false;
  bool _isMandatory = false;
  MoneyBudgetAllocationEntity? _editing;
  String? _errorText;

  bool get _isFamilyLedger => widget.ledger?.isFamily ?? false;

  @override
  void dispose() {
    _amountController.dispose();
    _alertThresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allocations = ref.watch(
      currentUserBudgetAllocationsProvider(widget.budget.id),
    );
    final members = _isFamilyLedger && widget.ledger != null
        ? ref.watch(currentUserMoneyLedgerMembersProvider(widget.ledger!.id))
        : const AsyncValue<List<MoneyMemberEntity>>.data(<MoneyMemberEntity>[]);

    return AppDialogScaffold(
      title: '预算分配',
      subtitle: widget.budget.name,
      maxWidth: 620,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: allocations.when(
        data: (allocationRows) => members.when(
          data: (memberRows) => AppFormColumn(
            children: [
              _BudgetAllocationSummary(
                budget: widget.budget,
                allocations: allocationRows,
              ),
              _buildForm(memberRows, allocationRows),
              _BudgetAllocationList(
                budget: widget.budget,
                allocations: allocationRows,
                catalog: widget.catalog,
                members: memberRows,
                onEdit: _startEdit,
                onDelete: _confirmDelete,
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => const Text('成员读取失败'),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => const Text('预算分配读取失败'),
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }

  Widget _buildForm(
    List<MoneyMemberEntity> members,
    List<MoneyBudgetAllocationEntity> allocations,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final editing = _editing;
    final availableAmountMinor = BudgetAllocationSummary.availableAmountForEdit(
      budgetAmountMinor: widget.budget.amountMinor,
      allocations: allocations,
      editingAllocationId: editing?.id,
    );
    final availableColor = availableAmountMinor < 0
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;

    return Form(
      key: _formKey,
      child: AppSurface(
        tone: AppSurfaceTone.subtle,
        child: AppFormColumn(
          children: [
            Row(
              children: [
                AppListItemIcon(
                  icon: editing == null
                      ? Icons.add_chart_rounded
                      : Icons.edit_rounded,
                  color: colorScheme.primary,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    editing == null ? '新增分配项' : '编辑分配项',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (editing != null)
                  AppIconActionButton(
                    tooltip: '取消编辑',
                    onPressed: _resetForm,
                    icon: Icons.close_rounded,
                    variant: AppIconActionVariant.outlined,
                  ),
              ],
            ),
            AppAmountField(
              controller: _amountController,
              labelText: '分配金额',
              currencyCode: widget.budget.currencyCode,
              validator: (value) => _validateAmount(value, allocations),
            ),
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: availableColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    availableAmountMinor < 0
                        ? '当前已超分配 ${formatMoneyMinor(availableAmountMinor.abs(), widget.budget.currencyCode)}'
                        : '本次最多可分配 ${formatMoneyMinor(availableAmountMinor, widget.budget.currencyCode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: availableColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            CategorySelector(
              catalog: widget.catalog,
              selectedCategoryId: _categoryId,
              selectedSubCategoryId: null,
              showSubCategory: false,
              allowClear: true,
              clearCategoryLabel: '不限分类',
              categoryLabelText: widget.budget.isIncomeTarget ? '收入分类' : '支出分类',
              onChanged: (selection) {
                setState(() => _categoryId = selection.category?.id);
              },
            ),
            if (_isFamilyLedger)
              FormDropdown<String>(
                key: ValueKey('budget-allocation-member-${_memberId ?? 'all'}'),
                initialSelection: _memberId ?? '',
                label: '成员',
                leadingIcon: const Icon(Icons.person_outline_rounded),
                width: double.infinity,
                enableFilter: true,
                onSelected: (memberId) {
                  setState(
                    () => _memberId = memberId == null || memberId.isEmpty
                        ? null
                        : memberId,
                  );
                },
                entries: [
                  const DropdownMenuEntry(value: '', label: '不限成员'),
                  ...members.map(
                    (member) =>
                        DropdownMenuEntry(value: member.id, label: member.name),
                  ),
                ],
              ),
            AppSwitchField(
              title: '单独提醒',
              subtitle: '为这个分配项单独设置提醒阈值',
              icon: Icons.notifications_active_rounded,
              value: _alertEnabled,
              onChanged: (value) => setState(() => _alertEnabled = value),
            ),
            if (_alertEnabled)
              AppTextFormField(
                controller: _alertThresholdController,
                keyboardType: TextInputType.number,
                labelText: '提醒阈值',
                prefixIcon: const Icon(Icons.percent_rounded),
                suffixText: '%',
                validator: _validateAlertThreshold,
              ),
            AppSwitchField(
              title: '必需项',
              subtitle: '适合房租、保险、固定还款等刚性预算',
              icon: Icons.lock_outline_rounded,
              value: _isMandatory,
              onChanged: (value) => setState(() => _isMandatory = value),
            ),
            AppTextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 3,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
            if (_errorText != null)
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: AppIconActionButton(
                tooltip: editing == null ? '添加分配项' : '保存分配项',
                onPressed: () => _submit(allocations),
                icon: editing == null ? Icons.add_rounded : Icons.check_rounded,
                variant: AppIconActionVariant.filled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateAmount(
    String? value,
    List<MoneyBudgetAllocationEntity> allocations,
  ) {
    final amountMinor = _tryParseAmount(value);
    if (amountMinor == null || amountMinor <= 0) {
      return '请输入有效金额';
    }

    final availableAmountMinor = BudgetAllocationSummary.availableAmountForEdit(
      budgetAmountMinor: widget.budget.amountMinor,
      allocations: allocations,
      editingAllocationId: _editing?.id,
    );
    if (amountMinor > availableAmountMinor) {
      return '分配总额不能超过预算金额';
    }
    return null;
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

  int? _tryParseAmount(String? value) {
    try {
      return parseMoneyAmountToMinor(value ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit(List<MoneyBudgetAllocationEntity> allocations) async {
    setState(() => _errorText = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amountMinor = _tryParseAmount(_amountController.text);
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorText = '请输入有效金额');
      return;
    }

    final threshold = _alertEnabled
        ? int.parse(_alertThresholdController.text.trim())
        : 80;
    final notes = _notesController.text.trim();
    final actions = ref.read(currentUserMoneyBudgetActionsProvider);
    final editing = _editing;

    try {
      if (editing == null) {
        await actions.createBudgetAllocation(
          MoneyBudgetAllocationDraft(
            budgetId: widget.budget.id,
            categoryId: _categoryId,
            memberId: _memberId,
            allocatedAmountMinor: amountMinor,
            alertEnabled: _alertEnabled,
            alertThresholdPercent: threshold,
            isMandatory: _isMandatory,
            notes: notes.isEmpty ? null : notes,
          ),
        );
      } else {
        await actions.updateBudgetAllocation(
          MoneyBudgetAllocationUpdate(
            id: editing.id,
            categoryId: _categoryId,
            memberId: _memberId,
            allocatedAmountMinor: amountMinor,
            alertEnabled: _alertEnabled,
            alertThresholdPercent: threshold,
            isMandatory: _isMandatory,
            status: editing.status,
            notes: notes.isEmpty ? null : notes,
          ),
        );
      }
      if (mounted) {
        _resetForm();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '保存分配项失败');
    }
  }

  void _startEdit(MoneyBudgetAllocationEntity allocation) {
    setState(() {
      _editing = allocation;
      _categoryId = allocation.categoryId;
      _memberId = allocation.memberId;
      _alertEnabled = allocation.alertEnabled;
      _isMandatory = allocation.isMandatory;
      _amountController.text = (allocation.allocatedAmountMinor / 100)
          .toStringAsFixed(2);
      _alertThresholdController.text = allocation.alertThresholdPercent
          .toString();
      _notesController.text = allocation.notes ?? '';
      _errorText = null;
    });
  }

  Future<void> _confirmDelete(MoneyBudgetAllocationEntity allocation) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除分配项',
      message: '确认删除这个预算分配项？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyBudgetActionsProvider)
          .deleteBudgetAllocation(allocation.id, widget.budget.id);
      if (_editing?.id == allocation.id && mounted) {
        _resetForm();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '删除分配项失败');
    }
  }

  void _resetForm() {
    setState(() {
      _editing = null;
      _categoryId = null;
      _memberId = null;
      _alertEnabled = false;
      _isMandatory = false;
      _amountController.clear();
      _alertThresholdController.text = '80';
      _notesController.clear();
      _errorText = null;
    });
  }
}

class _BudgetAllocationSummary extends StatelessWidget {
  const _BudgetAllocationSummary({
    required this.budget,
    required this.allocations,
  });

  final MoneyBudgetEntity budget;
  final List<MoneyBudgetAllocationEntity> allocations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = BudgetAllocationSummary.fromAllocations(
      budgetAmountMinor: budget.amountMinor,
      allocations: allocations,
    );

    return AppSurface(
      tone: AppSurfaceTone.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _SummaryMetric(
                label: '预算总额',
                value: formatMoneyMinor(
                  budget.amountMinor,
                  budget.currencyCode,
                ),
              ),
              _SummaryMetric(
                label: '已分配',
                value: formatMoneyMinor(
                  summary.allocatedAmountMinor,
                  budget.currencyCode,
                ),
              ),
              _SummaryMetric(
                label: summary.isOverAllocated ? '超出' : '未分配',
                value: formatMoneyMinor(
                  summary.unallocatedAmountMinor.abs(),
                  budget.currencyCode,
                ),
                color: summary.isOverAllocated ? colorScheme.error : null,
              ),
              Text(
                '${summary.count} 项',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          if (summary.needsAttention || summary.isOverAllocated) ...[
            const SizedBox(height: 10),
            _BudgetAllocationNotice(summary: summary),
          ],
        ],
      ),
    );
  }
}

class _BudgetAllocationNotice extends StatelessWidget {
  const _BudgetAllocationNotice({required this.summary});

  final BudgetAllocationSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notices = <String>[
      if (summary.isOverAllocated) '分配总额已超过预算',
      if (summary.overspentCount > 0) '${summary.overspentCount} 项已超支',
      if (summary.alertingCount > summary.overspentCount)
        '${summary.alertingCount - summary.overspentCount} 项接近提醒阈值',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: colorScheme.error),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              notices.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color ?? colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _BudgetAllocationList extends StatelessWidget {
  const _BudgetAllocationList({
    required this.budget,
    required this.allocations,
    required this.catalog,
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  final MoneyBudgetEntity budget;
  final List<MoneyBudgetAllocationEntity> allocations;
  final MoneyCategoryCatalog catalog;
  final List<MoneyMemberEntity> members;
  final ValueChanged<MoneyBudgetAllocationEntity> onEdit;
  final ValueChanged<MoneyBudgetAllocationEntity> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (allocations.isEmpty) {
      return AppSurface(
        tone: AppSurfaceTone.inset,
        child: Text(
          '还没有分配项',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '分配项',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        ...allocations.map(
          (allocation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BudgetAllocationTile(
              budget: budget,
              allocation: allocation,
              catalog: catalog,
              members: members,
              onEdit: () => onEdit(allocation),
              onDelete: () => onDelete(allocation),
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetAllocationTile extends StatelessWidget {
  const _BudgetAllocationTile({
    required this.budget,
    required this.allocation,
    required this.catalog,
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  final MoneyBudgetEntity budget;
  final MoneyBudgetAllocationEntity allocation;
  final MoneyCategoryCatalog catalog;
  final List<MoneyMemberEntity> members;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = catalog.categoryById(allocation.categoryId);
    final member = _memberById(allocation.memberId);
    final labels = <String>[
      category?.name ?? (allocation.categoryId == null ? '不限分类' : '分类已不可用'),
      if (allocation.memberId != null) member?.name ?? '成员已不可用',
      if (allocation.isMandatory) '必需项',
      if (allocation.alertEnabled) '${allocation.alertThresholdPercent}%提醒',
    ];
    final usageText =
        '已用 ${formatMoneyMinor(allocation.usedAmountMinor, budget.currencyCode)}'
        ' · 剩余 ${formatMoneyMinor(allocation.remainingAmountMinor, budget.currencyCode)}';
    final usageColor = allocation.remainingAmountMinor < 0
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final rawProgress = allocation.allocatedAmountMinor <= 0
        ? 0.0
        : allocation.usedAmountMinor / allocation.allocatedAmountMinor;
    final progress = rawProgress.clamp(0.0, 1.0).toDouble();
    final progressPercent = (rawProgress * 100).round();
    final progressColor = allocation.remainingAmountMinor < 0
        ? colorScheme.error
        : colorScheme.secondary;

    return AppSurface(
      tone: AppSurfaceTone.plain,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AppListItemIcon(
            icon: allocation.memberId == null
                ? Icons.category_rounded
                : Icons.group_rounded,
            color: colorScheme.secondary,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMoneyMinor(
                    allocation.allocatedAmountMinor,
                    budget.currencyCode,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labels.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usageText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: usageColor,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: progressColor,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progressPercent%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                if (allocation.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    allocation.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIconActionButton(
            tooltip: '编辑分配项',
            onPressed: onEdit,
            icon: Icons.edit_rounded,
            variant: AppIconActionVariant.outlined,
          ),
          const SizedBox(width: 6),
          AppIconActionButton(
            tooltip: '删除分配项',
            onPressed: onDelete,
            icon: Icons.delete_outline_rounded,
            variant: AppIconActionVariant.outlined,
          ),
        ],
      ),
    );
  }

  MoneyMemberEntity? _memberById(String? memberId) {
    if (memberId == null) {
      return null;
    }
    for (final member in members) {
      if (member.id == memberId) {
        return member;
      }
    }
    return null;
  }
}
