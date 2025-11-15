# todo - 待办事项表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `todo`
- **说明**: 待办事项表，用于管理任务、提醒、子任务等个人/项目事务
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132240_create_todo.rs`

## 📊 表结构

### 状态与优先级枚举

**Status 枚举（存储为 Text）**：
- `NotStarted` - 未开始
- `InProgress` - 进行中
- `Completed` - 已完成
- `Cancelled` - 已取消
- `Overdue` - 逾期

**Priority 枚举（存储为 Text）**：
- `Low` - 低优先级
- `Medium` - 中优先级
- `High` - 高优先级
- `Urgent` - 紧急

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 待办唯一ID |
| `title` | VARCHAR | 200 | NOT NULL | - | 标题 |
| `description` | TEXT | - | NULLABLE | NULL | 详细描述 |
| `due_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 截止时间 |
| `priority` | ENUM(Priority) | - | NOT NULL | 'Medium' | 优先级 |
| `status` | ENUM(Status) | - | NOT NULL | 'NotStarted' | 当前状态 |
| `repeat_period_type` | VARCHAR | 20 | NOT NULL | 'None' | 重复类型 |
| `repeat` | JSON | - | NOT NULL | - | 重复配置（如每天/每周） |
| `completed_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 完成时间 |
| `assignee_id` | VARCHAR | 38 | NULLABLE | NULL | 被指派人ID（成员/用户） |
| `progress` | INTEGER | - | NOT NULL | 0 | 完成进度 0~100 |
| `location` | VARCHAR | 200 | NULLABLE | NULL | 位置（地址/地点名称） |
| `owner_id` | VARCHAR | 38 | FK, NULLABLE | NULL | 所有者用户ID |
| `is_archived` | BOOLEAN | - | NOT NULL | false | 是否归档 |
| `is_pinned` | BOOLEAN | - | NOT NULL | false | 是否置顶 |
| `estimate_minutes` | INTEGER | - | NULLABLE | NULL | 预估耗时（分钟） |
| `reminder_count` | INTEGER | - | NOT NULL | 0 | 已发送提醒次数 |
| `parent_id` | VARCHAR | 38 | NULLABLE | NULL | 父任务ID（子任务用） |
| `subtask_order` | INTEGER | - | NULLABLE | NULL | 子任务排序序号 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |
| `reminder_enabled` | BOOLEAN | - | NOT NULL | true | 是否启用提醒 |
| `reminder_advance_value` | INTEGER | - | NULLABLE | NULL | 提前提醒数值 |
| `reminder_advance_unit` | VARCHAR | 20 | NULLABLE | NULL | 提前提醒单位（分钟/小时/天） |
| `last_reminder_sent_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后一次提醒时间 |
| `reminder_frequency` | VARCHAR | 20 | NULLABLE | NULL | 重复提醒频率（如 EveryDay） |
| `snooze_until` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 贪睡（稍后提醒）到期时间 |
| `reminder_methods` | JSON | - | NULLABLE | NULL | 提醒方式（如 App、Email、SMS） |
| `timezone` | VARCHAR | 50 | NULLABLE | NULL | 任务时区 |
| `smart_reminder_enabled` | BOOLEAN | - | NOT NULL | false | 是否启用智能提醒 |
| `location_based_reminder` | BOOLEAN | - | NOT NULL | false | 是否基于位置提醒 |
| `weather_dependent` | BOOLEAN | - | NOT NULL | false | 是否与天气相关（如晴天才提醒） |
| `priority_boost_enabled` | BOOLEAN | - | NOT NULL | false | 是否启用临近截止时自动提升优先级 |
| `batch_reminder_id` | VARCHAR | 38 | NULLABLE | NULL | 批量提醒ID（归属某个批量提醒任务） |

### repeat / reminder JSON 示例

```json
// repeat
{
  "type": "Weekly",
  "daysOfWeek": [1, 3, 5]
}

// reminder_methods
["App", "Email"]
```

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `attachment` | 待办关联的附件（图片、文件等） |
| HAS_MANY | `reminder` | 辅助提醒记录（旧实现） |
| HAS_MANY | `todo_project` | 待办与项目关联 |
| HAS_MANY | `todo_tag` | 待办与标签关联 |

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `users` | `owner_id` → `serial_num` | ON DELETE: SET NULL | 任务所有者 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `project` | `todo_project` | 任务与项目的关联 |
| MANY_TO_MANY | `tag` | `todo_tag` | 任务与标签的关联 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_todo_owner ON todo(owner_id);
CREATE INDEX idx_todo_status ON todo(status);
CREATE INDEX idx_todo_priority ON todo(priority);
CREATE INDEX idx_todo_due_at ON todo(due_at);
CREATE INDEX idx_todo_parent ON todo(parent_id);
CREATE INDEX idx_todo_archived ON todo(is_archived, is_pinned);
```

## 💡 使用示例

### 创建一个普通待办

```rust
use entity::todo;
use sea_orm::*;

let task = todo::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    title: Set("支付信用卡账单".to_string()),
    description: Set(Some("本月15号前支付信用卡".to_string())),
    due_at: Set(Utc::now() + chrono::Duration::days(3)),
    priority: Set(todo::Priority::High),
    status: Set(todo::Status::NotStarted),
    repeat_period_type: Set("None".to_string()),
    repeat: Set(json!({"type": "None"})),
    progress: Set(0),
    owner_id: Set(Some(user_id.clone())),
    is_archived: Set(false),
    is_pinned: Set(false),
    reminder_enabled: Set(true),
    reminder_advance_value: Set(Some(1)),
    reminder_advance_unit: Set(Some("Day".to_string())),
    timezone: Set(Some("Asia/Shanghai".to_string())),
    smart_reminder_enabled: Set(false),
    location_based_reminder: Set(false),
    weather_dependent: Set(false),
    priority_boost_enabled: Set(true),
    reminder_methods: Set(Some(json!(["App"]))),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = task.insert(db).await?;
```

### 标记任务为完成

```rust
let task = Todo::find_by_id(task_id)
    .one(db)
    .await?
    .unwrap();

let mut active: todo::ActiveModel = task.into();
active.status = Set(todo::Status::Completed);
active.completed_at = Set(Some(Utc::now().into()));
active.progress = Set(100);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 查询今天到期且未完成的任务

```rust
let today = Utc::now().date_naive();

let tasks = Todo::find()
    .filter(todo::Column::DueAt.date().eq(today))
    .filter(todo::Column::Status.ne(todo::Status::Completed))
    .filter(todo::Column::IsArchived.eq(false))
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **状态与进度一致性**: `status = Completed` 时，`progress` 应为 100 且 `completed_at` 有值
2. **重复任务**: `repeat` 和 `repeat_period_type` 仅描述规则，实际生成下一次任务需业务层处理
3. **提醒逻辑**: 提醒字段较多，实际发送提醒由应用服务统一调度
4. **归档与删除**: 建议使用 `is_archived` 做归档，避免物理删除影响统计
5. **子任务关系**: `parent_id` 用于子任务结构，更新父任务状态时要考虑子任务完成情况

## 🔗 相关表

- [users - 用户表](../core/users.md)
- [attachment - 附件表](../system/attachment.md)
- [reminder - 提醒表](./reminder.md)
- [project - 项目表](./project.md)
- [tag - 标签表](./tag.md)
- [todo_project - 任务项目关联表](../association/todo_project.md)
- [todo_tag - 任务标签关联表](../association/todo_tag.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
