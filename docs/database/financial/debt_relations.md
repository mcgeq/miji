# debt_relations - 债务关系表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `debt_relations`
- **说明**: 成员间债务关系汇总表，存储在某个账本中，两个成员之间当前净欠款金额
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000005_create_debt_relations_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 债务关系唯一ID |
| `family_ledger_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属账本ID |
| `creditor_member_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 债权人成员ID（别人欠他） |
| `debtor_member_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 债务人成员ID（他欠别人） |
| `amount` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 当前净欠款金额（>0 表示 debtor 欠 creditor） |
| `currency` | VARCHAR | 3 | NOT NULL | - | 货币代码 |
| `status` | VARCHAR | 20 | NOT NULL | 'Active' | 债务状态 |
| `last_updated_by` | VARCHAR | 38 | NOT NULL | - | 最后更新人ID（通常为成员或用户ID） |
| `last_calculated_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 最后一次计算时间 |
| `settled_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 完全结清时间 |
| `notes` | VARCHAR | 500 | NULLABLE | NULL | 备注 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**status 约定值**：
- `Active`: 有未结清债务
- `Settled`: 债务已结清
- `Archived`: 已归档（历史记录）

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属账本 |
| BELONGS_TO | `family_member` | `creditor_member_serial_num` → `serial_num` | ON DELETE: CASCADE | 债权人 |
| BELONGS_TO | `family_member` | `debtor_member_serial_num` → `serial_num` | ON DELETE: CASCADE | 债务人 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_debt_ledger ON debt_relations(family_ledger_serial_num);
CREATE INDEX idx_debt_creditor ON debt_relations(creditor_member_serial_num);
CREATE INDEX idx_debt_debtor ON debt_relations(debtor_member_serial_num);
CREATE INDEX idx_debt_status ON debt_relations(status);

-- 对 (ledger, creditor, debtor) 建立唯一索引，保证两人之间只有一条关系记录
CREATE UNIQUE INDEX idx_debt_unique_pair 
ON debt_relations(family_ledger_serial_num, creditor_member_serial_num, debtor_member_serial_num);
```

## 💡 使用示例

### 更新两人之间的债务关系（伪代码）

```rust
// 假设已经计算出 delta_amount (>0 表示 debtor 欠 creditor 增加，<0 表示减少)
let existing = DebtRelations::find()
    .filter(debt_relations::Column::FamilyLedgerSerialNum.eq(ledger_id.clone()))
    .filter(debt_relations::Column::CreditorMemberSerialNum.eq(creditor_id.clone()))
    .filter(debt_relations::Column::DebtorMemberSerialNum.eq(debtor_id.clone()))
    .one(db)
    .await?;

if let Some(relation) = existing {
    let mut active: debt_relations::ActiveModel = relation.into();
    let new_amount = active.amount.clone().unwrap() + delta_amount;

    active.amount = Set(new_amount);
    active.last_updated_by = Set(operator_id.clone());
    active.last_calculated_at = Set(Utc::now().into());

    if new_amount.is_zero() {
        active.status = Set("Settled".to_string());
        active.settled_at = Set(Some(Utc::now().into()));
    } else {
        active.status = Set("Active".to_string());
        active.settled_at = Set(None);
    }

    active.updated_at = Set(Some(Utc::now().into()));
    active.update(db).await?;
} else {
    // 新建一条关系
    let relation = debt_relations::ActiveModel {
        serial_num: Set(McgUuid::new().to_string()),
        family_ledger_serial_num: Set(ledger_id.clone()),
        creditor_member_serial_num: Set(creditor_id.clone()),
        debtor_member_serial_num: Set(debtor_id.clone()),
        amount: Set(delta_amount),
        currency: Set("CNY".to_string()),
        status: Set("Active".to_string()),
        last_updated_by: Set(operator_id.clone()),
        last_calculated_at: Set(Utc::now().into()),
        created_at: Set(Utc::now().into()),
        ..Default::default()
    };

    relation.insert(db).await?;
}
```

### 查询某成员的净负债/净应收

```rust
// 作为债务人
let owed_to_others = DebtRelations::find()
    .filter(debt_relations::Column::FamilyLedgerSerialNum.eq(ledger_id.clone()))
    .filter(debt_relations::Column::DebtorMemberSerialNum.eq(member_id.clone()))
    .filter(debt_relations::Column::Status.eq("Active"))
    .all(db)
    .await?;

// 作为债权人
let others_owed_to_me = DebtRelations::find()
    .filter(debt_relations::Column::FamilyLedgerSerialNum.eq(ledger_id.clone()))
    .filter(debt_relations::Column::CreditorMemberSerialNum.eq(member_id.clone()))
    .filter(debt_relations::Column::Status.eq("Active"))
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **金额方向**: `amount` 始终为正数，方向由 creditor/debtor 决定
2. **唯一关系**: 每个账本内，任意两成员之间应只有一条关系记录（通过唯一索引保证）
3. **对称性**: A→B 的欠款与 B→A 的欠款不重复记录，应做净额合并
4. **结算行为**: 完成一次结算后，应重新计算并更新所有相关关系
5. **货币一致性**: 同一账本内的债务通常使用账本的基础货币

## 🔗 相关表

- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [family_member - 家庭成员表](../core/family_member.md)
- [split_records - 分摊记录表](./split_records.md)
- [settlement_records - 结算记录表](./settlement_records.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
