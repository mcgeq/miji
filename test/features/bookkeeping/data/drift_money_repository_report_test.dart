import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;
  late DateTime now;

  setUp(() async {
    now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftMoneyRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
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

  Future<void> insertReportRow({
    required String id,
    required String status,
    String? errorMessage,
    required String period,
    Map<String, dynamic>? data,
    DateTime? updatedAt,
  }) {
    return database
        .into(database.moneyAnalysisReports)
        .insert(
          MoneyAnalysisReportsCompanion.insert(
            id: id,
            userId: 'user_1',
            scopeType: 'ledger',
            reportPeriod: period,
            periodStartDate: 20260101,
            periodEndDate: 20260131,
            status: status,
            reportDataJson: data == null ? '{}' : '{"income_minor":100}',
            errorMessage: Value<String?>(errorMessage),
            createdAt: now,
            updatedAt: updatedAt ?? now,
          ),
        );
  }

  test(
    'failed report row surfaces as failed state instead of stuck generation',
    () async {
      await insertReportRow(
        id: 'report-failed',
        status: 'failed',
        errorMessage: 'boom: stats broke',
        period: 'monthly',
      );

      final report = await repository.getLatestReportForUser(
        'user_1',
        'default_ledger_user_1',
        'monthly',
      );

      expect(report, isNotNull);
      expect(report!.status, 'failed');
      expect(report.errorMessage, contains('stats broke'));
    },
  );

  test('completed report is preferred over a newer failed row', () async {
    await insertReportRow(
      id: 'report-old-completed',
      status: 'completed',
      period: 'monthly',
      data: {'income_minor': 100},
    );
    await insertReportRow(
      id: 'report-failed',
      status: 'failed',
      errorMessage: 'boom',
      period: 'monthly',
      updatedAt: now.add(const Duration(hours: 3)),
    );

    final report = await repository.getLatestReportForUser(
      'user_1',
      'default_ledger_user_1',
      'monthly',
    );

    expect(report, isNotNull);
    expect(report!.status, 'completed');
  });

  test(
    'stale generation_started rows are cleared on next generation',
    () async {
      await insertReportRow(
        id: 'stale-row',
        status: 'generation_started',
        period: 'monthly',
      );

      final report = await repository.generateReportForUser(
        'user_1',
        MoneyAnalysisReportRequest(
          ledgerId: 'default_ledger_user_1',
          reportPeriod: 'monthly',
          periodStart: DateTime(2026, 1, 1),
          periodEnd: DateTime(2026, 2, 1),
        ),
      );

      expect(report.status, 'completed');
      final rows = await (database.select(database.moneyAnalysisReports)).get();
      expect(rows, hasLength(1));
      expect(rows.single.status, 'completed');
      final latest = await repository.getLatestReportForUser(
        'user_1',
        'default_ledger_user_1',
        'monthly',
      );
      expect(latest?.status, 'completed');
    },
  );
}
