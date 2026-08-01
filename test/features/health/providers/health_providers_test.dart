import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/domain/health_repository.dart';
import 'package:miji/features/health/providers/health_providers.dart';

void main() {
  test(
    'currentUserHealthTodaySnapshotProvider returns null when locked',
    () async {
      final repository = _FakeHealthRepository();
      final container = _container(
        repository: repository,
        session: const AuthSession.locked(),
      );
      addTearDown(container.dispose);

      final snapshot = await container.read(
        currentUserHealthTodaySnapshotProvider.future,
      );

      expect(snapshot, isNull);
      expect(repository.ensureReadyCalls, isEmpty);
    },
  );

  test(
    'currentUserHealthTodaySnapshotProvider reads unlocked user snapshot',
    () async {
      final today = DateTime.utc(2026, 7, 18);
      final repository = _FakeHealthRepository()
        ..todaySnapshot = _snapshot(today);
      final container = _container(
        repository: repository,
        session: const AuthSession(userId: 'user_1', isUnlocked: true),
      );
      addTearDown(container.dispose);
      container.read(healthTodayDateProvider.notifier).set(today);

      final snapshot = await container.read(
        currentUserHealthTodaySnapshotProvider.future,
      );
      expect(snapshot?.date.year, 2026);
      expect(snapshot?.date.month, 7);
      expect(snapshot?.date.day, 18);
      expect(repository.ensureReadyCalls, ['user_1']);
      expect(repository.todaySnapshotRequests.single.userId, 'user_1');
      expect(repository.todaySnapshotRequests.single.date.year, 2026);
      expect(repository.todaySnapshotRequests.single.date.month, 7);
      expect(repository.todaySnapshotRequests.single.date.day, 18);
    },
  );

  test(
    'HealthWriteController upsertDailyLog writes for unlocked user',
    () async {
      final today = DateTime.utc(2026, 7, 18);
      final repository = _FakeHealthRepository();
      final container = _container(
        repository: repository,
        session: const AuthSession(userId: 'user_1', isUnlocked: true),
      );
      addTearDown(container.dispose);

      final draft = _dailyDraft(today);
      await container
          .read(currentUserHealthWriteControllerProvider)
          .upsertDailyLog(draft);

      expect(repository.upsertDailyLogRequests.single.userId, 'user_1');
      expect(repository.upsertDailyLogRequests.single.draft, same(draft));
    },
  );
  test(
    'currentUserHealthTrendSummaryProvider passes selected trend query',
    () async {
      final repository = _FakeHealthRepository();
      final container = _container(
        repository: repository,
        session: const AuthSession(userId: 'user_1', isUnlocked: true),
      );
      addTearDown(container.dispose);

      container
          .read(healthTrendStartDateProvider.notifier)
          .set(DateTime.utc(2026, 5, 1));
      container
          .read(healthTrendPhaseProvider.notifier)
          .set(HealthTrendPhase.pms);

      await container.read(currentUserHealthTrendSummaryProvider.future);

      expect(repository.trendSummaryRequests.single.userId, 'user_1');
      expect(
        repository.trendSummaryRequests.single.query.startDate,
        DateTime.utc(2026, 5, 1),
      );
      expect(
        repository.trendSummaryRequests.single.query.phase,
        HealthTrendPhase.pms,
      );
    },
  );
}

ProviderContainer _container({
  required _FakeHealthRepository repository,
  required AuthSession session,
}) {
  return ProviderContainer(
    overrides: [
      healthRepositoryProvider.overrideWithValue(repository),
      authSessionControllerProvider.overrideWith(
        () => _TestAuthSessionController(session),
      ),
    ],
  );
}

HealthPeriodSettingsModel get _settings {
  return const HealthPeriodSettingsModel(
    averageCycleLength: 28,
    averagePeriodLength: 5,
    periodTrackingEnabled: true,
    periodReminderEnabled: true,
    ovulationReminderEnabled: true,
    pmsReminderEnabled: true,
    reminderDays: 1,
    dataSyncEnabled: true,
    analyticsEnabled: false,
  );
}

HealthTodaySnapshot _snapshot(DateTime date) {
  return HealthTodaySnapshot(
    date: date,
    settings: _settings,
    prediction: const HealthCyclePrediction.noHistory(mainStatus: ''),
    activePeriod: null,
    dailyLog: HealthDailyLog.empty(date),
    activePregnancy: null,
  );
}

