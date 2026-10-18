import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/health/data/drift_health_repository.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/domain/health_repository.dart';

Future<void> insertHealthTestUser(AppDatabase database) async {
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
  late DriftHealthRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    var nextId = 0;
    repository = DriftHealthRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
      now: () => DateTime.utc(2026, 7, 18, 8),
      createId: () => 'health_${nextId += 1}',
    );
    await insertHealthTestUser(database);
    await repository.ensureReadyForUser('user_1');
  });

  tearDown(() async {
    await database.close();
  });

  test('watchPeriodSettings returns seeded active settings', () async {
    final settings = await repository.watchPeriodSettings('user_1').first;

    expect(settings.averageCycleLength, 28);
    expect(settings.averagePeriodLength, 5);
    expect(settings.reminderDays, 1);
    expect(settings.dataSyncEnabled, isTrue);
  });

  test('watchPeriodSettings defaults period tracking to enabled', () async {
    final settings = await repository.watchPeriodSettings('user_1').first;

    expect(settings.periodTrackingEnabled, isTrue);
  });

  test('updatePeriodSettings persists reminder and average values', () async {
    await repository.updatePeriodSettings(
      'user_1',
      const HealthPeriodSettingsDraft(
        averageCycleLength: 30,
        averagePeriodLength: 6,
        periodTrackingEnabled: true,
        periodReminderEnabled: true,
        ovulationReminderEnabled: true,
        pmsReminderEnabled: true,
        reminderDays: 2,
        dataSyncEnabled: false,
        analyticsEnabled: true,
      ),
    );

    final settings = await repository.watchPeriodSettings('user_1').first;

    expect(settings.averageCycleLength, 30);
    expect(settings.averagePeriodLength, 6);
    expect(settings.periodReminderEnabled, isTrue);
    expect(settings.ovulationReminderEnabled, isTrue);
    expect(settings.pmsReminderEnabled, isTrue);
    expect(settings.reminderDays, 2);
    expect(settings.dataSyncEnabled, isFalse);
    expect(settings.analyticsEnabled, isTrue);
  });

  test('updatePeriodSettings persists period tracking toggle', () async {
    await repository.updatePeriodSettings(
      'user_1',
      const HealthPeriodSettingsDraft(
        averageCycleLength: 28,
        averagePeriodLength: 5,
        periodTrackingEnabled: false,
        periodReminderEnabled: false,
        ovulationReminderEnabled: false,
        pmsReminderEnabled: false,
        reminderDays: 1,
        dataSyncEnabled: true,
        analyticsEnabled: false,
      ),
    );

    final settings = await repository.watchPeriodSettings('user_1').first;

    expect(settings.periodTrackingEnabled, isFalse);
  });

  test('startPeriod creates an open active period', () async {
    final period = await repository.startPeriod(
      'user_1',
      DateTime.utc(2026, 7, 16),
      notes: 'started',
    );

    expect(period.startDate, DateTime.utc(2026, 7, 16));
    expect(period.endDate, isNull);
    expect(period.notes, 'started');
  });

  test('startPeriod rejects a second open period', () async {
    await repository.startPeriod('user_1', DateTime.utc(2026, 7, 16));

    expect(
      () => repository.startPeriod('user_1', DateTime.utc(2026, 8, 10)),
      throwsA(
        isA<HealthRepositoryException>().having(
          (error) => error.code,
          'code',
          HealthRepositoryErrorCode.openPeriodExists,
        ),
      ),
    );
  });

  test('endCurrentPeriod closes the open period', () async {
    await repository.startPeriod('user_1', DateTime.utc(2026, 7, 16));

    final period = await repository.endCurrentPeriod(
      'user_1',
      DateTime.utc(2026, 7, 20),
      notes: 'ended',
    );

    expect(period.startDate, DateTime.utc(2026, 7, 16));
    expect(period.endDate, DateTime.utc(2026, 7, 20));
    expect(period.notes, 'ended');
  });

  test('endCurrentPeriod rejects end before start', () async {
    await repository.startPeriod('user_1', DateTime.utc(2026, 7, 16));

    expect(
      () => repository.endCurrentPeriod('user_1', DateTime.utc(2026, 7, 15)),
      throwsA(
        isA<HealthRepositoryException>().having(
          (error) => error.code,
          'code',
          HealthRepositoryErrorCode.invalidDateRange,
        ),
      ),
    );
  });
  test('upsertDailyLog creates and updates one active row per date', () async {
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        flowLevel: HealthFlowLevel.medium,
      ),
    );
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        flowLevel: HealthFlowLevel.heavy,
        mood: HealthMood.anxious,
      ),
    );

    final rows =
        await (database.select(database.healthPeriodDailyRecords)..where(
              (row) =>
                  row.userId.equals('user_1') & row.isDeleted.equals(false),
            ))
            .get();

    expect(rows, hasLength(1));
    expect(rows.single.flowLevel, 'Heavy');
    expect(rows.single.mood, 'Anxious');
  });

  test('upsertDailyLog links dates inside an active period', () async {
    final period = await repository.startPeriod(
      'user_1',
      DateTime.utc(2026, 7, 16),
    );

    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        flowLevel: HealthFlowLevel.light,
      ),
    );

    final rows = await database.select(database.healthPeriodDailyRecords).get();
    final log = await repository
        .watchDailyLog('user_1', DateTime.utc(2026, 7, 18))
        .first;

    expect(rows.single.periodRecordId, period.id);
    expect(log.flowLevel, HealthFlowLevel.light);
  });

  test('upsertDailyLog replaces symptoms for the date', () async {
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        symptoms: const [
          HealthSymptomLog(
            id: null,
            type: HealthSymptomType.pain,
            intensity: HealthIntensity.light,
            notes: null,
          ),
          HealthSymptomLog(
            id: null,
            type: HealthSymptomType.fatigue,
            intensity: HealthIntensity.medium,
            notes: null,
          ),
        ],
      ),
    );
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        symptoms: const [
          HealthSymptomLog(
            id: null,
            type: HealthSymptomType.pain,
            intensity: HealthIntensity.heavy,
            notes: null,
          ),
        ],
      ),
    );

    final activeSymptoms =
        await (database.select(database.healthPeriodSymptoms)..where(
              (row) =>
                  row.userId.equals('user_1') & row.isDeleted.equals(false),
            ))
            .get();

    expect(activeSymptoms, hasLength(1));
    expect(activeSymptoms.single.symptomType, 'Pain');
    expect(activeSymptoms.single.intensity, 'Heavy');
  });

  test('upsertDailyLog stores one ovulation test per date', () async {
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        ovulationTest: HealthOvulationTestLog(
          id: null,
          testDate: DateTime.utc(2026, 7, 18),
          result: HealthOvulationTestResult.positive,
          lineIntensity: HealthTestLineIntensity.medium,
          notes: 'first',
        ),
      ),
    );
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        ovulationTest: HealthOvulationTestLog(
          id: null,
          testDate: DateTime.utc(2026, 7, 18),
          result: HealthOvulationTestResult.peak,
          lineIntensity: HealthTestLineIntensity.high,
          notes: 'updated',
        ),
      ),
    );

    final rows =
        await (database.select(database.healthOvulationTestRecords)..where(
              (row) =>
                  row.userId.equals('user_1') & row.isDeleted.equals(false),
            ))
            .get();

    expect(rows, hasLength(1));
    expect(rows.single.result, 'Peak');
    expect(rows.single.testLineIntensity, 'High');
    expect(rows.single.notes, 'updated');
  });

  test(
    'watchDailyLog returns an empty log for a date without records',
    () async {
      final log = await repository
          .watchDailyLog('user_1', DateTime.utc(2026, 7, 18))
          .first;

      expect(log.id, isNull);
      expect(log.date, DateTime.utc(2026, 7, 18));
      expect(log.flowLevel, isNull);
      expect(log.symptoms, isEmpty);
    },
  );
  test('watchDailyLog refreshes when child symptoms change', () async {
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(date: DateTime.utc(2026, 7, 18)),
    );
    final dailyRow = await database
        .select(database.healthPeriodDailyRecords)
        .getSingle();

    final events = <HealthDailyLog>[];
    final subscription = repository
        .watchDailyLog('user_1', DateTime.utc(2026, 7, 18))
        .listen(events.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    events.clear();

    final now = DateTime.utc(2026, 7, 18, 8);
    await database
        .into(database.healthPeriodSymptoms)
        .insert(
          HealthPeriodSymptomsCompanion.insert(
            id: 'manual_symptom_1',
            userId: 'user_1',
            dailyRecordId: dailyRow.id,
            symptomType: 'Pain',
            intensity: const Value('Heavy'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final refreshed =
        await Stream.periodic(const Duration(milliseconds: 10), (_) => events)
            .where((logs) => logs.any((log) => log.symptoms.isNotEmpty))
            .first
            .timeout(const Duration(seconds: 1));

    expect(refreshed.last.symptoms.single.type, HealthSymptomType.pain);
  });
  test('startPregnancyMode creates one active pregnancy', () async {
    final pregnancy = await repository.startPregnancyMode(
      'user_1',
      HealthPregnancyDraft(
        startDate: DateTime.utc(2026, 7, 1),
        dueDate: DateTime.utc(2027, 4, 7),
        notes: 'started',
      ),
    );

    expect(pregnancy.status, HealthPregnancyRecordStatus.active);
    expect(pregnancy.startDate, DateTime.utc(2026, 7, 1));
    expect(pregnancy.dueDate, DateTime.utc(2027, 4, 7));
  });

  test('endPregnancyMode closes active pregnancy', () async {
    await repository.startPregnancyMode(
      'user_1',
      HealthPregnancyDraft(
        startDate: DateTime.utc(2026, 7, 1),
        dueDate: DateTime.utc(2027, 4, 7),
        notes: null,
      ),
    );

    final pregnancy = await repository.endPregnancyMode(
      'user_1',
      HealthPregnancyEndDraft(
        endDate: DateTime.utc(2027, 4, 3),
        status: HealthPregnancyRecordStatus.completed,
        notes: 'completed',
      ),
    );

    expect(pregnancy.status, HealthPregnancyRecordStatus.completed);
    expect(pregnancy.endDate, DateTime.utc(2027, 4, 3));
  });

  test(
    'upsertMedicationLog creates and updates light medication log',
    () async {
      final created = await repository.upsertMedicationLog(
        'user_1',
        medicationDraft(
          name: 'Iron',
          dosage: '10mg',
          frequency: HealthMedicationFrequency.daily,
          startDate: DateTime.utc(2026, 7, 18),
        ),
      );

      final updated = await repository.upsertMedicationLog(
        'user_1',
        medicationDraft(
          id: created.id,
          name: 'Iron',
          dosage: '20mg',
          frequency: HealthMedicationFrequency.daily,
          startDate: DateTime.utc(2026, 7, 18),
        ),
      );

      final rows =
          await (database.select(database.healthMedicationRecords)..where(
                (row) =>
                    row.userId.equals('user_1') & row.isDeleted.equals(false),
              ))
              .get();

      expect(updated.id, created.id);
      expect(updated.dosage, '20mg');
      expect(rows, hasLength(1));
    },
  );
  test('watchTodaySnapshot combines prediction and daily log', () async {
    await repository.startPeriod('user_1', DateTime.utc(2026, 7, 16));
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(
        date: DateTime.utc(2026, 7, 18),
        flowLevel: HealthFlowLevel.medium,
      ),
    );

    final snapshot = await repository
        .watchTodaySnapshot('user_1', DateTime.utc(2026, 7, 18))
        .first;

    expect(snapshot.prediction.statusKind, HealthTodayStatusKind.periodDay);
    expect(snapshot.activePeriod?.startDate, DateTime.utc(2026, 7, 16));
    expect(snapshot.dailyLog.flowLevel, HealthFlowLevel.medium);
  });

  test(
    'listCalendarMarkers includes actual period and daily log markers',
    () async {
      await repository.startPeriod('user_1', DateTime.utc(2026, 7, 16));
      await repository.endCurrentPeriod('user_1', DateTime.utc(2026, 7, 20));
      await repository.upsertDailyLog(
        'user_1',
        dailyDraft(date: DateTime.utc(2026, 7, 18)),
      );

      final markers = await repository
          .listCalendarMarkers(
            'user_1',
            DateTimeRange(
              start: DateTime.utc(2026, 7),
              end: DateTime.utc(2026, 8, 31),
            ),
          )
          .first;

      expect(
        markers.where(
          (marker) => marker.kind == HealthCalendarMarkerKind.actualPeriod,
        ),
        isNotEmpty,
      );
      expect(
        markers.where(
          (marker) => marker.kind == HealthCalendarMarkerKind.dailyLog,
        ),
        isNotEmpty,
      );
    },
  );

  Future<void> insertCompletedPeriod(DateTime start, DateTime end) async {
    await repository.startPeriod('user_1', start);
    await repository.endCurrentPeriod('user_1', end);
  }

  test('watchTrendSummary defaults to latest 3 completed periods', () async {
    await insertCompletedPeriod(
      DateTime.utc(2026, 4, 1),
      DateTime.utc(2026, 4, 5),
    );
    await insertCompletedPeriod(
      DateTime.utc(2026, 4, 29),
      DateTime.utc(2026, 5, 3),
    );
    await insertCompletedPeriod(
      DateTime.utc(2026, 5, 27),
      DateTime.utc(2026, 5, 31),
    );
    await insertCompletedPeriod(
      DateTime.utc(2026, 6, 24),
      DateTime.utc(2026, 6, 28),
    );

    final summary = await repository.watchTrendSummary('user_1').first;

    expect(summary.recentPeriods.map((p) => p.startDate), [
      DateTime.utc(2026, 4, 29),
      DateTime.utc(2026, 5, 27),
      DateTime.utc(2026, 6, 24),
    ]);
    expect(summary.cycleLengthSeries.map((p) => p.value), [28, 28, 28]);
    expect(summary.periodDurationSeries.map((p) => p.value), [5, 5, 5]);
  });

  test('watchTrendSummary filters selected periods by start date', () async {
    await insertCompletedPeriod(
      DateTime.utc(2026, 4, 1),
      DateTime.utc(2026, 4, 5),
    );
    await insertCompletedPeriod(
      DateTime.utc(2026, 5, 1),
      DateTime.utc(2026, 5, 5),
    );
    await insertCompletedPeriod(
      DateTime.utc(2026, 6, 1),
      DateTime.utc(2026, 6, 5),
    );

    final summary = await repository
        .watchTrendSummary(
          'user_1',
          query: HealthTrendQuery(startDate: DateTime.utc(2026, 5, 1)),
        )
        .first;

    expect(summary.recentPeriods.map((p) => p.startDate), [
      DateTime.utc(2026, 5, 1),
      DateTime.utc(2026, 6, 1),
    ]);
    expect(summary.rangeStart, DateTime.utc(2026, 5, 1));
  });

  test('watchTrendSummary aggregates daily logs by selected phase', () async {
    await insertCompletedPeriod(
      DateTime.utc(2026, 6, 10),
      DateTime.utc(2026, 6, 14),
    );
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(date: DateTime.utc(2026, 6, 11), mood: HealthMood.calm),
    );
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(date: DateTime.utc(2026, 6, 3), mood: HealthMood.anxious),
    );

    final periodSummary = await repository
        .watchTrendSummary(
          'user_1',
          query: const HealthTrendQuery(phase: HealthTrendPhase.period),
        )
        .first;
    final pmsSummary = await repository
        .watchTrendSummary(
          'user_1',
          query: const HealthTrendQuery(phase: HealthTrendPhase.pms),
        )
        .first;

    expect(periodSummary.moodDistribution.single.value, HealthMood.calm);
    expect(pmsSummary.moodDistribution.single.value, HealthMood.anxious);
  });

  test(
    'watchTrendSummary keeps daily stats only when period tracking is disabled',
    () async {
      await repository.updatePeriodSettings(
        'user_1',
        const HealthPeriodSettingsDraft(
          averageCycleLength: 28,
          averagePeriodLength: 5,
          periodTrackingEnabled: false,
          periodReminderEnabled: false,
          ovulationReminderEnabled: false,
          pmsReminderEnabled: false,
          reminderDays: 1,
          dataSyncEnabled: true,
          analyticsEnabled: false,
        ),
      );
      await insertCompletedPeriod(
        DateTime.utc(2026, 7, 10),
        DateTime.utc(2026, 7, 14),
      );
      await repository.upsertDailyLog(
        'user_1',
        dailyDraft(
          date: DateTime.utc(2026, 7, 11),
          flowLevel: HealthFlowLevel.medium,
          mood: HealthMood.calm,
        ),
      );

      final summary = await repository.watchTrendSummary('user_1').first;

      expect(summary.periodTrackingEnabled, isFalse);
      expect(summary.recentPeriods, isEmpty);
      expect(summary.cycleLengthSeries, isEmpty);
      expect(summary.periodDurationSeries, isEmpty);
      expect(summary.flowDistribution, isEmpty);
      expect(summary.pmsSymptomDistribution, isEmpty);
      expect(summary.moodDistribution.single.value, HealthMood.calm);
    },
  );

  test('watchTrendSummary reports cycle lengths and coverage', () async {
    await repository.startPeriod('user_1', DateTime.utc(2026, 6, 2));
    await repository.endCurrentPeriod('user_1', DateTime.utc(2026, 6, 6));
    await repository.startPeriod('user_1', DateTime.utc(2026, 6, 30));
    await repository.endCurrentPeriod('user_1', DateTime.utc(2026, 7, 4));
    await repository.upsertDailyLog(
      'user_1',
      dailyDraft(date: DateTime.utc(2026, 7, 18)),
    );

    final summary = await repository.watchTrendSummary('user_1').first;

    expect(summary.cycleLengths, [28]);
    expect(summary.periodDurations, [5, 5]);
    expect(summary.loggedDaysInLast30Days, 1);
    expect(summary.predictionBasis, HealthPredictionBasis.history);
  });
}

HealthDailyLogDraft dailyDraft({
  required DateTime date,
  HealthFlowLevel? flowLevel,
  List<HealthSymptomLog> symptoms = const [],
  HealthMood? mood,
  HealthOvulationTestLog? ovulationTest,
}) {
  return HealthDailyLogDraft(
    date: date,
    flowLevel: flowLevel,
    symptoms: symptoms,
    mood: mood,
    exerciseIntensity: null,
    sexualActivity: null,
    contraceptionMethod: null,
    ovulationTest: ovulationTest,
    medications: const [],
    diet: null,
    waterIntake: null,
    sleepMinutes: null,
    weightGrams: null,
    temperatureCelsiusTenths: null,
    stressLevel: null,
    calories: null,
    notes: null,
  );
}

HealthMedicationDraft medicationDraft({
  String? id,
  required String name,
  required String dosage,
  required HealthMedicationFrequency frequency,
  required DateTime startDate,
}) {
  return HealthMedicationDraft(
    id: id,
    name: name,
    dosage: dosage,
    frequency: frequency,
    startDate: startDate,
    endDate: null,
    notes: null,
    periodRecordId: null,
  );
}
