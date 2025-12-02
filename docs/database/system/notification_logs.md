# notification_logs - 通知日志表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `notification_logs`
- **说明**: 通知发送日志表，用于记录每一次发送通知的结果（成功/失败等）
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132252_create_notification_logs.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 通知日志唯一ID |
| `reminder_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 对应的 `reminder` 记录ID |
| `notification_type` | VARCHAR | 50 | NOT NULL | - | 通知类型（App/Email/SMS 等） |
| `status` | VARCHAR | 20 | NOT NULL | 'Pending' | 状态（Pending/Sent/Failed 等） |
| `sent_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 实际发送时间 |
| `error_message` | VARCHAR | 500 | NULLABLE | NULL | 错误信息（仅失败时） |
| `retry_count` | INTEGER | - | NOT NULL | 0 | 重试次数 |
| `last_retry_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后一次重试时间 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `reminder` | `reminder_serial_num` → `serial_num` | ON DELETE: CASCADE | 对应的提醒记录 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_notification_logs_reminder 
  ON notification_logs(reminder_serial_num);

CREATE INDEX idx_notification_logs_status 
  ON notification_logs(status);
```

## 💡 使用示例

### 创建通知日志

```rust
use entity::notification_logs;
use sea_orm::*;

let log = notification_logs::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    reminder_serial_num: Set(reminder_id.clone()),
    notification_type: Set("App".to_string()),
    status: Set("Pending".to_string()),
    retry_count: Set(0),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = log.insert(db).await?;
```

### 更新为已发送

```rust
let log = NotificationLogs::find_by_id(log_id)
    .one(db)
    .await?
    .unwrap();

let mut active: notification_logs::ActiveModel = log.into();
active.status = Set("Sent".to_string());
active.sent_at = Set(Some(Utc::now().into()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

## ⚠️ 注意事项

1. **与 reminder 联动**：通常 `notification_logs` 与 `reminder` 一起使用，记录发送尝试和结果
2. **排错与审计**：失败日志中的 `error_message` 对排查问题非常关键
3. **清理策略**：可以按时间或数量定期清理旧日志，避免表无限增长

## 🔗 相关表

- [reminder - 通用提醒表](../business/reminder.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
