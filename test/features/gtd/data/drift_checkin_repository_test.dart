import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Drift 生成的表模型也叫 `CheckinPlan`，这里只用领域模型那一份。
import 'package:miji/core/database/app_database.dart' hide CheckinPlan;
import 'package:miji/features/gtd/data/drift_checkin_repository.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';

Future<void> insertCheckinTestUser(AppDatabase database) async {
  final now = DateTime.utc(2026, 7, 18, 8);
  await database
      .into(database.users)
      .insert(
        UsersCompanion.insert(
          id: 'user_1',
          username: 'user_1',
          email: 'user_1@example.com',
          displayName: 'User One',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  late AppDatabase database;
  late DriftCheckinRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftCheckinRepository(
      database: database,
      now: () => DateTime.utc(2026, 7, 18, 8),
    );
    await insertCheckinTestUser(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('merged plan merges records and records each checkin time', () async {
    final plan = await repository.createPlan(
      const CheckinPlanDraft(
        name: '喝水',
        recordGranularity: CheckinRecordGranularity.merged,
      ),
      'user_1',
    );

    await repository.upsertRecord(
      CheckinRecordDraft(
        planId: plan.id,
        recordDate: DateTime.utc(2026, 7, 18),
        completedAt: DateTime.utc(2026, 7, 18, 8, 30),
      ),
      'user_1',
    );
    await repository.upsertRecord(
      CheckinRecordDraft(
        planId: plan.id,
        recordDate: DateTime.utc(2026, 7, 18),
        completedAt: DateTime.utc(2026, 7, 18, 10, 15),
      ),
      'user_1',
    );

    final records = await repository.getRecordsByDate(
      'user_1',
      DateTime.utc(2026, 7, 18),
    );
    expect(records.length, 1);
    expect(records.first.count, 2);
    expect(records.first.extraJson, contains('08:30'));
    expect(records.first.extraJson, contains('10:15'));
  });

  test('detailed plan creates one record per checkin', () async {
    final plan = await repository.createPlan(
      const CheckinPlanDraft(
        name: '喝水',
        recordGranularity: CheckinRecordGranularity.detailed,
      ),
      'user_1',
    );

    await repository.upsertRecord(
      CheckinRecordDraft(
        planId: plan.id,
        recordDate: DateTime.utc(2026, 7, 18),
        completedAt: DateTime.utc(2026, 7, 18, 8, 30),
      ),
      'user_1',
    );
    await repository.upsertRecord(
      CheckinRecordDraft(
        planId: plan.id,
        recordDate: DateTime.utc(2026, 7, 18),
        completedAt: DateTime.utc(2026, 7, 18, 10, 15),
      ),
      'user_1',
    );

    final records = await repository.getRecordsByDate(
      'user_1',
      DateTime.utc(2026, 7, 18),
    );
    expect(records.length, 2);
    expect(records.every((r) => r.count == 1), isTrue);
    expect(records.map((r) => r.completedAt).toSet().length, 2);
  });

  test('getRecordsByDate attaches plan name to records', () async {
    final plan = await repository.createPlan(
      const CheckinPlanDraft(name: '喝水'),
      'user_1',
    );
    await repository.upsertRecord(
      CheckinRecordDraft(
        planId: plan.id,
        recordDate: DateTime.utc(2026, 7, 18),
        completedAt: DateTime.utc(2026, 7, 18, 8, 30),
      ),
      'user_1',
    );

    final records = await repository.getRecordsByDate(
      'user_1',
      DateTime.utc(2026, 7, 18),
    );
    expect(records.first.plan?.name, '喝水');
  });

  group('getTodayProgress 的连续天数', () {
    Future<CheckinPlan> seededPlan() =>
        repository.createPlan(const CheckinPlanDraft(name: '喝水'), 'user_1');

    Future<void> checkInOn(CheckinPlan plan, int day) async {
      await repository.upsertRecord(
        CheckinRecordDraft(
          planId: plan.id,
          recordDate: DateTime.utc(2026, 7, day),
          completedAt: DateTime.utc(2026, 7, day, 9),
          numericValue: 1,
        ),
        'user_1',
      );
    }

    test('连续三天有记录 → streak = 3', () async {
      final plan = await seededPlan();
      await checkInOn(plan, 16);
      await checkInOn(plan, 17);
      await checkInOn(plan, 18);

      final progress = await repository.getTodayProgress(
        'user_1',
        DateTime.utc(2026, 7, 18),
      );
      expect(progress.single.streak, 3);
      // 今天那部分进度仍然只算今天的记录。
      expect(progress.single.currentValue, 1);
    });

    test('今天还没打卡：连续天数从昨天往回数，不算断', () async {
      final plan = await seededPlan();
      await checkInOn(plan, 16);
      await checkInOn(plan, 17);

      final progress = await repository.getTodayProgress(
        'user_1',
        DateTime.utc(2026, 7, 18),
      );
      expect(progress.single.streak, 2);
      expect(progress.single.currentValue, 0);
    });

    test('中间缺一天就断在那里；从没打过卡就没有 streak', () async {
      final plan = await seededPlan();
      await checkInOn(plan, 18);
      await checkInOn(plan, 17);
      await checkInOn(plan, 15);

      final progress = await repository.getTodayProgress(
        'user_1',
        DateTime.utc(2026, 7, 18),
      );
      expect(progress.single.streak, 2);

      final other = await repository.createPlan(
        const CheckinPlanDraft(name: '阅读', targetUnit: '分钟', targetValue: 30),
        'user_1',
      );
      final after = await repository.getTodayProgress(
        'user_1',
        DateTime.utc(2026, 7, 18),
      );
      expect(after.firstWhere((p) => p.plan.id == other.id).streak, isNull);
    });
  });
}
