import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_history_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_bill_view.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';

abstract class MoneyRepository {
  Future<void> ensureReadyForUser(String userId);

  Future<void> applyRemoteMoneyChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  );

  Stream<List<MoneyAccountEntity>> watchVisibleAccountsForUser(String userId);

  Stream<List<MoneyAccountEntity>> watchAccountsForLedger(
    String userId,
    String ledgerId,
  );

  Stream<List<MoneyAccountEntity>> watchTransferAccountsForLedger(
    String userId,
    String ledgerId,
  );

  Future<void> addAccountToLedger(
    String userId,
    String ledgerId,
    String accountId,
  );

  Future<void> removeAccountFromLedger(
    String userId,
    String ledgerId,
    String accountId,
  );

  Future<Map<String, MoneyAccountMonthlySummary>>
  getAccountMonthlySummariesForUser(String userId, {String? ledgerId});

  Future<MoneyCreditCardStatement?> getCreditCardStatementForAccount(
    String userId,
    String accountId, {
    DateTime? asOf,
  });

  Future<MoneyCreditCardBillView?> getCurrentCreditCardBillViewForAccount(
    String userId,
    String accountId, {
    DateTime? asOf,
  });

  Stream<MoneyCategoryCatalog> watchCategoryCatalogForUser(
    String userId,
    MoneyCategoryKind kind, {
    bool includeDeleted = false,
  });

  Future<Map<MoneyPaymentMethod, int>> getPaymentMethodUsageRanksForUser(
    String userId,
  );

  Future<void> refreshUsageStatsForUser(String userId);

  Future<void> refreshUsageStatsForAllUsers();

  Future<MoneyCategoryEntity> createCategory(
    String userId,
    MoneyCategoryDraft draft,
  );

  Future<MoneyCategoryEntity> updateCategory(
    String userId,
    MoneyCategoryUpdate update,
  );

  Future<void> deleteCategory(String userId, String categoryId);

  Future<void> restoreCategory(String userId, String categoryId);

  Future<MoneySubCategoryEntity> createSubCategory(
    String userId,
    MoneySubCategoryDraft draft,
  );

  Future<MoneySubCategoryEntity> updateSubCategory(
    String userId,
    MoneySubCategoryUpdate update,
  );

  Future<void> deleteSubCategory(String userId, String subCategoryId);

  Future<void> restoreSubCategory(String userId, String subCategoryId);

  Stream<List<MoneyBudgetEntity>> watchBudgetsForUser(
    String userId, {
    String? ledgerId,
  });

  Stream<List<MoneyBudgetAllocationEntity>> watchBudgetAllocationsForUser(
    String userId,
    String budgetId,
  );

  Stream<List<MoneyBudgetHistorySnapshotEntity>> watchBudgetSnapshotsForUser(
    String userId, {
    String? budgetId,
  });

  Stream<List<MoneyBudgetAllocationHistorySnapshotEntity>>
  watchBudgetAllocationSnapshotsForUser(String userId, String budgetId);

  Future<void> ensureBudgetSnapshotForBudget(String userId, String budgetId);

  Future<void> refreshBudgetSnapshotsForUser(String userId);

  Stream<List<MoneyBillReminderEntity>> watchBillRemindersForUser(
    String userId, {
    String? ledgerId,
  });

  Stream<List<MoneyAutoPostingTemplateEntity>> watchAutoPostingTemplatesForUser(
    String userId, {
    String? ledgerId,
  });

  Stream<List<MoneyAutoPostingRunEntity>> watchAutoPostingRunsForTemplate(
    String userId,
    String templateId,
  );

  Future<List<MoneyReminderCenterItem>> getPendingReminderCenterItems(
    String userId, {
    String? ledgerId,
    DateTime? today,
  });

  Future<List<MoneyReminderCenterItem>> getReminderCenterHistory(
    String userId, {
    String? ledgerId,
    int limit = 50,
  });

  Future<void> setReminderCenterState(
    String userId,
    MoneyReminderCenterItem item,
    MoneyReminderCenterState state, {
    DateTime? snoozedUntil,
  });
  Stream<List<MoneyInstallmentPlanEntity>> watchInstallmentPlansForUser(
    String userId, {
    String? ledgerId,
  });

  Stream<List<MoneyInstallmentDetailEntity>> watchInstallmentDetailsForPlan(
    String userId,
    String planId,
  );

  Future<void> repairInstallmentPlanStatuses(String userId, {String? ledgerId});

  Future<MoneySplitContextEntity> getDefaultSplitContextForUser(String userId);

  Stream<List<MoneyMemberEntity>> watchMembersForUser(String userId);

  Stream<List<MoneyLedgerEntity>> watchLedgersForUser(String userId);

  Stream<List<MoneyLedgerEntity>> watchLedgersForTransaction(
    String userId,
    String transactionId,
  );

  Stream<List<MoneyMemberEntity>> watchMembersForLedger(
    String userId,
    String ledgerId,
  );

  Future<MoneyLedgerEntity> getDefaultLedgerForUser(String userId);

  Stream<List<MoneySplitRecordEntity>> watchSplitRecordsForTransaction(
    String userId,
    String transactionId,
  );

  Stream<List<MoneySplitRuleEntity>> watchSplitRulesForLedger(
    String userId,
    String ledgerId, {
    bool includeDeleted = false,
  });

  Future<MoneyAccountEntity> createAccount(
    String userId,
    MoneyAccountDraft draft,
  );

  Future<MoneyAccountEntity> updateAccount(
    String userId,
    MoneyAccountUpdate update,
  );

  Future<void> setAccountActive(String userId, String accountId, bool isActive);

  Future<void> deleteAccount(String userId, String accountId);

  Future<MoneyTransactionEntity> createTransaction(
    String userId,
    MoneyTransactionDraft draft,
  );

  Future<MoneyTransactionEntity> createTransactionWithSplit(
    String userId,
    MoneyTransactionDraft draft,
    MoneySplitConfigDraft splitConfig,
  );

  Future<MoneyTransferResult> createTransfer(
    String userId,
    MoneyTransferDraft draft,
  );

  Future<MoneyTransactionEntity> updateTransaction(
    String userId,
    MoneyTransactionUpdate update,
  );

  Future<MoneyTransactionEntity> recordTransactionRefund(
    String userId,
    String transactionId,
    int refundAmountMinor,
  );

  Future<MoneyTransferResult> updateTransfer(
    String userId,
    MoneyTransferUpdate update,
  );

  Future<void> deleteTransaction(String userId, String transactionId);

  Future<MoneyBudgetEntity> createBudget(String userId, MoneyBudgetDraft draft);

  Future<MoneyBillReminderEntity> createBillReminder(
    String userId,
    MoneyBillReminderDraft draft,
  );

  Future<MoneyAutoPostingTemplateEntity> createAutoPostingTemplate(
    String userId,
    MoneyAutoPostingTemplateDraft draft,
  );

  Future<MoneyBudgetAllocationEntity> createBudgetAllocation(
    String userId,
    MoneyBudgetAllocationDraft draft,
  );

  Future<MoneyInstallmentPlanEntity> createInstallmentPlan(
    String userId,
    MoneyInstallmentPlanDraft draft,
  );

  Future<void> cancelInstallmentPlan(String userId, String planId);

  Future<MoneyTransactionEntity> postInstallmentDetail(
    String userId,
    String detailId,
  );

  Future<MoneyLedgerEntity> createLedger(String userId, MoneyLedgerDraft draft);

  Future<MoneyLedgerEntity> updateLedger(
    String userId,
    MoneyLedgerUpdate update,
  );

  Future<MoneyMemberEntity> createMember(
    String userId,
    MoneyMemberDraft draft, {
    required String ledgerId,
  });

  Future<MoneyMemberEntity> updateMember(
    String userId,
    MoneyMemberUpdate update, {
    required String ledgerId,
  });

  Future<void> deleteMember(
    String userId,
    String memberId, {
    required String ledgerId,
  });

  Future<MoneySplitRecordEntity> createSplitForTransaction(
    String userId,
    MoneySplitDraft draft,
  );

  Future<void> linkTransactionToLedger(
    String userId,
    String transactionId,
    String ledgerId,
  );

  Future<void> unlinkTransactionFromLedger(
    String userId,
    String transactionId,
    String ledgerId,
  );

  Future<MoneySplitRecordEntity> replaceSplitForTransaction(
    String userId,
    MoneySplitDraft draft,
  );

  Future<void> cancelSplitRecord(String userId, String splitRecordId);

  Future<MoneySplitRuleEntity> createSplitRule(
    String userId,
    MoneySplitRuleDraft draft,
  );

  Future<MoneySplitRuleEntity> updateSplitRule(
    String userId,
    MoneySplitRuleUpdate update,
  );

  Future<void> deleteSplitRule(String userId, String ruleId);

  Future<MoneyBudgetEntity> updateBudget(
    String userId,
    MoneyBudgetUpdate update,
  );

  Future<MoneyBudgetAllocationEntity> updateBudgetAllocation(
    String userId,
    MoneyBudgetAllocationUpdate update,
  );

  Future<void> deleteBudget(String userId, String budgetId);

  Future<MoneyBillReminderEntity> updateBillReminder(
    String userId,
    MoneyBillReminderUpdate update,
  );

  Future<void> setBillReminderStatus(
    String userId,
    String reminderId,
    MoneyBillReminderStatus status,
  );

  Future<void> deleteBillReminder(String userId, String reminderId);

  Future<MoneyAutoPostingTemplateEntity> updateAutoPostingTemplate(
    String userId,
    MoneyAutoPostingTemplateUpdate update,
  );

  Future<void> deleteAutoPostingTemplate(String userId, String templateId);

  Future<MoneyAutoPostingExecutionSummary> executeDueAutoPostings(
    String userId, {
    DateTime? now,
  });

  Future<int> getPendingAutoPostingAmountForBudget(
    String userId,
    String budgetId,
    DateTime periodStart,
    DateTime periodEnd,
  );

  Future<void> deleteBudgetAllocation(String userId, String allocationId);

  Future<MoneyTransactionPage> listTransactions(
    String userId,
    MoneyTransactionQuery query,
  );

  Stream<List<MoneyTransactionEntity>> watchRecentTransactionsForUser(
    String userId, {
    int limit = 20,
    String? ledgerId,
  });

  Future<MoneyTransactionEntity> getTransactionForUser(
    String userId,
    String transactionId,
  );

  Future<MoneyStatisticsSummary> getStatisticsForUser(
    String userId,
    MoneyStatisticsQuery query,
  );

  Future<MoneyStatisticsInsights> getStatisticsInsightsForUser(
    String userId,
    MoneyStatisticsQuery query,
  );

  Future<MoneySpendingAnalysis> getSpendingAnalysisForUser(
    String userId,
    MoneySpendingAnalysisQuery query,
  );

  Future<List<MoneyBudgetHistoryTrendPoint>> getBudgetHistoryTrendForUser(
    String userId,
    String ledgerId, {
    int months = 6,
  });

  Future<MoneyUpcomingCashFlowSummary> getUpcomingCashFlowForUser(
    String userId, {
    required String ledgerId,
    int windowDays = 90,
  });

  Future<MoneyAnalysisReportEntity> generateReportForUser(
    String userId,
    MoneyAnalysisReportRequest request,
  );

  Future<MoneyAnalysisReportEntity?> getLatestReportForUser(
    String userId,
    String ledgerId,
    String reportPeriod,
  );

  Future<MoneyReportGenerationConfigEntity> getReportGenerationConfig(
    String userId,
    String ledgerId,
  );

  Future<void> updateReportGenerationConfig(
    String userId,
    MoneyReportGenerationConfigEntity config,
  );

  Future<void> captureAssetSnapshotsForUser(String userId);

  Future<void> refreshAssetSnapshotsForUser(String userId);

  Future<List<MoneyNetWorthTrendPoint>> getNetWorthTrendForUser(
    String userId, {
    int days = 90,
  });
}

enum MoneyRepositoryErrorCode {
  databaseReadFailed,
  databaseWriteFailed,
  invalidAccountBalance,
  invalidTransactionAmount,
  accountNotFound,
  categoryNotFound,
  budgetNotFound,
  invalidBudgetAmount,
  invalidBudgetScope,
  unsupportedBudgetPeriod,
  invalidInstallmentAmount,
  invalidInstallmentAccount,
  installmentPlanNotFound,
  invalidInstallmentStatus,
  invalidTransactionStatus,
  ledgerNotFound,
  memberNotFound,
  activeSplitAlreadyExists,
  invalidSplitAmount,
  invalidSplitTransaction,
  cannotUnlinkPersonalLedger,
  cannotUnlinkLedgerWithActiveSplit,
  splitRecordNotFound,
  insufficientFunds,
  invalidTransferAccounts,
  creditCardLimitExceeded,
}

class MoneyRepositoryException implements Exception {
  const MoneyRepositoryException(this.code, [this.cause]);

  final MoneyRepositoryErrorCode code;
  final Object? cause;

  @override
  String toString() {
    return 'MoneyRepositoryException($code, cause: $cause)';
  }
}
