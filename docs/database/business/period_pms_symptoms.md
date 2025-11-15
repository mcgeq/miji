# period_pms_symptoms - 经前综合征症状表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `period_pms_symptoms`
- **说明**: 经前综合征（PMS）症状记录表，用于记录 PMS 周期内的具体症状和强度
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000013_create_period_pms_symptoms_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 症状记录唯一ID |
| `period_pms_records_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属 PMS 周期ID |
| `symptom_type` | VARCHAR | 50 | NOT NULL | - | 症状类型（如 Irritability, Anxiety） |
| `intensity` | VARCHAR | 20 | NOT NULL | - | 强度（如 Mild/Moderate/Severe） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `period_pms_records` | `period_pms_records_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属 PMS 周期 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_period_pms_symptoms_period ON period_pms_symptoms(period_pms_records_serial_num);
CREATE INDEX idx_period_pms_symptoms_type ON period_pms_symptoms(symptom_type);
```

## 💡 使用示例

### 为 PMS 周期添加症状

```rust
use entity::period_pms_symptoms;
use sea_orm::*;

let symptom = period_pms_symptoms::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    period_pms_records_serial_num: Set(pms_id.clone()),
    symptom_type: Set("Irritability".to_string()),
    intensity: Set("Moderate".to_string()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = symptom.insert(db).await?;
```

## ⚠️ 注意事项

1. **症状类型和强度**：建议在应用层定义枚举表，避免字符串不一致
2. **统计分析**：可按 `symptom_type` 聚合分析 PMS 模式

## 🔗 相关表

- [period_pms_records - 经前综合征记录表](./period_pms_records.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
