import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
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

  test('createAccount round-trips background appearance fields', () async {
    final account = await repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: '旅游基金',
        type: MoneyAccountType.saving,
        initialBalanceMinor: 500000,
        icon: 'diamond',
        backgroundStyle: MoneyAccountBackgroundStyle.image,
        backgroundColor: '#BAE6FD',
        backgroundImage: 'user_1/202601/abc.jpg',
      ),
    );

    final visible = await repository
        .watchVisibleAccountsForUser('user_1')
        .first;
    final stored = visible.singleWhere((row) => row.id == account.id);
    expect(stored.icon, 'diamond');
    expect(stored.resolvedBackgroundStyle, MoneyAccountBackgroundStyle.image);
    expect(stored.backgroundColor, '#BAE6FD');
    expect(stored.backgroundImage, 'user_1/202601/abc.jpg');

    final row = await (database.select(
      database.moneyAccounts,
    )..where((column) => column.id.equals(account.id))).getSingle();
    expect(row.backgroundStyle, 'image');
    expect(row.backgroundColor, '#BAE6FD');
    expect(row.backgroundImage, 'user_1/202601/abc.jpg');
  });

  test(
    'updateAccount writes background fields into sync changedFields only when changed',
    () async {
      final account = await repository.createAccount(
        'user_1',
        const MoneyAccountDraft(
          name: '现金',
          type: MoneyAccountType.cash,
          initialBalanceMinor: 10000,
        ),
      );

      // 什么都不改：不应产生 update 日志。
      await repository.updateAccount(
        'user_1',
        MoneyAccountUpdate(
          id: account.id,
          name: account.name,
          type: account.type,
          currencyCode: account.currencyCode,
          initialBalanceMinor: account.initialBalanceMinor,
        ),
      );

      // 改背景：日志只带 background_* 三个字段。
      await repository.updateAccount(
        'user_1',
        MoneyAccountUpdate(
          id: account.id,
          name: account.name,
          type: account.type,
          currencyCode: account.currencyCode,
          initialBalanceMinor: account.initialBalanceMinor,
          backgroundStyle: MoneyAccountBackgroundStyle.color,
          backgroundColor: '#7DD3FC',
        ),
      );

      final logs = (await database.select(database.syncChangeLogs).get())
          .where(
            (row) =>
                row.targetTable == SyncChangeLogger.moneyAccountsTableName &&
                row.recordId == account.id,
          )
          .toList();
      expect(logs, hasLength(2)); // insert + 一次 update

      final updateLog = logs.last;
      expect(updateLog.operation, 'update');
      final changedFields =
          jsonDecode(updateLog.changedFieldsJson) as Map<String, dynamic>;
      expect(changedFields.keys, everyElement(startsWith('background_')));
      expect(changedFields['background_style'], 'color');
      expect(changedFields['background_color'], '#7DD3FC');
      expect(changedFields['background_image'], null);
    },
  );

  test('adjustAccountBalance preserves appearance fields', () async {
    final account = await repository.createAccount(
      'user_1',
      MoneyAccountDraft(
        name: '钱包',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 10000,
        icon: 'wallet',
        backgroundStyle: MoneyAccountBackgroundStyle.color,
        backgroundColor: '#BBF7D0',
      ),
    );

    await repository.adjustAccountBalance('user_1', account.id, 20000);

    final adjusted = await repository
        .watchVisibleAccountsForUser('user_1')
        .first
        .then((rows) => rows.singleWhere((row) => row.id == account.id));
    expect(adjusted.balanceMinor, 20000);
    expect(adjusted.icon, 'wallet');
    expect(adjusted.resolvedBackgroundStyle, MoneyAccountBackgroundStyle.color);
    expect(adjusted.backgroundColor, '#BBF7D0');
  });
}
