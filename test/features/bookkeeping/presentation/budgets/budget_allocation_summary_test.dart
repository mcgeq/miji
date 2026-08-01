import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_allocation_summary.dart';

void main() {
  test('summarizes allocation totals and attention counts', () {
    final summary = BudgetAllocationSummary.fromAllocations(
      budgetAmountMinor: 100000,
      allocations: [
        _allocation(
          allocatedAmountMinor: 30000,
          usedAmountMinor: 29000,
          remainingAmountMinor: 1000,
          alertEnabled: true,
          alertThresholdPercent: 90,
        ),
        _allocation(
          allocatedAmountMinor: 20000,
          usedAmountMinor: 26000,
          remainingAmountMinor: -6000,
          alertEnabled: true,
          alertThresholdPercent: 80,
        ),
        _allocation(
          allocatedAmountMinor: 15000,
          usedAmountMinor: 2000,
          remainingAmountMinor: 13000,
        ),
      ],
    );

    expect(summary.count, 3);
    expect(summary.allocatedAmountMinor, 65000);
    expect(summary.unallocatedAmountMinor, 35000);
    expect(summary.usedAmountMinor, 57000);
    expect(summary.remainingAmountMinor, 8000);
    expect(summary.alertingCount, 2);
    expect(summary.overspentCount, 1);
  });

  test('calculates available amount for create and edit', () {
    final allocations = [
      _allocation(
        id: 'food',
        allocatedAmountMinor: 30000,
        usedAmountMinor: 12000,
        remainingAmountMinor: 18000,
      ),
      _allocation(
        id: 'traffic',
        allocatedAmountMinor: 20000,
        usedAmountMinor: 8000,
        remainingAmountMinor: 12000,
      ),
    ];

    expect(
      BudgetAllocationSummary.availableAmountForEdit(
        budgetAmountMinor: 80000,
        allocations: allocations,
      ),
      30000,
    );
    expect(
      BudgetAllocationSummary.availableAmountForEdit(
        budgetAmountMinor: 80000,
        allocations: allocations,
        editingAllocationId: 'food',
      ),
      60000,
    );
  });
}

MoneyBudgetAllocationEntity _allocation({
  String? id,
  required int allocatedAmountMinor,
  required int usedAmountMinor,
  required int remainingAmountMinor,
  bool alertEnabled = false,
  int alertThresholdPercent = 80,
}) {
  final now = DateTime.utc(2026, 7, 13);
  return MoneyBudgetAllocationEntity(
    id: id ?? 'allocation_$allocatedAmountMinor',
    userId: 'user_1',
    budgetId: 'budget_1',
    allocatedAmountMinor: allocatedAmountMinor,
    usedAmountMinor: usedAmountMinor,
    remainingAmountMinor: remainingAmountMinor,
    allocationType: 'fixed',
    alertEnabled: alertEnabled,
    alertThresholdPercent: alertThresholdPercent,
    priority: 0,
    isMandatory: false,
    status: MoneyBudgetAllocationStatus.active,
    version: 1,
    createdAt: now,
    updatedAt: now,
  );
}
