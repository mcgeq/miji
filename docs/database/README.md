# 数据库表结构文档索引

本文档提供 Miji 家庭记账系统所有数据库表的完整说明。

## 📚 文档说明

- 每张表都有独立的文档文件
- 按功能模块分类组织
- 包含字段说明、关系、索引、使用示例等

## 🗂️ 表分类

### 1️⃣ 核心功能表 (Core)

核心业务实体表，系统的基础数据结构。

| 表名 | 说明 | 文档链接 |
|------|------|---------|
| `family_ledger` | 家庭账本表 | [📄 查看详情](./core/family_ledger.md) |
| `family_member` | 家庭成员表 | [📄 查看详情](./core/family_member.md) |
| `account` | 账户表 | [📄 查看详情](./core/account.md) |
| `transactions` | 交易记录表 | [📄 查看详情](./core/transactions.md) |
| `currency` | 货币表 | [📄 查看详情](./core/currency.md) |
| `users` | 用户表 | [📄 查看详情](./core/users.md) |

### 2️⃣ 关联关系表 (Association)

多对多关系的中间表。

| 表名 | 说明 | 文档链接 |
|------|------|---------|
| `family_ledger_member` | 账本-成员关联表 | [📄 查看详情](./association/family_ledger_member.md) |
| `family_ledger_account` | 账本-账户关联表 | [📄 查看详情](./association/family_ledger_account.md) |
| `family_ledger_transaction` | 账本-交易关联表 | [📄 查看详情](./association/family_ledger_transaction.md) |
| `todo_project` | 待办-项目关联表 | [📄 查看详情](./association/todo_project.md) |
| `todo_tag` | 待办-标签关联表 | [📄 查看详情](./association/todo_tag.md) |
| `task_dependency` | 任务依赖关联表 | [📄 查看详情](./association/task_dependency.md) |

### 3️⃣ 财务管理表 (Financial)

财务相关的业务表。

| 表名 | 说明 | 文档链接 |
|------|------|---------|
| `budget` | 预算表 | [📄 查看详情](./financial/budget.md) |
| `categories` | 分类表 | [📄 查看详情](./financial/categories.md) |
| `sub_categories` | 子分类表 | [📄 查看详情](./financial/sub_categories.md) |
| `split_rules` | 分摊规则表 | [📄 查看详情](./financial/split_rules.md) |
| `split_records` | 分摊记录表 | [📄 查看详情](./financial/split_records.md) |
| `debt_relations` | 债务关系表 | [📄 查看详情](./financial/debt_relations.md) |
| `settlement_records` | 结算记录表 | [📄 查看详情](./financial/settlement_records.md) |
| `installment_plans` | 分期计划表 | [📄 查看详情](./financial/installment_plans.md) |
| `installment_details` | 分期明细表 | [📄 查看详情](./financial/installment_details.md) |

### 4️⃣ 业务功能表 (Business)

其他业务功能模块的表。

| 表名 | 说明 | 文档链接 |
|------|------|---------|
| `todo` | 待办事项表 | [📄 查看详情](./business/todo.md) |
| `project` | 项目表 | [📄 查看详情](./business/project.md) |
| `tag` | 标签表 | [📄 查看详情](./business/tag.md) |
| `reminder` | 提醒表 | [📄 查看详情](./business/reminder.md) |
| `bil_reminder` | 账单提醒表 | [📄 查看详情](./business/bil_reminder.md) |
| `batch_reminders` | 批量提醒表 | [📄 查看详情](./business/batch_reminders.md) |
| `period_records` | 生理期记录表 | [📄 查看详情](./business/period_records.md) |
| `period_daily_records` | 生理期每日记录表 | [📄 查看详情](./business/period_daily_records.md) |
| `period_symptoms` | 生理期症状表 | [📄 查看详情](./business/period_symptoms.md) |
| `period_pms_records` | 经前综合症记录表 | [📄 查看详情](./business/period_pms_records.md) |
| `period_pms_symptoms` | 经前综合症症状表 | [📄 查看详情](./business/period_pms_symptoms.md) |
| `period_settings` | 生理期设置表 | [📄 查看详情](./business/period_settings.md) |

### 5️⃣ 系统配置表 (System)

系统级配置和日志表。

