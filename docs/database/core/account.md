# account - 账户表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `account`
- **说明**: 账户信息表，存储银行账户、现金、信用卡等各类资金账户
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132222_create_account.rs`

## 📊 表结构

### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 账户唯一标识符（UUID格式） |
| `name` | VARCHAR | 100 | UNIQUE, NOT NULL | - | 账户名称（全局唯一） |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 账户描述 |
| `type` | VARCHAR | 20 | NOT NULL, CHECK | - | 账户类型 |
| `currency` | VARCHAR | 3 | FK, NOT NULL | - | 货币代码，外键到 `currency.code` |
| `is_active` | BOOLEAN | - | NOT NULL | true | 是否激活 |
| `is_virtual` | BOOLEAN | - | NOT NULL | false | 是否虚拟账户 |
| `color` | VARCHAR | 7 | NULLABLE | NULL | 账户标识颜色（十六进制） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**枚举值**:
- `type`: 'BankSavings', 'Cash', 'CreditCard', 'Alipay', 'WeChat', 'Investment', 'Loan', 'Other'

**用途说明**:
- `serial_num`: UUID 格式，确保全局唯一性
- `name`: 账户名称必须全局唯一，便于识别
- `type`: 区分不同类型的账户，影响统计和展示
  - BankSavings: 银行储蓄账户
  - Cash: 现金
  - CreditCard: 信用卡
  - Alipay: 支付宝
  - WeChat: 微信
  - Investment: 投资账户
  - Loan: 贷款账户
  - Other: 其他类型
- `is_active`: 非活跃账户不参与日常统计
- `is_virtual`: 虚拟账户用于特殊记账场景（如应收应付）

### 财务字段

| 字段名 | 类型 | 精度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `balance` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 当前余额 |
| `initial_balance` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 初始余额 |

**用途说明**:
- `balance`: 账户当前余额，通过交易记录自动计算
- `initial_balance`: 账户初始余额，创建时设置

**计算逻辑**:
```
balance = initial_balance + Σ(收入交易) - Σ(支出交易)
```

### 所有权字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `owner_id` | VARCHAR(38) | FK, NULLABLE | NULL | 账户所有者ID，外键到 `family_member.serial_num` |
| `is_shared` | BOOLEAN | NULLABLE | NULL | 是否共享账户 |

**用途说明**:
- `owner_id`: 指定账户所有者，NULL 表示公共账户
- `is_shared`: 
  - true: 共享账户，多人可使用
  - false: 个人账户，仅所有者使用
  - NULL: 未设置（默认按 owner_id 判断）

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `currency` | `currency` → `code` | ON DELETE: RESTRICT<br>ON UPDATE: CASCADE | 账户货币 |
| BELONGS_TO | `family_member` | `owner_id` → `serial_num` | ON DELETE: RESTRICT<br>ON UPDATE: CASCADE | 账户所有者 |

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `transactions` | 账户的交易记录 |
| HAS_MANY | `budget` | 账户的预算 |
| HAS_MANY | `family_ledger_account` | 账户参与的账本关联 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `family_ledger` | `family_ledger_account` | 账户可关联多个账本 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 唯一索引（自动创建）
UNIQUE INDEX idx_account_name ON account(name);

-- 外键索引
CREATE INDEX idx_account_currency ON account(currency);
CREATE INDEX idx_account_owner ON account(owner_id);

-- 类型查询索引
CREATE INDEX idx_account_type ON account(type);

-- 活跃账户索引
CREATE INDEX idx_account_active ON account(is_active) WHERE is_active = true;

-- 复合索引（按类型查询活跃账户）
CREATE INDEX idx_account_type_active ON account(type, is_active);
```

## 💡 使用示例

### 创建银行账户

```rust
use entity::account;
use sea_orm::*;

let account = account::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("工商银行储蓄卡".to_string()),
    description: Set(Some("工资卡".to_string())),
    r#type: Set("BankSavings".to_string()),
    balance: Set(Decimal::from(10000)),
    initial_balance: Set(Decimal::from(10000)),
    currency: Set("CNY".to_string()),
    is_shared: Set(Some(false)),
    owner_id: Set(Some(member_id.clone())),
    color: Set(Some("#1E88E5".to_string())),
    is_active: Set(true),
    is_virtual: Set(false),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = account.insert(db).await?;
```

### 创建共享现金账户

