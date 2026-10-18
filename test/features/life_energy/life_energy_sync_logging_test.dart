import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/life_energy/data/life_energy_repository.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 同步的冲突判定比的是 `local.version != baseVersion`。这些表建表时就有
/// `version` 列，但写路径从来没递增过（恒为 1）—— 那样冲突永远检不出来，
/// 远端变更会静默覆盖本地。这一组用例钉住「每次写都 +1，并且进了变更日志」。
void main() {
  late AppDatabase database;
  late LifeEnergyRepository repository;
  final now = DateTime(2026, 10, 18, 9);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeEnergyRepository(
      database,
      now: () => now,
      syncLogger: SyncChangeLogger(
        database: database,
        identityResolver: const FixedSyncIdentityResolver(
          SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
        ),
        createId: () => 'change-${DateTime.now().microsecondsSinceEpoch}',
        now: () => now,
      ),
    );
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<List<SyncChangeLog>> logsFor(String table) {
    return (database.select(database.syncChangeLogs)
          ..where((row) => row.targetTable.equals(table))
          ..orderBy([(row) => OrderingTerm.asc(row.changedAt)]))
        .get();
  }

  test('档案：第一次保存是 insert(1)，第二次是 update(1→2)', () async {
    const profile = WorkProfile(
      userId: 'user-1',
      payAmountMinor: 1200000,
      workDaysPerMonth: 22,
      workMinutesPerDay: 480,
    );
    await repository.saveProfile(profile);
    await repository.saveProfile(profile.copyWith(payAmountMinor: 1500000));

    final logs = await logsFor(SyncChangeLogger.lifeEnergyProfilesTableName);
    // 两次 saveProfile，其中第二次还会顺手 upsert 当前段；档案表本身是两条。
    final profileLogs = logs
        .where(
          (row) =>
              row.targetTable == SyncChangeLogger.lifeEnergyProfilesTableName,
        )
        .toList();
    expect(profileLogs, hasLength(2));
    expect(profileLogs.first.operation, 'insert');
    expect(profileLogs.first.beforeVersion, isNull);
    expect(profileLogs.first.afterVersion, 1);
    expect(profileLogs.last.operation, 'update');
    expect(profileLogs.last.beforeVersion, 1);
    expect(profileLogs.last.afterVersion, 2);

    // 行里的 version 也真的变成 2 —— 日志说 2，行里也得是 2，否则冲突判定
    // 会拿一个假的基准去比。
    final row = await (database.select(
      database.lifeEnergyProfiles,
    )..where((r) => r.userId.equals('user-1'))).getSingle();
    expect(row.version, 2);

    // 快照要是完整整行（列名是 snake_case），不是一个 {id, user_id} 壳子。
    expect(profileLogs.last.changedFieldsJson, contains('pay_amount_minor'));
    expect(profileLogs.last.changedFieldsJson, contains('1500000'));
  });

  test('职业段：新建记 insert，删除记 delete 且版本 +1', () async {
    await repository.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    final id = await repository.createSalarySegment(
      userId: 'user-1',
      effectiveYear: 2025,
      effectiveMonth: 1,
      amountMinor: 1600000,
    );
    await repository.deleteSalarySegment('user-1', id);

    final logs = await logsFor(SyncChangeLogger.salarySegmentsTableName);
    expect(logs.first.operation, 'insert');
    expect(logs.last.operation, 'delete');
    expect(logs.last.beforeVersion, 1);
    expect(logs.last.afterVersion, 2);

    final row = await (database.select(
      database.salarySegments,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.isDeleted, isTrue);
    expect(row.version, 2);
  });

  test('年终奖：同年再存是 update，不是静默插第二条', () async {
    await repository.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    await repository.saveBonus(
      userId: 'user-1',
      taxYear: 2026,
      amountMinor: 4000000,
    );
    await repository.saveBonus(
      userId: 'user-1',
      taxYear: 2026,
      amountMinor: 4500000,
    );

    final logs = await logsFor(SyncChangeLogger.bonusPaymentsTableName);
    expect(logs.map((row) => row.operation), ['insert', 'update']);
    expect(logs.last.afterVersion, 2);
    expect(logs.last.changedFieldsJson, contains('4500000'));
  });

  test('想买与加班：新建也进日志（否则换机就丢）', () async {
    await repository.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    await repository.createWishlistEntry(
      userId: 'user-1',
      title: '降噪耳机',
      targetAmountMinor: 129900,
      cooldownUntil: now.add(const Duration(days: 7)),
    );
    await repository.createOvertimeEntry(
      userId: 'user-1',
      workDate: now,
      minutes: 120,
      compensation: OvertimeCompensation.none,
    );

    expect(
      await logsFor(SyncChangeLogger.wishlistItemsTableName),
      hasLength(1),
    );
    expect(
      await logsFor(SyncChangeLogger.overtimeEntriesTableName),
      hasLength(1),
    );
  });

  test('没接日志的仓库（测试 / 未登录）不写日志，也不崩', () async {
    final plain = LifeEnergyRepository(database, now: () => now);
    await plain.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    expect(
      await logsFor(SyncChangeLogger.lifeEnergyProfilesTableName),
      isEmpty,
    );
  });
}
