# family_ledger_member - 账本成员关联表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `family_ledger_member`
- **说明**: 家庭账本与成员的多对多关联表
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132221_create_family_ledger_member.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 关联记录唯一标识符（UUID格式） |
| `family_ledger_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 账本ID，外键到 `family_ledger.serial_num` |
| `family_member_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 成员ID，外键到 `family_member.serial_num` |
| `joined_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 加入时间 |
| `left_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 离开时间（NULL表示仍在账本中） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- `serial_num`: 关联记录的唯一标识
- `family_ledger_serial_num` + `family_member_serial_num`: 构成业务主键，一个成员在同一账本中只能有一条活跃记录
- `joined_at`: 记录成员何时加入账本
- `left_at`: 记录成员何时离开账本，NULL 表示仍在账本中

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `family_ledger` | `family_ledger_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 所属账本 |
| BELONGS_TO | `family_member` | `family_member_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 关联成员 |

**级联说明**:
- 删除账本时，自动删除所有成员关联
- 删除成员时，自动删除所有账本关联
- 更新账本或成员ID时，自动更新关联记录

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 外键索引
CREATE INDEX idx_family_ledger_member_ledger 
ON family_ledger_member(family_ledger_serial_num);

CREATE INDEX idx_family_ledger_member_member 
ON family_ledger_member(family_member_serial_num);

-- 唯一约束（防止重复关联）
CREATE UNIQUE INDEX idx_family_ledger_member_unique 
ON family_ledger_member(family_ledger_serial_num, family_member_serial_num) 
WHERE left_at IS NULL;

-- 活跃成员查询索引
CREATE INDEX idx_family_ledger_member_active 
ON family_ledger_member(family_ledger_serial_num, left_at);
```

## 💡 使用示例

### 添加成员到账本

```rust
use entity::family_ledger_member;
use sea_orm::*;

let association = family_ledger_member::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    family_ledger_serial_num: Set(ledger_id.clone()),
    family_member_serial_num: Set(member_id.clone()),
    joined_at: Set(Utc::now().into()),
    left_at: Set(None),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = association.insert(db).await?;
```

### 查询账本的所有活跃成员

```rust
use entity::{family_ledger_member, family_member};

let members = FamilyMember::find()
    .inner_join(FamilyLedgerMember)
    .filter(family_ledger_member::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .filter(family_ledger_member::Column::LeftAt.is_null())
    .all(db)
    .await?;
```

### 移除成员（软删除）

```rust
// 设置离开时间，而不是真正删除记录
let association = family_ledger_member::Entity::find()
    .filter(family_ledger_member::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .filter(family_ledger_member::Column::FamilyMemberSerialNum.eq(member_id))
    .filter(family_ledger_member::Column::LeftAt.is_null())
    .one(db)
    .await?
    .unwrap();

let mut active: family_ledger_member::ActiveModel = association.into();
active.left_at = Set(Some(Utc::now().into()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 查询成员参与的所有账本

```rust
use entity::{family_ledger_member, family_ledger};

let ledgers = FamilyLedger::find()
    .inner_join(FamilyLedgerMember)
    .filter(family_ledger_member::Column::FamilyMemberSerialNum.eq(member_id))
    .filter(family_ledger_member::Column::LeftAt.is_null())
    .all(db)
    .await?;
```

### 统计账本成员数量

```rust
let member_count = FamilyLedgerMember::find()
    .filter(family_ledger_member::Column::FamilyLedgerSerialNum.eq(ledger_id))
    .filter(family_ledger_member::Column::LeftAt.is_null())
    .count(db)
    .await?;
```

## ⚠️ 注意事项

1. **唯一性约束**: 同一成员在同一账本中只能有一条 `left_at = NULL` 的记录
2. **软删除**: 使用 `left_at` 字段标记成员离开，而不是删除记录，保留历史
3. **级联删除**: 删除账本或成员时会自动删除关联记录
4. **时间记录**: `joined_at` 和 `left_at` 用于追踪成员的参与时间线
5. **计数更新**: 添加或移除成员时，应同步更新 `family_ledger.members` 计数字段
6. **重新加入**: 如果成员离开后重新加入，应创建新的关联记录

## 🔄 业务流程

### 成员加入流程
```
1. 检查成员是否已在账本中（left_at IS NULL）
2. 如果存在活跃关联，返回错误
3. 创建新的关联记录
4. 更新 family_ledger.members 计数 +1
5. 记录审计日志
```

### 成员离开流程
```
1. 查找活跃的关联记录（left_at IS NULL）
2. 设置 left_at = 当前时间
3. 更新 family_ledger.members 计数 -1
4. 检查是否有未结算的债务
5. 记录审计日志
```

## 📊 数据示例

| serial_num | family_ledger_serial_num | family_member_serial_num | joined_at | left_at | 说明 |
|-----------|-------------------------|-------------------------|-----------|---------|------|
| uuid-1 | ledger-001 | member-001 | 2025-01-01 | NULL | 活跃成员 |
| uuid-2 | ledger-001 | member-002 | 2025-01-15 | NULL | 活跃成员 |
| uuid-3 | ledger-001 | member-003 | 2025-01-10 | 2025-02-01 | 已离开 |
| uuid-4 | ledger-002 | member-001 | 2025-02-01 | NULL | 同一成员参与多个账本 |

## 🔗 相关表

- [family_ledger - 家庭账本表](../core/family_ledger.md)
- [family_member - 家庭成员表](../core/family_member.md)
- [family_ledger_account - 账本账户关联表](./family_ledger_account.md)
- [family_ledger_transaction - 账本交易关联表](./family_ledger_transaction.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
