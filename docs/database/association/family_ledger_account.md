# family_ledger_account - 账本账户关联表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `family_ledger_account`
- **说明**: 家庭账本与账户的多对多关联表，用于记录某个账本可以使用哪些账户
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132226_create_family_ledger_account.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 关联记录唯一标识符（UUID） |
| `family_ledger_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 账本ID，外键到 `family_ledger.serial_num` |
| `account_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 账户ID，外键到 `account.serial_num` |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- `serial_num`: 便于在日志和审计中引用这条关联记录
- `family_ledger_serial_num`: 表示该账户属于哪个家庭账本
- `account_serial_num`: 表示哪个账户被加入到该账本

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 所属家庭账本 |
| BELONGS_TO | `account` | `account_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 关联账户 |

**级联说明**:
- 删除账本时自动删除所有关联账户
- 删除账户时自动将其从所有账本中移除

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `family_ledger` ↔ `account` | `family_ledger_account` | 一个账本可以关联多个账户，一个账户也可以属于多个账本 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 外键索引
CREATE INDEX idx_family_ledger_account_ledger 
ON family_ledger_account(family_ledger_serial_num);

CREATE INDEX idx_family_ledger_account_account 
ON family_ledger_account(account_serial_num);

-- 唯一约束：同一账本内同一账户只能出现一次
CREATE UNIQUE INDEX idx_family_ledger_account_unique 
ON family_ledger_account(family_ledger_serial_num, account_serial_num);
```

## 💡 使用示例

### 将账户加入账本

```rust
use entity::family_ledger_account;
use sea_orm::*;

let assoc = family_ledger_account::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    family_ledger_serial_num: Set(ledger_id.clone()),
    account_serial_num: Set(account_id.clone()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = assoc.insert(db).await?;
```

### 查询账本下的所有账户

```rust
use entity::{family_ledger_account, account};

let accounts = Account::find()
    .inner_join(FamilyLedgerAccount)
    .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .all(db)
    .await?;
```

### 查询某账户属于哪些账本

```rust
use entity::{family_ledger_account, family_ledger};

let ledgers = FamilyLedger::find()
    .inner_join(FamilyLedgerAccount)
    .filter(family_ledger_account::Column::AccountSerialNum.eq(account_id))
    .all(db)
    .await?;
```

### 从账本中移除账户

```rust
use entity::family_ledger_account;

FamilyLedgerAccount::delete_many()
    .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .filter(family_ledger_account::Column::AccountSerialNum.eq(account_id))
    .exec(db)
    .await?;
```

### 统计账本关联的账户数量

```rust
use entity::family_ledger_account;

let account_count = FamilyLedgerAccount::find()
    .filter(family_ledger_account::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .count(db)
    .await?;
```

## ⚠️ 注意事项

1. **唯一性**: 同一账本内同一账户只能关联一次，依赖唯一索引约束
2. **级联删除**: 删除账本或账户会级联删除关联记录，注意业务上的后果
3. **计数维护**: 建议在服务层中更新 `family_ledger.accounts` 计数字段
4. **多账本账户**: 一个账户可以属于多个账本，注意统计时不要重复计算
5. **审计日志**: 添加或移除账户时建议记录审计日志

## 🔄 业务流程

### 将账户绑定到账本
```
1. 检查 account 是否存在且 is_active = true
2. 检查是否已经存在相同的 (ledger, account) 关联
3. 创建 family_ledger_account 记录
4. 更新 family_ledger.accounts 计数 +1
5. 记录审计日志
```

### 从账本解绑账户
```
1. 检查是否存在关联记录
2. 删除关联记录
3. 更新 family_ledger.accounts 计数 -1
4. 记录审计日志
```

## 🔗 相关表

- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [account - 账户表](../core/account.md)
- [family_ledger_member - 账本成员关联表](./family_ledger_member.md)
- [family_ledger_transaction - 账本交易关联表](./family_ledger_transaction.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
