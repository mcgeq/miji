# split_records - 分摊记录表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `split_records`
- **说明**: 费用分摊明细表，用于记录每条交易在成员之间如何分摊
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000004_create_split_records_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 分摊记录唯一ID |
| `transaction_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 关联的交易ID |
| `family_ledger_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属账本ID |
| `split_rule_serial_num` | VARCHAR | 38 | FK, NULLABLE | NULL | 使用的分摊规则ID（可选） |
| `payer_member_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 实际付款成员ID |
| `owe_member_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 应承担费用的成员ID |
| `total_amount` | DECIMAL | (16, 4) | NOT NULL | - | 交易总金额（或该分摊上下文中的总额） |
| `split_amount` | DECIMAL | (16, 4) | NOT NULL | - | 该成员应承担的金额 |
| `split_percentage` | DECIMAL | (16, 4) | NULLABLE | NULL | 分摊比例（0~1），可选 |
| `currency` | VARCHAR | 3 | NOT NULL | - | 货币代码 |
| `status` | VARCHAR | 20 | NOT NULL | 'Pending' | 分摊状态 |
| `split_type` | VARCHAR | 20 | NOT NULL | 'Normal' | 分摊类型 |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 描述 |
| `notes` | TEXT | NULLABLE | NULL | 备注 |
| `confirmed_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 确认时间 |
| `paid_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 实际支付时间 |
| `due_date` | DATE | - | NULLABLE | NULL | 应还日期 |
| `reminder_sent` | BOOLEAN | - | NOT NULL | false | 是否已发送提醒 |
| `last_reminder_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后一次提醒时间 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**status 约定值**：
- `Pending`: 待确认/待支付
- `Confirmed`: 已确认但未支付
- `Paid`: 已支付
- `Cancelled`: 已取消

**split_type 约定值**：
- `Normal`: 普通分摊
- `Adjustment`: 调整记录
- `Settlement`: 结算生成的记录

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `transactions` | `transaction_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属交易 |
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE | 所属账本 |
| BELONGS_TO | `split_rules` | `split_rule_serial_num` → `serial_num` | ON DELETE: SET NULL | 使用的分摊规则 |
| BELONGS_TO | `family_member` | `payer_member_serial_num` → `serial_num` | ON DELETE: CASCADE | 付款人 |
| BELONGS_TO | `family_member` | `owe_member_serial_num` → `serial_num` | ON DELETE: CASCADE | 欠款人 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_split_records_tx ON split_records(transaction_serial_num);
CREATE INDEX idx_split_records_ledger ON split_records(family_ledger_serial_num);
CREATE INDEX idx_split_records_payer ON split_records(payer_member_serial_num);
CREATE INDEX idx_split_records_owe ON split_records(owe_member_serial_num);
CREATE INDEX idx_split_records_status ON split_records(status);
```

## 💡 使用示例

### 根据规则生成分摊记录（伪代码示例）

```rust
// 假设已计算出每个成员的 split_amount
for (member_id, split_amount) in member_splits {
    let record = split_records::ActiveModel {
        serial_num: Set(McgUuid::new().to_string()),
        transaction_serial_num: Set(tx_id.clone()),
        family_ledger_serial_num: Set(ledger_id.clone()),
        split_rule_serial_num: Set(Some(rule_id.clone())),
        payer_member_serial_num: Set(payer_id.clone()),
        owe_member_serial_num: Set(member_id.clone()),
        total_amount: Set(total_amount),
        split_amount: Set(split_amount),
        split_percentage: Set(Some(split_amount / total_amount)),
        currency: Set("CNY".to_string()),
        status: Set("Pending".to_string()),
        split_type: Set("Normal".to_string()),
        reminder_sent: Set(false),
        created_at: Set(Utc::now().into()),
        ..Default::default()
    };

    record.insert(db).await?;
}
```

### 查询某成员的未支付分摊

```rust
let pending_for_member = SplitRecords::find()
    .filter(split_records::Column::OweMemberSerialNum.eq(member_id.clone()))
    .filter(split_records::Column::Status.ne("Paid"))
    .all(db)
    .await?;
```

### 标记分摊为已支付

```rust
let record = SplitRecords::find_by_id(record_id)
    .one(db)
    .await?
    .unwrap();

let mut active: split_records::ActiveModel = record.into();
active.status = Set("Paid".to_string());
active.paid_at = Set(Some(Utc::now().into()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 发送提醒后更新状态

```rust
let record = SplitRecords::find_by_id(record_id)
    .one(db)
    .await?
    .unwrap();

let mut active: split_records::ActiveModel = record.into();
active.reminder_sent = Set(true);
active.last_reminder_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

## ⚠️ 注意事项

1. **金额一致性**: 对于同一笔交易，所有 `split_amount` 之和应等于交易金额
2. **状态同步**: 变更分摊状态时，应同步更新成员的债务和余额
3. **规则可选**: `split_rule_serial_num` 可为空，表示手工调整的分摊
4. **时间字段**: `confirmed_at`、`paid_at`、`due_date` 对于统计和提醒非常重要，应在业务流程中正确维护
5. **删除行为**: 删除交易或账本会级联删除分摊记录，注意对统计的影响

## 🔗 相关表

- [split_rules - 分摊规则表](./split_rules.md)
- [transactions - 交易记录表](../core/transactions.md)
- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [family_member - 家庭成员表](../core/family_member.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
