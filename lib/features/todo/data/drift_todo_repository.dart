import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart' as db;
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/domain/todo_repository.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';

/// Drift 实现的 Todo Repository
class DriftTodoRepository implements TodoRepository {
  DriftTodoRepository({
    required this.database,
    this.syncChangeLogger,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? (() => DateTime.now().toUtc());

  final db.AppDatabase database;
  final SyncChangeLogger? syncChangeLogger;
  final Uuid _uuid;
  final DateTime Function() _now;

  // ---- Sync change logging (V1.1) ----

  Future<void> _recordTaskChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) return;
    await logger.recordTodoTaskChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  // ---------------------------------------------------------------------------
  // 辅助方法
  // ---------------------------------------------------------------------------

  TodoTask _taskFromRow(db.TodoTask row) {
    return TodoTask(
      id: row.id,
      userId: row.userId,
      title: row.title,
      notes: row.notes,
      status: TodoTaskStatus.fromValue(row.status),
      priority: TodoTaskPriority.fromValue(row.priority),
      scheduledDate: row.scheduledDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.scheduledDate!, isUtc: true)
          : null,
      dueAt: row.dueAt,
      categoryId: row.categoryId,
      parentTaskId: row.parentTaskId,
      sortOrder: row.sortOrder,
      completedAt: row.completedAt,
      cancelledAt: row.cancelledAt,
      isRecurrenceTemplate: row.isRecurrenceTemplate,
      recurrenceRuleId: row.recurrenceRuleId,
      occurrenceDate: row.occurrenceDate != null
          ? DateTime.fromMillisecondsSinceEpoch(
              row.occurrenceDate!,
              isUtc: true,
            )
          : null,
      reminderAt: row.reminderAt,
      markdownBody: row.markdownBody,
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TodoCategory _categoryFromRow(db.TodoCategory row) {
    return TodoCategory(
      id: row.id,
      userId: row.userId,
      name: row.name,
      color: row.color,
      icon: row.icon,
      sortOrder: row.sortOrder,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TodoTag _tagFromRow(db.TodoTag row) {
    return TodoTag(
      id: row.id,
      userId: row.userId,
      name: row.name,
      color: row.color,
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TodoRecurrenceRule _ruleFromRow(db.TodoRecurrenceRule row) {
    return TodoRecurrenceRule(
      id: row.id,
      userId: row.userId,
      templateTaskId: row.templateTaskId,
      frequencyType: RecurrenceFrequencyType.fromValue(row.frequencyType),
      interval_: row.interval_,
      daysOfWeek: row.daysOfWeekJson != null
          ? (jsonDecode(row.daysOfWeekJson!) as List<dynamic>)
                .map((e) => e as int)
                .toList()
          : null,
      dayOfMonth: row.dayOfMonth,
      monthOfYear: row.monthOfYear,
      dayOfYear: row.dayOfYear,
      endsAt: row.endsAt,
      reminderMode: row.reminderMode,
      reminderConfigJson: row.reminderConfigJson,
      deviceId: row.deviceId,
      version: row.version,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<List<TodoTask>> _attachRelations(List<TodoTask> tasks) async {
    if (tasks.isEmpty) return tasks;

    // 分类
    final categoryIds = tasks
        .map((t) => t.categoryId)
        .whereType<String>()
        .toSet();
    Map<String, TodoCategory> categoryMap = {};
    if (categoryIds.isNotEmpty) {
      final catRows = await (database.select(
        database.todoCategories,
      )..where((row) => row.id.isIn(categoryIds))).get();
      for (final row in catRows) {
        categoryMap[row.id] = _categoryFromRow(row);
      }
    }

    // 子任务
    final taskIds = tasks.map((t) => t.id).toSet();
    final subRows =
        await (database.select(database.todoTasks)
              ..where(
                (row) =>
                    row.parentTaskId.isIn(taskIds) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    final Map<String, List<TodoTask>> subTaskMap = {};
    for (final row in subRows) {
      final parentId = row.parentTaskId!;
      subTaskMap.putIfAbsent(parentId, () => []).add(_taskFromRow(row));
    }

    // 标签 (V1.1)
    final Map<String, List<TodoTag>> tagMap = {};
    final joinRows = await (database.select(
      database.todoTaskTags,
    )..where((row) => row.taskId.isIn(taskIds))).get();
    if (joinRows.isNotEmpty) {
      final tagIds = joinRows.map((j) => j.tagId).toSet();
      final tagRows =
          await (database.select(database.todoTags)..where(
                (row) => row.id.isIn(tagIds) & row.isDeleted.equals(false),
              ))
              .get();
      final Map<String, TodoTag> allTags = {};
      for (final t in tagRows) {
        allTags[t.id] = _tagFromRow(t);
      }
      for (final j in joinRows) {
        final tag = allTags[j.tagId];
        if (tag != null) {
          tagMap.putIfAbsent(j.taskId, () => []).add(tag);
        }
      }
    }

    // 重复规则 (V1.1)
    final ruleIds = tasks
        .map((t) => t.recurrenceRuleId)
        .whereType<String>()
        .toSet();
    Map<String, TodoRecurrenceRule> ruleMap = {};
    if (ruleIds.isNotEmpty) {
      final ruleRows =
          await (database.select(database.todoRecurrenceRules)..where(
                (row) => row.id.isIn(ruleIds) & row.isDeleted.equals(false),
              ))
              .get();
      for (final row in ruleRows) {
        ruleMap[row.id] = _ruleFromRow(row);
      }
    }

    return tasks.map((task) {
      return task.copyWith(
        category: categoryMap[task.categoryId],
        subTasks: subTaskMap[task.id] ?? const [],
        tags: tagMap[task.id] ?? const [],
        recurrenceRule: ruleMap[task.recurrenceRuleId],
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 任务查询
  // ---------------------------------------------------------------------------

  @override
  Future<List<TodoTask>> getTodayTasks(String userId, DateTime today) async {
    final todayStart = DateTime.utc(today.year, today.month, today.day);
    final todayMs = todayStart.millisecondsSinceEpoch;
    final todayEnd = todayStart.add(const Duration(days: 1));

    final rows =
        await (database.select(database.todoTasks)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false) &
                    row.status.equals(TodoTaskStatus.todo.value) &
                    row.parentTaskId.isNull() &
                    (row.scheduledDate.equals(todayMs) |
                        row.occurrenceDate.equals(todayMs) |
                        row.dueAt.isBetweenValues(todayStart, todayEnd) |
                        row.dueAt.isSmallerThanValue(DateTime.now().toUtc())),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.dueAt),
                (row) => OrderingTerm.asc(row.sortOrder),
              ]))
            .get();

    final tasks = rows.map(_taskFromRow).toList();
    tasks.sort(_compareTaskPriority);
    return _attachRelations(tasks);
  }

  int _compareTaskPriority(TodoTask a, TodoTask b) {
    final aOverdue = a.isOverdue;
    final bOverdue = b.isOverdue;
    if (aOverdue && !bOverdue) return -1;
    if (!aOverdue && bOverdue) return 1;
    final pw = b.priority.sortWeight.compareTo(a.priority.sortWeight);
    if (pw != 0) return pw;
    if (a.dueAt != null && b.dueAt != null) return a.dueAt!.compareTo(b.dueAt!);
    if (a.dueAt != null) return -1;
    if (b.dueAt != null) return 1;
    return a.sortOrder.compareTo(b.sortOrder);
  }

  @override
  Future<List<TodoTask>> getTasks(String userId, TodoTaskFilter filter) async {
    final query = database.select(database.todoTasks)
      ..where((row) {
        var condition = row.userId.equals(userId);

        if (!filter.includeDeleted) {
          condition = condition & row.isDeleted.equals(false);
        }

        if (filter.excludeRecurrenceTemplates) {
          condition = condition & row.isRecurrenceTemplate.equals(false);
        }

        if (filter.statuses.length == 1) {
          condition =
              condition & row.status.equals(filter.statuses.first.value);
        } else if (filter.statuses.isNotEmpty) {
          condition =
              condition & row.status.isIn(filter.statuses.map((s) => s.value));
        }

        if (filter.priorities != null && filter.priorities!.isNotEmpty) {
          condition =
              condition &
              row.priority.isIn(filter.priorities!.map((p) => p.value));
        }

        if (filter.categoryId != null) {
          final cid = filter.categoryId!;
          condition = condition & row.categoryId.equals(cid);
        }

        if (filter.scheduledDate != null) {
          final ms = DateTime.utc(
            filter.scheduledDate!.year,
            filter.scheduledDate!.month,
            filter.scheduledDate!.day,
          ).millisecondsSinceEpoch;
          condition = condition & row.scheduledDate.equals(ms);
        }

        if (filter.parentTaskId != null) {
          final ptid = filter.parentTaskId!;
          condition = condition & row.parentTaskId.equals(ptid);
        } else {
          condition = condition & row.parentTaskId.isNull();
        }

        return condition;
      });

    query.orderBy([
      (row) => OrderingTerm.asc(row.dueAt),
      (row) => OrderingTerm.asc(row.sortOrder),
    ]);

    if (filter.limit != null) {
      query.limit(filter.limit!);
    }

    final rows = await query.get();
    var tasks = rows.map(_taskFromRow).toList();

    // 标签过滤 (V1.1): 在内存中完成
    if (filter.tagId != null) {
      final taskIds = tasks.map((t) => t.id).toSet();
      final joinRows =
          await (database.select(database.todoTaskTags)..where(
                (row) =>
                    row.tagId.equals(filter.tagId!) & row.taskId.isIn(taskIds),
              ))
              .get();
      final taggedIds = joinRows.map((j) => j.taskId).toSet();
      tasks = tasks.where((t) => taggedIds.contains(t.id)).toList();
    }

    // 标题搜索在内存中完成
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final q = filter.searchQuery!.toLowerCase();
      tasks.removeWhere((t) => !t.title.toLowerCase().contains(q));
    }

    tasks.sort(_compareTaskPriority);
    return _attachRelations(tasks);
  }

  @override
  Future<TodoTask?> getTask(String id) async {
    final row =
        await (database.select(database.todoTasks)
              ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
            .getSingleOrNull();
    if (row == null) return null;
    final task = _taskFromRow(row);
    final tasks = await _attachRelations([task]);
    return tasks.firstOrNull;
  }

  @override
  Future<List<TodoTask>> getSubTasks(String parentTaskId) async {
    final rows =
        await (database.select(database.todoTasks)
              ..where(
                (row) =>
                    row.parentTaskId.equals(parentTaskId) &
                    row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    return rows.map(_taskFromRow).toList();
  }

  @override
  Future<List<TodoTask>> getTasksByDate(String userId, DateTime date) async {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayMs = dayStart.millisecondsSinceEpoch;
    final dayEnd = dayStart.add(const Duration(days: 1));

    final rows =
        await (database.select(database.todoTasks)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false) &
                    row.parentTaskId.isNull() &
                    (row.scheduledDate.equals(dayMs) |
                        row.occurrenceDate.equals(dayMs) |
                        row.dueAt.isBetweenValues(dayStart, dayEnd)),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.dueAt),
                (row) => OrderingTerm.asc(row.sortOrder),
              ]))
            .get();

    final tasks = rows.map(_taskFromRow).toList();
    tasks.sort(_compareTaskPriority);
    return _attachRelations(tasks);
  }

  @override
  Future<List<TodoTask>> searchTasks(String userId, String query) async {
    final q = query.toLowerCase();

    // 先用标题和备注模糊匹配
    final rows =
        await (database.select(database.todoTasks)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();

    var tasks = rows
        .map(_taskFromRow)
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              (t.notes?.toLowerCase().contains(q) ?? false),
        )
        .toList();

    // 附加标签后再做标签匹配
    tasks = await _attachRelations(tasks);

    // 标签名称命中
    final tagMatchTasks = tasks
        .where((t) => t.tags.any((tag) => tag.name.toLowerCase().contains(q)))
        .toList();

    final seen = <String>{};
    final result = <TodoTask>[];
    for (final t in tasks) {
      if (t.title.toLowerCase().contains(q) ||
          (t.notes?.toLowerCase().contains(q) ?? false)) {
        seen.add(t.id);
        result.add(t);
      }
    }
    for (final t in tagMatchTasks) {
      if (!seen.contains(t.id)) {
        result.add(t);
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // 任务 CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<TodoTask> createTask(TodoTaskDraft draft, String userId) async {
    final now = _now();
    final id = _uuid.v4();

    await database
        .into(database.todoTasks)
        .insert(
          db.TodoTasksCompanion.insert(
            id: id,
            userId: userId,
            title: draft.title,
            notes: Value(draft.notes),
            status: const Value('todo'),
            priority: Value(draft.priority.value),
            scheduledDate: Value(
              draft.scheduledDate != null
                  ? DateTime.utc(
                      draft.scheduledDate!.year,
                      draft.scheduledDate!.month,
                      draft.scheduledDate!.day,
                    ).millisecondsSinceEpoch
                  : null,
            ),
            dueAt: Value(draft.dueAt),
            categoryId: Value(draft.categoryId),
            parentTaskId: Value(draft.parentTaskId),
            isRecurrenceTemplate: Value(draft.isRecurrenceTemplate),
            recurrenceRuleId: Value(draft.recurrenceRuleId),
            occurrenceDate: Value(
              draft.occurrenceDate != null
                  ? DateTime.utc(
                      draft.occurrenceDate!.year,
                      draft.occurrenceDate!.month,
                      draft.occurrenceDate!.day,
                    ).millisecondsSinceEpoch
                  : null,
            ),
            reminderAt: Value(draft.reminderAt),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 关联标签
    if (draft.tagIds != null && draft.tagIds!.isNotEmpty) {
      await _setTaskTags(id, draft.tagIds!);
    }

    // Sync log (V1.1)
    unawaited(
      _recordTaskChange(
        userId: userId,
        recordId: id,
        operation: SyncChangeOperation.insert,
        changedFields: _fieldsFromDraft(draft),
        afterVersion: 1,
      ),
    );

    return TodoTask(
      id: id,
      userId: userId,
      title: draft.title,
      notes: draft.notes,
      status: TodoTaskStatus.todo,
      priority: draft.priority,
      scheduledDate: draft.scheduledDate,
      dueAt: draft.dueAt,
      categoryId: draft.categoryId,
      parentTaskId: draft.parentTaskId,
      isRecurrenceTemplate: draft.isRecurrenceTemplate,
      recurrenceRuleId: draft.recurrenceRuleId,
      occurrenceDate: draft.occurrenceDate,
      reminderAt: draft.reminderAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<TodoTask> updateTask(TodoTask task) async {
    final now = _now();

    await (database.update(
      database.todoTasks,
    )..where((row) => row.id.equals(task.id))).write(
      db.TodoTasksCompanion(
        title: Value(task.title),
        notes: Value(task.notes),
        status: Value(task.status.value),
        priority: Value(task.priority.value),
        scheduledDate: Value(
          task.scheduledDate != null
              ? DateTime.utc(
                  task.scheduledDate!.year,
                  task.scheduledDate!.month,
                  task.scheduledDate!.day,
                ).millisecondsSinceEpoch
              : null,
        ),
        dueAt: Value(task.dueAt),
        categoryId: Value(task.categoryId),
        parentTaskId: Value(task.parentTaskId),
        sortOrder: Value(task.sortOrder),
        completedAt: Value(task.completedAt),
        cancelledAt: Value(task.cancelledAt),
        isRecurrenceTemplate: Value(task.isRecurrenceTemplate),
        recurrenceRuleId: Value(task.recurrenceRuleId),
        occurrenceDate: Value(
          task.occurrenceDate != null
              ? DateTime.utc(
                  task.occurrenceDate!.year,
                  task.occurrenceDate!.month,
                  task.occurrenceDate!.day,
                ).millisecondsSinceEpoch
              : null,
        ),
        reminderAt: Value(task.reminderAt),
        version: Value(task.version + 1),
        updatedAt: Value(now),
      ),
    );

    // Sync log (V1.1)
    unawaited(
      _recordTaskChange(
        userId: task.userId,
        recordId: task.id,
        operation: SyncChangeOperation.update,
        changedFields: _fieldsFromTask(task),
        beforeVersion: task.version,
        afterVersion: task.version + 1,
      ),
    );

    return task.copyWith(version: task.version + 1, updatedAt: now);
  }

  Future<void> _setTaskTags(String taskId, List<String> tagIds) async {
    // 先删后插
    await (database.delete(
      database.todoTaskTags,
    )..where((row) => row.taskId.equals(taskId))).go();
    final now = _now();
    for (final tagId in tagIds) {
      await database
          .into(database.todoTaskTags)
          .insert(
            db.TodoTaskTagsCompanion.insert(
              taskId: taskId,
              tagId: tagId,
              createdAt: now,
            ),
          );
    }
  }

  @override
  Future<void> completeTask(String id) async {
    final now = _now();
    await (database.update(
      database.todoTasks,
    )..where((row) => row.id.equals(id))).write(
      db.TodoTasksCompanion(
        status: const Value('completed'),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> reopenTask(String id) async {
    final now = _now();
    await (database.update(
      database.todoTasks,
    )..where((row) => row.id.equals(id))).write(
      db.TodoTasksCompanion(
        status: const Value('todo'),
        completedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> cancelTask(String id) async {
    final now = _now();
    await (database.update(
      database.todoTasks,
    )..where((row) => row.id.equals(id))).write(
      db.TodoTasksCompanion(
        status: const Value('cancelled'),
        cancelledAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> softDeleteTask(String id) async {
    final now = _now();
    await (database.update(
      database.todoTasks,
    )..where((row) => row.id.equals(id))).write(
      db.TodoTasksCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> restoreTask(String id) async {
    final now = _now();
    await (database.update(
      database.todoTasks,
    )..where((row) => row.id.equals(id))).write(
      db.TodoTasksCompanion(
        isDeleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> permanentlyDeleteTask(String id) async {
    await (database.delete(
      database.todoTasks,
    )..where((row) => row.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // 标签 (V1.1)
  // ---------------------------------------------------------------------------

  @override
  Future<List<TodoTag>> getTags(String userId) async {
    final rows =
        await (database.select(database.todoTags)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.name)]))
            .get();
    return rows.map(_tagFromRow).toList();
  }

  @override
  Future<TodoTag> createTag(String name, String color, String userId) async {
    final now = _now();
    final id = _uuid.v4();
    await database
        .into(database.todoTags)
        .insert(
          db.TodoTagsCompanion.insert(
            id: id,
            userId: userId,
            name: name,
            color: Value(color),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return TodoTag(
      id: id,
      userId: userId,
      name: name,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<TodoTag> updateTag(TodoTag tag) async {
    final now = _now();
    await (database.update(
      database.todoTags,
    )..where((row) => row.id.equals(tag.id))).write(
      db.TodoTagsCompanion(
        name: Value(tag.name),
        color: Value(tag.color),
        version: Value(tag.version + 1),
        updatedAt: Value(now),
      ),
    );
    return tag.copyWith(version: tag.version + 1, updatedAt: now);
  }

  @override
  Future<void> deleteTag(String id) async {
    final now = _now();
    // 软删除标签
    await (database.update(
      database.todoTags,
    )..where((row) => row.id.equals(id))).write(
      db.TodoTagsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    // 删除关联
    await (database.delete(
      database.todoTaskTags,
    )..where((row) => row.tagId.equals(id))).go();
  }

  @override
  Future<List<TodoTag>> getTaskTags(String taskId) async {
    final joinRows = await (database.select(
      database.todoTaskTags,
    )..where((row) => row.taskId.equals(taskId))).get();
    if (joinRows.isEmpty) return [];
    final tagIds = joinRows.map((j) => j.tagId).toSet();
    final tagRows = await (database.select(
      database.todoTags,
    )..where((row) => row.id.isIn(tagIds) & row.isDeleted.equals(false))).get();
    return tagRows.map(_tagFromRow).toList();
  }

  @override
  Future<void> setTaskTags(String taskId, List<String> tagIds) async {
    await _setTaskTags(taskId, tagIds);
  }

  @override
  Future<int> getTagTaskCount(String tagId) async {
    final count = await (database.select(
      database.todoTaskTags,
    )..where((row) => row.tagId.equals(tagId))).map((row) => row.taskId).get();
    return count.length;
  }

  // ---------------------------------------------------------------------------
  // 重复规则 (V1.1)
  // ---------------------------------------------------------------------------

  @override
  Future<List<TodoRecurrenceRule>> getRecurrenceRules(String userId) async {
    final rows =
        await (database.select(database.todoRecurrenceRules)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();
    return rows.map(_ruleFromRow).toList();
  }

  @override
  Future<TodoRecurrenceRule?> getRecurrenceRule(String id) async {
    final row =
        await (database.select(database.todoRecurrenceRules)
              ..where((row) => row.id.equals(id) & row.isDeleted.equals(false)))
            .getSingleOrNull();
    return row == null ? null : _ruleFromRow(row);
  }

  @override
  Future<TodoRecurrenceRule> createRecurrenceRule(
    TodoTaskDraft templateDraft,
    TodoRecurrenceRule rule,
    String userId,
  ) async {
    final now = _now();
    final ruleId = _uuid.v4();
    // 1. 创建模板任务
    final template = await createTask(
      templateDraft.copyWith(isRecurrenceTemplate: true),
      userId,
    );
    // 2. 创建规则
    await database
        .into(database.todoRecurrenceRules)
        .insert(
          db.TodoRecurrenceRulesCompanion.insert(
            id: ruleId,
            userId: userId,
            templateTaskId: template.id,
            frequencyType: rule.frequencyType.value,
            interval_: Value(rule.interval_),
            daysOfWeekJson: Value(
              rule.daysOfWeek != null ? jsonEncode(rule.daysOfWeek) : null,
            ),
            dayOfMonth: Value(rule.dayOfMonth),
            monthOfYear: Value(rule.monthOfYear),
            dayOfYear: Value(rule.dayOfYear),
            endsAt: Value(rule.endsAt),
            reminderMode: Value(rule.reminderMode),
            reminderConfigJson: Value(rule.reminderConfigJson),
            createdAt: now,
            updatedAt: now,
          ),
        );
    // 3. 预生成实例
    final createdRule = rule.copyWith(
      id: ruleId,
      userId: userId,
      templateTaskId: template.id,
      createdAt: now,
      updatedAt: now,
    );
    await generateRecurrenceInstances(userId, createdRule, template);
    return createdRule;
  }

  @override
  Future<TodoRecurrenceRule> updateRecurrenceRule(
    TodoRecurrenceRule rule,
    TodoTask updatedTemplate,
  ) async {
    final now = _now();
    // 更新模板任务
    await updateTask(updatedTemplate);
    // 更新规则
    await (database.update(
      database.todoRecurrenceRules,
    )..where((row) => row.id.equals(rule.id))).write(
      db.TodoRecurrenceRulesCompanion(
        frequencyType: Value(rule.frequencyType.value),
        interval_: Value(rule.interval_),
        daysOfWeekJson: Value(
          rule.daysOfWeek != null ? jsonEncode(rule.daysOfWeek) : null,
        ),
        dayOfMonth: Value(rule.dayOfMonth),
        monthOfYear: Value(rule.monthOfYear),
        dayOfYear: Value(rule.dayOfYear),
        endsAt: Value(rule.endsAt),
        reminderMode: Value(rule.reminderMode),
        reminderConfigJson: Value(rule.reminderConfigJson),
        version: Value(rule.version + 1),
        updatedAt: Value(now),
      ),
    );
    // 重新生成：删除未来未完成实例，重新生成
    final todayMs = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).millisecondsSinceEpoch;
    await (database.update(database.todoTasks)..where(
          (row) =>
              row.recurrenceRuleId.equals(rule.id) &
              row.status.equals('todo') &
              row.occurrenceDate.isBiggerOrEqualValue(todayMs),
        ))
        .write(
          db.TodoTasksCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
          ),
        );
    await generateRecurrenceInstances(rule.userId, rule, updatedTemplate);
    return rule.copyWith(version: rule.version + 1, updatedAt: now);
  }

  @override
  Future<void> deleteRecurrenceRule(String id) async {
    final now = _now();
    // 软删除规则
    await (database.update(
      database.todoRecurrenceRules,
    )..where((row) => row.id.equals(id))).write(
      db.TodoRecurrenceRulesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    // 软删除模板
    final ruleRow = await (database.select(
      database.todoRecurrenceRules,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (ruleRow != null) {
      await softDeleteTask(ruleRow.templateTaskId);
    }
    // 软删除未来未完成实例
    await (database.update(database.todoTasks)..where(
          (row) => row.recurrenceRuleId.equals(id) & row.status.equals('todo'),
        ))
        .write(
          db.TodoTasksCompanion(
            isDeleted: const Value(true),
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<void> generateRecurrenceInstances(
    String userId,
    TodoRecurrenceRule rule,
    TodoTask template,
  ) async {
    final today = DateTime.now();
    final todayStart = DateTime.utc(today.year, today.month, today.day);
    final endDate = todayStart.add(const Duration(days: 30));
    final generatedDates = <DateTime>[];

    var cursor = todayStart;
    while (cursor.isBefore(endDate) || cursor.isAtSameMomentAs(endDate)) {
      final dates = _datesForRule(rule, cursor, todayStart);
      for (final d in dates) {
        if (d.isBefore(todayStart)) continue;
        if (d.isAfter(endDate)) break;
        if (rule.endsAt != null && d.isAfter(rule.endsAt!)) break;
        generatedDates.add(d);
      }
      // 跳到下个月检查
      cursor = DateTime.utc(cursor.year, cursor.month + 1, 1);
    }

    // 去重（避免同一天生成多个）
    final uniqueDates = generatedDates
        .map((d) => DateTime.utc(d.year, d.month, d.day))
        .toSet();

    // 查询已存在的实例
    final existingRows =
        await (database.select(database.todoTasks)..where(
              (row) =>
                  row.recurrenceRuleId.equals(rule.id) &
                  row.isDeleted.equals(false) &
                  row.userId.equals(userId),
            ))
            .get();
    final existingDates = existingRows
        .where((r) => r.occurrenceDate != null)
        .map(
          (r) => DateTime.fromMillisecondsSinceEpoch(
            r.occurrenceDate!,
            isUtc: true,
          ),
        )
        .toSet();

    final now = _now();
    for (final date in uniqueDates) {
      final ms = date.millisecondsSinceEpoch;
      if (existingDates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      )) {
        continue; // 已存在，跳过
      }

      // 计算提醒时间
      DateTime? reminderAt;
      if (rule.reminderMode == 'absolute-time' &&
          rule.reminderConfigJson != null) {
        try {
          final config = jsonDecode(rule.reminderConfigJson!) as Map;
          final hour = config['hour'] as int? ?? 9;
          final minute = config['minute'] as int? ?? 0;
          reminderAt = DateTime(date.year, date.month, date.day, hour, minute);
        } catch (_) {}
      }

      final instanceId = _uuid.v4();
      await database
          .into(database.todoTasks)
          .insert(
            db.TodoTasksCompanion.insert(
              id: instanceId,
              userId: userId,
              title: template.title,
              notes: Value(template.notes),
              status: const Value('todo'),
              priority: Value(template.priority.value),
              dueAt: Value(
                template.dueAt != null
                    ? DateTime(
                        date.year,
                        date.month,
                        date.day,
                        template.dueAt!.hour,
                        template.dueAt!.minute,
                      )
                    : null,
              ),
              categoryId: Value(template.categoryId),
              recurrenceRuleId: Value(rule.id),
              occurrenceDate: Value(ms),
              reminderAt: Value(reminderAt),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  /// 根据规则类型和当前日期返回符合条件的日期列表
  List<DateTime> _datesForRule(
    TodoRecurrenceRule rule,
    DateTime cursor,
    DateTime start,
  ) {
    switch (rule.frequencyType) {
      case RecurrenceFrequencyType.daily:
        return _dailyDates(cursor, rule.interval_, start);
      case RecurrenceFrequencyType.weekly:
        return _weeklyDates(cursor, rule.interval_, rule.daysOfWeek ?? []);
      case RecurrenceFrequencyType.monthly:
        return _monthlyDates(cursor, rule.interval_, rule.dayOfMonth ?? 1);
      case RecurrenceFrequencyType.yearly:
        return _yearlyDates(
          cursor,
          rule.interval_,
          rule.monthOfYear ?? 1,
          rule.dayOfYear ?? 1,
        );
    }
  }

  List<DateTime> _dailyDates(DateTime cursor, int interval, DateTime start) {
    final dates = <DateTime>[];
    var d = DateTime.utc(cursor.year, cursor.month, cursor.day);
    final end = start.add(const Duration(days: 30));
    while (d.isBefore(end) || d.isAtSameMomentAs(end)) {
      dates.add(d);
      d = d.add(Duration(days: interval));
    }
    return dates;
  }

  List<DateTime> _weeklyDates(
    DateTime cursor,
    int interval,
    List<int> daysOfWeek,
  ) {
    final dates = <DateTime>[];
    final monthStart = DateTime.utc(cursor.year, cursor.month, 1);
    final nextMonthStart = DateTime.utc(cursor.year, cursor.month + 1, 1);
    var d = monthStart;
    while (d.isBefore(nextMonthStart)) {
      if (daysOfWeek.isEmpty || daysOfWeek.contains(d.weekday)) {
        dates.add(d);
      }
      d = d.add(const Duration(days: 1));
    }
    final now = DateTime.now();
    dates.removeWhere(
      (d) => d.isBefore(DateTime.utc(now.year, now.month, now.day)),
    );
    return dates;
  }

  List<DateTime> _monthlyDates(DateTime cursor, int interval, int dayOfMonth) {
    final dates = <DateTime>[];
    var year = cursor.year;
    var month = cursor.month;
    final end = DateTime.now().add(const Duration(days: 30));
    for (var i = 0; i < 12; i++) {
      if (i % interval != 0) {
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
        continue;
      }
      final maxDay = DateTime(year, month + 1, 0).day;
      final day = dayOfMonth > maxDay ? maxDay : dayOfMonth;
      final d = DateTime.utc(year, month, day);
      if (d.isAfter(end)) break;
      if (!d.isBefore(DateTime.now())) {
        dates.add(d);
      }
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
    return dates;
  }

  List<DateTime> _yearlyDates(
    DateTime cursor,
    int interval,
    int monthOfYear,
    int dayOfYear,
  ) {
    final dates = <DateTime>[];
    final year = cursor.year;
    final maxDay = DateTime(year, monthOfYear + 1, 0).day;
    final day = dayOfYear > maxDay ? maxDay : dayOfYear;
    final d = DateTime.utc(year, monthOfYear, day);
    if (!d.isBefore(DateTime.now())) {
      dates.add(d);
    }
    return dates;
  }

  // ---------------------------------------------------------------------------
  // 分类
  // ---------------------------------------------------------------------------

  @override
  Future<List<TodoCategory>> getCategories(String userId) async {
    final rows =
        await (database.select(database.todoCategories)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
            .get();
    return rows.map(_categoryFromRow).toList();
  }

  @override
  Future<TodoCategory> createCategory(String name, String userId) async {
    final now = _now();
    final id = _uuid.v4();
    await database
        .into(database.todoCategories)
        .insert(
          db.TodoCategoriesCompanion.insert(
            id: id,
            userId: userId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return TodoCategory(
      id: id,
      userId: userId,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<TodoCategory> updateCategory(TodoCategory category) async {
    final now = _now();
    await (database.update(
      database.todoCategories,
    )..where((row) => row.id.equals(category.id))).write(
      db.TodoCategoriesCompanion(
        name: Value(category.name),
        color: Value(category.color),
        icon: Value(category.icon),
        sortOrder: Value(category.sortOrder),
        updatedAt: Value(now),
      ),
    );
    return category.copyWith(updatedAt: now);
  }

  @override
  Future<void> deleteCategory(String id) async {
    final now = _now();
    await (database.update(
      database.todoCategories,
    )..where((row) => row.id.equals(id))).write(
      db.TodoCategoriesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sync 辅助 (V1.1)
  // ---------------------------------------------------------------------------

  Map<String, Object?> _fieldsFromDraft(TodoTaskDraft draft) {
    return {
      'title': draft.title,
      'notes': draft.notes,
      'priority': draft.priority.value,
      'scheduled_date': draft.scheduledDate?.toUtc().toIso8601String(),
      'due_at': draft.dueAt?.toUtc().toIso8601String(),
      'category_id': draft.categoryId,
      'parent_task_id': draft.parentTaskId,
      'is_recurrence_template': draft.isRecurrenceTemplate,
      'reminder_at': draft.reminderAt?.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _fieldsFromTask(TodoTask task) {
    return {
      'title': task.title,
      'notes': task.notes,
      'status': task.status.value,
      'priority': task.priority.value,
      'scheduled_date': task.scheduledDate?.toUtc().toIso8601String(),
      'due_at': task.dueAt?.toUtc().toIso8601String(),
      'category_id': task.categoryId,
      'parent_task_id': task.parentTaskId,
      'sort_order': task.sortOrder,
      'completed_at': task.completedAt?.toUtc().toIso8601String(),
      'cancelled_at': task.cancelledAt?.toUtc().toIso8601String(),
      'is_recurrence_template': task.isRecurrenceTemplate,
      'recurrence_rule_id': task.recurrenceRuleId,
      'occurrence_date': task.occurrenceDate?.toUtc().toIso8601String(),
      'reminder_at': task.reminderAt?.toUtc().toIso8601String(),
      'is_deleted': task.isDeleted,
      'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // 排序
  // ---------------------------------------------------------------------------

  @override
  Future<void> reorderTasks(List<String> taskIdsInOrder) async {
    final now = _now();
    for (var i = 0; i < taskIdsInOrder.length; i++) {
      await (database.update(
        database.todoTasks,
      )..where((row) => row.id.equals(taskIdsInOrder[i]))).write(
        db.TodoTasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // V1.2: 统计
  // ---------------------------------------------------------------------------

  @override
  Future<TodoStatsSummary> getStatsSummary(
    String userId,
    TodoStatsRangeInfo range,
  ) async {
    final startMs = range.start.millisecondsSinceEpoch;
    final endMs = range.end.millisecondsSinceEpoch;
    final now = DateTime.now().toUtc();

    final plannedQuery = database.select(database.todoTasks)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.isDeleted.equals(false) &
            row.isRecurrenceTemplate.equals(false) &
            row.parentTaskId.isNull() &
            row.status.isNotIn(['cancelled']) &
            (row.scheduledDate.isBetweenValues(startMs, endMs - 1) |
                row.occurrenceDate.isBetweenValues(startMs, endMs - 1) |
                row.dueAt.isBetweenValues(range.start, range.end)),
      );
    final plannedRows = await plannedQuery.get();
    final plannedCount = plannedRows.length;
    final completedPlannedCount = plannedRows
        .where((r) => r.status == 'completed')
        .length;

    final totalCompleted =
        (await (database.select(database.todoTasks)..where(
                  (row) =>
                      row.userId.equals(userId) &
                      row.isDeleted.equals(false) &
                      row.isRecurrenceTemplate.equals(false) &
                      row.status.equals('completed') &
                      row.completedAt.isBetweenValues(range.start, range.end),
                ))
                .get())
            .length;

    final overdueCount =
        (await (database.select(database.todoTasks)..where(
                  (row) =>
                      row.userId.equals(userId) &
                      row.isDeleted.equals(false) &
                      row.isRecurrenceTemplate.equals(false) &
                      row.parentTaskId.isNull() &
                      row.status.equals('todo') &
                      row.dueAt.isSmallerThanValue(now),
                ))
                .get())
            .length;

    final cancelledCount =
        (await (database.select(database.todoTasks)..where(
                  (row) =>
                      row.userId.equals(userId) &
                      row.isDeleted.equals(false) &
                      row.isRecurrenceTemplate.equals(false) &
                      row.status.equals('cancelled') &
                      row.cancelledAt.isBetweenValues(range.start, range.end),
                ))
                .get())
            .length;

    return TodoStatsSummary(
      plannedCount: plannedCount,
      completedPlannedCount: completedPlannedCount,
      completionRate: plannedCount > 0
          ? completedPlannedCount / plannedCount
          : null,
      totalCompleted: totalCompleted,
      overdueCount: overdueCount,
      cancelledCount: cancelledCount,
    );
  }

  @override
  Future<List<TodoDailyTrend>> getCompletionTrend(
    String userId,
    TodoStatsRangeInfo range,
  ) async {
    final days = range.end.difference(range.start).inDays;
    final result = <TodoDailyTrend>[];
    for (var i = 0; i < days; i++) {
      final day = range.start.add(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));
      final rows =
          await (database.select(database.todoTasks)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false) &
                    row.status.equals('completed') &
                    row.completedAt.isBetweenValues(day, dayEnd),
              ))
              .get();
      result.add(TodoDailyTrend(date: day, count: rows.length));
    }
    return result;
  }

  @override
  Future<List<TodoDistribution>> getCategoryDistribution(
    String userId,
    TodoStatsRangeInfo range,
  ) async {
    final cats = await getCategories(userId);
    final result = <TodoDistribution>[];
    for (final cat in cats) {
      final rows =
          await (database.select(database.todoTasks)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false) &
                    row.status.equals('completed') &
                    row.categoryId.equals(cat.id) &
                    row.completedAt.isBetweenValues(range.start, range.end),
              ))
              .get();
      if (rows.isNotEmpty) {
        result.add(
          TodoDistribution(
            key: cat.id,
            count: rows.length,
            label: cat.name,
            color: cat.color,
          ),
        );
      }
    }
    final uncategorizedRows =
        await (database.select(database.todoTasks)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false) &
                  row.isRecurrenceTemplate.equals(false) &
                  row.status.equals('completed') &
                  row.categoryId.isNull() &
                  row.completedAt.isBetweenValues(range.start, range.end),
            ))
            .get();
    if (uncategorizedRows.isNotEmpty) {
      result.add(
        TodoDistribution(
          key: '_none',
          count: uncategorizedRows.length,
          label: '未分类',
        ),
      );
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  @override
  Future<List<TodoDistribution>> getTagDistribution(
    String userId,
    TodoStatsRangeInfo range,
  ) async {
    final tags = await getTags(userId);
    final result = <TodoDistribution>[];
    for (final tag in tags) {
      final taskIds = await (database.select(
        database.todoTaskTags,
      )..where((row) => row.tagId.equals(tag.id))).get();
      if (taskIds.isEmpty) continue;
      final ids = taskIds.map((r) => r.taskId).toSet();
      final rows =
          await (database.select(database.todoTasks)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false) &
                    row.status.equals('completed') &
                    row.id.isIn(ids) &
                    row.completedAt.isBetweenValues(range.start, range.end),
              ))
              .get();
      if (rows.isNotEmpty) {
        result.add(
          TodoDistribution(
            key: tag.id,
            count: rows.length,
            label: tag.name,
            color: tag.color,
          ),
        );
      }
    }
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  @override
  Future<List<TodoDistribution>> getPriorityDistribution(
    String userId,
    TodoStatsRangeInfo range,
  ) async {
    final result = <TodoDistribution>[];
    final startMs = range.start.millisecondsSinceEpoch;
    final endMs = range.end.millisecondsSinceEpoch;
    for (final p in TodoTaskPriority.values) {
      final rows =
          await (database.select(database.todoTasks)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.isRecurrenceTemplate.equals(false) &
                    row.priority.equals(p.value) &
                    (row.scheduledDate.isBetweenValues(startMs, endMs - 1) |
                        row.occurrenceDate.isBetweenValues(startMs, endMs - 1) |
                        row.dueAt.isBetweenValues(range.start, range.end)),
              ))
              .get();
      if (rows.isNotEmpty) {
        result.add(
          TodoDistribution(
            key: p.value,
            count: rows.length,
            label: switch (p) {
              TodoTaskPriority.none => '无',
              TodoTaskPriority.low => '低',
              TodoTaskPriority.medium => '中',
              TodoTaskPriority.high => '高',
            },
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<List<TodoReviewTip>> getReviewTips(
    String userId,
    TodoStatsRangeInfo range,
  ) async {
    final tips = <TodoReviewTip>[];
    final summary = await getStatsSummary(userId, range);
    if (summary.overdueCount > 0) {
      tips.add(
        TodoReviewTip(
          message: '有 ${summary.overdueCount} 项任务已逾期，建议重新安排或取消。',
          type: TodoReviewTipType.danger,
        ),
      );
    }
    if (summary.completionRate != null &&
        summary.completionRate! < 0.5 &&
        summary.plannedCount >= 5) {
      tips.add(
        TodoReviewTip(
          message: '当前周期完成率偏低，建议减少计划量或优先处理高优先级任务。',
          type: TodoReviewTipType.warning,
        ),
      );
    }
    final highOverdueRows =
        await (database.select(database.todoTasks)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false) &
                  row.isRecurrenceTemplate.equals(false) &
                  row.priority.equals('high') &
                  row.status.equals('todo') &
                  row.dueAt.isSmallerThanValue(DateTime.now().toUtc()),
            ))
            .get();
    if (highOverdueRows.isNotEmpty) {
      tips.add(
        TodoReviewTip(
          message: '有 ${highOverdueRows.length} 项高优先级任务逾期，需要优先处理。',
          type: TodoReviewTipType.danger,
        ),
      );
    }
    return tips.take(2).toList();
  }

  // ---------------------------------------------------------------------------
  // V1.2: CSV 导出
  // ---------------------------------------------------------------------------

  @override
  Future<String> exportTasksCsv(String userId, TodoStatsRangeInfo range) async {
    final rows =
        await (database.select(database.todoTasks)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false) &
                  row.isRecurrenceTemplate.equals(false) &
                  (row.scheduledDate.isBetweenValues(
                        range.start.millisecondsSinceEpoch,
                        range.end.millisecondsSinceEpoch - 1,
                      ) |
                      row.occurrenceDate.isBetweenValues(
                        range.start.millisecondsSinceEpoch,
                        range.end.millisecondsSinceEpoch - 1,
                      ) |
                      row.dueAt.isBetweenValues(range.start, range.end) |
                      row.completedAt.isBetweenValues(range.start, range.end)),
            ))
            .get();

    final tasks = rows.map(_taskFromRow).toList();
    final withRelations = await _attachRelations(tasks);

    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.writeln(
      'title,status,scheduled_date,due_at,completed_at,cancelled_at,'
      'priority,category,tags,is_subtask,parent_task_title',
    );

    for (final t in withRelations) {
      final parentTitle = t.parentTaskId != null
          ? (await getTask(t.parentTaskId!))?.title ?? ''
          : '';
      final catName = t.category?.name ?? '';
      final tagNames = t.tags.map((tag) => tag.name).join(',');
      String fmtDate(DateTime? dt) => dt != null
          ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
          : '';
      String fmtDateTime(DateTime? dt) => dt != null
          ? '${fmtDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '';

      buf.writeln(
        '"${_csvEscape(t.title)}",${t.status.value},${fmtDate(t.scheduledDate)},'
        '${fmtDateTime(t.dueAt)},${fmtDateTime(t.completedAt)},${fmtDate(t.cancelledAt)},'
        '${t.priority.value},"${_csvEscape(catName)}","${_csvEscape(tagNames)}",'
        '${t.parentTaskId != null},"${_csvEscape(parentTitle)}"',
      );
    }
    return buf.toString();
  }

  String _csvEscape(String s) => s.replaceAll('"', '""');
}
