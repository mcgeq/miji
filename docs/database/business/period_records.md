# period_records - 生理期记录表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `period_records`
- **说明**: 记录每次完整的经期周期（从开始到结束）的基础信息
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000002_create_period_records_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 经期记录唯一ID |
| `notes` | VARCHAR | 500 | NULLABLE | NULL | 此次经期的备注（心情、特殊情况等） |
| `start_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 本次经期开始时间 |
| `end_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 本次经期结束时间 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 记录创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**：
- `start_date` / `end_date` 用于计算本次经期长度
- 多次记录之间的间隔用于推算周期长度，配合 `period_settings` 使用

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `period_pms_records` | 本次经期周期内的经前综合征记录 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_period_records_start ON period_records(start_date);
CREATE INDEX idx_period_records_end ON period_records(end_date);
```

## 💡 使用示例

### 创建一次经期记录

```rust
use entity::period_records;
use sea_orm::*;

let record = period_records::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    start_date: Set(start_dt),
    end_date: Set(end_dt),
    notes: Set(Some("本次经期略有提前".to_string())),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = record.insert(db).await?;
```

### 查询最近 N 次经期

```rust
let recent_records = PeriodRecords::find()
    .order_by_desc(period_records::Column::StartDate)
    .limit(6)
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **时间精度**：推荐使用日期（当天零点）或用户输入的实际时间，一旦保存不要随意改动
2. **与设置联动**：周期预测逻辑通常在 `period_settings` 中配置，本表提供历史数据基础
3. **数据隐私**：属于高度隐私信息，API 返回和前端展示时需注意保护

## 🔗 相关表

- [period_pms_records - 经前综合征记录表](./period_pms_records.md)
- [period_daily_records - 生理期每日记录表](./period_daily_records.md)
- [period_settings - 生理期设置表](./period_settings.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
