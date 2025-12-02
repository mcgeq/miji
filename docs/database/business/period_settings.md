# period_settings - 生理期设置表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `period_settings`
- **说明**: 生理期相关设置表，用于存储用户的平均周期、提醒偏好、数据分析开关等
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000014_create_period_settings_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 设置记录唯一ID（可与用户绑定） |
| `average_cycle_length` | INTEGER | - | NOT NULL | 28 | 平均周期长度（天） |
| `average_period_length` | INTEGER | - | NOT NULL | 5 | 平均经期长度（天） |
| `period_reminder` | BOOLEAN | - | NOT NULL | true | 是否开启经期开始提醒 |
| `ovulation_reminder` | BOOLEAN | - | NOT NULL | false | 是否开启排卵期提醒 |
| `pms_reminder` | BOOLEAN | - | NOT NULL | false | 是否开启 PMS 提醒 |
| `reminder_days` | INTEGER | - | NOT NULL | 3 | 提前多少天提醒（统一设置） |
| `data_sync` | BOOLEAN | - | NOT NULL | false | 是否允许数据同步/云备份 |
| `analytics` | BOOLEAN | - | NOT NULL | false | 是否开启统计分析功能（如周期预测） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);
```

> 如果未来支持多用户，每个用户会有一条 `period_settings`，则建议在上层逻辑中用 `serial_num` 映射用户ID，或者通过额外外键字段关联 `users`。

## 💡 使用示例

### 创建默认设置

```rust
use entity::period_settings;
use sea_orm::*;

let settings = period_settings::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    average_cycle_length: Set(28),
    average_period_length: Set(5),
    period_reminder: Set(true),
    ovulation_reminder: Set(false),
    pms_reminder: Set(false),
    reminder_days: Set(3),
    data_sync: Set(false),
    analytics: Set(true),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = settings.insert(db).await?;
```

### 更新提醒偏好

```rust
let settings = PeriodSettings::find_by_id(settings_id)
    .one(db)
    .await?
    .unwrap();

let mut active: period_settings::ActiveModel = settings.into();
active.period_reminder = Set(true);
active.ovulation_reminder = Set(true);
active.pms_reminder = Set(true);
active.reminder_days = Set(5);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

## ⚠️ 注意事项

1. **预测逻辑依赖**：周期预测、PMS 提醒等都依赖 `average_cycle_length` 和 `average_period_length`，修改后应重新计算
2. **隐私与授权**：`data_sync` 和 `analytics` 涉及数据上传与分析，需用户明确授权
3. **多用户场景**：如果未来一台设备支持多个用户，需在上层增加用户外键或映射逻辑

## 🔗 相关表

- [period_records - 生理期记录表](./period_records.md)
- [period_daily_records - 生理期每日记录表](./period_daily_records.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
