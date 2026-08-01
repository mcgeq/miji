import 'package:flutter/material.dart';
import 'package:miji/features/health/domain/health_models.dart';

abstract class HealthRepository {
  Future<void> ensureReadyForUser(String userId);

  Future<int> countPeriodRecordsForUser(String userId);

  Future<int> countDailyRecordsForUser(String userId);

  Stream<HealthPeriodSettingsModel> watchPeriodSettings(String userId);

  Future<void> updatePeriodSettings(
    String userId,
    HealthPeriodSettingsDraft draft,
  );

  Stream<HealthTodaySnapshot> watchTodaySnapshot(String userId, DateTime date);

  Stream<HealthDailyLog> watchDailyLog(String userId, DateTime date);

  Future<void> upsertDailyLog(String userId, HealthDailyLogDraft draft);

  Future<HealthPeriodRecordModel> startPeriod(
    String userId,
    DateTime startDate, {
    String? notes,
  });

  Future<HealthPeriodRecordModel> endCurrentPeriod(
    String userId,
    DateTime endDate, {
    String? notes,
  });

  Stream<List<HealthCalendarMarker>> listCalendarMarkers(
    String userId,
    DateTimeRange range,
  );

  Stream<HealthTrendSummary> watchTrendSummary(
    String userId, {
    HealthTrendQuery query = const HealthTrendQuery(),
  });

  Future<HealthPregnancyStatus> startPregnancyMode(
    String userId,
    HealthPregnancyDraft draft,
  );

  Future<HealthPregnancyStatus> endPregnancyMode(
    String userId,
    HealthPregnancyEndDraft draft,
  );

  Future<void> cancelPregnancyMode(String userId);

  Future<HealthMedicationLog> upsertMedicationLog(
    String userId,
    HealthMedicationDraft draft,
  );
}

enum HealthRepositoryErrorCode {
  databaseReadFailed,
  databaseWriteFailed,
  invalidDateRange,
  duplicatePeriodStart,
  openPeriodExists,
  openPeriodNotFound,
  activePregnancyExists,
  activePregnancyNotFound,
  invalidPregnancyEndStatus,
}

class HealthRepositoryException implements Exception {
  const HealthRepositoryException(this.code, [this.cause]);

  final HealthRepositoryErrorCode code;
  final Object? cause;

  @override
  String toString() {
    return 'HealthRepositoryException($code, cause: $cause)';
  }
}
