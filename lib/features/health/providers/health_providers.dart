import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/features/health/data/drift_health_repository.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/domain/health_repository.dart';

class HealthSummary {
  const HealthSummary({
    required this.periodRecordCount,
    required this.dailyRecordCount,
  });

  const HealthSummary.empty() : periodRecordCount = 0, dailyRecordCount = 0;

  final int periodRecordCount;
  final int dailyRecordCount;
}

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return DriftHealthRepository(
    database: ref.watch(appDatabaseProvider),
    seedRunner: ref.watch(databaseSeedRunnerProvider),
  );
});

final healthTodayDateProvider =
    NotifierProvider<HealthTodayDateController, DateTime>(
      HealthTodayDateController.new,
    );

class HealthTodayDateController extends Notifier<DateTime> {
  @override
  DateTime build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return DateUtils.dateOnly(DateTime.now().toUtc());
  }

  void set(DateTime value) {
    state = DateUtils.dateOnly(value.toUtc());
  }
}

final healthTrendStartDateProvider =
    NotifierProvider<HealthTrendStartDateController, DateTime?>(
      HealthTrendStartDateController.new,
    );

class HealthTrendStartDateController extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return null;
  }

  void set(DateTime? value) {
    state = value == null ? null : HealthDate.dateOnly(value.toUtc());
  }
}

final healthTrendPhaseProvider =
    NotifierProvider<HealthTrendPhaseController, HealthTrendPhase>(
      HealthTrendPhaseController.new,
    );

class HealthTrendPhaseController extends Notifier<HealthTrendPhase> {
  @override
  HealthTrendPhase build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return HealthTrendPhase.all;
  }

  void set(HealthTrendPhase value) {
    state = value;
  }
}

final currentUserHealthSummaryProvider = FutureProvider<HealthSummary>((
  ref,
) async {
  final userId = await _currentUnlockedHealthUserId(ref);
  if (userId == null) {
    return const HealthSummary.empty();
  }

  final repository = ref.watch(healthRepositoryProvider);
  return HealthSummary(
    periodRecordCount: await repository.countPeriodRecordsForUser(userId),
    dailyRecordCount: await repository.countDailyRecordsForUser(userId),
  );
});

final currentUserHealthTodaySnapshotProvider =
    FutureProvider<HealthTodaySnapshot?>((ref) async {
      final userId = await _currentUnlockedHealthUserId(ref);
      if (userId == null) {
        return null;
      }

      final date = ref.watch(healthTodayDateProvider);
      return ref
          .watch(healthRepositoryProvider)
          .watchTodaySnapshot(userId, date)
          .first;
    });

final currentUserHealthDailyLogProvider =
    FutureProvider.family<HealthDailyLog?, DateTime>((ref, date) async {
      final userId = await _currentUnlockedHealthUserId(ref);
      if (userId == null) {
        return null;
      }

      return ref
          .watch(healthRepositoryProvider)
          .watchDailyLog(userId, date)
          .first;
    });

final currentUserHealthCalendarMarkersProvider =
    FutureProvider.family<List<HealthCalendarMarker>, DateTimeRange>((
      ref,
      range,
    ) async {
      final userId = await _currentUnlockedHealthUserId(ref);
      if (userId == null) {
        return const <HealthCalendarMarker>[];
      }

      return ref
          .watch(healthRepositoryProvider)
          .listCalendarMarkers(userId, range)
          .first;
    });

final currentUserHealthTrendSummaryProvider =
    FutureProvider<HealthTrendSummary?>((ref) async {
      final userId = await _currentUnlockedHealthUserId(ref);
      if (userId == null) {
        return null;
      }

      final query = HealthTrendQuery(
        startDate: ref.watch(healthTrendStartDateProvider),
        phase: ref.watch(healthTrendPhaseProvider),
      );
      return ref
          .watch(healthRepositoryProvider)
          .watchTrendSummary(userId, query: query)
          .first;
    });

