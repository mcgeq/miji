import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

class BudgetAllocationSummary {
  const BudgetAllocationSummary({
    required this.count,
    required this.allocatedAmountMinor,
    required this.unallocatedAmountMinor,
    required this.usedAmountMinor,
    required this.remainingAmountMinor,
    required this.alertingCount,
    required this.overspentCount,
  });

  factory BudgetAllocationSummary.fromAllocations({
    required int budgetAmountMinor,
    required Iterable<MoneyBudgetAllocationEntity> allocations,
  }) {
    var count = 0;
    var allocatedAmountMinor = 0;
    var usedAmountMinor = 0;
    var remainingAmountMinor = 0;
    var alertingCount = 0;
    var overspentCount = 0;

    for (final allocation in allocations) {
      count += 1;
      allocatedAmountMinor += allocation.allocatedAmountMinor;
      usedAmountMinor += allocation.usedAmountMinor;
      remainingAmountMinor += allocation.remainingAmountMinor;
      if (allocation.remainingAmountMinor < 0) {
        overspentCount += 1;
      }
      if (_shouldAlert(allocation)) {
        alertingCount += 1;
      }
    }

    return BudgetAllocationSummary(
      count: count,
      allocatedAmountMinor: allocatedAmountMinor,
      unallocatedAmountMinor: budgetAmountMinor - allocatedAmountMinor,
      usedAmountMinor: usedAmountMinor,
      remainingAmountMinor: remainingAmountMinor,
      alertingCount: alertingCount,
      overspentCount: overspentCount,
    );
  }

  final int count;
  final int allocatedAmountMinor;
  final int unallocatedAmountMinor;
  final int usedAmountMinor;
  final int remainingAmountMinor;
  final int alertingCount;
  final int overspentCount;

  bool get hasAllocations => count > 0;

  bool get hasUnallocatedAmount => unallocatedAmountMinor > 0;

  bool get isOverAllocated => unallocatedAmountMinor < 0;

  bool get needsAttention => alertingCount > 0 || overspentCount > 0;

  static int availableAmountForEdit({
    required int budgetAmountMinor,
    required Iterable<MoneyBudgetAllocationEntity> allocations,
    String? editingAllocationId,
  }) {
    final otherAllocatedAmountMinor = allocations
        .where((allocation) => allocation.id != editingAllocationId)
        .fold<int>(
          0,
          (sum, allocation) => sum + allocation.allocatedAmountMinor,
        );
    return budgetAmountMinor - otherAllocatedAmountMinor;
  }

  static bool _shouldAlert(MoneyBudgetAllocationEntity allocation) {
    if (!allocation.alertEnabled || allocation.allocatedAmountMinor <= 0) {
      return false;
    }
    final progress =
        allocation.usedAmountMinor / allocation.allocatedAmountMinor;
    return progress * 100 >= allocation.alertThresholdPercent;
  }
}
