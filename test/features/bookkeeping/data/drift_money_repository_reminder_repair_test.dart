import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';

/// 覆盖「提醒已处理、源头却仍是 pending」这条链路：
///
/// * `repairBillReminderProcessingStatuses` —— 读取时自愈；
/// * `linkBillReminderTransaction` —— 提醒 ↔ 流水关联。
///
/// 背景：`moneyBillReminders.status` 长期不被置终态，`MoneyBillReminderEntity.isActive`
/// 只看 status，于是用户早已在提醒中心处理掉的非重复提醒仍然
/// 持续推送系统通知、并计入统计页「即将到期账单」。
void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;

  const ledgerId = 'default_ledger_user_1';
  const userId = 'user_1';

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
        now: () => DateTime.utc(2026, 7, 19, 8),
      ),
      now: () => DateTime.utc(2026, 7, 19, 8),
    );

    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: userId,
            username: userId,
            email: '$userId@example.com',
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
            userId: userId,
            name: '用户',
            role: 'owner',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.moneyLedgers)
        .insert(
          MoneyLedgersCompanion.insert(
            id: ledgerId,
            userId: userId,
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
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: ledgerId,
            memberId: 'default_member_user_1',
            createdAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<MoneyBillReminder> rowOf(String reminderId) {
    return (database.select(
      database.moneyBillReminders,
    )..where((reminder) => reminder.id.equals(reminderId))).getSingle();
  }

  Future<MoneyBillReminderEntity> createReminder({
    required String name,
    MoneyBillReminderRepeatPeriodType? repeatPeriodType,
    bool autoManaged = false,
  }) {
    return repository.createBillReminder(
      userId,
      MoneyBillReminderDraft(
        name: name,
        amountMinor: 300000,
        dueDate: DateTime.utc(2026, 7, 22),
        ledgerId: ledgerId,
        // 与既有用例保持一致：让 dueDate 2026-07-22 在 today 2026-07-19 可见。
        remindBeforeDays: 3,
        repeatPeriodType: repeatPeriodType,
        autoManaged: autoManaged,
      ),
    );
  }

  /// 取当前源数据里该提醒对应的实体，用来验证 `isActive`。
  Future<MoneyBillReminderEntity> entityOf(String reminderId) async {
    final rows = await repository
        .watchBillRemindersForUser(userId, ledgerId: ledgerId)
        .first;
    return rows.firstWhere((row) => row.id == reminderId);
  }

  Future<MoneyReminderCenterItem> pendingItemOf(String reminderId) async {
    final pending = await repository.getPendingReminderCenterItems(
      userId,
      ledgerId: ledgerId,
      today: DateTime.utc(2026, 7, 19),
    );
    return pending.firstWhere((item) => item.sourceId == reminderId);
  }

  group('repairBillReminderProcessingStatuses', () {
    test('把已完成的非重复提醒收敛为 done', () async {
      final reminder = await createReminder(name: '房租');
      final item = await pendingItemOf(reminder.id);

      await repository.setReminderCenterState(
        userId,
        item,
        MoneyReminderCenterState.completed,
      );
      expect((await rowOf(reminder.id)).status, 'pending');

      final repaired = await repository.repairBillReminderProcessingStatuses(
        userId,
        ledgerId: ledgerId,
      );

      expect(repaired, 1);
      expect(
        (await rowOf(reminder.id)).status,
        MoneyBillReminderStatus.done.storageValue,
      );
      // 这才是目的：不再被当作 active，通知与统计不再计入。
      expect((await entityOf(reminder.id)).isActive, isFalse);
    });

    test('幂等：重复执行返回 0 且不再改数据', () async {
      final reminder = await createReminder(name: '房租');
      await repository.setReminderCenterState(
        userId,
        await pendingItemOf(reminder.id),
        MoneyReminderCenterState.completed,
      );

      expect(
        await repository.repairBillReminderProcessingStatuses(
          userId,
          ledgerId: ledgerId,
        ),
        1,
      );
      final versionAfterFirst = (await rowOf(reminder.id)).version;

      expect(
        await repository.repairBillReminderProcessingStatuses(
          userId,
          ledgerId: ledgerId,
        ),
        0,
      );
      final row = await rowOf(reminder.id);
      expect(row.version, versionAfterFirst);
    });

    test('已忽略的提醒同样收敛，且历史记录不受影响', () async {
      final reminder = await createReminder(name: '网费');
      await repository.setReminderCenterState(
        userId,
        await pendingItemOf(reminder.id),
        MoneyReminderCenterState.ignored,
      );

      expect(
        await repository.repairBillReminderProcessingStatuses(
          userId,
          ledgerId: ledgerId,
        ),
        1,
      );
      expect(
        (await rowOf(reminder.id)).status,
        MoneyBillReminderStatus.done.storageValue,
      );

      // 完成/忽略的真值始终留在处理表里，处理历史仍能读出来。
      final history = await repository.getReminderCenterHistory(
        userId,
        ledgerId: ledgerId,
      );
      expect(history, hasLength(1));
      expect(history.single.state, MoneyReminderCenterState.ignored);
      expect(history.single.sourceId, reminder.id);
    });

    test('延后中的提醒不收敛', () async {
      final reminder = await createReminder(name: '电费');
      await repository.setReminderCenterState(
        userId,
        await pendingItemOf(reminder.id),
        MoneyReminderCenterState.snoozed,
        snoozedUntil: DateTime.utc(2026, 7, 26),
      );

      expect(
        await repository.repairBillReminderProcessingStatuses(
          userId,
          ledgerId: ledgerId,
        ),
        0,
      );
      expect((await rowOf(reminder.id)).status, 'pending');
    });

    test('周期性提醒保持 pending，否则下一期不再出现', () async {
      final reminder = await createReminder(
        name: '房租',
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
      );
      await repository.setReminderCenterState(
        userId,
        await pendingItemOf(reminder.id),
        MoneyReminderCenterState.completed,
      );

      expect(
        await repository.repairBillReminderProcessingStatuses(
          userId,
          ledgerId: ledgerId,
        ),
        0,
      );
      expect((await rowOf(reminder.id)).status, 'pending');
    });

    test('自动托管提醒保持 pending', () async {
      // 它的 status 由 _syncCreditAccountRepaymentReminder 独占管理：
      // 每次写流水都会改回 pending，本方法若写 done 会与之互踢。
      final reminder = await createReminder(name: '信用卡还款', autoManaged: true);
      await repository.setReminderCenterState(
        userId,
        await pendingItemOf(reminder.id),
        MoneyReminderCenterState.completed,
      );

      expect(
        await repository.repairBillReminderProcessingStatuses(
          userId,
          ledgerId: ledgerId,
        ),
        0,
      );
      expect((await rowOf(reminder.id)).status, 'pending');
    });

    test('收敛动作会落 sync 变更，保证多端一致', () async {
      final reminder = await createReminder(name: '房租');
      await repository.setReminderCenterState(
        userId,
        await pendingItemOf(reminder.id),
        MoneyReminderCenterState.completed,
      );
      await repository.repairBillReminderProcessingStatuses(
        userId,
        ledgerId: ledgerId,
      );

      final logs =
          await (database.select(database.syncChangeLogs)
                ..where(
                  (row) => row.targetTable.equals(
                    SyncChangeLogger.moneyBillRemindersTableName,
                  ),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.changedAt)]))
              .get();
      final fields = logs.map(
        (log) =>
            Map<String, Object?>.from(jsonDecode(log.changedFieldsJson) as Map),
      );
      expect(
        fields.any(
          (map) => map['status'] == MoneyBillReminderStatus.done.storageValue,
        ),
        isTrue,
      );
    });
  });

  group('linkBillReminderTransaction', () {
    test('写入关联流水并幂等', () async {
      final reminder = await createReminder(name: '房租');

      await repository.linkBillReminderTransaction(userId, reminder.id, 'tx_1');
      var row = await rowOf(reminder.id);
      expect(row.relatedTransactionId, 'tx_1');
      expect(row.version, 2);

      // 同一个 transactionId 重复写入不再产生新版本。
      await repository.linkBillReminderTransaction(userId, reminder.id, 'tx_1');
      row = await rowOf(reminder.id);
      expect(row.relatedTransactionId, 'tx_1');
      expect(row.version, 2);
    });

    test('提醒不存在时抛出 reminderNotFound', () async {
      expect(
        () => repository.linkBillReminderTransaction(
          userId,
          'missing_reminder',
          'tx_1',
        ),
        throwsA(isA<MoneyRepositoryException>()),
      );
    });
  });
}
