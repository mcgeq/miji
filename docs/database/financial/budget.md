# budget - 预算表

[← 返回索引](../README.md)

## 📋 表信息

- **表名**: `budget`
- **说明**: 预算配置表，用于管理账户 / 分类 / 多账户范围内的预算、进度和提醒
- **主键**: `serial_num`
- **创建迁移**: `m20250803_132228_create_budget.rs`

## 📊 表结构

### 基础字段

| 字段名 | 类型 | 长度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `serial_num` | VARCHAR | 38 | PK, NOT NULL | - | 预算唯一标识符（UUID） |
| `name` | VARCHAR | 100 | NOT NULL | - | 预算名称 |
| `description` | VARCHAR | 500 | NULLABLE | NULL | 预算描述 |
| `currency` | VARCHAR | 3 | NOT NULL | - | 预算货币代码（通常与账户/账本一致） |
| `is_active` | BOOLEAN | - | NOT NULL | true | 是否启用预算 |
| `budget_type` | VARCHAR | 20 | NOT NULL | 'Spending' | 预算类型 |
| `priority` | TINYINT | - | NOT NULL | 0 | 优先级（-128~127，一般使用 0~5） |
| `color` | VARCHAR | 7 | NULLABLE | NULL | UI 显示颜色（十六进制） |
| `linked_goal` | VARCHAR | 50 | NULLABLE | NULL | 关联目标ID（如储蓄目标） |
| `created_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 创建时间 |
| `updated_at` | TIMESTAMP WITH TIME ZONE | - | NULLABLE | NULL | 最后更新时间 |

**枚举值（约定）**：
- `budget_type`: 'Spending', 'Saving', 'IncomeLimit', 'Custom'

### 金额与周期字段

| 字段名 | 类型 | 精度 | 约束 | 默认值 | 说明 |
|--------|------|------|------|--------|------|
| `amount` | DECIMAL | (15, 2) | NOT NULL | 0.00 | 预算总金额（周期维度） |
| `used_amount` | DECIMAL | (15, 2) | NOT NULL | 0.00 | 从创建到现在累计已使用金额 |
| `current_period_used` | DECIMAL | (15, 2) | NOT NULL | 0.00 | 当前周期已使用金额 |
| `progress` | DECIMAL | (15, 2) | NOT NULL | 0.00 | 预算进度百分比（0~100，存为 0~100.00） |
| `repeat_period_type` | VARCHAR | 20 | NOT NULL | 'Monthly' | 周期类型 |
| `repeat_period` | JSON | - | NOT NULL | - | 周期配置（JSON） |
| `start_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 预算开始时间 |
| `end_date` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 预算结束时间（可能是某个远期时间） |
| `current_period_start` | DATE | - | NOT NULL | - | 当前周期开始日期 |
| `last_reset_at` | TIMESTAMP WITH TIME ZONE | - | NOT NULL | - | 上次重置日期时间 |

**用途说明**：
- `amount`: 单个周期的预算总额
- `used_amount`: 所有历史周期内已用金额，用于长期统计
- `current_period_used`: 当前周期已用金额，用于进度条显示
- `progress`: `current_period_used / amount * 100` 的结果
- `repeat_period_type`: 'Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly', 'Custom'
- `repeat_period`: 周期具体配置，例如：
  ```json
  { "type": "Monthly", "day": 1 }
  ```

### 范围与规则字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `budget_scope_type` | VARCHAR | 20 | NOT NULL | 'Account' | 预算作用范围类型 |
| `account_serial_num` | VARCHAR(38) | FK, NULLABLE | NULL | 单账户预算时的账户ID |
| `account_scope` | JSON | NULLABLE | NULL | 多账户范围（账户ID数组） |
| `category_scope` | JSON | NULLABLE | NULL | 分类范围（分类/子分类ID数组或名称） |
| `advanced_rules` | JSON | NULLABLE | NULL | 高级规则（如排除某些标签/交易） |

