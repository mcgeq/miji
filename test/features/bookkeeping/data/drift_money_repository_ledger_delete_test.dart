import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';

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

  test(
    'soft-deletes a family ledger and records a sync delete change',
    () async {
      final family = await repository.createLedger(
        'user_1',
        const MoneyLedgerDraft(name: '家庭'),
      );
      await repository.createMember(
        'user_1',
        const MoneyMemberDraft(name: '成员'),
        ledgerId: family.id,
      );

      await repository.deleteLedger('user_1', family.id);

      final row = await (database.select(
        database.moneyLedgers,
      )..where((ledger) => ledger.id.equals(family.id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(row.status, 'archived');
      expect(row.deletedAt, isNotNull);
      expect(row.version, 2);

      final ledgers = await repository.watchLedgersForUser('user_1').first;
      expect(ledgers.map((ledger) => ledger.id), isNot(contains(family.id)));

      final logs = (await database.select(database.syncChangeLogs).get())
          .where(
            (row) =>
                row.targetTable == SyncChangeLogger.moneyLedgersTableName &&
                row.recordId == family.id,
          )
          .toList();
      expect(logs.map((row) => row.operation), ['insert', 'delete']);
      expect(logs.last.beforeVersion, 1);
      expect(logs.last.afterVersion, 2);
    },
  );

  test('rejects deleting the personal ledger', () async {
    final personal = await repository.getDefaultLedgerForUser('user_1');

    await expectLater(
      repository.deleteLedger('user_1', personal.id),
      throwsA(
        isA<MoneyRepositoryException>().having(
          (error) => error.code,
          'code',
          MoneyRepositoryErrorCode.cannotDeletePersonalLedger,
        ),
      ),
    );

    final ledgers = await repository.watchLedgersForUser('user_1').first;
    expect(ledgers.map((ledger) => ledger.id), contains(personal.id));
  });

  test('deleted ledger is not visible to dependent queries', () async {
    final family = await repository.createLedger(
      'user_1',
      const MoneyLedgerDraft(name: '家庭'),
    );
    await repository.deleteLedger('user_1', family.id);

    await expectLater(
      repository.watchMembersForLedger('user_1', family.id).first,
      throwsA(
        isA<MoneyRepositoryException>().having(
          (error) => error.code,
          'code',
          MoneyRepositoryErrorCode.ledgerNotFound,
        ),
      ),
    );
  });
}
