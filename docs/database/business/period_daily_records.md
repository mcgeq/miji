# period_daily_records - 生理期每日记录表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `period_daily_records`
- **说明**: 生理期相关的每日记录表，用于追踪每天的经血量、运动、饮食、睡眠等信息
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000010_create_period_daily_records_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 每日记录唯一ID |
| `period_serial_num` | VARCHAR | 38 | NOT NULL | - | 关联的经期记录ID（period_records.serial_num） |
| `date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 记录日期（通常为当日零点） |
| `flow_level` | VARCHAR | 20 | NULLABLE | NULL | 经血量级别（如 Light/Medium/Heavy） |
| `exercise_intensity` | VARCHAR | 20 | NOT NULL | 'None' | 当天运动强度（None/Light/Moderate/Intense） |
| `sexual_activity` | BOOLEAN | - | NOT NULL | false | 当天是否有性生活 |
| `contraception_method` | VARCHAR | 50 | NULLABLE | NULL | 避孕方式（如 Condom/None 等） |
| `diet` | VARCHAR | 100 | NOT NULL | - | 饮食情况（如 Normal/HighSugar/HighFat 等） |
| `mood` | VARCHAR | 50 | NULLABLE | NULL | 情绪状态（如 Happy/Anxious） |
| `water_intake` | INTEGER | - | NULLABLE | NULL | 饮水量（毫升） |
| `sleep_hours` | INTEGER | - | NULLABLE | NULL | 睡眠时长（小时） |
| `notes` | TEXT | - | NULLABLE | NULL | 其他备注 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `period_symptoms` | 当天记录下的所有症状 |

> 注：虽然实体中未声明与 `period_records` 的 belongs_to 关系，但在业务上可以通过 `period_serial_num` 关联到 `period_records`。

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_period_daily_records_date ON period_daily_records(date);
CREATE INDEX idx_period_daily_records_period ON period_daily_records(period_serial_num);
```

## 💡 使用示例

### 创建每日记录

```rust
use entity::period_daily_records;
use sea_orm::*;

let daily = period_daily_records::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    period_serial_num: Set(period_id.clone()),
    date: Set(Utc::now().into()),
    flow_level: Set(Some("Medium".to_string())),
    exercise_intensity: Set("Light".to_string()),
    sexual_activity: Set(false),
    contraception_method: Set(None),
    diet: Set("Normal".to_string()),
    mood: Set(Some("Calm".to_string())),
    water_intake: Set(Some(1500)),
    sleep_hours: Set(Some(7)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = daily.insert(db).await?;
```

## ⚠️ 注意事项

1. **隐私数据**：本表包含敏感健康数据，访问权限需要严格控制
2. **时间粒度**：如果一天有多次记录，应在业务上决定是否允许或合并
3. **字段值枚举**：flow_level、exercise_intensity、diet、mood 等建议在前端/服务层定义枚举列表

## 🔗 相关表

- [period_records - 生理期记录表](./period_records.md)
- [period_symptoms - 生理期症状表](./period_symptoms.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
