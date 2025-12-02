# batch_reminders - 批量提醒任务表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `batch_reminders`
- **说明**: 批量提醒任务表，用于记录一次性或定时批量发送提醒（如针对多个账单/任务统一推送）
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000009_create_batch_reminders_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 批量提醒任务唯一ID |
| `name` | VARCHAR | 100 | NOT NULL | - | 任务名称（如「月底账单提醒批次」） |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 描述 |
| `scheduled_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 计划执行时间 |
| `status` | VARCHAR | 20 | NOT NULL | 'Pending' | 执行状态 |
| `total_count` | INTEGER | - | NOT NULL | 0 | 计划发送的提醒数量 |
| `sent_count` | INTEGER | - | NOT NULL | 0 | 已成功发送的数量 |
| `failed_count` | INTEGER | - | NOT NULL | 0 | 发送失败的数量 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**status 约定值**：
- `Pending`: 待执行
- `Running`: 执行中
- `Completed`: 执行完成
- `Failed`: 批量任务执行失败

## 🔗 关系说明

当前实体未声明关系，但在业务上通常与以下表关联：

- `bil_reminder.batch_reminder_id` → 批量任务生成的多个账单提醒
- `reminder.batch_reminder_id`（未来可能扩展）

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_batch_reminders_status ON batch_reminders(status);
CREATE INDEX idx_batch_reminders_scheduled ON batch_reminders(scheduled_at);
```

## 💡 使用示例

### 创建批量提醒任务

```rust
use entity::batch_reminders;
use sea_orm::*;

let batch = batch_reminders::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("月底账单提醒".to_string()),
    description: Set(Some("为所有启用的账单提醒发送本月通知".to_string())),
    scheduled_at: Set(scheduled_time),
    status: Set("Pending".to_string()),
    total_count: Set(0),
    sent_count: Set(0),
    failed_count: Set(0),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = batch.insert(db).await?;
```

### 执行批量任务（伪代码）

```rust
let batch = BatchReminders::find_by_id(batch_id)
    .one(db)
    .await?
    .unwrap();

let mut active: batch_reminders::ActiveModel = batch.into();
active.status = Set("Running".to_string());
active.update(db).await?;

let reminders = BilReminder::find()
    .filter(bil_reminder::Column::Enabled.eq(true))
    .all(db)
    .await?;

let mut sent = 0;
let mut failed = 0;

for r in reminders {
    // 实际发送逻辑...
    let success = send_reminder(&r).await;
    if success { sent += 1; } else { failed += 1; }
}

active.sent_count = Set(sent);
active.failed_count = Set(failed);
active.total_count = Set(sent + failed);
active.status = Set("Completed".to_string());
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

## ⚠️ 注意事项

1. **任务幂等性**: 执行批量任务时需确保不会重复发送（可通过状态和时间窗口控制）
2. **异常处理**: `failed_count` 的记录可以配合日志用于后续补偿发送
3. **调度系统**: `scheduled_at` 一般由任务调度器（如 cron）轮询触发
4. **性能考虑**: 大量提醒发送时建议分批处理，并考虑限流策略

## 🔗 相关表

- [bil_reminder - 账单提醒表](./bil_reminder.md)
- [reminder - 通用提醒表](./reminder.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