final currentUserHealthPeriodSettingsProvider =
    FutureProvider<HealthPeriodSettingsModel?>((ref) async {
      final userId = await _currentUnlockedHealthUserId(ref);
      if (userId == null) {
        return null;
      }

      return ref
          .watch(healthRepositoryProvider)
          .watchPeriodSettings(userId)
          .first;
    });

final currentUserActivePregnancyProvider = Provider<HealthPregnancyStatus?>((
  ref,
) {
  final snapshot = ref.watch(currentUserHealthTodaySnapshotProvider);
  return snapshot.value?.activePregnancy;
});

final currentUserHealthWriteControllerProvider =
    Provider<HealthWriteController>((ref) {
      return HealthWriteController(ref);
    });

Future<String?> _currentUnlockedHealthUserId(Ref ref) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (!session.isUnlocked || userId == null || userId.isEmpty) {
    return null;
  }

  await ref.watch(healthRepositoryProvider).ensureReadyForUser(userId);
  return userId;
}

class HealthWriteController {
  const HealthWriteController(this._ref);

  final Ref _ref;

  Future<void> upsertDailyLog(HealthDailyLogDraft draft) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return;
    }

    await _ref.read(healthRepositoryProvider).upsertDailyLog(userId, draft);
    _refreshAfterWrite();
  }

  Future<HealthPeriodRecordModel?> startPeriod(
    DateTime startDate, {
    String? notes,
  }) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return null;
    }

    final period = await _ref
        .read(healthRepositoryProvider)
        .startPeriod(userId, startDate, notes: notes);
    _refreshAfterWrite();
    return period;
  }

  Future<HealthPeriodRecordModel?> endPeriod(
    DateTime endDate, {
    String? notes,
  }) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return null;
    }

    final period = await _ref
        .read(healthRepositoryProvider)
        .endCurrentPeriod(userId, endDate, notes: notes);
    _refreshAfterWrite();
    return period;
  }

  Future<void> updatePeriodSettings(HealthPeriodSettingsDraft draft) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return;
    }

    await _ref
        .read(healthRepositoryProvider)
        .updatePeriodSettings(userId, draft);
    _refreshAfterWrite();
  }

  Future<HealthPregnancyStatus?> startPregnancyMode(
    HealthPregnancyDraft draft,
  ) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return null;
    }

    final pregnancy = await _ref
        .read(healthRepositoryProvider)
        .startPregnancyMode(userId, draft);
    _refreshAfterWrite();
    return pregnancy;
  }

  Future<HealthPregnancyStatus?> endPregnancyMode(
    HealthPregnancyEndDraft draft,
  ) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return null;
    }

    final pregnancy = await _ref
        .read(healthRepositoryProvider)
        .endPregnancyMode(userId, draft);
    _refreshAfterWrite();
    return pregnancy;
  }

  Future<void> cancelPregnancyMode() async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return;
    }

    await _ref.read(healthRepositoryProvider).cancelPregnancyMode(userId);
    _refreshAfterWrite();
  }

  Future<HealthMedicationLog?> upsertMedicationLog(
    HealthMedicationDraft draft,
  ) async {
    final userId = _currentUnlockedUserIdOrNull();
    if (userId == null) {
      return null;
    }

    final medication = await _ref
        .read(healthRepositoryProvider)
        .upsertMedicationLog(userId, draft);
    _refreshAfterWrite();
    return medication;
  }

  String? _currentUnlockedUserIdOrNull() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null || userId.isEmpty) {
      return null;
    }

    return userId;
  }

  void _refreshAfterWrite() {
    _ref.invalidate(currentUserHealthSummaryProvider);
    _ref.invalidate(currentUserHealthTodaySnapshotProvider);
    _ref.invalidate(currentUserHealthDailyLogProvider);
    _ref.invalidate(currentUserHealthCalendarMarkersProvider);
    _ref.invalidate(currentUserHealthTrendSummaryProvider);
    _ref.invalidate(currentUserHealthPeriodSettingsProvider);
  }
}
