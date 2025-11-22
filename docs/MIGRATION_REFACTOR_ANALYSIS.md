# 迁移文件重构分析报告

## 分析目标
分析所有迁移文件，按表分组，准备重构为每个表一个完整的迁移文件。

## 当前迁移文件统计
- **总文件数**: 64个
- **创建表文件**: ~40个
- **修改表文件**: ~24个

## 数据库表分类

### 1. 用户相关 (User)

#### Users 表
- **创建**: `m20250803_114611_create_user.rs`
- **初始化数据**: `m20250101_000000_insert_default_user.rs`

---

### 2. 货币相关 (Currency)

#### Currency 表
- **创建**: `m20250803_132058_create_currency.rs`
- **修改**: `m20251121_000001_add_currency_flags.rs` (添加 is_default, is_active 字段)

---

### 3. 账户相关 (Account)

#### Account 表
- **创建**: `m20250803_132124_create_account.rs`
- **修改**: `m20250101_120000_add_is_virtual_to_account.rs` (添加 is_virtual 字段)

---

### 4. 交易相关 (Transaction)

#### Transactions 表
- **创建**: `m20250803_132157_create_transactions.rs`
- **修改**:
  - `m20250102_000000_add_installment_fields_to_transactions.rs` (添加分期付款字段)
  - `m20251017_160622_create_transaction_alert.rs` (添加预警字段)
  - `m20251117_000001_remove_split_config_use_tables.rs` (移除 split_config JSON字段)

---

### 5. 预算相关 (Budget)

#### Budget 表
- **创建**: `m20250803_132130_create_budget.rs`
- **修改**:
  - `m20250924_185222_create_budget_alert.rs` (添加预警字段)
  - `m20251116_000007_enhance_budget_for_family.rs` (添加家庭账本支持)

#### BudgetAllocations 表
- **创建**: `m20251116_000007_enhance_budget_for_family.rs`

---

### 6. 分类相关 (Category)

#### Categories 表
- **创建**: `m20250916_221212_create_categories.rs`
- **修改**: `m20250918_115414_create_categories_alert.rs` (添加预警字段)

#### SubCategories 表
- **创建**: `m20251916_221213_create_sub_categories.rs`
- **初始化数据**:
  - `m20251917_223412_create_sub_category_insert.rs`
  - `m20251918_120000_add_sub_category_property_rental.rs`
  - `m20250120_000000_add_phone_bill_subcategory.rs`
- **修改**: `m20250918_121424_create_sub_categories_alert.rs` (添加预警字段)

---

### 7. 家庭账本相关 (Family Ledger)

#### FamilyLedger 表
- **创建**: `m20250803_132219_create_family_ledger.rs`
- **修改**:
  - `m20251112_000001_enhance_family_ledger_fields.rs` (扩展字段)
  - `m20251115_000000_add_settlement_day_to_family_ledger.rs` (添加结算日)
  - `m20251115_000007_change_family_ledger_counts_to_integer.rs` (修改计数字段类型)
  - `m20251116_000001_add_family_ledger_financial_stats.rs` (添加财务统计字段)

#### FamilyMember 表
- **创建**: `m20250803_132113_create_family_member.rs`
- **修改**:
  - `m20251112_000002_enhance_family_member_fields.rs` (扩展字段)
  - `m20251116_add_unique_constraint_family_member_name.rs` (添加唯一约束)

#### FamilyLedgerAccount 表
- **创建**: `m20250803_132247_create_family_ledger_account.rs`

#### FamilyLedgerTransaction 表
- **创建**: `m20250803_132301_create_family_ledger_transaction.rs`

#### FamilyLedgerMember 表
- **创建**: `m20250803_132314_create_family_ledger_member.rs`

---

### 8. 费用分摊相关 (Split)

#### SplitRules 表
- **创建**: `m20251112_000003_create_split_rules_table.rs`

#### SplitRecords 表
- **创建**: `m20251112_000004_create_split_records_table.rs`
- **修改**: `m20251116_drop_split_members.rs` (删除 split_members 字段)

#### SplitRecordDetails 表
- **创建**: `m20251116_create_split_record_details.rs`

---

### 9. 债务与结算 (Debt & Settlement)

#### DebtRelations 表
- **创建**: `m20251112_000005_create_debt_relations_table.rs`

#### SettlementRecords 表
- **创建**: `m20251112_000006_create_settlement_records_table.rs`

---

### 10. 分期付款 (Installment)

#### InstallmentPlans 表
- **创建**: `m20251116_000000_create_installment_tables.rs`

#### InstallmentDetails 表
- **创建**: `m20251116_000000_create_installment_tables.rs`

---

### 11. 账单提醒 (Bill Reminder)

