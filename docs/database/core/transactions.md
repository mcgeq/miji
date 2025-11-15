# transactions - 交易记录表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `transactions`
- **说明**: 交易记录表，存储所有收入、支出、转账等财务交易
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132223_create_transactions.rs`
- **扩展迁移**: `m20251113_000001_add_installment_fields_to_transactions.rs`

## 📊 表结构

### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 交易唯一标识符（UUID格式） |
| `transaction_type` | VARCHAR | 20 | NOT NULL, CHECK | - | 交易类型 |
| `transaction_status` | VARCHAR | 20 | NOT NULL, CHECK | 'Completed' | 交易状态 |
| `date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 交易日期时间 |
| `description` | VARCHAR | 500 | NOT NULL | - | 交易描述 |
| `notes` | TEXT | - | NULLABLE | NULL | 备注信息 |
| `is_deleted` | BOOLEAN | - | NOT NULL | false | 是否已删除（软删除） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**枚举值**:
- `transaction_type`: 'Income', 'Expense', 'Transfer'
- `transaction_status`: 'Pending', 'Completed', 'Cancelled', 'Refunded'

**用途说明**:
- `transaction_type`: 
  - Income: 收入
  - Expense: 支出
  - Transfer: 转账（账户间转移）
- `transaction_status`:
  - Pending: 待处理（如未到账的收入）
  - Completed: 已完成
  - Cancelled: 已取消
  - Refunded: 已退款
- `is_deleted`: 软删除标记，已删除的交易不参与统计

### 金额字段

| 字段名 | 类型 | 精度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `amount` | DECIMAL | (16, 4) | NOT NULL | - | 交易金额 |
| `refund_amount` | DECIMAL | (16, 4) | NOT NULL | 0.0000 | 退款金额 |
| `currency` | VARCHAR | 3 | FK, NOT NULL | - | 货币代码，外键到 `currency.code` |

**用途说明**:
- `amount`: 交易的原始金额，始终为正数
- `refund_amount`: 已退款金额，用于部分退款场景
- `currency`: 交易使用的货币

### 账户字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `account_serial_num` | VARCHAR(38) | FK, NOT NULL | - | 主账户ID，外键到 `account.serial_num` |
| `to_account_serial_num` | VARCHAR(38) | FK, NULLABLE | NULL | 目标账户ID（转账时使用） |
| `actual_payer_account` | VARCHAR(38) | NOT NULL | - | 实际支付账户 |
| `payment_method` | VARCHAR | 20 | NOT NULL | - | 支付方式 |

**用途说明**:
- `account_serial_num`: 
  - 收入：收款账户
  - 支出：付款账户
  - 转账：转出账户
- `to_account_serial_num`: 仅转账时使用，表示转入账户
- `actual_payer_account`: 实际支付的账户（可能与主账户不同）
- `payment_method`: 'Cash', 'Card', 'Alipay', 'WeChat', 'BankTransfer', 'Other'

### 分类字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `category` | VARCHAR | 50 | NOT NULL | - | 主分类 |
| `sub_category` | VARCHAR | 50 | NULLABLE | NULL | 子分类 |
| `tags` | JSON | NULLABLE | NULL | 标签列表（JSON数组） |

**用途说明**:
- `category`: 交易的主要分类（如餐饮、交通、工资等）
- `sub_category`: 更细致的分类（如餐饮下的早餐、午餐等）
- `tags`: 自定义标签，JSON 格式：`["标签1", "标签2"]`

### 分摊字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `split_members` | JSON | NULLABLE | NULL | 分摊成员信息（JSON对象） |

**用途说明**:
- `split_members`: 记录费用分摊信息，JSON 格式：
  ```json
  {
    "member_id_1": {"amount": 100.00, "ratio": 0.5},
    "member_id_2": {"amount": 100.00, "ratio": 0.5}
  }
  ```

### 关联字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `related_transaction_serial_num` | VARCHAR(38) | FK, NULLABLE | NULL | 关联交易ID（如退款关联原交易） |

### 分期字段

| 字段名 | 类型 | 精度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `is_installment` | BOOLEAN | - | NULLABLE | false | 是否为分期交易 |
| `first_due_date` | DATE | - | NULLABLE | NULL | 首期还款日期 |
| `total_periods` | INTEGER | - | NULLABLE | NULL | 总期数 |
| `installment_amount` | DECIMAL | (16, 4) | NULLABLE | NULL | 每期金额 |
| `remaining_periods_amount` | DECIMAL | (16, 4) | NULLABLE | NULL | 剩余期数总金额 |
| `remaining_periods` | INTEGER | - | NULLABLE | NULL | 剩余期数 |
| `installment_plan_serial_num` | VARCHAR(38) | FK, NULLABLE | NULL | 分期计划ID |