**用途说明**：
- `budget_scope_type`: 'Account', 'Category', 'Mixed', 'Global'
- `account_serial_num`: 当 `budget_scope_type = 'Account'` 时，指定单一账户
- `account_scope`: 多账户预算（示例：`["acc-1", "acc-2"]`）
- `category_scope`: 针对分类的预算（示例：`{"include": ["餐饮", "交通"], "exclude": ["报销"]}`）
- `advanced_rules`: 复杂过滤条件，例如：
  ```json
  {
    "excludeTags": ["报销"],
    "minAmount": 10,
    "maxAmount": 500
  }
  ```

### 提醒与滚动字段

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `alert_enabled` | BOOLEAN | NOT NULL | true | 是否启用预算预警 |
| `alert_threshold` | JSON | NULLABLE | NULL | 预警阈值配置 |
| `reminders` | JSON | NULLABLE | NULL | 自定义提醒设置 |
| `auto_rollover` | BOOLEAN | NOT NULL | false | 是否自动结转剩余额度 |
| `rollover_history` | JSON | NULLABLE | NULL | 结转历史记录 |
| `sharing_settings` | JSON | NULLABLE | NULL | 分享设置（哪些成员可见/可编辑） |
| `attachments` | JSON | NULLABLE | NULL | 附件信息（票据、截图等） |
| `tags` | JSON | NULLABLE | NULL | 标签列表 |

**用途说明**：
- `alert_threshold`: 示例：
  ```json
  { "warning": 80, "critical": 95 }
  ```
- `reminders`: 示例：
  ```json
  [
    { "type": "BeforeEnd", "days": 3 },
    { "type": "OnOverBudget" }
  ]
  ```
- `auto_rollover`: 上周期未用完的额度是否结转到下一周期
- `rollover_history`: 记录每次结转的时间和金额
- `sharing_settings`: 控制预算在家庭成员之间的可见性
- `attachments`: 保存票据扫描件等

## 🔗 关系说明

### 外键关系

| 关系类型 | 目标表 | 关联字段 | 级联操作 | 说明 |
|---------|--------|---------|---------|------|
| BELONGS_TO | `account` | `account_serial_num` → `serial_num` | ON DELETE: CASCADE<br>ON UPDATE: CASCADE | 单账户预算对应的账户 |

> 注意：多账户/按分类的预算通过 JSON 字段 `account_scope`、`category_scope` 进行关联，而不是外键。

## 📑 索引建议

```sql
-- 主键索引（自动创建）
PRIMARY KEY (serial_num)

-- 启用状态索引
CREATE INDEX idx_budget_active ON budget(is_active);

-- 范围和周期查询索引
CREATE INDEX idx_budget_scope_type ON budget(budget_scope_type);
CREATE INDEX idx_budget_type_active ON budget(budget_type, is_active);
CREATE INDEX idx_budget_period ON budget(repeat_period_type, current_period_start);

-- 单账户预算索引
CREATE INDEX idx_budget_account ON budget(account_serial_num);

-- 警告查询索引（示例：进度较高的预算）
CREATE INDEX idx_budget_progress ON budget(progress);
```

## 💡 使用示例

### 创建一个按月的餐饮预算（按分类）

```rust
use entity::budget;
use sea_orm::*;

let food_budget = budget::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("餐饮预算".to_string()),
    description: Set(Some("本月餐饮支出控制".to_string())),
    amount: Set(dec!(2000.00)),
    currency: Set("CNY".to_string()),
    repeat_period_type: Set("Monthly".to_string()),
    repeat_period: Set(json!({ "type": "Monthly", "day": 1 })),
    start_date: Set(Utc::now().into()),
    end_date: Set((Utc::now() + chrono::Duration::days(365)).into()),
    used_amount: Set(dec!(0.00)),
    current_period_used: Set(dec!(0.00)),
    is_active: Set(true),
    alert_enabled: Set(true),
    alert_threshold: Set(Some(json!({ "warning": 80, "critical": 95 }))),
    color: Set(Some("#EF4444".to_string())),
    budget_type: Set("Spending".to_string()),
    progress: Set(dec!(0.00)),
    budget_scope_type: Set("Category".to_string()),
    account_serial_num: Set(None),
    account_scope: Set(None),
    category_scope: Set(Some(json!({ "include": ["餐饮"] }))),
    current_period_start: Set(chrono::Utc::now().date_naive()),
    last_reset_at: Set(Utc::now().into()),
    priority: Set(1),
    auto_rollover: Set(false),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = food_budget.insert(db).await?;
```

