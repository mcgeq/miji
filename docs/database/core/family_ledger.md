# 数据库表结构说明文档

本文档详细说明了 Miji 家庭记账系统的数据库表结构，包括字段类型、用途、约束条件等。

## 目录

- [核心功能表](#核心功能表)
  - [family_ledger - 家庭账本表](#family_ledger---家庭账本表)
- [关联关系表](#关联关系表)
- [财务管理表](#财务管理表)
- [系统配置表](#系统配置表)

---

## 核心功能表

### family_ledger - 家庭账本表

家庭账本是系统的核心实体，用于管理家庭或个人的财务记录。

#### 表信息
- **表名**: `family_ledger`
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132219_create_family_ledger.rs`
- **扩展迁移**: `m20251112_000001_enhance_family_ledger_fields.rs`, `m20251115_000007_change_family_ledger_counts_to_integer.rs`

#### 字段说明

##### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PRIMARY KEY, NOT NULL | - | 账本唯一标识符（UUID格式） |
| `name` | VARCHAR | - | NULLABLE | NULL | 账本名称 |
| `description` | VARCHAR | 1000 | NOT NULL | '' | 账本描述信息 |
| `base_currency` | VARCHAR | 3 | NOT NULL, FK | - | 基础货币代码（如 CNY, USD），关联 `currency.code` |
| `audit_logs` | TEXT | - | NOT NULL | '' | 审计日志（JSON格式） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**用途说明**:
- `serial_num`: 使用 UUID 确保全局唯一性，便于分布式系统
- `name`: 可为空，允许用户创建后再命名
- `base_currency`: 外键关联货币表，确保货币代码有效性
- `audit_logs`: 记录账本的所有变更历史，便于追溯

##### 统计字段（计数）

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `members` | INTEGER | NOT NULL | 0 | 账本成员数量 |
| `accounts` | INTEGER | NOT NULL | 0 | 关联账户数量 |
| `transactions` | INTEGER | NOT NULL | 0 | 交易记录数量 |
| `budgets` | INTEGER | NOT NULL | 0 | 预算项数量 |

**用途说明**:
- 这些字段用于快速统计，避免频繁的 COUNT 查询
- 通过服务层钩子（hooks）自动更新
- 初始值为 0，在创建关联记录时自动递增

**历史变更**:
- 原始设计为 JSON 字符串存储列表
- `m20251115_000007` 迁移改为整数计数，提升查询性能

##### 账本类型与配置

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 可选值 | 说明 |
|--------|------|------|------|--------|--------|------|
| `ledger_type` | VARCHAR | 20 | NOT NULL, CHECK | 'Family' | Personal, Family, Project, Business | 账本类型 |
| `status` | VARCHAR | 20 | NOT NULL, CHECK | 'Active' | Active, Archived, Closed | 账本状态 |

**用途说明**:
- `ledger_type`: 区分不同使用场景，支持个人、家庭、项目、商业等
- `status`: 管理账本生命周期，已归档或关闭的账本不参与日常统计

##### 结算相关字段

| 字段名 | 类型 | 约束 | 默认值 | 可选值 | 说明 |
|--------|------|------|--------|--------|------|
| `settlement_cycle` | VARCHAR(20) | NOT NULL, CHECK | 'Monthly' | Weekly, Monthly, Quarterly, Yearly, Manual | 结算周期 |
| `settlement_day` | INTEGER | NOT NULL, CHECK | 1 | 1-31 | 每月结算日（1-31号） |
| `auto_settlement` | BOOLEAN | NOT NULL | false | - | 是否自动结算 |
| `last_settlement_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | - | 最后结算时间 |
| `next_settlement_at` | TIMESTAMP WITH TIME ZONE | NULLABLE | NULL | - | 下次结算时间 |
| `default_split_rule` | JSON | NULLABLE | NULL | - | 默认分摊规则（JSON格式） |

**用途说明**:
- `settlement_cycle`: 定义账本的结算频率
- `settlement_day`: 配合月度结算使用，指定每月的结算日期
- `auto_settlement`: 启用后系统将在结算日自动执行结算
- `last_settlement_at` / `next_settlement_at`: 用于追踪结算时间线
- `default_split_rule`: 存储默认的费用分摊规则，可被具体交易覆盖

**业务逻辑**:
```
如果 auto_settlement = true 且 settlement_cycle = 'Monthly':
  - 系统会在每月的 settlement_day 日自动执行结算
  - 结算后更新 last_settlement_at 和 next_settlement_at
```

#### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `currency` | `base_currency` → `code` | ON DELETE: RESTRICT<br>ON UPDATE: CASCADE | 基础货币 |
| HAS_MANY | `family_ledger_member` | `serial_num` | - | 账本成员关联 |
| HAS_MANY | `family_ledger_account` | `serial_num` | - | 账本账户关联 |
| HAS_MANY | `family_ledger_transaction` | `serial_num` | - | 账本交易关联 |
| HAS_MANY | `split_rules` | `serial_num` | - | 分摊规则 |
| HAS_MANY | `split_records` | `serial_num` | - | 分摊记录 |
| HAS_MANY | `debt_relations` | `serial_num` | - | 债务关系 |
| HAS_MANY | `settlement_records` | `serial_num` | - | 结算记录 |
| MANY_TO_MANY | `family_member` | via `family_ledger_member` | - | 账本成员 |
| MANY_TO_MANY | `transactions` | via `family_ledger_transaction` | - | 交易记录 |

**级联说明**:
- `RESTRICT`: 防止删除被引用的货币，确保数据完整性
- `CASCADE`: 货币代码更新时自动更新账本中的引用

#### 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 外键索引（建议）
CREATE INDEX idx_family_ledger_base_currency ON family_ledger(base_currency);

-- 状态查询索引
CREATE INDEX idx_family_ledger_status ON family_ledger(status);

-- 结算时间索引（用于自动结算任务）
CREATE INDEX idx_family_ledger_next_settlement 
ON family_ledger(next_settlement_at) 
WHERE auto_settlement = true AND status = 'Active';
```

#### 使用示例

##### 创建家庭账本
```rust
let ledger = family_ledger::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set(Some("我的家庭账本".to_string())),
    description: Set("记录家庭日常开支".to_string()),
    base_currency: Set("CNY".to_string()),
    ledger_type: Set("Family".to_string()),
    settlement_cycle: Set("Monthly".to_string()),
    settlement_day: Set(1),
    auto_settlement: Set(true),
    members: Set(0),
    accounts: Set(0),
    transactions: Set(0),
    budgets: Set(0),
    status: Set("Active".to_string()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};
```

##### 查询活跃账本
```rust
let active_ledgers = FamilyLedger::find()
    .filter(family_ledger::Column::Status.eq("Active"))
    .all(db)
    .await?;
```

#### 注意事项

1. **计数字段维护**: `members`, `accounts`, `transactions`, `budgets` 字段应通过服务层钩子自动更新，不要手动修改
2. **货币限制**: 删除货币前必须确保没有账本使用该货币
3. **结算日期**: `settlement_day` 对于非月度结算周期可能不适用
4. **JSON 字段**: `default_split_rule` 和 `audit_logs` 存储 JSON 数据，需要在应用层进行序列化/反序列化
5. **状态转换**: 账本状态转换应遵循业务规则：Active → Archived → Closed

#### 相关迁移文件

1. **m20250803_132219_create_family_ledger.rs** - 创建基础表结构
2. **m20251112_000001_enhance_family_ledger_fields.rs** - 添加账本类型、结算配置等扩展字段
3. **m20251115_000007_change_family_ledger_counts_to_integer.rs** - 将计数字段从 JSON 字符串改为整数

---

## 文档说明

### 字段类型映射

| Rust 类型 | SQL 类型 | 说明 |
|-----------|---------|------|
| `String` | VARCHAR | 可变长度字符串 |
| `i32` | INTEGER | 32位整数 |
| `bool` | BOOLEAN | 布尔值 |
| `Json` | JSON | JSON 数据 |
| `DateTimeWithTimeZone` | TIMESTAMP WITH TIME ZONE | 带时区的时间戳 |
| `Option<T>` | NULLABLE | 可为空的字段 |

### 约束说明

- **PRIMARY KEY**: 主键，唯一且非空
- **NOT NULL**: 不允许为空
- **NULLABLE**: 允许为空
- **FK (Foreign Key)**: 外键，关联其他表
- **CHECK**: 检查约束，限制字段值范围
- **DEFAULT**: 默认值

### 级联操作

- **RESTRICT**: 限制删除，如果有引用则拒绝操作
- **CASCADE**: 级联操作，自动更新或删除相关记录
- **SET NULL**: 设置为 NULL
- **NO ACTION**: 不执行任何操作

---

**文档版本**: v1.0  
**最后更新**: 2025-11-15  
**维护者**: Miji Team