#### BilReminder 表
- **创建**: `m20250803_132329_create_bil_reminder.rs`
- **修改**:
  - `m20250115_000002_enhance_bil_reminder_fields.rs` (扩展提醒字段)
  - `m20250924_184622_create_bil_reminder_alter.rs` (添加预警字段)

---

### 12. 通知相关 (Notification)

#### NotificationLogs 表
- **创建**: `m20250115_000004_create_notification_tables.rs`

#### NotificationSettings 表
- **创建**: `m20250115_000004_create_notification_tables.rs`

#### BatchReminders 表
- **创建**: `m20250115_000004_create_notification_tables.rs`

---

### 13. 待办事项 (Todo)

#### Todo 表
- **创建**: `m20250803_124210_create_todo.rs`
- **修改**:
  - `m20250115_000001_enhance_todo_reminder_fields.rs` (扩展提醒字段)
  - `m20250929_120022_create_todo_drop.rs` (删除某些字段?)
  - `m20250929_110022_create_todo_alert.rs` (添加预警字段)
  - `m20250929_121722_create_todo_repeat_period_type.rs` (添加重复周期类型)

#### TodoProject 表
- **创建**: `m20250803_124220_create_todo_project.rs`

#### TodoTag 表
- **创建**: `m20250803_124230_create_todo_tag.rs`

---

### 14. 项目与标签 (Project & Tag)

#### Project 表
- **创建**: `m20250803_122206_create_projects.rs`

#### Tag 表
- **创建**: `m20250803_122150_create_tags.rs`

---

### 15. 提醒相关 (Reminder)

#### Reminder 表
- **创建**: `m20250803_131055_create_reminder.rs`
- **修改**: `m20250115_000003_enhance_reminder_fields.rs` (扩展字段)

---

### 16. 任务依赖与附件 (Task)

#### TaskDependency 表
- **创建**: `m20250803_131019_create_task_dependency.rs`

#### Attachment 表
- **创建**: `m20250803_131035_create_task_attachment.rs`

---

### 17. 操作日志 (Operation Log)

#### OperationLog 表
- **创建**: `m20250803_124248_create_operation_log.rs`

---

### 18. 健康周期 (Health Period)

#### PeriodRecords 表
- **创建**: `m20250803_124310_create_health_period.rs`

#### PeriodSettings 表
- **创建**: `m20250914_212312_create_health_period_settings.rs`

#### PeriodDailyRecords 表
- **创建**: `m20250803_125402_create_health_period_daily_records.rs`

#### PeriodSymptoms 表
- **创建**: `m20250803_125420_create_health_period_symptoms.rs`

#### PeriodPmsRecords 表
- **创建**: `m20250803_125442_create_health_period_pms_records.rs`

#### PeriodPmsSymptoms 表
- **创建**: `m20250803_125454_create_health_period_pms_symptoms.rs`

---

## 重构策略

### 原则
1. **一表一文件**: 每个表的所有定义字段都放在一个迁移文件中
2. **先定义后数据**: 表定义在前，初始化数据在后
3. **保持依赖顺序**: 外键依赖的表必须先创建
4. **版本号统一**: 使用新的版本号序列

### 新迁移文件命名规范
格式: `m{YYYYMMDD}_{序号}_create_{table_name}.rs`

建议时间戳: `m20251122` (今天的日期)

### 依赖关系分析

```
Users
├── FamilyMember (可选)
└── FamilyLedger

Currency
└── Transactions
└── Account

Account
└── Transactions
└── FamilyLedgerAccount

FamilyLedger
├── FamilyLedgerMember
├── FamilyLedgerAccount
├── FamilyLedgerTransaction
└── SplitRules

FamilyMember
├── FamilyLedgerMember
├── SplitRecords
└── DebtRelations

Transactions
├── FamilyLedgerTransaction
├── SplitRecords
├── InstallmentPlans
└── TransactionAlert

Budget
└── BudgetAllocations

Categories
└── SubCategories

SplitRecords
└── SplitRecordDetails

SplitRules
└── SplitRecords

Todo
├── TodoProject
├── TodoTag
├── TaskDependency
└── Attachment

Project
└── TodoProject

Tag
└── TodoTag

Reminder
└── NotificationLogs

BilReminder
└── NotificationLogs
```

### 建议的新迁移文件顺序

