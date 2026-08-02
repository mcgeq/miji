import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
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
}
