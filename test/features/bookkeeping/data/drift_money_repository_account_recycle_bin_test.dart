import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;

  setUp(() async {
    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    database = AppDatabase(NativeDatabase.memory());
    var nextChangeId = 0;
    repository = DriftMoneyRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
      syncChangeLogger: SyncChangeLogger(
        database: database,
        identityResolver: const FixedSyncIdentityResolver(
          SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
        ),
        createId: () => 'change-${nextChangeId += 1}',
        now: () => now,
      ),
      now: () => now,
    );

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.moneyMembers)
        .insert(
          MoneyMembersCompanion.insert(
            id: 'default_member_user_1',
            userId: 'user_1',
            name: '用户',
            role: 'owner',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgers)
        .insert(
          MoneyLedgersCompanion.insert(
            id: 'default_ledger_user_1',
            userId: 'user_1',
            name: '个人账本',
            createdByMemberId: 'default_member_user_1',
            ledgerType: 'personal',
            status: 'active',
            baseCurrencyCode: 'CNY',
            settlementCycle: 'manual',
            settlementDay: 1,
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: 'default_ledger_user_1',
            memberId: 'default_member_user_1',
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('lists deleted accounts and restores them', () async {
    final cash = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 12000,
      ),
    );

    await repository.deleteAccount('user_1', cash.id);

    final deleted = await repository.getDeletedAccountsForUser('user_1');
    expect(deleted.map((account) => account.id), [cash.id]);
    expect(
      await repository.watchVisibleAccountsForUser('user_1').first,
      isEmpty,
    );

    await repository.restoreAccount('user_1', cash.id);

    expect(await repository.getDeletedAccountsForUser('user_1'), isEmpty);
    final visible = await repository
        .watchVisibleAccountsForUser('user_1')
        .first;
    expect(visible.map((account) => account.id), contains(cash.id));
    final restored = visible.firstWhere((account) => account.id == cash.id);
    expect(restored.isActive, isTrue);
    expect(restored.balanceMinor, 12000);
  });

  test('restore records a sync update change', () async {
    final cash = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 12000,
      ),
    );
    await repository.deleteAccount('user_1', cash.id);
    await repository.restoreAccount('user_1', cash.id);

    final logs = (await database.select(database.syncChangeLogs).get())
        .where(
          (row) =>
              row.targetTable == SyncChangeLogger.moneyAccountsTableName &&
              row.recordId == cash.id,
        )
        .toList();
    expect(logs.map((row) => row.operation), ['insert', 'delete', 'update']);
    expect(logs.last.beforeVersion, 2);
    expect(logs.last.afterVersion, 3);
  });

  test('restoring an active account is a no-op', () async {
    final cash = await repository.createAccount(
      'user_1',
      const MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 12000,
      ),
    );

    await repository.restoreAccount('user_1', cash.id);

    final row = await (database.select(
      database.moneyAccounts,
    )..where((account) => account.id.equals(cash.id))).getSingle();
    expect(row.isDeleted, isFalse);
    expect(row.version, 1);
  });
}