1. `m20251122_001_create_users.rs` - Users 表 + 默认用户数据
2. `m20251122_002_create_currency.rs` - Currency 表 + 货币数据
3. `m20251122_003_create_account.rs` - Account 表
4. `m20251122_004_create_categories.rs` - Categories 表
5. `m20251122_005_create_sub_categories.rs` - SubCategories 表 + 初始数据
6. `m20251122_006_create_transactions.rs` - Transactions 表
7. `m20251122_007_create_budget.rs` - Budget 表
8. `m20251122_008_create_budget_allocations.rs` - BudgetAllocations 表
9. `m20251122_009_create_family_ledger.rs` - FamilyLedger 表
10. `m20251122_010_create_family_member.rs` - FamilyMember 表
11. `m20251122_011_create_family_ledger_account.rs` - FamilyLedgerAccount 表
12. `m20251122_012_create_family_ledger_transaction.rs` - FamilyLedgerTransaction 表
13. `m20251122_013_create_family_ledger_member.rs` - FamilyLedgerMember 表
14. `m20251122_014_create_split_rules.rs` - SplitRules 表
15. `m20251122_015_create_split_records.rs` - SplitRecords 表
16. `m20251122_016_create_split_record_details.rs` - SplitRecordDetails 表
17. `m20251122_017_create_debt_relations.rs` - DebtRelations 表
18. `m20251122_018_create_settlement_records.rs` - SettlementRecords 表
19. `m20251122_019_create_installment_plans.rs` - InstallmentPlans 表
20. `m20251122_020_create_installment_details.rs` - InstallmentDetails 表
21. `m20251122_021_create_bil_reminder.rs` - BilReminder 表
22. `m20251122_022_create_project.rs` - Project 表
23. `m20251122_023_create_tag.rs` - Tag 表
24. `m20251122_024_create_todo.rs` - Todo 表
25. `m20251122_025_create_todo_project.rs` - TodoProject 表
26. `m20251122_026_create_todo_tag.rs` - TodoTag 表
27. `m20251122_027_create_task_dependency.rs` - TaskDependency 表
28. `m20251122_028_create_attachment.rs` - Attachment 表
29. `m20251122_029_create_reminder.rs` - Reminder 表
30. `m20251122_030_create_notification_logs.rs` - NotificationLogs 表
31. `m20251122_031_create_notification_settings.rs` - NotificationSettings 表
32. `m20251122_032_create_batch_reminders.rs` - BatchReminders 表
33. `m20251122_033_create_operation_log.rs` - OperationLog 表
34. `m20251122_034_create_period_records.rs` - PeriodRecords 表
35. `m20251122_035_create_period_settings.rs` - PeriodSettings 表
36. `m20251122_036_create_period_daily_records.rs` - PeriodDailyRecords 表
37. `m20251122_037_create_period_symptoms.rs` - PeriodSymptoms 表
38. `m20251122_038_create_period_pms_records.rs` - PeriodPmsRecords 表
39. `m20251122_039_create_period_pms_symptoms.rs` - PeriodPmsSymptoms 表

---

## 重构工作清单

### 阶段1: 准备工作
- [x] 分析所有现有迁移文件
- [x] 识别表依赖关系
- [x] 确定新的迁移顺序
- [ ] 备份现有数据库

### 阶段2: 创建新迁移文件
- [ ] 创建用户相关表迁移
- [ ] 创建货币和账户相关表迁移
- [ ] 创建交易和预算相关表迁移
- [ ] 创建家庭账本相关表迁移
- [ ] 创建费用分摊相关表迁移
- [ ] 创建分期付款相关表迁移
- [ ] 创建提醒和通知相关表迁移
- [ ] 创建待办事项相关表迁移
- [ ] 创建健康周期相关表迁移

### 阶段3: 整合和测试
- [ ] 更新 lib.rs 注册新迁移
- [ ] 删除旧迁移文件
- [ ] 在测试环境运行迁移
- [ ] 验证数据完整性
- [ ] 验证外键约束
- [ ] 验证索引创建

### 阶段4: 文档更新
- [ ] 更新数据库文档
- [ ] 更新 README
- [ ] 创建迁移历史记录

---

## 注意事项

### ⚠️ 重要提示
1. **数据迁移**: 如果生产环境已有数据，需要编写数据迁移脚本
2. **版本控制**: 不要删除已运行过的迁移文件，考虑使用新的迁移目录
3. **测试先行**: 必须在测试环境完整验证后再应用到生产环境
4. **回滚计划**: 准备好回滚方案和数据备份

### 🔍 需要特别关注的表
1. **Transactions** - 有多次修改，字段较多
2. **FamilyLedger** - 有4次修改，逻辑复杂
3. **Budget** - 有扩展，关联表多
4. **Todo** - 有多次扩展提醒相关字段
5. **SplitRecords** - 新功能，需要整合多个迁移

---

## 下一步行动

执行重构前需要确认:
1. 是否要保留现有迁移历史?
2. 是否需要在新的目录下创建? (如 `migration_v2/`)
3. 生产环境数据迁移策略是什么?
4. 是否需要向后兼容?
