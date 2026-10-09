// 「提醒中心的『处理』必须真的落一笔流水」这条闭环的集成验证。
//
// 与 `drift_money_repository_reminder_repair_test.dart` 的区别：
// 那个文件只验证仓储方法的正确性，这里用**真实的 DriftMoneyRepository** 挂在
// ProviderContainer 上，跑完整的 UI 侧调用序列——
//
//     createTransaction(draft)  →  MoneyTransactionEntity.id
//     complete(item, transactionId: id) → setReminderCenterState + _syncSource
//
// 断言的是用户实际能感知的三件事：账本里多了一条钱、源头不再当作待办、
// 提醒与流水双向可查。任何一环退回去都会在这里红.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late ProviderContainer container;
  late String accountId;
  late String categoryId;

  const ledgerId = 'default_ledger_user_1';
  const userId = 'user_1';
  final today = DateTime.utc(2026, 7, 19);

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

    await insertUserRows(database, userId: userId, ledgerId: ledgerId);

    // 走仓储 API 而不是裸插表：货币、默认账本、货币汇率等前置数据由
    // ensureReadyForUser 一并准备，账户还要挂到账本上。
    final account = await repository.createAccount(
      userId,
      const MoneyAccountDraft(
        name: '现金',
        type: MoneyAccountType.cash,
        initialBalanceMinor: 1000000,
      ),
    );
    accountId = account.id;
    final category = await repository.createCategory(
      userId,
      const MoneyCategoryDraft(name: '居家', kind: MoneyCategoryKind.expense),
    );
    categoryId = category.id;

    container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith(_UnlockedAuthController.new),
        moneyRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

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
        accountId: accountId,
        remindBeforeDays: 3,
        repeatPeriodType: repeatPeriodType,
        autoManaged: autoManaged,
      ),
    );
  }

  Future<MoneyReminderCenterItem> pendingItemOf(String reminderId) async {
    final pending = await repository.getPendingReminderCenterItems(
      userId,
      ledgerId: ledgerId,
      today: today,
    );
    return pending.firstWhere((item) => item.sourceId == reminderId);
  }

  Future<MoneyBillReminder> rowOf(String reminderId) {
    return (database.select(
      database.moneyBillReminders,
    )..where((reminder) => reminder.id.equals(reminderId))).getSingle();
  }

  Future<List<MoneyTransaction>> transactionRows() {
    return database.select(database.moneyTransactions).get();
  }

  /// UI 侧「记账」的完整调用序列：先落流水，再把流水 id 回填给提醒。
  Future<MoneyTransactionEntity> record({
    required MoneyReminderCenterItem item,
    int? amountMinor,
  }) async {
    final transaction = await container
        .read(currentUserMoneyTransactionActionsProvider)
        .createTransaction(
          MoneyTransactionDraft(
            type: MoneyTransactionType.expense,
            transactionAt: item.dueDate,
            amountMinor: amountMinor ?? item.amountMinor,
            currencyCode: item.currencyCode,
            description: item.title,
            accountId: item.accountId ?? accountId,
            categoryId: categoryId,
            paymentMethod: MoneyPaymentMethod.bankCard,
            ledgerId: item.ledgerId,
          ),
          rememberDefaults: false,
        );
    await container
        .read(currentUserReminderCenterActionsProvider)
        .complete(item, transactionId: transaction.id);
    return transaction;
  }

  test('完成账单提醒会落一笔流水，并把源头置为 done 且关联该流水', () async {
    final reminder = await createReminder(name: '房租');
    final item = await pendingItemOf(reminder.id);

    final transaction = await record(item: item);

    // 1. 账本里真的多了一条钱。
    final rows = await transactionRows();
    expect(rows, hasLength(1));
    expect(rows.single.amountMinor, item.amountMinor);
    expect(rows.single.description, '房租');
    expect(rows.single.id, transaction.id);

    // 2. 源头不再是待办 —— 通知与统计页不再计入它。
    final row = await rowOf(reminder.id);
    expect(row.status, MoneyBillReminderStatus.done.storageValue);
    // 3. 提醒 ↔ 流水双向可查。
    expect(row.relatedTransactionId, transaction.id);
  });

  test('完成后从待处理列表消失、进入处理历史', () async {
    final reminder = await createReminder(name: '水电费');
    await record(item: await pendingItemOf(reminder.id));

    final pending = await repository.getPendingReminderCenterItems(
      userId,
      ledgerId: ledgerId,
      today: today,
    );
    expect(pending.map((item) => item.sourceId), isNot(contains(reminder.id)));

    final history = await repository.getReminderCenterHistory(
      userId,
      ledgerId: ledgerId,
    );
    expect(history, hasLength(1));
    expect(history.single.sourceId, reminder.id);
    expect(history.single.state, MoneyReminderCenterState.completed);
  });

  test('完成回写后 repair 不再重复修理，两阶段不互踢', () async {
    final reminder = await createReminder(name: '物业费');
    await record(item: await pendingItemOf(reminder.id));

    // 阶段 A 已经把源头写对了，阶段 0 的自愈应当识别为「无需改动」。
    expect(
      await repository.repairBillReminderProcessingStatuses(
        userId,
        ledgerId: ledgerId,
      ),
      0,
    );
    final version = (await rowOf(reminder.id)).version;
    expect(
      await repository.repairBillReminderProcessingStatuses(
        userId,
        ledgerId: ledgerId,
      ),
      0,
    );
    expect((await rowOf(reminder.id)).version, version);
  });

  test('重复完成同一条提醒是幂等的', () async {
    final reminder = await createReminder(name: '宽带费');
    final item = await pendingItemOf(reminder.id);
    await record(item: item);

    final firstRow = await rowOf(reminder.id);
    await container
        .read(currentUserReminderCenterActionsProvider)
        .complete(item, transactionId: firstRow.relatedTransactionId);

    final secondRow = await rowOf(reminder.id);
    expect(secondRow.status, MoneyBillReminderStatus.done.storageValue);
    expect(secondRow.relatedTransactionId, firstRow.relatedTransactionId);
    expect(secondRow.version, firstRow.version);
    // 重复处理也不会再造第二笔流水。
    expect(await transactionRows(), hasLength(1));
  });

  test('周期性提醒记账后仍保持 pending，下一期还会出现', () async {
    final reminder = await createReminder(
      name: '房租',
      repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
    );
    await record(item: await pendingItemOf(reminder.id));

    final row = await rowOf(reminder.id);
    expect(row.status, 'pending');
    expect(row.relatedTransactionId, isNull);
  });

  test('自动托管提醒记账后仍保持 pending，不与账单同步互踢', () async {
    final reminder = await createReminder(name: '信用卡还款', autoManaged: true);
    await record(item: await pendingItemOf(reminder.id));

    final row = await rowOf(reminder.id);
    expect(row.status, 'pending');
    expect(row.relatedTransactionId, isNull);
  });

  test('分期/预算/周期性支出类提醒不会误写账单提醒状态', () async {
    // sourceId 借用分期提醒的复合格式（planId:detailId），账单提醒表里没有这个 id。
    // 若 _syncSource 误走到账单分支，setBillReminderStatus 会抛 reminderNotFound。
    Future<void> completeAs(MoneyReminderCenterSourceType sourceType) {
      return container
          .read(currentUserReminderCenterActionsProvider)
          .complete(
            MoneyReminderCenterItem(
              sourceType: sourceType,
              sourceId: 'plan-1:detail-2',
              title: '第 2 期',
              dueDate: DateTime.utc(2026, 7, 22),
              amountMinor: 30000,
              currencyCode: 'CNY',
              ledgerId: ledgerId,
              accountId: accountId,
              actionType: MoneyReminderCenterActionType.recordTransaction,
            ),
          );
    }

    for (final sourceType in const [
      MoneyReminderCenterSourceType.installment,
      MoneyReminderCenterSourceType.budget,
      MoneyReminderCenterSourceType.recurringExpense,
    ]) {
      await expectLater(completeAs(sourceType), completes);
    }
  });
}

Future<void> insertUserRows(
  AppDatabase database, {
  required String userId,
  required String ledgerId,
}) async {
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
        mode: InsertMode.insertOrIgnore,
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
        mode: InsertMode.insertOrIgnore,
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
}

class _UnlockedAuthController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user_1', isUnlocked: true);
}
