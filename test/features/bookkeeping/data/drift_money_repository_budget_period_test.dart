import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());

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
    'monthly budget period follows local calendar month across UTC boundary',
    () async {
      // 2026-07-31T16:00Z is 2026-08-01 00:00 in UTC+8 timezones.
      final localNow = DateTime.fromMillisecondsSinceEpoch(
        DateTime.utc(2026, 7, 31, 16).millisecondsSinceEpoch,
      );
      final pinned = DriftMoneyRepository(
        database: database,
        seedRunner: DatabaseSeedRunner(database: database),
        now: () => localNow,
      );

      final budget = await pinned.createBudget(
        'user_1',
        const MoneyBudgetDraft(name: '月度消费', amountMinor: 100000),
      );

      expect(budget.periodStart, DateTime(localNow.year, localNow.month));
      expect(
        budget.periodEnd,
        DateTime(
          localNow.year,
          localNow.month + 1,
        ).subtract(const Duration(milliseconds: 1)),
      );
      expect(budget.periodType, MoneyBudgetPeriodType.monthly);
    },
  );

  test(
    'weekly budget period starts on the local Monday of the pinned clock',
    () async {
      // 2026-07-30T16:00Z is 2026-07-31 00:00 (Friday) in UTC+8 timezones.
      final localNow = DateTime.fromMillisecondsSinceEpoch(
        DateTime.utc(2026, 7, 30, 16).millisecondsSinceEpoch,
      );
      final pinned = DriftMoneyRepository(
        database: database,
        seedRunner: DatabaseSeedRunner(database: database),
        now: () => localNow,
      );

      final budget = await pinned.createBudget(
        'user_1',
        const MoneyBudgetDraft(
          name: '周度消费',
          amountMinor: 50000,
          periodType: MoneyBudgetPeriodType.weekly,
        ),
      );

      final localDay = DateTime(localNow.year, localNow.month, localNow.day);
      final expectedStart = localDay.subtract(
        Duration(days: localDay.weekday - 1),
      );
      expect(budget.periodStart, expectedStart);
      expect(
        budget.periodEnd,
        expectedStart
            .add(const Duration(days: 7))
            .subtract(const Duration(milliseconds: 1)),
      );
    },
  );
}