HealthDailyLogDraft _dailyDraft(DateTime date) {
  return HealthDailyLogDraft(
    date: date,
    flowLevel: HealthFlowLevel.medium,
    symptoms: const [],
    mood: null,
    exerciseIntensity: null,
    sexualActivity: null,
    contraceptionMethod: null,
    ovulationTest: null,
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

class _TestAuthSessionController extends AuthSessionController {
  _TestAuthSessionController(this._session);

  final AuthSession _session;

  @override
  AuthSession build() {
    return _session;
  }
}

class _FakeHealthRepository implements HealthRepository {
  final ensureReadyCalls = <String>[];
  final todaySnapshotRequests = <_DatedRequest>[];
  final upsertDailyLogRequests = <_DailyLogWrite>[];
  final trendSummaryRequests = <_TrendSummaryRequest>[];

  HealthTodaySnapshot? todaySnapshot;

  @override
  Future<void> ensureReadyForUser(String userId) async {
    ensureReadyCalls.add(userId);
  }

  @override
  Future<int> countPeriodRecordsForUser(String userId) async {
    return 0;
  }

  @override
  Future<int> countDailyRecordsForUser(String userId) async {
    return 0;
  }

  @override
  Stream<HealthPeriodSettingsModel> watchPeriodSettings(String userId) {
    return Stream.value(_settings);
  }

  @override
  Future<void> updatePeriodSettings(
    String userId,
    HealthPeriodSettingsDraft draft,
  ) async {}

  @override
  Stream<HealthTodaySnapshot> watchTodaySnapshot(String userId, DateTime date) {
    todaySnapshotRequests.add(_DatedRequest(userId, date));
    return Stream.value(todaySnapshot ?? _snapshot(date));
  }

  @override
  Stream<HealthDailyLog> watchDailyLog(String userId, DateTime date) {
    return Stream.value(HealthDailyLog.empty(date));
  }

  @override
  Future<void> upsertDailyLog(String userId, HealthDailyLogDraft draft) async {
    upsertDailyLogRequests.add(_DailyLogWrite(userId, draft));
  }

  @override
  Future<HealthPeriodRecordModel> startPeriod(
    String userId,
    DateTime startDate, {
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HealthPeriodRecordModel> endCurrentPeriod(
    String userId,
    DateTime endDate, {
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<List<HealthCalendarMarker>> listCalendarMarkers(
    String userId,
    DateTimeRange range,
  ) {
    return Stream.value(const []);
  }

  @override
  Stream<HealthTrendSummary> watchTrendSummary(
    String userId, {
    HealthTrendQuery query = const HealthTrendQuery(),
  }) {
    trendSummaryRequests.add(_TrendSummaryRequest(userId, query));
    return Stream.value(
      HealthTrendSummary(
        cycleLengths: const [],
        periodDurations: const [],
        recentPeriods: const [],
        loggedDaysInLast30Days: 0,
        predictionBasis: HealthPredictionBasis.settings,
        query: query,
        periodTrackingEnabled: true,
        rangeStart: DateTime.utc(2026, 7, 18),
        rangeEnd: DateTime.utc(2026, 7, 18),
        cycleLengthSeries: const [],
        periodDurationSeries: const [],
        flowDistribution: const [],
        moodDistribution: const [],
        symptomDistribution: const [],
        exerciseDistribution: const [],
        healthMetrics: const HealthTrendMetricAverages(loggedDays: 0),
        pmsSymptomDistribution: const [],
        completeness: const HealthTrendCompleteness(
          expectedDays: 0,
          loggedDays: 0,
          moodDays: 0,
          symptomDays: 0,
          metricDays: 0,
        ),
      ),
    );
  }

  @override
  Future<HealthPregnancyStatus> startPregnancyMode(
    String userId,
    HealthPregnancyDraft draft,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<HealthPregnancyStatus> endPregnancyMode(
    String userId,
    HealthPregnancyEndDraft draft,
  ) async {
    return todaySnapshot!.activePregnancy!;
  }

  @override
  Future<void> cancelPregnancyMode(String userId) async {}

  @override
  Future<HealthMedicationLog> upsertMedicationLog(
    String userId,
    HealthMedicationDraft draft,
  ) {
    throw UnimplementedError();
  }
}

class _DatedRequest {
  const _DatedRequest(this.userId, this.date);

  final String userId;
  final DateTime date;
}

class _TrendSummaryRequest {
  const _TrendSummaryRequest(this.userId, this.query);

  final String userId;
  final HealthTrendQuery query;
}

class _DailyLogWrite {
  const _DailyLogWrite(this.userId, this.draft);

  final String userId;
  final HealthDailyLogDraft draft;
}
