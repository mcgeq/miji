import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';
import 'package:miji/features/health/domain/health_prediction_service.dart';
import 'package:miji/features/health/domain/health_repository.dart';

class DriftHealthRepository implements HealthRepository {
  DriftHealthRepository({
    required this.database,
    required this.seedRunner,
    DateTime Function()? now,
    String Function()? createId,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _createId = createId ?? const Uuid().v4;

  final AppDatabase database;
  final DatabaseSeedRunner seedRunner;
  final DateTime Function() _now;
  final String Function() _createId;

  @override
  Future<void> ensureReadyForUser(String userId) async {
    try {
      await seedRunner.seedUserDefaults(userId);
    } catch (error) {
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<int> countPeriodRecordsForUser(String userId) async {
    try {
      final count = database.healthPeriodRecords.id.count();
      final query = database.selectOnly(database.healthPeriodRecords)
        ..addColumns([count])
        ..where(
          database.healthPeriodRecords.userId.equals(userId) &
              database.healthPeriodRecords.isDeleted.equals(false),
        );

      return (await query.getSingle()).read(count) ?? 0;
    } catch (error) {
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<int> countDailyRecordsForUser(String userId) async {
    try {
      final count = database.healthPeriodDailyRecords.id.count();
      final query = database.selectOnly(database.healthPeriodDailyRecords)
        ..addColumns([count])
        ..where(
          database.healthPeriodDailyRecords.userId.equals(userId) &
              database.healthPeriodDailyRecords.isDeleted.equals(false),
        );

      return (await query.getSingle()).read(count) ?? 0;
    } catch (error) {
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Stream<HealthPeriodSettingsModel> watchPeriodSettings(String userId) {
    final query = database.select(database.healthPeriodSettings)
      ..where(
        (setting) =>
            setting.userId.equals(userId) & setting.isDeleted.equals(false),
      )
      ..limit(1);
    return query.watchSingle().map(_mapSettings);
  }

  @override
  Future<void> updatePeriodSettings(
    String userId,
    HealthPeriodSettingsDraft draft,
  ) async {
    try {
      final setting = await _activeSettingsForUser(userId);
      final now = _now();
      await (database.update(
        database.healthPeriodSettings,
      )..where((row) => row.id.equals(setting.id))).write(
        HealthPeriodSettingsCompanion(
          averageCycleLength: Value(draft.averageCycleLength),
          averagePeriodLength: Value(draft.averagePeriodLength),
          periodTrackingEnabled: Value(draft.periodTrackingEnabled),
          periodReminderEnabled: Value(draft.periodReminderEnabled),
          ovulationReminderEnabled: Value(draft.ovulationReminderEnabled),
          pmsReminderEnabled: Value(draft.pmsReminderEnabled),
          reminderDays: Value(draft.reminderDays),
          dataSyncEnabled: Value(draft.dataSyncEnabled),
          analyticsEnabled: Value(draft.analyticsEnabled),
          version: Value(setting.version + 1),
          updatedAt: Value(now),
        ),
      );
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<HealthPeriodRecordModel> startPeriod(
    String userId,
    DateTime startDate, {
    String? notes,
  }) async {
    try {
      return await database.transaction(() async {
        final existingOpen = await _openPeriodForUser(userId);
        if (existingOpen != null) {
          throw const HealthRepositoryException(
            HealthRepositoryErrorCode.openPeriodExists,
          );
        }

        final startKey = HealthDate.dayKey(startDate);
        final duplicateStart =
            await (database.select(database.healthPeriodRecords)
                  ..where(
                    (row) =>
                        row.userId.equals(userId) &
                        row.startDate.equals(startKey) &
                        row.isDeleted.equals(false),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (duplicateStart != null) {
          throw const HealthRepositoryException(
            HealthRepositoryErrorCode.duplicatePeriodStart,
          );
        }

        final now = _now();
        final id = _createId();
        await database
            .into(database.healthPeriodRecords)
            .insert(
              HealthPeriodRecordsCompanion.insert(
                id: id,
                userId: userId,
                startDate: startKey,
                notes: Value(notes),
                createdAt: now,
                updatedAt: now,
              ),
            );
        final row = await (database.select(
          database.healthPeriodRecords,
        )..where((period) => period.id.equals(id))).getSingle();
        return _mapPeriod(row);
      });
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<HealthPeriodRecordModel> endCurrentPeriod(
    String userId,
    DateTime endDate, {
    String? notes,
  }) async {
    try {
      return await database.transaction(() async {
        final openPeriod = await _openPeriodForUser(userId);
        if (openPeriod == null) {
          throw const HealthRepositoryException(
            HealthRepositoryErrorCode.openPeriodNotFound,
          );
        }

        final endKey = HealthDate.dayKey(endDate);
        if (endKey < openPeriod.startDate) {
          throw const HealthRepositoryException(
            HealthRepositoryErrorCode.invalidDateRange,
          );
        }

        final now = _now();
        await (database.update(
          database.healthPeriodRecords,
        )..where((row) => row.id.equals(openPeriod.id))).write(
          HealthPeriodRecordsCompanion(
            endDate: Value(endKey),
            notes: Value(notes ?? openPeriod.notes),
            version: Value(openPeriod.version + 1),
            updatedAt: Value(now),
          ),
        );
        final row = await (database.select(
          database.healthPeriodRecords,
        )..where((period) => period.id.equals(openPeriod.id))).getSingle();
        return _mapPeriod(row);
      });
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Stream<HealthTodaySnapshot> watchTodaySnapshot(String userId, DateTime date) {
    return Stream.fromFuture(_readTodaySnapshot(userId, date));
  }

  @override
  Stream<HealthDailyLog> watchDailyLog(String userId, DateTime date) {
    final dateKey = HealthDate.dayKey(date);
    late StreamController<HealthDailyLog> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    var disposed = false;
    var pending = false;

    Future<void> emitSnapshot() async {
      if (disposed || pending) {
        return;
      }
      pending = true;
      try {
        final snapshot = await _readDailyLog(userId, date);
        if (!disposed && !controller.isClosed) {
          controller.add(snapshot);
        }
      } catch (error, stackTrace) {
        if (!disposed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        pending = false;
      }
    }

    void watch(Stream<Object?> stream) {
      subscriptions.add(
        stream.listen(
          (_) => unawaited(emitSnapshot()),
          onError: controller.addError,
        ),
      );
    }

    controller = StreamController<HealthDailyLog>(
      onListen: () {
        watch(_watchDailyRow(userId, dateKey));
        watch(_watchSymptomsForUser(userId));
        watch(_watchOvulationTestRow(userId, dateKey));
        watch(_watchActiveMedicationRows(userId, dateKey));
        unawaited(emitSnapshot());
      },
      onCancel: () async {
        disposed = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<void> upsertDailyLog(String userId, HealthDailyLogDraft draft) async {
    try {
      await database.transaction(() async {
        final dateKey = HealthDate.dayKey(draft.date);
        final now = _now();
        final existingDaily =
            await (database.select(database.healthPeriodDailyRecords)
                  ..where(
                    (row) =>
                        row.userId.equals(userId) &
                        row.recordDate.equals(dateKey) &
                        row.isDeleted.equals(false),
                  )
                  ..limit(1))
                .getSingleOrNull();
        final period = await _containingPeriodForUser(userId, dateKey);
        final periodId = period?.id;
        final dailyRecordId = existingDaily?.id ?? _createId();

        if (existingDaily == null) {
          await database
              .into(database.healthPeriodDailyRecords)
              .insert(
                HealthPeriodDailyRecordsCompanion.insert(
                  id: dailyRecordId,
                  userId: userId,
                  periodRecordId: Value(periodId),
                  recordDate: dateKey,
                  flowLevel: Value(_flowToDb(draft.flowLevel)),
                  exerciseIntensity: Value(
                    _exerciseIntensityToDb(draft.exerciseIntensity),
                  ),
                  sexualActivity: Value(draft.sexualActivity),
                  contraceptionMethod: Value(
                    _contraceptionMethodToDb(draft.contraceptionMethod),
                  ),
                  diet: Value(draft.diet),
                  mood: Value(_moodToDb(draft.mood)),
                  waterIntake: Value(draft.waterIntake),
                  sleepMinutes: Value(draft.sleepMinutes),
                  weightGrams: Value(draft.weightGrams),
                  temperatureCelsiusTenths: Value(
                    draft.temperatureCelsiusTenths,
                  ),
                  stressLevel: Value(draft.stressLevel),
                  calories: Value(draft.calories),
                  notes: Value(draft.notes),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        } else {
          await (database.update(
            database.healthPeriodDailyRecords,
          )..where((row) => row.id.equals(existingDaily.id))).write(
            HealthPeriodDailyRecordsCompanion(
              periodRecordId: Value(periodId),
              flowLevel: Value(_flowToDb(draft.flowLevel)),
              exerciseIntensity: Value(
                _exerciseIntensityToDb(draft.exerciseIntensity),
              ),
              sexualActivity: Value(draft.sexualActivity),
              contraceptionMethod: Value(
                _contraceptionMethodToDb(draft.contraceptionMethod),
              ),
              diet: Value(draft.diet),
              mood: Value(_moodToDb(draft.mood)),
              waterIntake: Value(draft.waterIntake),
              sleepMinutes: Value(draft.sleepMinutes),
              weightGrams: Value(draft.weightGrams),
              temperatureCelsiusTenths: Value(draft.temperatureCelsiusTenths),
              stressLevel: Value(draft.stressLevel),
              calories: Value(draft.calories),
              notes: Value(draft.notes),
              version: Value(existingDaily.version + 1),
              updatedAt: Value(now),
            ),
          );
        }

        await (database.update(database.healthPeriodSymptoms)..where(
              (row) =>
                  row.dailyRecordId.equals(dailyRecordId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              HealthPeriodSymptomsCompanion(
                isDeleted: const Value(true),
                deletedAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        for (final symptom in draft.symptoms) {
          await database
              .into(database.healthPeriodSymptoms)
              .insert(
                HealthPeriodSymptomsCompanion.insert(
                  id: _createId(),
                  userId: userId,
                  dailyRecordId: dailyRecordId,
                  symptomType: _symptomTypeToDb(symptom.type),
                  intensity: Value(_intensityToDb(symptom.intensity)),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        final ovulationTest = draft.ovulationTest;
        if (ovulationTest != null) {
          final testDateKey = HealthDate.dayKey(ovulationTest.testDate);
          final existingTest =
              await (database.select(database.healthOvulationTestRecords)
                    ..where(
                      (row) =>
                          row.userId.equals(userId) &
                          row.testDate.equals(testDateKey) &
                          row.isDeleted.equals(false),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (existingTest == null) {
            await database
                .into(database.healthOvulationTestRecords)
                .insert(
                  HealthOvulationTestRecordsCompanion.insert(
                    id: _createId(),
                    userId: userId,
                    testDate: testDateKey,
                    result: _ovulationResultToDb(ovulationTest.result),
                    testLineIntensity: Value(
                      _testLineIntensityToDb(ovulationTest.lineIntensity),
                    ),
                    notes: Value(ovulationTest.notes),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          } else {
            await (database.update(
              database.healthOvulationTestRecords,
            )..where((row) => row.id.equals(existingTest.id))).write(
              HealthOvulationTestRecordsCompanion(
                result: Value(_ovulationResultToDb(ovulationTest.result)),
                testLineIntensity: Value(
                  _testLineIntensityToDb(ovulationTest.lineIntensity),
                ),
                notes: Value(ovulationTest.notes),
                version: Value(existingTest.version + 1),
                updatedAt: Value(now),
              ),
            );
          }
        }
      });
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Stream<List<HealthCalendarMarker>> listCalendarMarkers(
    String userId,
    DateTimeRange range,
  ) {
    return Stream.fromFuture(_readCalendarMarkers(userId, range));
  }

  @override
  Stream<HealthTrendSummary> watchTrendSummary(
    String userId, {
    HealthTrendQuery query = const HealthTrendQuery(),
  }) {
    return Stream.fromFuture(_readTrendSummary(userId, query));
  }

  @override
  Future<HealthPregnancyStatus> startPregnancyMode(
    String userId,
    HealthPregnancyDraft draft,
  ) async {
    try {
      return await database.transaction(() async {
        final active = await _activePregnancyForUser(userId);
        if (active != null) {
          throw const HealthRepositoryException(
            HealthRepositoryErrorCode.activePregnancyExists,
          );
        }

        final now = _now();
        final id = _createId();
        await database
            .into(database.healthPregnancyRecords)
            .insert(
              HealthPregnancyRecordsCompanion.insert(
                id: id,
                userId: userId,
                startDate: HealthDate.dayKey(draft.startDate),
                dueDate: Value(
                  draft.dueDate == null
                      ? null
                      : HealthDate.dayKey(draft.dueDate!),
                ),
                status: _pregnancyStatusToDb(
                  HealthPregnancyRecordStatus.active,
                ),
                notes: Value(draft.notes),
                createdAt: now,
                updatedAt: now,
              ),
            );
        final row = await (database.select(
          database.healthPregnancyRecords,
        )..where((pregnancy) => pregnancy.id.equals(id))).getSingle();
        return _mapPregnancy(row);
      });
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<HealthPregnancyStatus> endPregnancyMode(
    String userId,
    HealthPregnancyEndDraft draft,
  ) async {
    try {
      if (draft.status == HealthPregnancyRecordStatus.active) {
        throw const HealthRepositoryException(
          HealthRepositoryErrorCode.invalidPregnancyEndStatus,
        );
      }
      return await database.transaction(() async {
        final active = await _activePregnancyForUser(userId);
        if (active == null) {
          throw const HealthRepositoryException(
            HealthRepositoryErrorCode.activePregnancyNotFound,
          );
        }

        final now = _now();
        await (database.update(
          database.healthPregnancyRecords,
        )..where((row) => row.id.equals(active.id))).write(
          HealthPregnancyRecordsCompanion(
            endDate: Value(HealthDate.dayKey(draft.endDate)),
            status: Value(_pregnancyStatusToDb(draft.status)),
            notes: Value(draft.notes ?? active.notes),
            version: Value(active.version + 1),
            updatedAt: Value(now),
          ),
        );
        final row = await (database.select(
          database.healthPregnancyRecords,
        )..where((pregnancy) => pregnancy.id.equals(active.id))).getSingle();
        return _mapPregnancy(row);
      });
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> cancelPregnancyMode(String userId) async {
    try {
      final now = _now();
      await (database.update(database.healthPregnancyRecords)..where(
            (row) =>
                row.userId.equals(userId) &
                row.status.equals('active') &
                row.isDeleted.equals(false),
          ))
          .write(
            HealthPregnancyRecordsCompanion(
              isDeleted: const Value(true),
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<HealthMedicationLog> upsertMedicationLog(
    String userId,
    HealthMedicationDraft draft,
  ) async {
    try {
      final now = _now();
      if (draft.id == null) {
        final id = _createId();
        await database
            .into(database.healthMedicationRecords)
            .insert(
              HealthMedicationRecordsCompanion.insert(
                id: id,
                userId: userId,
                periodRecordId: Value(draft.periodRecordId),
                name: draft.name,
                dosage: Value(draft.dosage),
                frequency: _medicationFrequencyToDb(draft.frequency),
                startDate: HealthDate.dayKey(draft.startDate),
                endDate: Value(
                  draft.endDate == null
                      ? null
                      : HealthDate.dayKey(draft.endDate!),
                ),
                notes: Value(draft.notes),
                createdAt: now,
                updatedAt: now,
              ),
            );
        final row = await (database.select(
          database.healthMedicationRecords,
        )..where((medication) => medication.id.equals(id))).getSingle();
        return _mapMedication(row);
      }

      final existing =
          await (database.select(database.healthMedicationRecords)
                ..where(
                  (row) =>
                      row.id.equals(draft.id!) &
                      row.userId.equals(userId) &
                      row.isDeleted.equals(false),
                )
                ..limit(1))
              .getSingle();
      await (database.update(
        database.healthMedicationRecords,
      )..where((row) => row.id.equals(existing.id))).write(
        HealthMedicationRecordsCompanion(
          periodRecordId: Value(draft.periodRecordId),
          name: Value(draft.name),
          dosage: Value(draft.dosage),
          frequency: Value(_medicationFrequencyToDb(draft.frequency)),
          startDate: Value(HealthDate.dayKey(draft.startDate)),
          endDate: Value(
            draft.endDate == null ? null : HealthDate.dayKey(draft.endDate!),
          ),
          notes: Value(draft.notes),
          version: Value(existing.version + 1),
          updatedAt: Value(now),
        ),
      );
      final row = await (database.select(
        database.healthMedicationRecords,
      )..where((medication) => medication.id.equals(existing.id))).getSingle();
      return _mapMedication(row);
    } catch (error) {
      if (error is HealthRepositoryException) {
        rethrow;
      }
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  Future<HealthTodaySnapshot> _readTodaySnapshot(
    String userId,
    DateTime date,
  ) async {
    final dateOnly = HealthDate.dateOnly(date);
    final settings = _mapSettings(await _activeSettingsForUser(userId));
    final periods = await _periodsForUser(userId);
    final activePregnancyRow = await _activePregnancyForUser(userId);
    final activePregnancy = activePregnancyRow == null
        ? null
        : _mapPregnancy(activePregnancyRow);
    final activePeriodRow = await _containingPeriodForUser(
      userId,
      HealthDate.dayKey(dateOnly),
    );
    final dailyLog = await _readDailyLog(userId, dateOnly);
    final prediction = HealthPredictionService.predictCycle(
      today: dateOnly,
      settings: settings,
      periods: periods,
      activePregnancy: activePregnancy,
    );

    return HealthTodaySnapshot(
      date: dateOnly,
      settings: settings,
      prediction: prediction,
      activePeriod: activePeriodRow == null
          ? null
          : _mapPeriod(activePeriodRow),
      dailyLog: dailyLog,
      activePregnancy: activePregnancy,
    );
  }

  Future<List<HealthCalendarMarker>> _readCalendarMarkers(
    String userId,
    DateTimeRange range,
  ) async {
    final start = HealthDate.dateOnly(range.start);
    final end = HealthDate.dateOnly(range.end);
    final startKey = HealthDate.dayKey(start);
    final endKey = HealthDate.dayKey(end);
    final markers = <HealthCalendarMarker>[];

    final periodRows =
        await (database.select(database.healthPeriodRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.startDate.isSmallerOrEqualValue(endKey) &
                  (row.endDate.isNull() |
                      row.endDate.isBiggerOrEqualValue(startKey)) &
                  row.isDeleted.equals(false),
            ))
            .get();
    for (final period in periodRows) {
      final periodStart = HealthDate.fromDayKey(period.startDate);
      final periodEnd = period.endDate == null
          ? end
          : HealthDate.fromDayKey(period.endDate!);
      for (final day in _daysInRange(
        _maxDate(periodStart, start),
        _minDate(periodEnd, end),
      )) {
        markers.add(
          HealthCalendarMarker(
            date: day,
            kind: HealthCalendarMarkerKind.actualPeriod,
            label: healthCalendarMarkerLabel(
              HealthCalendarMarkerKind.actualPeriod,
            ),
          ),
        );
      }
    }

    final dailyRows =
        await (database.select(database.healthPeriodDailyRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.isBiggerOrEqualValue(startKey) &
                  row.recordDate.isSmallerOrEqualValue(endKey) &
                  row.isDeleted.equals(false),
            ))
            .get();
    for (final row in dailyRows) {
      markers.add(
        HealthCalendarMarker(
          date: HealthDate.fromDayKey(row.recordDate),
          kind: HealthCalendarMarkerKind.dailyLog,
          label: healthCalendarMarkerLabel(HealthCalendarMarkerKind.dailyLog),
        ),
      );
    }

    final ovulationRows =
        await (database.select(database.healthOvulationTestRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.testDate.isBiggerOrEqualValue(startKey) &
                  row.testDate.isSmallerOrEqualValue(endKey) &
                  row.isDeleted.equals(false),
            ))
            .get();
    for (final row in ovulationRows) {
      markers.add(
        HealthCalendarMarker(
          date: HealthDate.fromDayKey(row.testDate),
          kind: HealthCalendarMarkerKind.ovulationTest,
          label: healthCalendarMarkerLabel(
            HealthCalendarMarkerKind.ovulationTest,
          ),
        ),
      );
    }

    final medicationRows =
        await (database.select(database.healthMedicationRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.startDate.isSmallerOrEqualValue(endKey) &
                  (row.endDate.isNull() |
                      row.endDate.isBiggerOrEqualValue(startKey)) &
                  row.isDeleted.equals(false),
            ))
            .get();
    for (final row in medicationRows) {
      final medicationStart = HealthDate.fromDayKey(row.startDate);
      final medicationEnd = row.endDate == null
          ? end
          : HealthDate.fromDayKey(row.endDate!);
      for (final day in _daysInRange(
        _maxDate(medicationStart, start),
        _minDate(medicationEnd, end),
      )) {
        markers.add(
          HealthCalendarMarker(
            date: day,
            kind: HealthCalendarMarkerKind.medication,
            label: healthCalendarMarkerLabel(
              HealthCalendarMarkerKind.medication,
            ),
          ),
        );
      }
    }

    final settings = _mapSettings(await _activeSettingsForUser(userId));
    final periods = await _periodsForUser(userId);
    final activePregnancyRow = await _activePregnancyForUser(userId);
    final prediction = HealthPredictionService.predictCycle(
      today: HealthDate.dateOnly(_now()),
      settings: settings,
      periods: periods,
      activePregnancy: activePregnancyRow == null
          ? null
          : _mapPregnancy(activePregnancyRow),
    );
    _addPredictionRange(
      markers,
      prediction.nextPeriodStart,
      prediction.nextPeriodEnd,
      HealthCalendarMarkerKind.predictedPeriod,
      healthCalendarMarkerLabel(HealthCalendarMarkerKind.predictedPeriod),
      start,
      end,
    );
    _addPredictionRange(
      markers,
      prediction.fertileWindowStart,
      prediction.fertileWindowEnd,
      HealthCalendarMarkerKind.fertileWindow,
      healthCalendarMarkerLabel(HealthCalendarMarkerKind.fertileWindow),
      start,
      end,
    );
    _addPredictionRange(
      markers,
      prediction.pmsStart,
      prediction.pmsEnd,
      HealthCalendarMarkerKind.pms,
      healthCalendarMarkerLabel(HealthCalendarMarkerKind.pms),
      start,
      end,
    );

    markers.sort((a, b) => a.date.compareTo(b.date));
    return markers;
  }

  Future<HealthTrendSummary> _readTrendSummary(
    String userId,
    HealthTrendQuery query,
  ) async {
    final settings = _mapSettings(await _activeSettingsForUser(userId));
    final periods = await _periodsForUser(userId);
    final selectedPeriods = settings.periodTrackingEnabled
        ? _selectedCompletedPeriods(periods, query)
        : <HealthPeriodRecordModel>[];

    final cycleLengthSeries = <HealthTrendPoint>[];
    if (settings.periodTrackingEnabled) {
      for (final period in selectedPeriods) {
        final periodIndex = periods.indexWhere(
          (candidate) => candidate.id == period.id,
        );
        if (periodIndex <= 0) {
          continue;
        }
        final previous = periods[periodIndex - 1];
        final length = HealthDate.dateOnly(
          period.startDate,
        ).difference(HealthDate.dateOnly(previous.startDate)).inDays;
        cycleLengthSeries.add(
          HealthTrendPoint(
            date: HealthDate.dateOnly(period.startDate),
            value: length,
            label: healthMonthDayLabel(period.startDate),
          ),
        );
      }
    }

    final periodDurationSeries = settings.periodTrackingEnabled
        ? [
            for (final period in selectedPeriods)
              if (period.endDate != null)
                HealthTrendPoint(
                  date: HealthDate.dateOnly(period.startDate),
                  value:
                      HealthDate.dateOnly(period.endDate!)
                          .difference(HealthDate.dateOnly(period.startDate))
                          .inDays +
                      1,
                  label: healthMonthDayLabel(period.startDate),
                ),
          ]
        : <HealthTrendPoint>[];

    final today = HealthDate.dateOnly(_now());
    final rangeStart = selectedPeriods.isNotEmpty
        ? _dailyTrendRangeStartForPhase(
            selectedPeriods.first.startDate,
            query.phase,
          )
        : query.startDate == null
        ? today.subtract(const Duration(days: 29))
        : HealthDate.dateOnly(query.startDate!);
    final rangeEnd = selectedPeriods.isNotEmpty
        ? HealthDate.dateOnly(selectedPeriods.last.endDate!)
        : today;

    final dailyLogs = await _dailyLogsInRange(userId, rangeStart, rangeEnd);
    final filteredDailyLogs = settings.periodTrackingEnabled
        ? dailyLogs
              .where(
                (log) => _dateMatchesTrendPhase(
                  log.date,
                  selectedPeriods,
                  query.phase,
                  periodRecordId: log.periodRecordId,
                ),
              )
              .toList()
        : dailyLogs;
    final pmsLogs = settings.periodTrackingEnabled
        ? dailyLogs
              .where(
                (log) => _dateMatchesTrendPhase(
                  log.date,
                  selectedPeriods,
                  HealthTrendPhase.pms,
                ),
              )
              .toList()
        : <HealthDailyLog>[];

    final coverageStart = today.subtract(const Duration(days: 29));
    final coverageCount = await _dailyLogCountInRange(
      userId,
      HealthDate.dayKey(coverageStart),
      HealthDate.dayKey(today),
    );
    final expectedDays = rangeEnd.isBefore(rangeStart)
        ? 0
        : rangeEnd.difference(rangeStart).inDays + 1;

    return HealthTrendSummary(
      query: query,
      periodTrackingEnabled: settings.periodTrackingEnabled,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      cycleLengths: cycleLengthSeries.map((point) => point.value).toList(),
      periodDurations: periodDurationSeries
          .map((point) => point.value)
          .toList(),
      recentPeriods: selectedPeriods,
      loggedDaysInLast30Days: coverageCount,
      predictionBasis: settings.periodTrackingEnabled && periods.length >= 2
          ? HealthPredictionBasis.history
          : HealthPredictionBasis.settings,
      cycleLengthSeries: cycleLengthSeries,
      periodDurationSeries: periodDurationSeries,
      flowDistribution: settings.periodTrackingEnabled
          ? _countBuckets(filteredDailyLogs.map((log) => log.flowLevel))
          : const <HealthTrendBucket<HealthFlowLevel>>[],
      moodDistribution: _countBuckets(filteredDailyLogs.map((log) => log.mood)),
      symptomDistribution: _countBuckets(
        filteredDailyLogs.expand(
          (log) => log.symptoms.map((symptom) => symptom.type),
        ),
      ),
      exerciseDistribution: _countBuckets(
        filteredDailyLogs.map((log) => log.exerciseIntensity),
      ),
      healthMetrics: HealthTrendMetricAverages(
        loggedDays: filteredDailyLogs.length,
        averageSleepMinutes: _averageNullableInts(
          filteredDailyLogs.map((log) => log.sleepMinutes),
        ),
        averageWaterIntake: _averageNullableInts(
          filteredDailyLogs.map((log) => log.waterIntake),
        ),
        averageWeightGrams: _averageNullableInts(
          filteredDailyLogs.map((log) => log.weightGrams),
        ),
        averageTemperatureCelsiusTenths: _averageNullableInts(
          filteredDailyLogs.map((log) => log.temperatureCelsiusTenths),
        ),
        averageStressLevel: _averageNullableInts(
          filteredDailyLogs.map((log) => log.stressLevel),
        ),
        averageCalories: _averageNullableInts(
          filteredDailyLogs.map((log) => log.calories),
        ),
      ),
      pmsSymptomDistribution: settings.periodTrackingEnabled
          ? _countBuckets(
              pmsLogs.expand(
                (log) => log.symptoms.map((symptom) => symptom.type),
              ),
            )
          : const <HealthTrendBucket<HealthSymptomType>>[],
      completeness: HealthTrendCompleteness(
        expectedDays: expectedDays,
        loggedDays: filteredDailyLogs.length,
        moodDays: filteredDailyLogs.where((log) => log.mood != null).length,
        symptomDays: filteredDailyLogs
            .where((log) => log.symptoms.isNotEmpty)
            .length,
        metricDays: filteredDailyLogs.where(_hasHealthMetric).length,
      ),
    );
  }

  Future<List<HealthPeriodRecordModel>> _periodsForUser(String userId) async {
    final rows =
        await (database.select(database.healthPeriodRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.startDate)]))
            .get();
    return rows.map(_mapPeriod).toList();
  }

  DateTime _dailyTrendRangeStartForPhase(
    DateTime firstPeriodStart,
    HealthTrendPhase phase,
  ) {
    final start = HealthDate.dateOnly(firstPeriodStart);
    return switch (phase) {
      HealthTrendPhase.pms => start.subtract(const Duration(days: 7)),
      HealthTrendPhase.fertileWindow => start.subtract(
        const Duration(days: 16),
      ),
      HealthTrendPhase.all ||
      HealthTrendPhase.period ||
      HealthTrendPhase.nonPeriod => start,
    };
  }

  Future<List<HealthDailyLog>> _dailyLogsInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    if (end.isBefore(start)) {
      return const [];
    }
    final startKey = HealthDate.dayKey(start);
    final endKey = HealthDate.dayKey(end);
    final rows =
        await (database.select(database.healthPeriodDailyRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.recordDate.isBiggerOrEqualValue(startKey) &
                    row.recordDate.isSmallerOrEqualValue(endKey) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.recordDate)]))
            .get();
    final logs = <HealthDailyLog>[];
    for (final daily in rows) {
      final symptomRows =
          await (database.select(database.healthPeriodSymptoms)..where(
                (row) =>
                    row.dailyRecordId.equals(daily.id) &
                    row.isDeleted.equals(false),
              ))
              .get();
      logs.add(
        HealthDailyLog(
          id: daily.id,
          date: HealthDate.fromDayKey(daily.recordDate),
          periodRecordId: daily.periodRecordId,
          flowLevel: _flowFromDb(daily.flowLevel),
          symptoms: symptomRows.map(_mapSymptom).toList(),
          mood: _moodFromDb(daily.mood),
          exerciseIntensity: _exerciseIntensityFromDb(daily.exerciseIntensity),
          sexualActivity: daily.sexualActivity,
          contraceptionMethod: _contraceptionMethodFromDb(
            daily.contraceptionMethod,
          ),
          ovulationTest: null,
          medications: const [],
          diet: daily.diet,
          waterIntake: daily.waterIntake,
          sleepMinutes: daily.sleepMinutes,
          weightGrams: daily.weightGrams,
          temperatureCelsiusTenths: daily.temperatureCelsiusTenths,
          stressLevel: daily.stressLevel,
          calories: daily.calories,
          notes: daily.notes,
        ),
      );
    }
    return logs;
  }

  bool _hasHealthMetric(HealthDailyLog log) {
    return log.waterIntake != null ||
        log.sleepMinutes != null ||
        log.weightGrams != null ||
        log.temperatureCelsiusTenths != null ||
        log.stressLevel != null ||
        log.calories != null;
  }

  List<HealthPeriodRecordModel> _selectedCompletedPeriods(
    List<HealthPeriodRecordModel> periods,
    HealthTrendQuery query,
  ) {
    final completed = periods.where((period) => period.endDate != null).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    if (query.startDate != null) {
      final startDate = HealthDate.dateOnly(query.startDate!);
      return completed
          .where(
            (period) =>
                !HealthDate.dateOnly(period.startDate).isBefore(startDate),
          )
          .toList();
    }

    if (query.defaultCompletedPeriodCount <= 0) {
      return const [];
    }
    final takeCount = query.defaultCompletedPeriodCount > completed.length
        ? completed.length
        : query.defaultCompletedPeriodCount;
    return completed.skip(completed.length - takeCount).toList();
  }

  bool _dateMatchesTrendPhase(
    DateTime date,
    List<HealthPeriodRecordModel> selectedPeriods,
    HealthTrendPhase phase, {
    String? periodRecordId,
  }) {
    final normalized = HealthDate.dateOnly(date);
    if (phase == HealthTrendPhase.all) {
      return true;
    }

    bool inRange(DateTime start, DateTime end) {
      final rangeStart = HealthDate.dateOnly(start);
      final rangeEnd = HealthDate.dateOnly(end);
      return !normalized.isBefore(rangeStart) && !normalized.isAfter(rangeEnd);
    }

    final isPeriodDay = selectedPeriods.any((period) {
      final endDate = period.endDate;
      return endDate != null && inRange(period.startDate, endDate);
    });

    return switch (phase) {
      HealthTrendPhase.all => true,
      HealthTrendPhase.period => isPeriodDay || periodRecordId != null,
      HealthTrendPhase.pms => selectedPeriods.any((period) {
        return inRange(
          period.startDate.subtract(const Duration(days: 7)),
          period.startDate.subtract(const Duration(days: 1)),
        );
      }),
      HealthTrendPhase.fertileWindow => selectedPeriods.any((period) {
        return inRange(
          period.startDate.subtract(const Duration(days: 16)),
          period.startDate.subtract(const Duration(days: 11)),
        );
      }),
      HealthTrendPhase.nonPeriod => !isPeriodDay,
    };
  }

  List<HealthTrendBucket<T>> _countBuckets<T>(Iterable<T?> values) {
    final counts = <T, int>{};
    for (final value in values) {
      if (value == null) {
        continue;
      }
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final buckets = [
      for (final entry in counts.entries)
        HealthTrendBucket<T>(value: entry.key, count: entry.value),
    ];
    buckets.sort((a, b) => b.count.compareTo(a.count));
    return buckets;
  }

  int? _averageNullableInts(Iterable<int?> values) {
    final present = values.whereType<int>().toList();
    if (present.isEmpty) {
      return null;
    }
    final total = present.fold<int>(0, (sum, value) => sum + value);
    return (total / present.length).round();
  }

  Future<int> _dailyLogCountInRange(
    String userId,
    int startKey,
    int endKey,
  ) async {
    final count = database.healthPeriodDailyRecords.id.count();
    final query = database.selectOnly(database.healthPeriodDailyRecords)
      ..addColumns([count])
      ..where(
        database.healthPeriodDailyRecords.userId.equals(userId) &
            database.healthPeriodDailyRecords.recordDate.isBiggerOrEqualValue(
              startKey,
            ) &
            database.healthPeriodDailyRecords.recordDate.isSmallerOrEqualValue(
              endKey,
            ) &
            database.healthPeriodDailyRecords.isDeleted.equals(false),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  Iterable<DateTime> _daysInRange(DateTime start, DateTime end) sync* {
    var cursor = HealthDate.dateOnly(start);
    final last = HealthDate.dateOnly(end);
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  DateTime _minDate(DateTime a, DateTime b) {
    return a.isBefore(b) ? a : b;
  }

  DateTime _maxDate(DateTime a, DateTime b) {
    return a.isAfter(b) ? a : b;
  }

  void _addPredictionRange(
    List<HealthCalendarMarker> markers,
    DateTime? predictedStart,
    DateTime? predictedEnd,
    HealthCalendarMarkerKind kind,
    String label,
    DateTime visibleStart,
    DateTime visibleEnd,
  ) {
    if (predictedStart == null || predictedEnd == null) {
      return;
    }
    final start = _maxDate(HealthDate.dateOnly(predictedStart), visibleStart);
    final end = _minDate(HealthDate.dateOnly(predictedEnd), visibleEnd);
    if (start.isAfter(end)) {
      return;
    }
    for (final day in _daysInRange(start, end)) {
      markers.add(HealthCalendarMarker(date: day, kind: kind, label: label));
    }
  }

  Stream<Object?> _watchDailyRow(String userId, int dateKey) {
    final query = database.select(database.healthPeriodDailyRecords)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.recordDate.equals(dateKey) &
            row.isDeleted.equals(false),
      );
    return query.watch();
  }

  Stream<Object?> _watchSymptomsForUser(String userId) {
    final query = database.select(database.healthPeriodSymptoms)
      ..where((row) => row.userId.equals(userId) & row.isDeleted.equals(false));
    return query.watch();
  }

  Stream<Object?> _watchOvulationTestRow(String userId, int dateKey) {
    final query = database.select(database.healthOvulationTestRecords)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.testDate.equals(dateKey) &
            row.isDeleted.equals(false),
      );
    return query.watch();
  }

  Stream<Object?> _watchActiveMedicationRows(String userId, int dateKey) {
    final query = database.select(database.healthMedicationRecords)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.startDate.isSmallerOrEqualValue(dateKey) &
            (row.endDate.isNull() | row.endDate.isBiggerOrEqualValue(dateKey)) &
            row.isDeleted.equals(false),
      );
    return query.watch();
  }

  Future<HealthPregnancyRecord?> _activePregnancyForUser(String userId) {
    return (database.select(database.healthPregnancyRecords)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.status.equals('active') &
                row.isDeleted.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  String _pregnancyStatusToDb(HealthPregnancyRecordStatus status) {
    return switch (status) {
      HealthPregnancyRecordStatus.active => 'active',
      HealthPregnancyRecordStatus.completed => 'completed',
      HealthPregnancyRecordStatus.miscarriage => 'miscarriage',
      HealthPregnancyRecordStatus.terminated => 'terminated',
    };
  }

  HealthPregnancyRecordStatus _pregnancyStatusFromDb(String status) {
    return switch (status) {
      'completed' => HealthPregnancyRecordStatus.completed,
      'miscarriage' => HealthPregnancyRecordStatus.miscarriage,
      'terminated' => HealthPregnancyRecordStatus.terminated,
      _ => HealthPregnancyRecordStatus.active,
    };
  }

  HealthPregnancyStatus _mapPregnancy(HealthPregnancyRecord row) {
    return HealthPregnancyStatus(
      id: row.id,
      startDate: HealthDate.fromDayKey(row.startDate),
      dueDate: row.dueDate == null ? null : HealthDate.fromDayKey(row.dueDate!),
      endDate: row.endDate == null ? null : HealthDate.fromDayKey(row.endDate!),
      status: _pregnancyStatusFromDb(row.status),
      notes: row.notes,
    );
  }

  Future<HealthDailyLog> _readDailyLog(String userId, DateTime date) async {
    final dateOnly = HealthDate.dateOnly(date);
    final dateKey = HealthDate.dayKey(dateOnly);
    final daily =
        await (database.select(database.healthPeriodDailyRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.recordDate.equals(dateKey) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (daily == null) {
      return HealthDailyLog.empty(dateOnly);
    }

    final symptomRows =
        await (database.select(database.healthPeriodSymptoms)..where(
              (row) =>
                  row.dailyRecordId.equals(daily.id) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final ovulationTest =
        await (database.select(database.healthOvulationTestRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.testDate.equals(dateKey) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    final medicationRows =
        await (database.select(database.healthMedicationRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.startDate.isSmallerOrEqualValue(dateKey) &
                  (row.endDate.isNull() |
                      row.endDate.isBiggerOrEqualValue(dateKey)) &
                  row.isDeleted.equals(false),
            ))
            .get();

    return HealthDailyLog(
      id: daily.id,
      date: HealthDate.fromDayKey(daily.recordDate),
      periodRecordId: daily.periodRecordId,
      flowLevel: _flowFromDb(daily.flowLevel),
      symptoms: symptomRows.map(_mapSymptom).toList(),
      mood: _moodFromDb(daily.mood),
      exerciseIntensity: _exerciseIntensityFromDb(daily.exerciseIntensity),
      sexualActivity: daily.sexualActivity,
      contraceptionMethod: _contraceptionMethodFromDb(
        daily.contraceptionMethod,
      ),
      ovulationTest: ovulationTest == null
          ? null
          : _mapOvulationTest(ovulationTest),
      medications: medicationRows.map(_mapMedication).toList(),
      diet: daily.diet,
      waterIntake: daily.waterIntake,
      sleepMinutes: daily.sleepMinutes,
      weightGrams: daily.weightGrams,
      temperatureCelsiusTenths: daily.temperatureCelsiusTenths,
      stressLevel: daily.stressLevel,
      calories: daily.calories,
      notes: daily.notes,
    );
  }

  Future<HealthPeriodRecord?> _containingPeriodForUser(
    String userId,
    int dateKey,
  ) {
    return (database.select(database.healthPeriodRecords)
          ..where(
            (period) =>
                period.userId.equals(userId) &
                period.startDate.isSmallerOrEqualValue(dateKey) &
                (period.endDate.isNull() |
                    period.endDate.isBiggerOrEqualValue(dateKey)) &
                period.isDeleted.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  String? _flowToDb(HealthFlowLevel? value) {
    return switch (value) {
      HealthFlowLevel.spotting => 'Spotting',
      HealthFlowLevel.light => 'Light',
      HealthFlowLevel.medium => 'Medium',
      HealthFlowLevel.heavy => 'Heavy',
      null => null,
    };
  }

  HealthFlowLevel? _flowFromDb(String? value) {
    return switch (value) {
      'Spotting' => HealthFlowLevel.spotting,
      'Light' => HealthFlowLevel.light,
      'Medium' => HealthFlowLevel.medium,
      'Heavy' => HealthFlowLevel.heavy,
      _ => null,
    };
  }

  String? _moodToDb(HealthMood? value) {
    return switch (value) {
      HealthMood.happy => 'Happy',
      HealthMood.sad => 'Sad',
      HealthMood.angry => 'Angry',
      HealthMood.anxious => 'Anxious',
      HealthMood.calm => 'Calm',
      HealthMood.irritable => 'Irritable',
      null => null,
    };
  }

  HealthMood? _moodFromDb(String? value) {
    return switch (value) {
      'Happy' => HealthMood.happy,
      'Sad' => HealthMood.sad,
      'Angry' => HealthMood.angry,
      'Anxious' => HealthMood.anxious,
      'Calm' => HealthMood.calm,
      'Irritable' => HealthMood.irritable,
      _ => null,
    };
  }

  String _symptomTypeToDb(HealthSymptomType value) {
    return switch (value) {
      HealthSymptomType.pain => 'Pain',
      HealthSymptomType.fatigue => 'Fatigue',
      HealthSymptomType.moodSwing => 'MoodSwing',
      HealthSymptomType.bloating => 'Bloating',
      HealthSymptomType.headache => 'Headache',
      HealthSymptomType.nausea => 'Nausea',
      HealthSymptomType.insomnia => 'Insomnia',
      HealthSymptomType.appetiteChange => 'AppetiteChange',
      HealthSymptomType.skinBreakout => 'SkinBreakout',
      HealthSymptomType.breastTenderness => 'BreastTenderness',
      HealthSymptomType.cramps => 'Cramps',
      HealthSymptomType.backPain => 'BackPain',
      HealthSymptomType.other => 'Other',
    };
  }

  HealthSymptomType _symptomTypeFromDb(String value) {
    return switch (value) {
      'Pain' => HealthSymptomType.pain,
      'Fatigue' => HealthSymptomType.fatigue,
      'MoodSwing' => HealthSymptomType.moodSwing,
      'Bloating' => HealthSymptomType.bloating,
      'Headache' => HealthSymptomType.headache,
      'Nausea' => HealthSymptomType.nausea,
      'Insomnia' => HealthSymptomType.insomnia,
      'AppetiteChange' => HealthSymptomType.appetiteChange,
      'SkinBreakout' => HealthSymptomType.skinBreakout,
      'BreastTenderness' => HealthSymptomType.breastTenderness,
      'Cramps' => HealthSymptomType.cramps,
      'BackPain' => HealthSymptomType.backPain,
      _ => HealthSymptomType.other,
    };
  }

  String? _intensityToDb(HealthIntensity? value) {
    return switch (value) {
      HealthIntensity.light => 'Light',
      HealthIntensity.medium => 'Medium',
      HealthIntensity.heavy => 'Heavy',
      null => null,
    };
  }

  HealthIntensity _intensityFromDb(String? value) {
    return switch (value) {
      'Medium' => HealthIntensity.medium,
      'Heavy' => HealthIntensity.heavy,
      _ => HealthIntensity.light,
    };
  }

  String _ovulationResultToDb(HealthOvulationTestResult value) {
    return switch (value) {
      HealthOvulationTestResult.negative => 'Negative',
      HealthOvulationTestResult.positive => 'Positive',
      HealthOvulationTestResult.peak => 'Peak',
      HealthOvulationTestResult.invalid => 'Invalid',
    };
  }

  HealthOvulationTestResult _ovulationResultFromDb(String value) {
    return switch (value) {
      'Positive' => HealthOvulationTestResult.positive,
      'Peak' => HealthOvulationTestResult.peak,
      'Invalid' => HealthOvulationTestResult.invalid,
      _ => HealthOvulationTestResult.negative,
    };
  }

  String? _testLineIntensityToDb(HealthTestLineIntensity? value) {
    return switch (value) {
      HealthTestLineIntensity.low => 'Low',
      HealthTestLineIntensity.medium => 'Medium',
      HealthTestLineIntensity.high => 'High',
      null => null,
    };
  }

  HealthTestLineIntensity? _testLineIntensityFromDb(String? value) {
    return switch (value) {
      'Low' => HealthTestLineIntensity.low,
      'Medium' => HealthTestLineIntensity.medium,
      'High' => HealthTestLineIntensity.high,
      _ => null,
    };
  }

  String? _exerciseIntensityToDb(HealthExerciseIntensity? value) {
    return switch (value) {
      HealthExerciseIntensity.none => 'None',
      HealthExerciseIntensity.light => 'Light',
      HealthExerciseIntensity.medium => 'Medium',
      HealthExerciseIntensity.heavy => 'Heavy',
      null => null,
    };
  }

  HealthExerciseIntensity? _exerciseIntensityFromDb(String? value) {
    return switch (value) {
      'None' => HealthExerciseIntensity.none,
      'Light' => HealthExerciseIntensity.light,
      'Medium' => HealthExerciseIntensity.medium,
      'Heavy' => HealthExerciseIntensity.heavy,
      _ => null,
    };
  }

  String? _contraceptionMethodToDb(HealthContraceptionMethod? value) {
    return switch (value) {
      HealthContraceptionMethod.none => 'None',
      HealthContraceptionMethod.condom => 'Condom',
      HealthContraceptionMethod.pill => 'Pill',
      HealthContraceptionMethod.iud => 'Iud',
      HealthContraceptionMethod.other => 'Other',
      null => null,
    };
  }

  HealthContraceptionMethod? _contraceptionMethodFromDb(String? value) {
    return switch (value) {
      'None' => HealthContraceptionMethod.none,
      'Condom' => HealthContraceptionMethod.condom,
      'Pill' => HealthContraceptionMethod.pill,
      'Iud' => HealthContraceptionMethod.iud,
      'Other' => HealthContraceptionMethod.other,
      _ => null,
    };
  }

  HealthSymptomLog _mapSymptom(HealthPeriodSymptom row) {
    return HealthSymptomLog(
      id: row.id,
      type: _symptomTypeFromDb(row.symptomType),
      intensity: _intensityFromDb(row.intensity),
      notes: null,
    );
  }

  HealthOvulationTestLog _mapOvulationTest(HealthOvulationTestRecord row) {
    return HealthOvulationTestLog(
      id: row.id,
      testDate: HealthDate.fromDayKey(row.testDate),
      result: _ovulationResultFromDb(row.result),
      lineIntensity: _testLineIntensityFromDb(row.testLineIntensity),
      notes: row.notes,
    );
  }

  HealthMedicationLog _mapMedication(HealthMedicationRecord row) {
    return HealthMedicationLog(
      id: row.id,
      name: row.name,
      dosage: row.dosage,
      frequency: _medicationFrequencyFromDb(row.frequency),
      startDate: HealthDate.fromDayKey(row.startDate),
      endDate: row.endDate == null ? null : HealthDate.fromDayKey(row.endDate!),
      notes: row.notes,
      periodRecordId: row.periodRecordId,
    );
  }

  String _medicationFrequencyToDb(HealthMedicationFrequency value) {
    return switch (value) {
      HealthMedicationFrequency.once => 'Once',
      HealthMedicationFrequency.daily => 'Daily',
      HealthMedicationFrequency.twiceDaily => 'TwiceDaily',
      HealthMedicationFrequency.threeTimesDaily => 'ThreeTimesDaily',
      HealthMedicationFrequency.weekly => 'Weekly',
      HealthMedicationFrequency.monthly => 'Monthly',
      HealthMedicationFrequency.asNeeded => 'AsNeeded',
    };
  }

  HealthMedicationFrequency _medicationFrequencyFromDb(String value) {
    return switch (value) {
      'Daily' => HealthMedicationFrequency.daily,
      'TwiceDaily' => HealthMedicationFrequency.twiceDaily,
      'ThreeTimesDaily' => HealthMedicationFrequency.threeTimesDaily,
      'Weekly' => HealthMedicationFrequency.weekly,
      'Monthly' => HealthMedicationFrequency.monthly,
      'AsNeeded' => HealthMedicationFrequency.asNeeded,
      _ => HealthMedicationFrequency.once,
    };
  }

  Future<HealthPeriodSetting> _activeSettingsForUser(String userId) async {
    try {
      return await (database.select(database.healthPeriodSettings)
            ..where(
              (setting) =>
                  setting.userId.equals(userId) &
                  setting.isDeleted.equals(false),
            )
            ..limit(1))
          .getSingle();
    } catch (error) {
      throw HealthRepositoryException(
        HealthRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  Future<HealthPeriodRecord?> _openPeriodForUser(String userId) async {
    return (database.select(database.healthPeriodRecords)
          ..where(
            (period) =>
                period.userId.equals(userId) &
                period.endDate.isNull() &
                period.isDeleted.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  HealthPeriodSettingsModel _mapSettings(HealthPeriodSetting row) {
    return HealthPeriodSettingsModel(
      averageCycleLength: row.averageCycleLength,
      averagePeriodLength: row.averagePeriodLength,
      periodTrackingEnabled: row.periodTrackingEnabled,
      periodReminderEnabled: row.periodReminderEnabled,
      ovulationReminderEnabled: row.ovulationReminderEnabled,
      pmsReminderEnabled: row.pmsReminderEnabled,
      reminderDays: row.reminderDays,
      dataSyncEnabled: row.dataSyncEnabled,
      analyticsEnabled: row.analyticsEnabled,
    );
  }

  HealthPeriodRecordModel _mapPeriod(HealthPeriodRecord row) {
    return HealthPeriodRecordModel(
      id: row.id,
      startDate: HealthDate.fromDayKey(row.startDate),
      endDate: row.endDate == null ? null : HealthDate.fromDayKey(row.endDate!),
      notes: row.notes,
    );
  }
}
