import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;

  setUp(() async {
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
        now: () => DateTime.utc(2026, 7, 13, 8),
      ),
    );

    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
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
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'manages family ledger account links without changing balances',
    () async {
      final cash = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '现金',
          type: MoneyAccountType.cash,
          initialBalanceMinor: 12000,
        ),
      );
      final bank = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '银行卡',
          type: MoneyAccountType.bank,
          initialBalanceMinor: 50000,
        ),
      );
      final personal = await repository.getDefaultLedgerForUser('user_1');
      final family = await repository.createLedger(
        'user_1',
        const MoneyLedgerDraft(name: '家庭'),
      );

      final personalAccounts = await repository
          .watchAccountsForLedger('user_1', personal.id)
          .first;
      expect(personalAccounts.map((account) => account.id), contains(cash.id));
      expect(personalAccounts.map((account) => account.id), contains(bank.id));

      expect(
        await repository.watchAccountsForLedger('user_1', family.id).first,
        isEmpty,
      );

      await repository.addAccountToLedger('user_1', family.id, cash.id);

      final linkedAccounts = await repository
          .watchAccountsForLedger('user_1', family.id)
          .first;
      expect(linkedAccounts.map((account) => account.id), [cash.id]);

      final unchangedCash = await (database.select(
        database.moneyAccounts,
      )..where((row) => row.id.equals(cash.id))).getSingle();
      expect(unchangedCash.balanceMinor, 12000);
      expect(unchangedCash.initialBalanceMinor, 12000);

      await repository.removeAccountFromLedger('user_1', family.id, cash.id);

      expect(
        await repository.watchAccountsForLedger('user_1', family.id).first,
        isEmpty,
      );

      final relationLogs =
          (await database.select(database.syncChangeLogs).get())
              .where(
                (row) =>
                    row.targetTable ==
                    SyncChangeLogger.moneyLedgerAccountsTableName,
              )
              .toList();
      expect(relationLogs.map((row) => row.operation), ['insert', 'delete']);
      expect(relationLogs.map((row) => row.recordId), [
        '${family.id}::${cash.id}',
        '${family.id}::${cash.id}',
      ]);
    },
  );
}
