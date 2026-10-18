import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/features/life_energy/data/life_energy_remote_apply.dart';
import 'package:miji/features/life_energy/data/life_energy_repository.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 远端变更落地。这一层不做合并决策（版本比对在上游），只负责：
/// 整行写进去、软删要真的删掉、年终奖守住「一年一条」。
void main() {
  late AppDatabase database;
  final now = DateTime.utc(2026, 10, 18, 9);

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
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

  DeltaChangeRecord change(
    String table,
    String recordId,
    Map<String, Object?> fields, {
    String operation = 'insert',
    int? newVersion = 1,
  }) {
    return DeltaChangeRecord(
      table: table,
      recordId: recordId,
      operation: operation,
      baseVersion: null,
      newVersion: newVersion,
      changedFields: fields,
      recordSnapshot: const {},
    );
  }

  test('档案：远端写入后本地读得到，删除后读不到', () async {
    await database.applyRemoteLifeEnergyChange(
      change('life_energy_profiles', 'user-1', {
        'user_id': 'user-1',
        'pay_amount_minor': 1300000,
        'work_days_per_month': 21,
        'version': 2,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }),
      null,
    );

    final repository = LifeEnergyRepository(database);
    final profile = await repository.fetchProfile('user-1');
    expect(profile, isNotNull);
    expect(profile!.payAmountMinor, 1300000);
    expect(profile.workDaysPerMonth, 21);

    // 远端软删：本地读不到，但行还在（可追溯）。
    await database.applyRemoteLifeEnergyChange(
      change(
        'life_energy_profiles',
        'user-1',
        {
          'user_id': 'user-1',
          'pay_amount_minor': 1300000,
          'is_deleted': true,
          'version': 3,
          'deleted_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        operation: 'delete',
        newVersion: 3,
      ),
      null,
    );
    expect(await repository.fetchProfile('user-1'), isNull);
    expect(
      await database.select(database.lifeEnergyProfiles).get(),
      hasLength(1),
    );
  });

  test('职业段：参数快照原样落地，软删后列表里消失', () async {
    const payroll = '{"housingFundBp":500,"baseFloorMinor":352300}';
    await database.applyRemoteLifeEnergyChange(
      change('salary_segments', 'seg-1', {
        'id': 'seg-1',
        'user_id': 'user-1',
        'effective_year': 2025,
        'effective_month': 7,
        'amount_minor': 1600000,
        'gross_amount_minor': 2000000,
        'payroll_json': payroll,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }),
      null,
    );

    final repository = LifeEnergyRepository(database);
    final segments = await repository.fetchSalarySegments('user-1');
    expect(segments, hasLength(1));
    expect(segments.single.payroll?.housingFundBp, 500);
    expect(segments.single.effectiveMonth, 7);

    await database.applyRemoteLifeEnergyChange(
      change(
        'salary_segments',
        'seg-1',
        {
          'id': 'seg-1',
          'user_id': 'user-1',
          'effective_year': 2025,
          'effective_month': 7,
          'amount_minor': 1600000,
          'is_deleted': true,
          'deleted_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        operation: 'delete',
        newVersion: 2,
      ),
      null,
    );
    expect(await repository.fetchSalarySegments('user-1'), isEmpty);
  });

  test('年终奖：两台设备同年各一笔时，本地只留一条（不撞唯一索引也不丢事实）', () async {
    final repository = LifeEnergyRepository(database, now: () => now);
    await repository.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    // 本地先有一笔 2026 的 40,000。
    await repository.saveBonus(
      userId: 'user-1',
      taxYear: 2026,
      amountMinor: 4000000,
      sourceLabel: '云图科技',
    );
    final localId = (await repository.fetchBonuses('user-1')).single.id;

    // 远端另一台设备同年写了 45,000，行 id 不同。
    await database.applyRemoteLifeEnergyChange(
      change('bonus_payments', 'remote-row', {
        'id': 'remote-row',
        'user_id': 'user-1',
        'tax_year': 2026,
        'amount_minor': 4500000,
        'source_label': '云图科技',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }, newVersion: 2),
      null,
    );

    final bonuses = await repository.fetchBonuses('user-1');
    // 一年一条：不是两条，也不是把本地的丢了插一条新的。
    expect(bonuses, hasLength(1));
    expect(bonuses.single.id, localId, reason: '写回本地那一行，保留本地 id');
    expect(bonuses.single.amountMinor, 4500000);
    expect(bonuses.single.taxYear, 2026);
  });

  test('想买 / 加班：整行落地，三态答案与补偿方式都不丢', () async {
    await database.applyRemoteLifeEnergyChange(
      change('wishlist_items', 'w-1', {
        'id': 'w-1',
        'user_id': 'user-1',
        'title': '降噪耳机',
        'target_amount_minor': 129900,
        'desire_level': 'strong',
        'status': 'waiting',
        'q1_satisfaction': true,
        'q2_aligned': false,
        'cooldown_until': now.add(const Duration(days: 7)).toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }),
      null,
    );
    await database.applyRemoteLifeEnergyChange(
      change('overtime_entries', 'o-1', {
        'id': 'o-1',
        'user_id': 'user-1',
        'work_date': now.toIso8601String(),
        'minutes': 120,
        'comp_type': 'timeOff',
        'extra_cost_minor': 3000,
        'is_rest_day': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }),
      null,
    );

    final repository = LifeEnergyRepository(database);
    final wish =
        (await repository.watchWishlist(userId: 'user-1').first).single;
    expect(wish.desire, WishDesireLevel.strong);
    expect(wish.q1Satisfaction, isTrue);
    expect(wish.q2Aligned, isFalse);
    expect(wish.q3NoJob, isNull);

    final overtime =
        (await repository
                .watchOvertimeEntries(
                  userId: 'user-1',
                  monthStart: DateTime.utc(2026, 10),
                )
                .first)
            .single;
    expect(overtime.compensation, OvertimeCompensation.timeOff);
    expect(overtime.minutes, 120);
    expect(overtime.isRestDay, isTrue);
  });

  test('不认识的表返回 false（交给记账那条路）', () async {
    final applied = await database.applyRemoteLifeEnergyChange(
      change('money_accounts', 'a-1', {'id': 'a-1'}),
      null,
    );
    expect(applied, isFalse);
  });
}
