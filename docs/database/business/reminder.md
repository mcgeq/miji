# reminder - 通用提醒表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `reminder`
- **说明**: 通用提醒表，主要用于为 `todo` 待办生成历史提醒记录（老实现，部分能力已被 todo 上的扩展字段取代）
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132245_create_reminder.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 提醒记录唯一ID |
| `todo_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 关联的待办ID |
| `remind_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 计划提醒时间 |
| `type` | INTEGER | - | NULLABLE | NULL | 提醒类型（保留字段，枚举值由业务层定义） |
| `is_sent` | BOOLEAN | - | NOT NULL | false | 是否已发送成功 |
| `reminder_method` | VARCHAR | 50 | NULLABLE | NULL | 实际提醒方式（App / Email / SMS 等） |
| `retry_count` | INTEGER | - | NOT NULL | 0 | 发送失败后的重试次数 |
| `last_retry_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后一次重试时间 |
| `snooze_count` | INTEGER | - | NOT NULL | 0 | 贪睡（稍后提醒）次数 |
| `escalation_level` | INTEGER | - | NOT NULL | 0 | 升级级别（0=无，1=轻度，2=强提醒等） |
| `notification_id` | VARCHAR | 100 | NULLABLE | NULL | 对应系统通知ID（如本地通知/推送ID） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `todo` | `todo_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属待办任务 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_reminder_todo ON reminder(todo_serial_num);
CREATE INDEX idx_reminder_remind_at ON reminder(remind_at);
CREATE INDEX idx_reminder_sent ON reminder(is_sent);
```

## 💡 使用示例

> 说明：目前新提醒字段更多集中在 `todo` 表本身，`reminder` 更多扮演历史记录或扩展用途。

### 创建一次性提醒记录

```rust
use entity::reminder;
use sea_orm::*;

let r = reminder::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    todo_serial_num: Set(todo_id.clone()),
    remind_at: Set(next_time),
    r#type: Set(Some(0)),
    is_sent: Set(false),
    reminder_method: Set(Some("App".to_string())),
    retry_count: Set(0),
    snooze_count: Set(0),
    escalation_level: Set(0),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = r.insert(db).await?;
```

### 标记提醒为已发送

```rust
let r = Reminder::find_by_id(reminder_id)
    .one(db)
    .await?
    .unwrap();

let mut active: reminder::ActiveModel = r.into();
active.is_sent = Set(true);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 重试失败的提醒

```rust
let failed = Reminder::find()
    .filter(reminder::Column::IsSent.eq(false))
    .filter(reminder::Column::RetryCount.lt(3))
    .all(db)
    .await?;

for r in failed {
    // 发送逻辑...
    let mut active: reminder::ActiveModel = r.into();
    active.retry_count = Set(active.retry_count.unwrap() + 1);
    active.last_retry_at = Set(Some(Utc::now().into()));
    active.updated_at = Set(Some(Utc::now().into()));
    active.update(db).await?;
}
```

## ⚠️ 注意事项

1. **新旧方案共存**：新的提醒配置主要在 `todo` 表上，本表可作为历史记录或增强型提醒日志
2. **清理策略**：长期积累的提醒记录较多时，建议做归档/清理策略
3. **时区处理**：`remind_at` 应以 UTC 存储，在触发和展示时根据用户时区转换
4. **幂等性**：发送提醒时，应确保同一 `reminder` 不被重复执行（检查 `is_sent`/`retry_count`）

## 🔗 相关表

- [todo - 待办事项表](./todo.md)
- [batch_reminders - 批量提醒任务表](./batch_reminders.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
