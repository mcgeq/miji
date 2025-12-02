# bil_reminder - 账单提醒表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `bil_reminder`
- **说明**: 账单提醒表，用于管理周期性/一次性的账单（信用卡、房贷、水电费等）的提醒计划
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132246_create_bil_reminder.rs`

## 📊 表结构

### 字段说明

| 字段名 | 类型 | 精度/长度 | 约束 | 默认值 | 说明 |
|--------|------|-----------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 账单提醒唯一ID |
| `name` | VARCHAR | 100 | NOT NULL | - | 提醒名称（如「房贷」「信用卡账单」） |
| `enabled` | BOOLEAN | - | NOT NULL | true | 是否启用该提醒 |
| `type` | VARCHAR | 20 | NOT NULL | 'Bill' | 提醒类型（如 Bill/Subscription 等） |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 描述 |
| `category` | VARCHAR | 50 | NOT NULL | - | 分类（如「住房」「信用卡」） |
| `amount` | DECIMAL | (16, 4) | NULLABLE | NULL | 账单金额（可选，部分账单金额不固定） |
| `currency` | VARCHAR | 3 | NULLABLE | NULL | 货币代码 |
| `due_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 截止/付款时间 |
| `bill_date` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 出账时间（如每月账单日） |
| `remind_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 本次提醒时间 |
| `repeat_period_type` | VARCHAR | 20 | NOT NULL | 'Monthly' | 重复周期类型 |
| `repeat_period` | JSON | - | NOT NULL | - | 重复周期配置（如每月第几天） |
| `is_paid` | BOOLEAN | - | NOT NULL | false | 当前周期是否已标记为已支付 |
| `priority` | VARCHAR | 20 | NOT NULL | 'Normal' | 优先级（Low/Normal/High/Urgent） |
| `advance_value` | INTEGER | - | NULLABLE | NULL | 提前提醒数值 |
| `advance_unit` | VARCHAR | 20 | NULLABLE | NULL | 提前提醒单位（Day/Hour 等） |
| `related_transaction_serial_num` | VARCHAR | 38 | FK, NULLABLE | NULL | 关联的实际交易ID |
| `color` | VARCHAR | 7 | NULLABLE | NULL | UI 颜色（如 #EF4444） |
| `is_deleted` | BOOLEAN | - | NOT NULL | false | 是否已删除（软删除） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |
| `last_reminder_sent_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后提醒时间 |
| `reminder_frequency` | VARCHAR | 20 | NULLABLE | NULL | 重复提醒频率（如 EveryDay） |
| `snooze_until` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 贪睡到期时间 |
| `reminder_methods` | JSON | - | NULLABLE | NULL | 提醒方式列表（App/Email/SMS 等） |
| `escalation_enabled` | BOOLEAN | - | NOT NULL | false | 是否启用升级提醒 |
| `escalation_after_hours` | INTEGER | - | NULLABLE | NULL | 多少小时未处理后升级提醒 |
| `timezone` | VARCHAR | 50 | NULLABLE | NULL | 提醒时区 |
| `smart_reminder_enabled` | BOOLEAN | - | NOT NULL | false | 是否启用智能提醒（根据行为/历史优化） |
| `auto_reschedule` | BOOLEAN | - | NOT NULL | false | 到期未支付时是否自动顺延到下一期 |
| `payment_reminder_enabled` | BOOLEAN | - | NOT NULL | false | 是否在支付后发送确认提醒 |
| `batch_reminder_id` | VARCHAR | 38 | NULLABLE | NULL | 所属批量提醒任务ID |

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `transactions` | `related_transaction_serial_num` → `serial_num` | ON DELETE: RESTRICT | 对应支付交易（可选） |

## 📑 索引建议

```sql
PRIMARY KEY (serial_num);

CREATE INDEX idx_bil_reminder_due_at ON bil_reminder(due_at);
CREATE INDEX idx_bil_reminder_enabled ON bil_reminder(enabled);
CREATE INDEX idx_bil_reminder_category ON bil_reminder(category);
CREATE INDEX idx_bil_reminder_is_paid ON bil_reminder(is_paid);
```

## 💡 使用示例

### 创建信用卡账单提醒

```rust
use entity::bil_reminder;
use sea_orm::*;

let reminder = bil_reminder::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("信用卡账单".to_string()),
    enabled: Set(true),
    r#type: Set("CreditCard".to_string()),
    description: Set(Some("每月15号出账，25号前还款".to_string())),
    category: Set("信用卡".to_string()),
    amount: Set(Some(dec!(3000.00))),
    currency: Set(Some("CNY".to_string())),
    due_at: Set(due_at),
    bill_date: Set(Some(bill_date)),
    remind_date: Set(remind_date),
    repeat_period_type: Set("Monthly".to_string()),
    repeat_period: Set(json!({ "day": 15 })),
    is_paid: Set(false),
    priority: Set("High".to_string()),
    advance_value: Set(Some(3)),
    advance_unit: Set(Some("Day".to_string())),
    color: Set(Some("#EF4444".to_string())),
    is_deleted: Set(false),
    reminder_methods: Set(Some(json!(["App", "Email"]))),
    timezone: Set(Some("Asia/Shanghai".to_string())),
    smart_reminder_enabled: Set(true),
    auto_reschedule: Set(true),
    payment_reminder_enabled: Set(true),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = reminder.insert(db).await?;
```

## ⚠️ 注意事项

1. **软删除**: 使用 `is_deleted` 标记，而不是物理删除，便于查看历史账单
2. **金额可选**: 对于金额不固定的账单（如水电费），`amount` 可以为空，仅作为提醒
3. **重复周期**: `repeat_period_type` + `repeat_period` 决定下次账单日期，生成逻辑由业务层处理
4. **与交易联动**: 可选地将实际支付的交易记录到 `related_transaction_serial_num`
5. **升级提醒**: 当启用 `escalation_enabled` 时，需在提醒任务中实现升级逻辑

## 🔗 相关表

- [transactions - 交易记录表](../core/transactions.md)
- [batch_reminders - 批量提醒任务表](./batch_reminders.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