### 创建一个账户级预算（银行卡支出）

```rust
let card_budget = budget::ActiveModel {
    serial_num: Set(McgUuid::new().to_string()),
    name: Set("银行卡支出预算".to_string()),
    amount: Set(dec!(5000.00)),
    currency: Set("CNY".to_string()),
    repeat_period_type: Set("Monthly".to_string()),
    repeat_period: Set(json!({ "type": "Monthly", "day": 1 })),
    start_date: Set(Utc::now().into()),
    end_date: Set((Utc::now() + chrono::Duration::days(365)).into()),
    used_amount: Set(dec!(0.00)),
    current_period_used: Set(dec!(0.00)),
    is_active: Set(true),
    alert_enabled: Set(true),
    alert_threshold: Set(Some(json!({ "warning": 90 }))),
    budget_type: Set("Spending".to_string()),
    budget_scope_type: Set("Account".to_string()),
    account_serial_num: Set(Some(account_id.clone())),
    current_period_start: Set(chrono::Utc::now().date_naive()),
    last_reset_at: Set(Utc::now().into()),
    progress: Set(dec!(0.00)),
    priority: Set(0),
    auto_rollover: Set(true),
    created_at: Set(Utc::now().into()),
    ..Default::default()
};

let result = card_budget.insert(db).await?;
```

### 更新当前周期使用金额与进度

```rust
let budget = Budget::find_by_id(budget_id)
    .one(db)
    .await?
    .unwrap();

let mut active: budget::ActiveModel = budget.into();

// 假设本次新增支出为 delta
let delta = dec!(150.00);
let new_used = active.current_period_used.clone().unwrap() + delta;
active.current_period_used = Set(new_used);

let amount = active.amount.clone().unwrap();
let progress = if amount.is_zero() {
    dec!(0.00)
} else {
    (new_used / amount) * dec!(100.00)
};
active.progress = Set(progress);
active.updated_at = Set(Some(Utc::now().into()));

active.update(db).await?;
```

### 查询当前激活的预算

```rust
let active_budgets = Budget::find()
    .filter(budget::Column::IsActive.eq(true))
    .all(db)
    .await?;
```

## ⚠️ 注意事项

1. **金额单位**: 所有金额字段使用 DECIMAL(15,2)，避免浮点误差
2. **进度计算**: `progress` 应始终与 `current_period_used / amount` 一致，更新时需同步维护
3. **周期重置**: 到达新周期时需要重置 `current_period_used` 并更新 `current_period_start`、`last_reset_at`
4. **多账户/多分类范围**: `account_scope` 和 `category_scope` 为 JSON，需要在应用层解析
5. **自动结转**: 当 `auto_rollover = true` 时，需要将上周期剩余额度写入 `rollover_history`
6. **提醒策略**: `alert_threshold` 仅定义阈值，具体何时触发提醒由业务层控制
7. **性能考虑**: 预算计算通常基于交易聚合，建议使用预计算或定时任务更新
8. **可见性控制**: `sharing_settings` 仅定义规则，实际权限控制需在服务层实现

## 🔗 相关表

- [account - 账户表](../core/account.md)
- [transactions - 交易记录表](../core/transactions.md)
- [family_ledger - 家庭账本表](../core/family_ledger.md)

---

**最后更新**: 2025-11-15  
[← 返回索引](../README.md)
