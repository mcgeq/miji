# period_pms_records - 经前综合征记录表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `period_pms_records`
- **说明**: 经前综合征（PMS）周期记录表，用于记录每次经期前一段时间整体的PMS情况
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000012_create_period_pms_records_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度/精度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | PMS周期记录唯一ID |
| `period_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 对应的经期记录ID（period_records.serial_num） |
| `start_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | PMS 开始时间 |
| `end_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | PMS 结束时间 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

## 🔗 关系说明

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `period_pms_symptoms` | PMS期间记录的具体症状 |

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `period_records` | `period_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属经期记录 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_period_pms_records_period ON period_pms_records(period_serial_num);
CREATE INDEX idx_period_pms_records_start ON period_pms_records(start_date);
```

## 💡 使用示例

### 创建一次 PMS 周期记录

```rust
use entity::period_pms_records;
use sea_orm::*;

let pms = period_pms_records::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    period_serial_num: Set(period_id.clone()),
    start_date: Set(pms_start),
    end_date: Set(pms_end),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = pms.insert(db).await?;
```

## ⚠️ 注意事项

1. **时间范围**：PMS 通常出现在经期前 3~7 天，具体逻辑由业务层决定
2. **与经期关联**：`period_serial_num` 用于将 PMS 周期与具体经期关联，便于整体分析

## 🔗 相关表

- [period_records - 生理期记录表](./period_records.md)
- [period_pms_symptoms - 经前综合征症状表](./period_pms_symptoms.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