**用途说明**:
- 用于信用卡分期、贷款等场景
- `installment_plan_serial_num` 关联到 `installment_plans` 表

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `account` | `account_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 主账户 |
| BELONGS_TO | `currency` | `currency` → `code` | ON DELETE: RESTRICT<br>ON UPDATE: CASCADE | 交易货币 |
| BELONGS_TO | `transactions` | `related_transaction_serial_num` → `serial_num` | - | 关联交易（自关联） |
| BELONGS_TO | `installment_plans` | `installment_plan_serial_num` → `serial_num` | - | 分期计划 |

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `bil_reminder` | 账单提醒 |
| HAS_MANY | `family_ledger_transaction` | 账本交易关联 |
| HAS_ONE | `installment_plans` | 分期计划 |

### 多对多关系

| 关系 | 目标表 | 中间表 | 说明 |
|------|--------|--------|------|
| MANY_TO_MANY | `family_ledger` | `family_ledger_transaction` | 交易可关联多个账本 |

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 外键索引
CREATE INDEX idx_transactions_account ON transactions(account_serial_num);
CREATE INDEX idx_transactions_currency ON transactions(currency);
CREATE INDEX idx_transactions_related ON transactions(related_transaction_serial_num);
CREATE INDEX idx_transactions_installment_plan ON transactions(installment_plan_serial_num);

-- 业务查询索引
CREATE INDEX idx_transactions_date ON transactions(date DESC);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_status ON transactions(transaction_status);
CREATE INDEX idx_transactions_category ON transactions(category);

-- 复合索引（常用查询）
CREATE INDEX idx_transactions_account_date 
ON transactions(account_serial_num, date DESC);

CREATE INDEX idx_transactions_type_status_date 
ON transactions(transaction_type, transaction_status, date DESC);

-- 软删除查询索引
CREATE INDEX idx_transactions_active 
ON transactions(is_deleted, date DESC) 
WHERE is_deleted = false;
```

## 💡 使用示例

### 创建收入交易

```rust
use entity::transactions;
use sea_orm::*;

let income = transactions::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    transaction_type: Set("Income".to_string()),
    transaction_status: Set("Completed".to_string()),
    date: Set(Utc::now().into()),
    amount: Set(Decimal::from(5000)),
    refund_amount: Set(Decimal::ZERO),
    currency: Set("CNY".to_string()),
    description: Set("工资收入".to_string()),
    notes: Set(Some("2025年1月工资".to_string())),
    account_serial_num: Set(account_id.clone()),
    to_account_serial_num: Set(None),
    category: Set("工资".to_string()),
    sub_category: Set(Some("月薪".to_string())),
    tags: Set(Some(json!(["工资", "收入"]))),
    split_members: Set(None),
    payment_method: Set("BankTransfer".to_string()),
    actual_payer_account: Set(account_id.clone()),
    related_transaction_serial_num: Set(None),
    is_deleted: Set(false),
    is_installment: Set(Some(false)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = income.insert(db).await?;
```

### 创建支出交易

```rust
let expense = transactions::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    transaction_type: Set("Expense".to_string()),
    transaction_status: Set("Completed".to_string()),
    date: Set(Utc::now().into()),
    amount: Set(Decimal::from(150)),
    refund_amount: Set(Decimal::ZERO),
    currency: Set("CNY".to_string()),
    description: Set("午餐".to_string()),
    notes: Set(None),
    account_serial_num: Set(account_id.clone()),
    to_account_serial_num: Set(None),
    category: Set("餐饮".to_string()),
    sub_category: Set(Some("午餐".to_string())),
    tags: Set(Some(json!(["餐饮", "工作日"]))),
    split_members: Set(None),
    payment_method: Set("Alipay".to_string()),
    actual_payer_account: Set(account_id.clone()),
    related_transaction_serial_num: Set(None),
    is_deleted: Set(false),
    is_installment: Set(Some(false)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = expense.insert(db).await?;
```

### 创建转账交易

```rust
let transfer = transactions::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    transaction_type: Set("Transfer".to_string()),
    transaction_status: Set("Completed".to_string()),
    date: Set(Utc::now().into()),
    amount: Set(Decimal::from(1000)),
    refund_amount: Set(Decimal::ZERO),
    currency: Set("CNY".to_string()),
    description: Set("账户间转账".to_string()),
    notes: Set(None),
    account_serial_num: Set(from_account_id.clone()),
    to_account_serial_num: Set(Some(to_account_id.clone())),
    category: Set("转账".to_string()),
    sub_category: Set(None),
    tags: Set(None),
    split_members: Set(None),
    payment_method: Set("BankTransfer".to_string()),
    actual_payer_account: Set(from_account_id.clone()),
    related_transaction_serial_num: Set(None),
    is_deleted: Set(false),
    is_installment: Set(Some(false)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = transfer.insert(db).await?;
```

### 创建分摊交易

```rust
let split_expense = transactions::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    transaction_type: Set("Expense".to_string()),
    transaction_status: Set("Completed".to_string()),
    date: Set(Utc::now().into()),
    amount: Set(Decimal::from(300)),
    refund_amount: Set(Decimal::ZERO),
    currency: Set("CNY".to_string()),
    description: Set("聚餐费用".to_string()),
    notes: Set(Some("3人AA".to_string())),
    account_serial_num: Set(account_id.clone()),
    to_account_serial_num: Set(None),
    category: Set("餐饮".to_string()),
    sub_category: Set(Some("聚餐".to_string())),
    tags: Set(Some(json!(["聚餐", "AA"]))),
    split_members: Set(Some(json!({
        "member1": {"amount": 100.00, "ratio": 0.333},
        "member2": {"amount": 100.00, "ratio": 0.333},
        "member3": {"amount": 100.00, "ratio": 0.334}
    }))),
    payment_method: Set("Alipay".to_string()),
    actual_payer_account: Set(account_id.clone()),
    related_transaction_serial_num: Set(None),
    is_deleted: Set(false),
    is_installment: Set(Some(false)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = split_expense.insert(db).await?;
```

