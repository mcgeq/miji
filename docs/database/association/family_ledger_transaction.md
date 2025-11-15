# family_ledger_transaction - 账本交易关联表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `family_ledger_transaction`
- **说明**: 家庭账本与交易记录的多对多关联表，用于将一条交易归属到一个或多个家庭账本
- **主键**: 复合主键 (`family_ledger_serial_num`, `transaction_serial_num`)
- **创建迁移**: `m20250803_132227_create_family_ledger_transaction.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `family_ledger_serial_num` | VARCHAR | 38 | PK, FK, NOT NULL | - | 账本ID，外键到 `family_ledger.serial_num` |
| `transaction_serial_num` | VARCHAR | 38 | PK, FK, NOT NULL | - | 交易ID，外键到 `transactions.serial_num` |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- 复合主键确保同一账本与同一交易之间只有一条关联记录
- 支持以下场景：
  - 一条交易只属于一个账本（常见）
  - 一条交易同时分摊到多个账本（高级用法）

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 所属家庭账本 |
| BELONGS_TO | `transactions` | `transaction_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 关联的交易记录 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `family_ledger` ↔ `transactions` | `family_ledger_transaction` | 一个账本可以有多条交易，一条交易也可以属于多个账本 |

## 📑 索引建议

```sql
-- 复合主键（自动创建）
PRIMARY KEY (family_ledger_serial_num, transaction_serial_num)

-- 单列索引（便于按账本或按交易查询）
CREATE INDEX idx_flt_ledger 
ON family_ledger_transaction(family_ledger_serial_num);

CREATE INDEX idx_flt_transaction 
ON family_ledger_transaction(transaction_serial_num);
```

## 💡 使用示例

### 将交易添加到账本

```rust
use entity::family_ledger_transaction;
use sea_orm::*;

let assoc = family_ledger_transaction::ActiveModel {
    family_ledger_serial_num: Set(ledger_id.clone()),
    transaction_serial_num: Set(transaction_id.clone()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = assoc.insert(db).await?;
```

### 查询账本的所有交易

```rust
use entity::{family_ledger_transaction, transactions};

let txs = Transactions::find()
    .inner_join(FamilyLedgerTransaction)
    .filter(family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .all(db)
    .await?;
```

### 查询某交易属于哪些账本

```rust
use entity::{family_ledger_transaction, family_ledger};

let ledgers = FamilyLedger::find()
    .inner_join(FamilyLedgerTransaction)
    .filter(family_ledger_transaction::Column::TransactionSerialNum.eq(transaction_id))
    .all(db)
    .await?;
```

### 从账本中移除交易

```rust
use entity::family_ledger_transaction;

FamilyLedgerTransaction::delete_many()
    .filter(family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .filter(family_ledger_transaction::Column::TransactionSerialNum.eq(transaction_id))
    .exec(db)
    .await?;
```

### 统计账本的交易数量

```rust
use entity::family_ledger_transaction;

let tx_count = FamilyLedgerTransaction::find()
    .filter(family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .count(db)
    .await?;
```

## ⚠️ 注意事项

1. **复合主键**: 使用 (`family_ledger_serial_num`, `transaction_serial_num`) 作为主键，无单独 `serial_num` 字段
2. **唯一性**: 不需额外唯一索引，复合主键已保证唯一
3. **级联删除**: 删除账本或交易会自动删除关联记录
4. **计数维护**: 建议在服务层中更新 `family_ledger.transactions` 计数字段
5. **多账本交易**: 如果允许一条交易属于多个账本，汇总统计时要注意去重
6. **审计日志**: 添加或移除关联时建议记录审计日志

## 🔄 业务流程

### 交易入账流程
```
1. 创建交易记录 (transactions)
2. 为每个相关账本插入 family_ledger_transaction 记录
3. 更新各账本的 transactions 计数
4. 更新账户余额及成员分摊信息
```

### 删除交易流程（软删除 + 解绑）
```
1. 将 transactions.is_deleted 设置为 true
2. 删除对应的 family_ledger_transaction 记录
3. 更新相关账本的 transactions 计数
4. 记录审计日志
```

## 🔗 相关表

- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [transactions - 交易记录表](../core/transactions.md)
- [family_ledger_account - 账本账户关联表](./family_ledger_account.md)
- [family_ledger_member - 账本成员关联表](./family_ledger_member.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
