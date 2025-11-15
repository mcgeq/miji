# period_symptoms - 生理期症状表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `period_symptoms`
- **说明**: 生理期期间的症状记录表，记录每日症状类型和强度
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000011_create_period_symptoms_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 症状记录唯一ID |
| `period_daily_records_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 对应的每日记录ID |
| `symptom_type` | INTEGER | - | NOT NULL | - | 症状类型（枚举值，由应用层维护映射） |
| `intensity` | INTEGER | - | NOT NULL | - | 强度（如 1~5 级） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `period_daily_records` | `period_daily_records_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属每日记录 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_period_symptoms_daily ON period_symptoms(period_daily_records_serial_num);
CREATE INDEX idx_period_symptoms_type ON period_symptoms(symptom_type);
```

## 💡 使用示例

### 为某天添加症状记录

```rust
use entity::period_symptoms;
use sea_orm::*;

let symptom = period_symptoms::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    period_daily_records_serial_num: Set(daily_id.clone()),
    symptom_type: Set(1), // 例如 1=腹痛
    intensity: Set(3),    // 强度 3/5
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = symptom.insert(db).await?;
```

## ⚠️ 注意事项

1. **症状类型映射**：`symptom_type` 为整数，实际含义需在应用层维护表或枚举（如 1=腹痛, 2=头痛）
2. **强度范围**：`intensity` 建议统一约定范围（如 1~5），便于统计和可视化
3. **数据量控制**：长期使用会积累较多记录，可考虑按周期归档

## 🔗 相关表

- [period_daily_records - 生理期每日记录表](./period_daily_records.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
