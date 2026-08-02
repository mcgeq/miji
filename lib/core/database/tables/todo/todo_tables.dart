import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

// ---------------------------------------------------------------------------
// todo_tasks — 待办任务
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_status '
  'ON todo_tasks(user_id, status)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_scheduled '
  'ON todo_tasks(user_id, scheduled_date)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_due '
  'ON todo_tasks(user_id, due_at)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_parent '
  'ON todo_tasks(user_id, parent_task_id)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_deleted '
  'ON todo_tasks(user_id, is_deleted)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_updated '
  'ON todo_tasks(user_id, updated_at)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_recurrence '
  'ON todo_tasks(user_id, recurrence_rule_id)',
)
@TableIndex.sql(
  'CREATE INDEX todo_tasks_user_occurrence '
  'ON todo_tasks(user_id, occurrence_date)',
)
class TodoTasks extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get title => text()();

  TextColumn get notes => text().nullable()();

  /// todo | completed | cancelled
  TextColumn get status => text().withDefault(const Constant('todo'))();

  /// none | low | medium | high
  TextColumn get priority => text().withDefault(const Constant('none'))();

  /// date-only (millisecondsSinceEpoch UTC)
  IntColumn get scheduledDate => integer().nullable()();

  DateTimeColumn get dueAt => dateTime().nullable()();

  TextColumn get categoryId => text().nullable()();

  /// 只支持一层子任务，UI 上不展开更深层级
  TextColumn get parentTaskId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();

  // ---- V1.1 新增 ----

  /// 是否为重复模板任务（模板不进入任务列表）
  BoolColumn get isRecurrenceTemplate =>
      boolean().withDefault(const Constant(false))();

  /// 实例关联的重复规则 ID
  TextColumn get recurrenceRuleId => text().nullable()();

  /// 实例发生日期 (date-only, millisecondsSinceEpoch UTC)
  IntColumn get occurrenceDate => integer().nullable()();

  /// 提醒时间 (绝对时间)
  DateTimeColumn get reminderAt => dateTime().nullable()();

  // ---- V1.2+ Markdown 正文 ----

  /// Markdown 格式的正文内容
  TextColumn get markdownBody => text().nullable()();

  // ---- 同步字段 ----

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'todo_tasks';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// todo_categories — 任务分类
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE UNIQUE INDEX todo_categories_user_name_unique '
  'ON todo_categories(user_id, name) '
  'WHERE is_deleted = 0',
)
class TodoCategories extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get color => text().withDefault(const Constant('#6366F1'))();

  TextColumn get icon => text().withDefault(const Constant('📋'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'todo_categories';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// todo_tags — 任务标签 (V1.1)
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE UNIQUE INDEX todo_tags_user_name_unique '
  'ON todo_tags(user_id, name) '
  'WHERE is_deleted = 0',
)
class TodoTags extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get color => text().withDefault(const Constant('#6366F1'))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'todo_tags';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// todo_task_tags — 任务-标签关联 (V1.1)
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE UNIQUE INDEX todo_task_tags_unique '
  'ON todo_task_tags(task_id, tag_id)',
)
class TodoTaskTags extends Table {
  TextColumn get taskId =>
      text().references(TodoTasks, #id, onDelete: KeyAction.cascade)();

  TextColumn get tagId =>
      text().references(TodoTags, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'todo_task_tags';

  @override
  Set<Column<Object>> get primaryKey => {taskId, tagId};
}

// ---------------------------------------------------------------------------
// todo_recurrence_rules — 重复任务规则 (V1.1)
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE INDEX todo_recurrence_user '
  'ON todo_recurrence_rules(user_id)',
)
class TodoRecurrenceRules extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  /// 关联的模板任务 ID
  TextColumn get templateTaskId => text().references(TodoTasks, #id)();

  /// daily | weekly | monthly | yearly
  TextColumn get frequencyType => text()();

  /// 间隔数，默认 1
  IntColumn get interval_ => integer().withDefault(const Constant(1))();

  /// JSON: 每周规则的星期数组，如 [1,3,5]
  TextColumn get daysOfWeekJson => text().nullable()();

  /// 每月规则的日期
  IntColumn get dayOfMonth => integer().nullable()();

  /// 每年规则的月份
  IntColumn get monthOfYear => integer().nullable()();

  /// 每年规则的日期
  IntColumn get dayOfYear => integer().nullable()();

  /// 规则结束时间
  DateTimeColumn get endsAt => dateTime().nullable()();

  /// 提醒模式: none | absolute-time | due-offset
  TextColumn get reminderMode => text().withDefault(const Constant('none'))();

  /// 提醒时间或偏移配置 (JSON)
  TextColumn get reminderConfigJson => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'todo_recurrence_rules';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
