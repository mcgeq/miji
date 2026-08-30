import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_resolver.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/features/bookkeeping/application/money_delta_conflict_apply_service.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  test(
    'applies selected field groups through money repository update',
    () async {
      final repository = _FakeMoneyRepository();
      final store = _FakeDeltaConflictStore();
      final service = MoneyDeltaConflictApplyService(
        repository: repository,
        conflictStore: store,
      );

      await service.applyTransactionConflict(
        conflict: _storedConflict(),
        deviceId: 'device-a',
        choices: const [
          DeltaConflictFieldChoice(
            group: TransactionConflictFieldGroup.basic,
            side: DeltaConflictSide.remote,
          ),
          DeltaConflictFieldChoice(
            group: TransactionConflictFieldGroup.text,
            side: DeltaConflictSide.local,
          ),
        ],
      );

      expect(repository.updatedUserIds, ['user-1']);
      expect(repository.updates, hasLength(1));
      expect(repository.updates.single.id, 'tx-1');
      expect(repository.updates.single.amountMinor, 1200);
      expect(repository.updates.single.notes, 'local note');
      expect(repository.updates.single.accountId, 'account-local');
      expect(store.resolvedIds, ['conflict-1']);
      expect(store.resolutions, [DeltaConflictResolution.merged]);
    },
  );

  test('rejects unsupported remote field groups without resolving', () async {
    final repository = _FakeMoneyRepository();
    final store = _FakeDeltaConflictStore();
    final service = MoneyDeltaConflictApplyService(
      repository: repository,
      conflictStore: store,
    );

    await expectLater(
      service.applyTransactionConflict(
        conflict: _storedConflict(
          fieldGroups: const {TransactionConflictFieldGroup.split},
          changedFields: const {'split_details': []},
        ),
        deviceId: 'device-a',
        choices: const [
          DeltaConflictFieldChoice(
            group: TransactionConflictFieldGroup.split,
            side: DeltaConflictSide.remote,
          ),
        ],
      ),
      throwsA(
        isA<MoneyDeltaConflictApplyException>().having(
          (error) => error.code,
          'code',
          MoneyDeltaConflictApplyErrorCode.unsupportedRemoteFieldGroup,
        ),
      ),
    );

    expect(repository.updates, isEmpty);
    expect(store.resolvedIds, isEmpty);
  });
}

StoredDeltaConflict _storedConflict({
  Set<TransactionConflictFieldGroup> fieldGroups = const {
    TransactionConflictFieldGroup.basic,
    TransactionConflictFieldGroup.text,
  },
  Map<String, Object?> changedFields = const {
    'transaction_at': '2026-07-12T09:00:00.000Z',
    'amount_minor': 1200,
    'notes': 'remote note',
  },
}) {
  return StoredDeltaConflict(
    id: 'conflict-1',
    datasetId: 'dataset-1',
    userId: 'user-1',
    tableName: 'money_transactions',
    recordId: 'tx-1',
    fieldGroups: fieldGroups,
    localSnapshot: {
      'id': 'tx-1',
      'user_id': 'user-1',
      'type': 'expense',
      'transaction_at': '2026-07-11T09:00:00.000Z',
      'amount_minor': 900,
      'currency_code': 'CNY',
      'notes': 'local note',
      'account_id': 'account-local',
      'category_id': 'category-local',
      'sub_category_id': null,
      'payment_method': 'cash',
      'custom_payment_method_name': null,
      'tags': ['local'],
    },
    remoteChange: DeltaChangeRecord(
      table: 'money_transactions',
      recordId: 'tx-1',
      operation: 'update',
      baseVersion: 1,
      newVersion: 2,
      changedFields: changedFields,
      recordSnapshot: {
        'id': 'tx-1',
        'user_id': 'user-1',
        'type': 'expense',
        'transaction_at': '2026-07-12T09:00:00.000Z',
        'amount_minor': 1200,
        'currency_code': 'CNY',
        'notes': 'remote note',
        'account_id': 'account-local',
        'category_id': 'category-local',
        'sub_category_id': null,
        'payment_method': 'cash',
        'custom_payment_method_name': null,
        'tags': ['remote'],
      },
    ),
    createdAt: DateTime.utc(2026, 7, 11, 12),
    updatedAt: DateTime.utc(2026, 7, 11, 12),
  );
}

class _FakeDeltaConflictStore implements DeltaConflictStore {
  final resolvedIds = <String>[];
  final resolutions = <DeltaConflictResolution>[];

  @override
  Future<List<StoredDeltaConflict>> listOpenConflicts(String userId) async {
    return const <StoredDeltaConflict>[];
  }

  @override
  Future<void> markResolved({
    required String id,
    required DeltaConflictResolution resolution,
    required String deviceId,
    DateTime? resolvedAt,
  }) async {
    resolvedIds.add(id);
    resolutions.add(resolution);
  }

  @override
  Future<void> saveConflict({
    required String userId,
    required String datasetId,
    required DeltaDetectedConflict conflict,
    required String localSnapshotJson,
    required String deviceId,
    DateTime? createdAt,
  }) async {}
}

class _FakeMoneyRepository implements MoneyRepository {
  final updatedUserIds = <String>[];
  final updates = <MoneyTransactionUpdate>[];

  @override
  Future<MoneyTransactionEntity> updateTransaction(
    String userId,
    MoneyTransactionUpdate update,
  ) async {
    updatedUserIds.add(userId);
    updates.add(update);
    return _transactionFromUpdate(userId, update);
  }

  @override
  Future<MoneyTransactionEntity> recordTransactionRefund(
    String userId,
    String transactionId,
    int refundAmountMinor,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<MoneyPaymentMethod, int>> getPaymentMethodUsageRanksForUser(
    String userId,
  ) async {
    return const <MoneyPaymentMethod, int>{};
  }

  @override
  Future<void> refreshUsageStatsForUser(String userId) async {}

  @override
  Future<void> refreshUsageStatsForAllUsers() async {}

  @override
  Future<void> resetAutoPostingRun(String userId, String runId) async {}

  MoneyTransactionEntity _transactionFromUpdate(
    String userId,
    MoneyTransactionUpdate update,
  ) {
    return MoneyTransactionEntity(
      id: update.id,
      userId: userId,
      type: update.type,
      status: MoneyTransactionStatus.completed,
      transactionAt: update.transactionAt,
      amountMinor: update.amountMinor,
      refundAmountMinor: 0,
      currencyCode: update.currencyCode,
      description: update.type.label,
      notes: update.notes,
      merchant: null,
      location: null,
      accountId: update.accountId,
      toAccountId: null,
      categoryId: update.categoryId,
      subCategoryId: update.subCategoryId,
      paymentMethod: update.paymentMethod,
      customPaymentMethodName: update.customPaymentMethodName,
      actualPayerAccount: 'default',
      relatedTransactionId: null,
      installmentPlanId: null,
      sourceTemplateRunId: null,
      interestRateBasisPoints: null,
      totalInterestMinor: 0,
      calcMethod: null,
      tags: update.tags,
      isDeleted: false,
      createdAt: DateTime.utc(2026, 7, 11),
      updatedAt: DateTime.utc(2026, 7, 11),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