```rust
let cash_account = account::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("家庭现金".to_string()),
    description: Set(Some("家庭共用现金".to_string())),
    r#type: Set("Cash".to_string()),
    balance: Set(Decimal::from(5000)),
    initial_balance: Set(Decimal::from(5000)),
    currency: Set("CNY".to_string()),
    is_shared: Set(Some(true)),
    owner_id: Set(None), // 公共账户
    color: Set(Some("#4CAF50".to_string())),
    is_active: Set(true),
    is_virtual: Set(false),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = cash_account.insert(db).await?;
```

### 查询活跃账户

```rust
let active_accounts = Account::find()
    .filter(account::Column::IsActive.eq(true))
    .all(db)
    .await?;
```

### 按类型查询账户

```rust
// 查询所有银行账户
let bank_accounts = Account::find()
    .filter(account::Column::Type.eq("BankSavings"))
    .filter(account::Column::IsActive.eq(true))
    .all(db)
    .await?;
```

### 查询成员的账户

```rust
let member_accounts = Account::find()
    .filter(account::Column::OwnerId.eq(member_id))
    .filter(account::Column::IsActive.eq(true))
    .all(db)
    .await?;
```

### 更新账户余额

```rust
// 注意：余额应通过交易记录自动更新，不建议直接修改
let account = account::Entity::find_by_id(account_id)
    .one(db)
    .await?
    .unwrap();

let mut active: account::ActiveModel = account.into();
active.balance = Set(new_balance);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 统计账户总资产

```rust
use sea_orm::sea_query::Expr;

let total_assets: Decimal = Account::find()
    .filter(account::Column::IsActive.eq(true))
    .filter(account::Column::IsVirtual.eq(false))
    .filter(account::Column::Currency.eq("CNY"))
    .select_only()
    .column_as(Expr::col(account::Column::Balance).sum(), "total")
    .into_tuple::<Decimal>()
    .one(db)
    .await?
    .unwrap_or(Decimal::ZERO);
```

## ⚠️ 注意事项

1. **账户名称唯一性**: `name` 字段全局唯一，创建前需检查重名
2. **余额更新**: `balance` 应通过交易记录自动计算，避免手动修改
3. **货币限制**: 删除货币前必须确保没有账户使用该货币
4. **所有者限制**: 删除成员前必须处理其拥有的账户
5. **虚拟账户**: `is_virtual = true` 的账户不计入资产统计
6. **共享账户**: 共享账户的交易需要记录实际使用者
7. **颜色格式**: `color` 字段应存储标准的十六进制颜色值（如 #1E88E5）
8. **货币一致性**: 同一账本内的账户应使用相同货币，或做好汇率转换

## 🔄 账户类型说明

### 资产类账户
- **BankSavings**: 银行储蓄账户，余额为正
- **Cash**: 现金，余额为正
- **Alipay**: 支付宝余额，余额为正
- **WeChat**: 微信余额，余额为正
- **Investment**: 投资账户，余额可正可负

### 负债类账户
- **CreditCard**: 信用卡，余额为负表示欠款
- **Loan**: 贷款账户，余额为负表示欠款

### 特殊账户
- **Other**: 其他类型账户
- **Virtual**: 虚拟账户（`is_virtual = true`），用于应收应付等

## 📊 账户状态管理

### 激活/停用账户

```rust
// 停用账户
let mut account: account::ActiveModel = account.into();
account.is_active = Set(false);
account.updated_at = Set(Some(Utc::now().into()));
account.update(db).await?;

// 重新激活
account.is_active = Set(true);
account.updated_at = Set(Some(Utc::now().into()));
account.update(db).await?;
```

**停用规则**:
- 停用前应确保余额为 0 或已妥善处理
- 停用后账户不参与统计
- 历史交易记录保留

## 💰 余额计算示例

```rust
// 计算账户实际余额（通过交易记录）
use entity::transactions;

let calculated_balance = Transactions::find()
    .filter(transactions::Column::AccountSerialNum.eq(account_id))
    .select_only()
    .column_as(
        Expr::case(
            Expr::col(transactions::Column::Type).eq("Income"),
            Expr::col(transactions::Column::Amount)
        )
        .finally(Expr::col(transactions::Column::Amount).neg())
        .sum(),
        "balance"
    )
    .into_tuple::<Decimal>()
    .one(db)
    .await?
    .unwrap_or(Decimal::ZERO);

let total_balance = initial_balance + calculated_balance;
```

## 🔗 相关表

- [currency - 货币表](./currency.md)
- [family_member - 家庭成员表](./family_member.md)
- [transactions - 交易记录表](./transactions.md)
- [budget - 预算表](../financial/budget.md)
- [family_ledger_account - 账本账户关联表](../association/family_ledger_account.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
