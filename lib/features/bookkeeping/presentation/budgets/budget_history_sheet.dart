import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_history_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class BudgetHistorySheet extends ConsumerWidget {
  const BudgetHistorySheet({super.key, required this.budget});

  final MoneyBudgetEntity budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(currentUserBudgetSnapshotsProvider(budget.id));
    final allocationHistory = ref.watch(
      currentUserBudgetAllocationSnapshotsProvider(budget.id),
    );
    final categoryCatalog = ref.watch(
      currentUserCategoryCatalogProvider(
        budget.isIncomeTarget
            ? MoneyCategoryKind.income
            : MoneyCategoryKind.expense,
      ),
    );
    final members = ref.watch(currentUserMoneyMembersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = appColorFromHex(budget.color ?? '#F97316');

    return AppDialogScaffold(
      title: '${budget.name} · 历史',
      subtitle:
          '${budget.periodType.label} · ${budget.trackingType == MoneyBudgetTrackingType.expenseLimit ? '支出限额' : '收入目标'}',
      maxWidth: 720,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BudgetSummaryCard(budget: budget, accent: accent),
          const SizedBox(height: 16),
          history.when(
            data: (snapshots) {
              if (snapshots.isEmpty) {
                return const AppEmptyState(title: '暂无预算历史快照');
              }

              final allocationsBySnapshotId =
                  <String, List<MoneyBudgetAllocationHistorySnapshotEntity>>{};
              final allocationSnapshots = allocationHistory.maybeWhen(
                data: (items) => items,
                orElse: () =>
                    const <MoneyBudgetAllocationHistorySnapshotEntity>[],
              );
              final catalog = categoryCatalog.maybeWhen(
                data: (value) => value,
                orElse: () => const MoneyCategoryCatalog.empty(),
              );
              final memberList = members.maybeWhen(
                data: (value) => value,
                orElse: () => const <MoneyMemberEntity>[],
              );
              for (final allocation in allocationSnapshots) {
                allocationsBySnapshotId
                    .putIfAbsent(allocation.budgetSnapshotId, () => [])
                    .add(allocation);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 4),
                itemCount: snapshots.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final snapshot = snapshots[index];
                  return _BudgetSnapshotTile(
                    snapshot: snapshot,
                    budget: budget,
                    allocations:
                        allocationsBySnapshotId[snapshot.id] ??
                        const <MoneyBudgetAllocationHistorySnapshotEntity>[],
                    catalog: catalog,
                    members: memberList,
                    accent: accent,
                    colorScheme: colorScheme,
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                AppEmptyState(title: '读取预算历史失败', message: error.toString()),
          ),
        ],
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
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({required this.budget, required this.accent});

  final MoneyBudgetEntity budget;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _SummaryItem(
            label: '周期',
            value: budget.periodType.label,
            color: accent,
          ),
          _SummaryItem(
            label: '预算',
            value: formatMoneyMinor(budget.amountMinor, budget.currencyCode),
            color: colorScheme.onSurface,
          ),
          _SummaryItem(
            label: budget.isIncomeTarget ? '已赚' : '已用',
            value: formatMoneyMinor(
              budget.usedAmountMinor,
              budget.currencyCode,
            ),
            color: budget.isIncomeTarget
                ? colorScheme.primary
                : colorScheme.error,
          ),
          _SummaryItem(
            label: budget.isIncomeTarget
                ? (budget.isCompleted ? '超额' : '剩余')
                : (budget.isOverspent ? '超支' : '剩余'),
            value: formatMoneyMinor(
              budget.remainingAmountMinor.abs(),
              budget.currencyCode,
            ),
            color: budget.isExpenseLimit && budget.isOverspent
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.8),
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _BudgetSnapshotTile extends StatelessWidget {
  const _BudgetSnapshotTile({
    required this.snapshot,
    required this.budget,
    required this.allocations,
    required this.catalog,
    required this.members,
    required this.accent,
    required this.colorScheme,
  });

  final MoneyBudgetHistorySnapshotEntity snapshot;
  final MoneyBudgetEntity budget;
  final List<MoneyBudgetAllocationHistorySnapshotEntity> allocations;
  final MoneyCategoryCatalog catalog;
  final List<MoneyMemberEntity> members;
  final Color accent;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isIncomeTarget =
        snapshot.trackingType == MoneyBudgetTrackingType.incomeTarget;
    final isOverspent = snapshot.remainingAmountMinor < 0;
    final remainingLabel = isOverspent ? (isIncomeTarget ? '超额' : '超支') : '剩余';
    final remainingColor = isOverspent
        ? (isIncomeTarget ? colorScheme.primary : colorScheme.error)
        : colorScheme.onSurfaceVariant;
    final statusColor = switch (snapshot.status) {
      MoneyBudgetHistoryStatus.open => accent,
      MoneyBudgetHistoryStatus.closed => colorScheme.outline,
      MoneyBudgetHistoryStatus.rolledOver => colorScheme.secondary,
    };
    final isCurrentPeriod = _sameDay(snapshot.periodStart, budget.periodStart);
    final carriedIntoCurrent =
        isCurrentPeriod && snapshot.budgetAmountMinor > budget.amountMinor
        ? snapshot.budgetAmountMinor - budget.amountMinor
        : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_shortDate(snapshot.periodStart)} 至 ${_shortDate(snapshot.periodEnd)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _StatusChip(
                label: _statusLabel(snapshot.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SnapshotAmountRow(
            label: '预算',
            amountMinor: snapshot.budgetAmountMinor,
            currencyCode: snapshot.currencyCode,
            color: colorScheme.onSurfaceVariant,
          ),
          if (carriedIntoCurrent > 0) ...[
            const SizedBox(height: 4),
            _SnapshotAmountRow(
              label: '含结转',
              amountMinor: carriedIntoCurrent,
              currencyCode: snapshot.currencyCode,
              color: colorScheme.secondary,
              emphasized: true,
            ),
          ],
          const SizedBox(height: 4),
          _SnapshotAmountRow(
            label: '已用',
            amountMinor: snapshot.usedAmountMinor,
            currencyCode: snapshot.currencyCode,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          _SnapshotAmountRow(
            label: remainingLabel,
            amountMinor: snapshot.remainingAmountMinor.abs(),
            currencyCode: snapshot.currencyCode,
            color: isOverspent ? remainingColor : colorScheme.onSurfaceVariant,
            emphasized: isOverspent,
          ),
          if (snapshot.status == MoneyBudgetHistoryStatus.rolledOver &&
              snapshot.remainingAmountMinor > 0) ...[
            const SizedBox(height: 4),
            _SnapshotAmountRow(
              label: '结转下期',
              amountMinor: snapshot.remainingAmountMinor,
              currencyCode: snapshot.currencyCode,
              color: colorScheme.secondary,
              emphasized: true,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '捕获于 ${_dateTimeText(snapshot.capturedAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          if (allocations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 10),
            ...allocations.map(
              (allocation) => _AllocationSnapshotLine(
                allocation: allocation,
                catalog: catalog,
                members: members,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(MoneyBudgetHistoryStatus status) {
    return switch (status) {
      MoneyBudgetHistoryStatus.open => '进行中',
      MoneyBudgetHistoryStatus.closed => '已结束',
      MoneyBudgetHistoryStatus.rolledOver => '已结转',
    };
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _shortDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dateTimeText(DateTime dateTime) {
    return '${_shortDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _AllocationSnapshotLine extends StatelessWidget {
  const _AllocationSnapshotLine({
    required this.allocation,
    required this.catalog,
    required this.members,
    required this.colorScheme,
  });

  final MoneyBudgetAllocationHistorySnapshotEntity allocation;
  final MoneyCategoryCatalog catalog;
  final List<MoneyMemberEntity> members;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _allocationLabel();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
          if (allocation.status == MoneyBudgetAllocationStatus.inactive) ...[
            const SizedBox(width: 8),
            _StatusChip(label: '已停用', color: colorScheme.outline),
          ],
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '已用 ${formatMoneyMinor(allocation.usedAmountMinor, allocation.currencyCode)} / ${formatMoneyMinor(allocation.allocatedAmountMinor, allocation.currencyCode)}',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _allocationLabel() {
    final memberId = allocation.memberId;
    if (memberId != null) {
      for (final member in members) {
        if (member.id == memberId) {
          return member.name;
        }
      }
      return '成员分配';
    }

    final category = catalog.categoryById(allocation.categoryId);
    if (category != null) {
      return category.name;
    }
    return '通用分配';
  }
}

class _SnapshotAmountRow extends StatelessWidget {
  const _SnapshotAmountRow({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(
          child: Text(
            formatMoneyMinor(amountMinor, currencyCode),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : null,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
