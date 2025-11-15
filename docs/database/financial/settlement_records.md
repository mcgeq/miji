# settlement_records - 结算记录表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `settlement_records`
- **说明**: 结算记录表，用于记录每次账本结算的周期、参与成员、优化转账方案等信息
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000006_create_settlement_records_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 结算记录唯一ID |
| `family_ledger_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属账本ID |
| `settlement_type` | VARCHAR | 20 | NOT NULL | 'Manual' | 结算类型 |
| `period_start` | DATE | - | NOT NULL | - | 结算周期开始日期 |
| `period_end` | DATE | - | NOT NULL | - | 结算周期结束日期 |
| `total_amount` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 结算涉及的总金额 |
| `currency` | VARCHAR | 3 | NOT NULL | - | 货币代码 |
| `participant_members` | JSON | - | NOT NULL | - | 参与结算的成员列表及其金额 |
| `settlement_details` | JSON | - | NOT NULL | - | 结算明细，包括谁欠谁多少 |
| `optimized_transfers` | JSON | - | NULLABLE | NULL | 优化后的转账方案 |
| `status` | VARCHAR | 20 | NOT NULL | 'Pending' | 结算状态 |
| `initiated_by` | VARCHAR | 38 | FK, NOT NULL | - | 发起人成员ID |
| `completed_by` | VARCHAR | 38 | FK, NULLABLE | NULL | 完成人成员ID |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 描述 |
| `notes` | TEXT | NULLABLE | NULL | 备注 |
| `completed_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 完成时间 |
| `cancelled_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 取消时间 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**settlement_type 约定值**：
- `Manual`: 手动结算
- `Auto`: 自动结算（根据账本设置周期触发）
- `Partial`: 部分结算

**status 约定值**：
- `Pending`: 已创建但未执行/确认
- `Completed`: 结算已完成
- `Cancelled`: 结算已取消

**participant_members 示例**：
```json
{
  "member1": { "name": "张三", "net": 100.0 },
  "member2": { "name": "李四", "net": -60.0 },
  "member3": { "name": "王五", "net": -40.0 }
}
```

**settlement_details 示例**：
```json
{
  "pairs": [
    { "from": "member2", "to": "member1", "amount": 60.0 },
    { "from": "member3", "to": "member1", "amount": 40.0 }
  ]
}
```

**optimized_transfers 示例**：
```json
{
  "transfers": [
    { "from": "member2", "to": "member1", "amount": 80.0 },
    { "from": "member3", "to": "member2", "amount": 20.0 }
  ]
}
```

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属账本 |
| BELONGS_TO | `family_member` | `initiated_by` → `serial_num` | ON DELETE: RESTRICT | 发起人 |
| BELONGS_TO | `family_member` | `completed_by` → `serial_num` | ON DELETE: SET NULL | 完成人 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_settlement_ledger ON settlement_records(family_ledger_serial_num);
CREATE INDEX idx_settlement_status ON settlement_records(status);
CREATE INDEX idx_settlement_period ON settlement_records(period_start, period_end);
CREATE INDEX idx_settlement_initiated_by ON settlement_records(initiated_by);
```

## 💡 使用示例

### 创建结算记录（仅保存方案，不立即执行）

```rust
use entity::settlement_records;
use sea_orm::*;

let record = settlement_records::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    family_ledger_serial_num: Set(ledger_id.clone()),
    settlement_type: Set("Manual".to_string()),
    period_start: Set(period_start),
    period_end: Set(period_end),
    total_amount: Set(total_amount),
    currency: Set("CNY".to_string()),
    participant_members: Set(participants_json),
    settlement_details: Set(details_json),
    optimized_transfers: Set(Some(optimized_json)),
    status: Set("Pending".to_string()),
    initiated_by: Set(initiator_id.clone()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = record.insert(db).await?;
```

### 完成结算

```rust
let record = SettlementRecords::find_by_id(record_id)
    .one(db)
    .await?
    .unwrap();

let mut active: settlement_records::ActiveModel = record.into();
active.status = Set("Completed".to_string());
active.completed_by = Set(Some(completer_id.clone()));
active.completed_at = Set(Some(Utc::now().into()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 查询账本历史结算记录

```rust
let records = SettlementRecords::find()
    .filter(settlement_records::Column::FamilyLedgerSerialNum.eq(ledger_id.clone()))
    .order_by_desc(settlement_records::Column::PeriodEnd)
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **快照数据**: 结算记录应视为当时状态的快照，不应随之后变动而修改
2. **不可逆性**: 已完成的结算应尽量避免修改，如需变更建议新增一条调整记录
3. **与债务关系联动**: 完成结算后需根据 `settlement_details` 和 `optimized_transfers` 更新 `debt_relations`
4. **周期覆盖**: `period_start` 和 `period_end` 应与账本的结算周期匹配，避免重叠和空档
5. **数据量控制**: 长期使用后结算记录可能较多，可考虑归档策略

## 🔗 相关表

- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [family_member - 家庭成员表](../core/family_member.md)
- [debt_relations - 债务关系表](./debt_relations.md)
- [split_records - 分摊记录表](./split_records.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
