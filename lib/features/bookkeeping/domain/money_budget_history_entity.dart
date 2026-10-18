import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

enum MoneyBudgetHistoryStatus {
  open('open'),
  closed('closed'),
  rolledOver('rolled_over');

  const MoneyBudgetHistoryStatus(this.storageValue);

  final String storageValue;

  static MoneyBudgetHistoryStatus fromStorageValue(String value) {
    return MoneyBudgetHistoryStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => MoneyBudgetHistoryStatus.open,
    );
  }
}

class MoneyBudgetHistorySnapshotEntity {
  const MoneyBudgetHistorySnapshotEntity({
    required this.id,
    required this.userId,
    required this.budgetId,
    required this.ledgerId,
    required this.trackingType,
    required this.periodType,
    required this.repeatInterval,
    required this.periodStart,
    required this.periodEnd,
    required this.budgetAmountMinor,
    required this.usedAmountMinor,
    required this.remainingAmountMinor,
    required this.currencyCode,
    required this.status,
    required this.capturedAt,
    required this.sourceBudgetVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String budgetId;
  final String? ledgerId;
  final MoneyBudgetTrackingType trackingType;
  final MoneyBudgetPeriodType periodType;
  final int repeatInterval;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int budgetAmountMinor;
  final int usedAmountMinor;
  final int remainingAmountMinor;
  final String currencyCode;
  final MoneyBudgetHistoryStatus status;
  final DateTime capturedAt;
  final int sourceBudgetVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyBudgetAllocationHistorySnapshotEntity {
  const MoneyBudgetAllocationHistorySnapshotEntity({
    required this.id,
    required this.userId,
    required this.budgetSnapshotId,
    required this.budgetId,
    required this.allocationId,
    required this.allocatedAmountMinor,
    required this.usedAmountMinor,
    required this.remainingAmountMinor,
    required this.currencyCode,
    required this.status,
    required this.capturedAt,
    required this.sourceAllocationVersion,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.memberId,
  });

  final String id;
  final String userId;
  final String budgetSnapshotId;
  final String budgetId;
  final String allocationId;
  final String? categoryId;
  final String? memberId;
  final int allocatedAmountMinor;
  final int usedAmountMinor;
  final int remainingAmountMinor;
  final String currencyCode;
  final MoneyBudgetAllocationStatus status;
  final DateTime capturedAt;
  final int sourceAllocationVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}