| 表名 | 说明 | 文档链接 |
|------|------|---------|
| `attachment` | 附件表 | [📄 查看详情](./system/attachment.md) |
| `notification_settings` | 通知设置表 | [📄 查看详情](./system/notification_settings.md) |
| `notification_logs` | 通知日志表 | [📄 查看详情](./system/notification_logs.md) |
| `operation_log` | 操作日志表 | [📄 查看详情](./system/operation_log.md) |

## 📊 表关系图

```
┌─────────────────┐
│  family_ledger  │ (核心)
└────────┬────────┘
         │
         ├─────────────────────────────────┐
         │                                 │
         ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐
│ family_ledger_   │            │ family_ledger_   │
│    member        │            │    account       │
└────────┬─────────┘            └────────┬─────────┘
         │                               │
         ▼                               ▼
┌──────────────────┐            ┌──────────────────┐
│  family_member   │            │     account      │
└──────────────────┘            └──────────────────┘
                                         │
                                         ▼
                                ┌──────────────────┐
                                │   transactions   │
                                └────────┬─────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
            ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
            │ split_rules  │    │ split_records│    │debt_relations│
            └──────────────┘    └──────────────┘    └──────────────┘
```

## 🔍 快速查找

### 按功能查找

- **账本管理**: `family_ledger`, `family_member`, `family_ledger_member`
- **账户管理**: `account`, `family_ledger_account`
- **交易管理**: `transactions`, `family_ledger_transaction`, `categories`, `sub_categories`
- **预算管理**: `budget`
- **分摊结算**: `split_rules`, `split_records`, `debt_relations`, `settlement_records`
- **分期付款**: `installment_plans`, `installment_details`
- **提醒功能**: `reminder`, `bil_reminder`, `batch_reminders`
- **待办管理**: `todo`, `project`, `tag`, `todo_project`, `todo_tag`, `task_dependency`
- **生理期管理**: `period_*` 系列表
- **系统功能**: `users`, `currency`, `attachment`, `notification_*`, `operation_log`

### 按关系类型查找

- **主实体表**: `family_ledger`, `family_member`, `account`, `transactions`, `users`
- **关联表**: `family_ledger_member`, `family_ledger_account`, `family_ledger_transaction`
- **配置表**: `currency`, `categories`, `sub_categories`, `period_settings`, `notification_settings`
- **记录表**: `transactions`, `split_records`, `debt_relations`, `settlement_records`, `operation_log`

## 📝 文档约定

### 字段类型映射

| Rust 类型 | SQL 类型 | 说明 |
|-----------|---------|------|
| `String` | VARCHAR | 可变长度字符串 |
| `i32` | INTEGER | 32位整数 |
| `i64` | BIGINT | 64位整数 |
| `f64` | DOUBLE | 双精度浮点数 |
| `bool` | BOOLEAN | 布尔值 |
| `Decimal` | DECIMAL | 高精度十进制数（财务计算） |
| `Json` | JSON | JSON 数据 |
| `DateTimeWithTimeZone` | TIMESTAMP WITH TIME ZONE | 带时区的时间戳 |
| `Option<T>` | NULLABLE | 可为空的字段 |

### 约束说明

- **PK (Primary Key)**: 主键，唯一且非空
- **FK (Foreign Key)**: 外键，关联其他表
- **NOT NULL**: 不允许为空
- **NULLABLE**: 允许为空
- **UNIQUE**: 唯一约束
- **CHECK**: 检查约束，限制字段值范围
- **DEFAULT**: 默认值

### 级联操作

- **RESTRICT**: 限制删除，如果有引用则拒绝操作
- **CASCADE**: 级联操作，自动更新或删除相关记录
- **SET NULL**: 设置为 NULL
- **NO ACTION**: 不执行任何操作

## 🔧 迁移文件位置

所有数据库迁移文件位于：`src-tauri/migration/src/`

迁移文件命名规则：`mYYYYMMDD_NNNNNN_description.rs`

## 📚 相关资源

- [SeaORM 文档](https://www.sea-ql.org/SeaORM/)
- [SQLite 文档](https://www.sqlite.org/docs.html)
- [数据库设计最佳实践](../BEST_PRACTICES.md)

---

**文档版本**: v1.0  
**最后更新**: 2025-11-15  
**维护者**: Miji Team
