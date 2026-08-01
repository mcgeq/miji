import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart' as db;
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/checkin_repository.dart';

/// Drift 实现的打卡 Repository
class DriftCheckinRepository implements CheckinRepository {
  DriftCheckinRepository({
    required this.database,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? (() => DateTime.now().toUtc());

  final db.AppDatabase database;
  final Uuid _uuid;
  final DateTime Function() _now;

  // ---------------------------------------------------------------------------
  // 计划管理
  // ---------------------------------------------------------------------------

  @override
  Future<List<CheckinPlan>> getActivePlans(String userId) async {
    final rows =
        await (database.select(database.checkinPlans)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isArchived.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();

    return rows.map(_planFromRow).toList();
  }

  @override
  Future<List<CheckinPlan>> getAllPlans(String userId) async {
    final rows =
        await (database.select(database.checkinPlans)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.isArchived),
                (row) => OrderingTerm.asc(row.sortOrder),
              ]))
            .get();

    return rows.map(_planFromRow).toList();
  }

  @override
  Future<CheckinPlan?> getPlan(String planId) async {
    final row =
        await (database.select(database.checkinPlans)..where(
              (row) => row.id.equals(planId) & row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    return row == null ? null : _planFromRow(row);
  }

  @override
  Future<CheckinPlan> createPlan(CheckinPlanDraft draft, String userId) async {
    final now = _now();
    final id = _uuid.v4();

    await database
        .into(database.checkinPlans)
        .insert(
          db.CheckinPlansCompanion.insert(
            id: id,
            userId: userId,
            name: draft.name,
            icon: Value(draft.icon),
            color: Value(draft.color),
            category: Value(draft.category),
            planType: Value(draft.planType.value),
            frequencyType: Value(draft.frequencyType.value),
            frequencyConfig: Value(draft.frequencyConfig),
            targetValue: Value(draft.targetValue),
            targetUnit: Value(draft.targetUnit),
            triggerMode: Value(draft.triggerMode.value),
            recordGranularity: Value(draft.recordGranularity.value),
            defaultVisibility: Value(draft.defaultVisibility.value),
            reminderEnabled: Value(draft.reminderEnabled),
            reminderTime: Value(draft.reminderTime),
            reminderDaysBefore: Value(draft.reminderDaysBefore),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (await getPlan(id))!;
  }

  @override
  Future<CheckinPlan> updatePlan(CheckinPlan plan) async {
    final now = _now();

    await (database.update(
      database.checkinPlans,
    )..where((row) => row.id.equals(plan.id))).write(
      db.CheckinPlansCompanion(
        name: Value(plan.name),
        icon: Value(plan.icon),
        color: Value(plan.color),
        category: Value(plan.category),
        planType: Value(plan.planType.value),
        frequencyType: Value(plan.frequencyType.value),
        frequencyConfig: Value(plan.frequencyConfig),
        targetValue: Value(plan.targetValue),
        targetUnit: Value(plan.targetUnit),
        triggerMode: Value(plan.triggerMode.value),
        recordGranularity: Value(plan.recordGranularity.value),
        defaultVisibility: Value(plan.defaultVisibility.value),
        reminderEnabled: Value(plan.reminderEnabled),
        reminderTime: Value(plan.reminderTime),
        reminderDaysBefore: Value(plan.reminderDaysBefore),
        isArchived: Value(plan.isArchived),
        sortOrder: Value(plan.sortOrder),
        version: Value(plan.version + 1),
        updatedAt: Value(now),
      ),
    );

    return (await getPlan(plan.id))!;
  }

  @override
  Future<void> archivePlan(String planId, bool archived) async {
    final now = _now();
    await (database.update(
      database.checkinPlans,
    )..where((row) => row.id.equals(planId))).write(
      db.CheckinPlansCompanion(
        isArchived: Value(archived),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> deletePlan(String planId) async {
    final now = _now();
    await (database.update(
      database.checkinPlans,
    )..where((row) => row.id.equals(planId))).write(
      db.CheckinPlansCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> reorderPlans(List<String> planIdsInOrder) async {
    final now = _now();
    await database.transaction(() async {
      for (var i = 0; i < planIdsInOrder.length; i++) {
        await (database.update(
          database.checkinPlans,
        )..where((row) => row.id.equals(planIdsInOrder[i]))).write(
          db.CheckinPlansCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }

  @override
  Future<List<CheckinPlan>> getPlansByCategory(
    String userId,
    String category,
  ) async {
    final rows =
        await (database.select(database.checkinPlans)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.category.equals(category) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();

    return rows.map(_planFromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // 打卡记录
  // ---------------------------------------------------------------------------

  @override
  Future<List<CheckinRecord>> getRecordsByDate(
    String userId,
    DateTime date,
  ) async {
    final dateKey = _dateOnly(date).millisecondsSinceEpoch;
    final rows =
        await (database.select(database.checkinRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.recordDate.equals(dateKey) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.completedAt)]))
            .get();

    return Future.wait(rows.map(_recordFromRow));
  }

  @override
  Future<List<CheckinRecord>> getRecordsByPlanAndDate(
    String planId,
    DateTime date,
  ) async {
    final dateKey = _dateOnly(date).millisecondsSinceEpoch;
    final rows =
        await (database.select(database.checkinRecords)
              ..where(
                (row) =>
                    row.planId.equals(planId) &
                    row.recordDate.equals(dateKey) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.completedAt)]))
            .get();

    return Future.wait(rows.map(_recordFromRow));
  }

  @override
  Future<List<CheckinRecord>> getRecordsByPlanAndDateRange(
    String planId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startKey = _dateOnly(startDate).millisecondsSinceEpoch;
    final endKey = _dateOnly(endDate).millisecondsSinceEpoch;

    final rows =
        await (database.select(database.checkinRecords)
              ..where(
                (row) =>
                    row.planId.equals(planId) &
                    row.recordDate.isBetweenValues(startKey, endKey) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.recordDate)]))
            .get();

    return Future.wait(rows.map(_recordFromRow));
  }

  @override
  Future<CheckinRecord> upsertRecord(
    CheckinRecordDraft draft,
    String userId,
  ) async {
    final now = _now();
    final dateKey = _dateOnly(draft.recordDate).millisecondsSinceEpoch;

    final existing =
        await (database.select(database.checkinRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.planId.equals(draft.planId) &
                    row.recordDate.equals(dateKey) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      final newCount = existing.count + draft.count;
      final newValue = (existing.numericValue ?? 0) + (draft.numericValue ?? 0);

      await (database.update(
        database.checkinRecords,
      )..where((row) => row.id.equals(existing.id))).write(
        db.CheckinRecordsCompanion(
          count: Value(newCount),
          numericValue: Value(newValue),
          completedAt: Value(now),
          mood: Value(draft.mood ?? existing.mood),
          notes: Value(draft.notes ?? existing.notes),
          durationSeconds: Value(
            (existing.durationSeconds ?? 0) + (draft.durationSeconds ?? 0),
          ),
          version: Value(existing.version + 1),
          updatedAt: Value(now),
        ),
      );

      final updated = await (database.select(
        database.checkinRecords,
      )..where((row) => row.id.equals(existing.id))).getSingle();
      return _recordFromRow(updated);
    } else {
      return createRecord(draft, userId);
    }
  }

  @override
  Future<CheckinRecord> createRecord(
    CheckinRecordDraft draft,
    String userId,
  ) async {
    final now = _now();
    final id = _uuid.v4();
    final dateKey = _dateOnly(draft.recordDate).millisecondsSinceEpoch;

    await database
        .into(database.checkinRecords)
        .insert(
          db.CheckinRecordsCompanion.insert(
            id: id,
            userId: userId,
            planId: draft.planId,
            recordDate: dateKey,
            completedAt: draft.completedAt,
            count: Value(draft.count),
            numericValue: Value(draft.numericValue),
            durationSeconds: Value(draft.durationSeconds),
            mood: Value(draft.mood),
            notes: Value(draft.notes),
            visibility: Value(draft.visibility.value),
            locationJson: Value(draft.locationJson),
            extraJson: Value(draft.extraJson),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final row = await (database.select(
      database.checkinRecords,
    )..where((row) => row.id.equals(id))).getSingle();
    return _recordFromRow(row);
  }

  @override
  Future<CheckinRecord> updateRecord(CheckinRecord record) async {
    final now = _now();

    await (database.update(
      database.checkinRecords,
    )..where((row) => row.id.equals(record.id))).write(
      db.CheckinRecordsCompanion(
        count: Value(record.count),
        numericValue: Value(record.numericValue),
        durationSeconds: Value(record.durationSeconds),
        mood: Value(record.mood),
        notes: Value(record.notes),
        visibility: Value(record.visibility.value),
        locationJson: Value(record.locationJson),
        extraJson: Value(record.extraJson),
        version: Value(record.version + 1),
        updatedAt: Value(now),
      ),
    );

    final row = await (database.select(
      database.checkinRecords,
    )..where((row) => row.id.equals(record.id))).getSingle();
    return _recordFromRow(row);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    final now = _now();
    await (database.update(
      database.checkinRecords,
    )..where((row) => row.id.equals(recordId))).write(
      db.CheckinRecordsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<List<PlanProgress>> getTodayProgress(
    String userId,
    DateTime date,
  ) async {
    final plans = await getActivePlans(userId);
    final dateKey = _dateOnly(date).millisecondsSinceEpoch;

    final rows =
        await (database.select(database.checkinRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(dateKey) &
                  row.isDeleted.equals(false),
            ))
            .get();

    final recordsByPlan = <String, List<CheckinRecord>>{};
    for (final row in rows) {
      final record = await _recordFromRow(row);
      recordsByPlan.putIfAbsent(record.planId, () => []).add(record);
    }

    return plans.map((plan) {
      final planRecords = recordsByPlan[plan.id] ?? [];
      var totalCount = 0;
      var totalValue = 0.0;
      for (final r in planRecords) {
        totalCount += r.count;
        totalValue += r.numericValue ?? 0;
      }
      final lastCheckin = planRecords.isNotEmpty
          ? planRecords.first.completedAt
          : null;

      return PlanProgress(
        plan: plan,
        currentCount: totalCount,
        currentValue: totalValue,
        lastCheckinAt: lastCheckin,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 照片
  // ---------------------------------------------------------------------------

  @override
  Future<CheckinPhoto> addPhoto({
    required String recordId,
    required String userId,
    required String localPath,
    DateTime? takenAt,
    String? gpsJson,
  }) async {
    final now = _now();
    final id = _uuid.v4();

    await database
        .into(database.checkinPhotos)
        .insert(
          db.CheckinPhotosCompanion.insert(
            id: id,
            userId: userId,
            recordId: recordId,
            localPath: localPath,
            takenAt: Value(takenAt),
            gpsJson: Value(gpsJson),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final row = await (database.select(
      database.checkinPhotos,
    )..where((row) => row.id.equals(id))).getSingle();
    return _photoFromRow(row);
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    final now = _now();
    await (database.update(
      database.checkinPhotos,
    )..where((row) => row.id.equals(photoId))).write(
      db.CheckinPhotosCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 统计
  // ---------------------------------------------------------------------------

  @override
  Future<CheckinStreak> getStreak(String userId, DateTime upTo) async {
    var currentStreak = 0;
    var longestStreak = 0;
    var date = _dateOnly(upTo);

    final rows =
        await (database.select(database.checkinRecords)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.recordDate)]))
            .get();

    final checkinDates = rows.map((row) => row.recordDate).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    for (final checkinDate in checkinDates) {
      final expectedDateKey = date.millisecondsSinceEpoch;
      if (checkinDate == expectedDateKey) {
        currentStreak++;
        date = date.subtract(const Duration(days: 1));
      } else if (checkinDate < expectedDateKey) {
        break;
      }
    }

    var tempStreak = 0;
    var prevDate = 0;
    for (final checkinDate in checkinDates) {
      if (prevDate == 0) {
        tempStreak = 1;
      } else {
        final prevDay = DateTime.fromMillisecondsSinceEpoch(
          prevDate,
          isUtc: true,
        );
        final currDay = DateTime.fromMillisecondsSinceEpoch(
          checkinDate,
          isUtc: true,
        );
        final diffDays = prevDay.difference(currDay).inDays;
        if (diffDays == 1) {
          tempStreak++;
        } else {
          if (tempStreak > longestStreak) longestStreak = tempStreak;
          tempStreak = 1;
        }
      }
      prevDate = checkinDate;
    }
    if (tempStreak > longestStreak) longestStreak = tempStreak;

    return CheckinStreak(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }

  @override
  Future<List<DailyCheckinSummary>> getDailySummaries(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startKey = _dateOnly(startDate).millisecondsSinceEpoch;
    final endKey = _dateOnly(endDate).millisecondsSinceEpoch;

    final rows =
        await (database.select(database.checkinRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.isBetweenValues(startKey, endKey) &
                  row.isDeleted.equals(false),
            ))
            .get();

    final byDate = <int, List<db.CheckinRecord>>{};
    for (final row in rows) {
      byDate.putIfAbsent(row.recordDate, () => []).add(row);
    }

    final activePlanCount = (await getActivePlans(userId)).length;

    return byDate.entries.map((entry) {
      final records = entry.value;
      final completedPlanIds = records.map((r) => r.planId).toSet();
      return DailyCheckinSummary(
        date: DateTime.fromMillisecondsSinceEpoch(entry.key, isUtc: true),
        totalPlans: activePlanCount,
        completedPlans: completedPlanIds.length,
        totalCheckins: records.length,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<Map<String, dynamic>>> getPlanTrend(
    String planId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final records = await getRecordsByPlanAndDateRange(
      planId,
      startDate,
      endDate,
    );

    final byDate = <int, List<CheckinRecord>>{};
    for (final record in records) {
      final dateKey = _dateOnly(record.recordDate).millisecondsSinceEpoch;
      byDate.putIfAbsent(dateKey, () => []).add(record);
    }

    return byDate.entries.map((entry) {
      final dateRecords = entry.value;
      var totalCount = 0;
      var totalValue = 0.0;
      for (final r in dateRecords) {
        totalCount += r.count;
        totalValue += r.numericValue ?? 0;
      }
      return <String, dynamic>{
        'date': DateTime.fromMillisecondsSinceEpoch(entry.key, isUtc: true),
        'count': totalCount,
        'value': totalValue,
        'records': dateRecords.length,
      };
    }).toList()..sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
  }

  @override
  Future<Map<String, int>> getCategoryStats(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startKey = _dateOnly(startDate).millisecondsSinceEpoch;
    final endKey = _dateOnly(endDate).millisecondsSinceEpoch;

    final rows =
        await (database.select(database.checkinRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.isBetweenValues(startKey, endKey) &
                  row.isDeleted.equals(false),
            ))
            .get();

    final planIds = rows.map((r) => r.planId).toSet().toList();
    if (planIds.isEmpty) return {};

    final plans =
        await (database.select(database.checkinPlans)..where(
              (row) => row.id.isIn(planIds) & row.isDeleted.equals(false),
            ))
            .get();

    final planCategoryMap = {for (final plan in plans) plan.id: plan.category};

    final stats = <String, int>{};
    for (final row in rows) {
      final category = planCategoryMap[row.planId] ?? '其他';
      stats[category] = (stats[category] ?? 0) + 1;
    }

    return stats;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime _dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  CheckinPlan _planFromRow(db.CheckinPlan row) {
    return CheckinPlan(
      id: row.id,
      userId: row.userId,
      name: row.name,
      icon: row.icon,
      color: row.color,
      category: row.category,
      planType: CheckinPlanType.fromValue(row.planType),
      frequencyType: CheckinFrequencyType.fromValue(row.frequencyType),
      frequencyConfig: row.frequencyConfig,
      targetValue: row.targetValue,
      targetUnit: row.targetUnit,
      triggerMode: CheckinTriggerMode.fromValue(row.triggerMode),
      recordGranularity: CheckinRecordGranularity.fromValue(
        row.recordGranularity,
      ),
      defaultVisibility: CheckinVisibility.fromValue(row.defaultVisibility),
      reminderEnabled: row.reminderEnabled,
      reminderTime: row.reminderTime,
      reminderDaysBefore: row.reminderDaysBefore,
      isArchived: row.isArchived,
      sortOrder: row.sortOrder,
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<CheckinRecord> _recordFromRow(db.CheckinRecord row) async {
    final photoRows =
        await (database.select(database.checkinPhotos)..where(
              (photo) =>
                  photo.recordId.equals(row.id) & photo.isDeleted.equals(false),
            ))
            .get();

    return CheckinRecord(
      id: row.id,
      userId: row.userId,
      planId: row.planId,
      recordDate: DateTime.fromMillisecondsSinceEpoch(
        row.recordDate,
        isUtc: true,
      ),
      completedAt: row.completedAt,
      count: row.count,
      numericValue: row.numericValue,
      durationSeconds: row.durationSeconds,
      mood: row.mood,
      notes: row.notes,
      visibility: CheckinVisibility.fromValue(row.visibility),
      locationJson: row.locationJson,
      extraJson: row.extraJson,
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      photos: photoRows.map(_photoFromRow).toList(),
    );
  }

  CheckinPhoto _photoFromRow(db.CheckinPhoto row) {
    return CheckinPhoto(
      id: row.id,
      userId: row.userId,
      recordId: row.recordId,
      localPath: row.localPath,
      takenAt: row.takenAt,
      gpsJson: row.gpsJson,
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<String> exportAllJson(String userId) async {
    final plans = await getAllPlans(userId);
    final now = DateTime.now();
    final records =
        await (database.select(database.checkinRecords)..where(
              (row) => row.userId.equals(userId) & row.isDeleted.equals(false),
            ))
            .get();

    final photos =
        await (database.select(database.checkinPhotos)..where(
              (photo) =>
                  photo.userId.equals(userId) & photo.isDeleted.equals(false),
            ))
            .get();

    final json = <String, dynamic>{
      'exportedAt': now.toIso8601String(),
      'plans': plans
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'icon': p.icon,
              'category': p.category,
              'planType': p.planType.value,
              'frequencyType': p.frequencyType.value,
              'targetValue': p.targetValue,
              'targetUnit': p.targetUnit,
              'triggerMode': p.triggerMode.value,
              'isArchived': p.isArchived,
              'createdAt': p.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'records': records
          .map(
            (r) => {
              'id': r.id,
              'planId': r.planId,
              'recordDate': DateTime.fromMillisecondsSinceEpoch(
                r.recordDate,
                isUtc: true,
              ).toIso8601String(),
              'completedAt': r.completedAt.toIso8601String(),
              'count': r.count,
              'numericValue': r.numericValue,
              'durationSeconds': r.durationSeconds,
              'mood': r.mood,
              'notes': r.notes,
              'extraJson': r.extraJson,
              'createdAt': r.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'photos': photos
          .map(
            (p) => {
              'id': p.id,
              'recordId': p.recordId,
              'localPath': p.localPath,
              'takenAt': p.takenAt?.toIso8601String(),
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(json);
  }

  @override
  Future<Map<int, int>> getMoodDistribution(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startKey = _dateOnly(startDate).millisecondsSinceEpoch;
    final endKey = _dateOnly(endDate).millisecondsSinceEpoch;
    final rows =
        await (database.select(database.checkinRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.isBetweenValues(startKey, endKey) &
                  row.mood.isNotNull() &
                  row.isDeleted.equals(false),
            ))
            .get();
    final dist = <int, int>{};
    for (final row in rows) {
      if (row.mood != null) dist[row.mood!] = (dist[row.mood!] ?? 0) + 1;
    }
    return dist;
  }
}
