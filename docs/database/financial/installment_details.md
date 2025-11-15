# installment_details - 分期明细表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `installment_details`
- **说明**: 分期明细表，用于记录分期计划中每一期的还款安排与状态
- **主键**: `serial_num`
- **创建迁移**: `m20251112_000008_create_installment_details_table.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 分期明细唯一ID |
| `plan_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 所属分期计划ID |
| `period_number` | INTEGER | - | NOT NULL | - | 期数编号（从1开始） |
| `due_date` | DATE | - | NOT NULL | - | 当期应还日期 |
| `amount` | DECIMAL | (15, 2) | NOT NULL | - | 当期应还金额 |
| `account_serial_num` | VARCHAR | 38 | FK, NOT NULL | - | 当期还款使用的账户 |
| `status` | VARCHAR | 20 | NOT NULL | 'Pending' | 当期状态 |
| `paid_date` | DATE | - | NULLABLE | NULL | 实际还款日期 |
| `paid_amount` | DECIMAL | (15, 2) | NULLABLE | NULL | 实际还款金额 |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**status 约定值**：
- `Pending`: 未到期或未支付
- `Paid`: 已按时或提前支付
- `Overdue`: 逾期未支付
- `PartialPaid`: 部分支付

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `installment_plans` | `plan_serial_num` → `serial_num` | - | 所属分期计划 |
| BELONGS_TO | `account` | `account_serial_num` → `serial_num` | - | 实际还款使用的账户 |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_installment_detail_plan ON installment_details(plan_serial_num);
CREATE INDEX idx_installment_detail_account ON installment_details(account_serial_num);
CREATE INDEX idx_installment_detail_status ON installment_details(status);
CREATE INDEX idx_installment_detail_due_date ON installment_details(due_date);
```

## 💡 使用示例

### 为分期计划生成明细（伪代码）

```rust
for period in 1..=total_periods {
    let due_date = // 根据 first_due_date 和期数计算
    let detail = installment_details::ActiveModel {
        serial_num: Set(McgUuid::new().to_string()),
        plan_serial_num: Set(plan_id.clone()),
        period_number: Set(period),
        due_date: Set(due_date),
        amount: Set(installment_amount),
        account_serial_num: Set(account_id.clone()),
        status: Set("Pending".to_string()),
        created_at: Set(Utc::now().into()),
        ..Default::default()
    };

    detail.insert(db).await?;
}
```

### 标记一期为已支付

```rust
let detail = InstallmentDetails::find_by_id(detail_id)
    .one(db)
    .await?
    .unwrap();

let mut active: installment_details::ActiveModel = detail.into();
active.status = Set("Paid".to_string());
active.paid_date = Set(Some(Utc::now().date_naive()));
active.paid_amount = Set(Some(active.amount.clone().unwrap()));
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 查询即将到期的分期

```rust
let upcoming = InstallmentDetails::find()
    .filter(installment_details::Column::Status.eq("Pending"))
    .filter(installment_details::Column::DueDate.lte(today + chrono::Duration::days(7)))
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **金额一致性**: 所有明细的 `amount` 之和应与计划的 `total_amount` 保持一致
2. **期数编号**: `period_number` 应从1开始连续递增，便于展示和计算
3. **逾期判断**: 通常由定时任务根据 `due_date` 和 `status` 更新为 `Overdue`
4. **部分支付**: 若支持部分支付，应合理维护 `paid_amount` 与剩余金额
5. **账户变更**: 若中途更换还款账户，可更新 `account_serial_num` 或在业务层处理

## 🔗 相关表

- [installment_plans - 分期计划表](./installment_plans.md)
- [account - 账户表](../core/account.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
