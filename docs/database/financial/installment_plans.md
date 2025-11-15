# installment_plans - 分期计划表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `installment_plans`
- **说明**: 分期计划表，用于描述一笔分期交易的整体信息（总金额、期数、每期金额等）
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000007_create_installment_plans_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 分期计划唯一ID |
| `transaction_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 对应的原始交易ID |
| `account_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 分期所属账户ID |
| `total_amount` | DECIMAL | (15, 2) | NOT NULL | - | 分期总金额 |
| `total_periods` | INTEGER | - | NOT NULL | - | 总期数 |
| `installment_amount` | DECIMAL | (15, 2) | NOT NULL | - | 每期应还金额 |
| `first_due_date` | DATE | - | NOT NULL | - | 首期还款日 |
| `status` | VARCHAR | 20 | NOT NULL | 'Active' | 分期状态 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**status 约定值**：
- `Active`: 分期正常进行中
- `Completed`: 所有期数已还清
- `Cancelled`: 分期已取消/展期到其他计划
- `Overdue`: 存在逾期未还的期数

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `transactions` | `transaction_serial_num` → `serial_num` | - | 原始消费/借款交易 |
| BELONGS_TO | `account` | `account_serial_num` → `serial_num` | - | 对应的账户（信用卡/贷款等） |

### 一对多关系

| 关系 | 目标表 | 说明 |
|------|--------|------|
| HAS_MANY | `installment_details` | 分期的每一期明细 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_installment_plan_tx ON installment_plans(transaction_serial_num);
CREATE INDEX idx_installment_plan_account ON installment_plans(account_serial_num);
CREATE INDEX idx_installment_plan_status ON installment_plans(status);
```

## 💡 使用示例

### 创建分期计划

```rust
use entity::installment_plans;
use sea_orm::*;

let plan = installment_plans::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    transaction_serial_num: Set(tx_id.clone()),
    account_serial_num: Set(account_id.clone()),
    total_amount: Set(dec!(12000.00)),
    total_periods: Set(12),
    installment_amount: Set(dec!(1000.00)),
    first_due_date: Set(first_due_date),
    status: Set("Active".to_string()),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = plan.insert(db).await?;
```

### 查询账户下所有分期计划

```rust
let plans = InstallmentPlans::find()
    .filter(installment_plans::Column::AccountSerialNum.eq(account_id.clone()))
    .all(db)
    .await?;
```

### 更新分期计划状态

```rust
let plan = InstallmentPlans::find_by_id(plan_id)
    .one(db)
    .await?
    .unwrap();

let mut active: installment_plans::ActiveModel = plan.into();
active.status = Set("Completed".to_string());
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

## ⚠️ 注意事项

1. **金额一致性**: `installment_amount * total_periods` 应接近 `total_amount`，差额可放在首/末期
2. **与交易联动**: 分期计划应与原始交易保持一致（金额、币种等）
3. **逾期判断**: 逾期逻辑通常基于 `installment_details.due_date` 与当前日期对比
4. **提前结清**: 提前结清时需更新所有期数的状态，并将计划标记为 `Completed`
5. **展期/重组**: 如需展期，可以创建新的计划并将旧计划标记为 `Cancelled`

## 🔗 相关表

- [installment_details - 分期明细表](./installment_details.md)
- [transactions - 交易记录表](../core/transactions.md)
- [account - 账户表](../core/account.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