### 查询交易记录

```rust
// 按日期范围查询
let transactions = Transactions::find()
    .filter(transactions::Column::Date.between(start_date, end_date))
    .filter(transactions::Column::IsDeleted.eq(false))
    .order_by_desc(transactions::Column::Date)
    .all(db)
    .await?;

// 按类型查询
let expenses = Transactions::find()
    .filter(transactions::Column::TransactionType.eq("Expense"))
    .filter(transactions::Column::IsDeleted.eq(false))
    .all(db)
    .await?;

// 按分类查询
let food_expenses = Transactions::find()
    .filter(transactions::Column::Category.eq("餐饮"))
    .filter(transactions::Column::IsDeleted.eq(false))
    .all(db)
    .await?;
```

### 软删除交易

```rust
let mut transaction: transactions::ActiveModel = transaction.into();
transaction.is_deleted = Set(true);
transaction.updated_at = Set(Some(Utc::now().into()));

transaction.update(db).await?;
```

### 退款处理

```rust
// 创建退款交易
let refund = transactions::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    transaction_type: Set("Income".to_string()), // 退款作为收入
    transaction_status: Set("Refunded".to_string()),
    date: Set(Utc::now().into()),
    amount: Set(original_amount),
    refund_amount: Set(Decimal::ZERO),
    currency: Set(original_currency),
    description: Set(format!("退款：{}", original_description)),
    notes: Set(Some("全额退款".to_string())),
    account_serial_num: Set(account_id.clone()),
    to_account_serial_num: Set(None),
    category: Set("退款".to_string()),
    sub_category: Set(None),
    tags: Set(Some(json!(["退款"]))),
    split_members: Set(None),
    payment_method: Set(original_payment_method),
    actual_payer_account: Set(account_id.clone()),
    related_transaction_serial_num: Set(Some(original_transaction_id)),
    is_deleted: Set(false),
    is_installment: Set(Some(false)),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = refund.insert(db).await?;

// 更新原交易状态
let mut original: transactions::ActiveModel = original_transaction.into();
original.transaction_status = Set("Refunded".to_string());
original.refund_amount = Set(original_amount);
original.updated_at = Set(Some(Utc::now().into()));

original.update(db).await?;
```

## ⚠️ 注意事项

1. **金额正负**: `amount` 始终为正数，通过 `transaction_type` 区分收支
2. **转账处理**: 转账需要创建两条记录（转出和转入），或使用 `to_account_serial_num`
3. **软删除**: 使用 `is_deleted` 标记删除，不要物理删除交易记录
4. **退款关联**: 退款交易应通过 `related_transaction_serial_num` 关联原交易
5. **分摊信息**: `split_members` 的总金额应等于 `amount`
6. **货币一致性**: 同一账本内的交易应使用统一货币
7. **状态管理**: 状态转换应遵循业务规则（Pending → Completed → Refunded）
8. **分期交易**: 分期交易应关联 `installment_plans` 表

## 🔄 交易状态转换

```
Pending (待处理)
  ↓ 确认
Completed (已完成)
  ↓ 退款
Refunded (已退款)

或

Pending (待处理)
  ↓ 取消
Cancelled (已取消)
```

## 📊 统计查询示例

### 按月统计收支

```rust
use sea_orm::sea_query::{Expr, Func};

let monthly_stats = Transactions::find()
    .filter(transactions::Column::IsDeleted.eq(false))
    .filter(transactions::Column::TransactionStatus.eq("Completed"))
    .select_only()
    .column_as(
        Func::date_format(Expr::col(transactions::Column::Date), "%Y-%m"),
        "month"
    )
    .column_as(
        Expr::case(
            Expr::col(transactions::Column::TransactionType).eq("Income"),
            Expr::col(transactions::Column::Amount)
        )
        .finally(Expr::value(0))
        .sum(),
        "total_income"
    )
    .column_as(
        Expr::case(
            Expr::col(transactions::Column::TransactionType).eq("Expense"),
            Expr::col(transactions::Column::Amount)
        )
        .finally(Expr::value(0))
        .sum(),
        "total_expense"
    )
    .group_by(Expr::col(transactions::Column::Date))
    .into_json()
    .all(db)
    .await?;
```

## 🔗 相关表

- [account - 账户表](./account.md)
- [currency - 货币表](./currency.md)
- [categories - 分类表](../financial/categories.md)
- [family_ledger_transaction - 账本交易关联表](../association/family_ledger_transaction.md)
- [installment_plans - 分期计划表](../financial/installment_plans.md)
- [bil_reminder - 账单提醒表](../business/bil_reminder.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
