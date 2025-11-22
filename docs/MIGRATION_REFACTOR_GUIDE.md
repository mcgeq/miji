# 迁移文件重构实施指南

## 已完成的工作

### ✅ 阶段1: 分析与规划
- [x] 分析所有64个现有迁移文件
- [x] 识别39个数据库表及其依赖关系
- [x] 制定重构策略和新的迁移顺序
- [x] 生成详细分析报告: `MIGRATION_REFACTOR_ANALYSIS.md`

### ✅ 阶段2: 创建新迁移文件(已完成3个)
- [x] `m20251122_001_create_users.rs` - Users 表（完整字段）
- [x] `m20251122_002_create_currency.rs` - Currency 表（包含 is_default, is_active 字段 + 初始数据）
- [x] `m20251122_003_create_account.rs` - Account 表（包含 is_virtual 字段）

---

## 重构原则

1. **一表一文件**: 每个表的所有字段定义合并到一个迁移文件中
2. **先定义后数据**: 表结构 → 索引 → 初始数据
3. **保持依赖顺序**: 遵循外键约束的创建顺序
4. **文件命名规范**: `m20251122_{序号}_create_{table_name}.rs`

---

## 待创建的迁移文件清单

### 🔵 优先级1: 核心业务表 (7个)

#### ⬜ 004 - Categories
- **源文件**:
  - `m20250916_221212_create_categories.rs` (创建)
  - `m20250918_115414_create_categories_alert.rs` (添加预警字段)
- **字段整合**: 需添加预警相关字段
  
#### ⬜ 005 - SubCategories
- **源文件**:
  - `m20251916_221213_create_sub_categories.rs` (创建)
  - `m20251917_223412_create_sub_category_insert.rs` (初始数据)
  - `m20251918_120000_add_sub_category_property_rental.rs` (添加租金子分类)
  - `m20250120_000000_add_phone_bill_subcategory.rs` (添加话费子分类)
  - `m20250918_121424_create_sub_categories_alert.rs` (添加预警字段)
- **字段整合**: 需添加预警字段，合并所有初始数据

#### ⬜ 006 - Transactions
- **源文件**:
  - `m20250803_132157_create_transactions.rs` (创建)
  - `m20250102_000000_add_installment_fields_to_transactions.rs` (添加分期付款字段)
  - `m20251017_160622_create_transaction_alert.rs` (添加预警字段)
  - `m20251117_000001_remove_split_config_use_tables.rs` (移除 split_config 字段)
- **重要**: 需包含分期付款字段，但不包含 split_config JSON字段

#### ⬜ 007 - Budget
- **源文件**:
  - `m20250803_132130_create_budget.rs` (创建)
  - `m20250924_185222_create_budget_alert.rs` (添加预警字段)
  - `m20251116_000007_enhance_budget_for_family.rs` (添加家庭账本支持)
- **字段整合**: 需添加预警字段和家庭账本相关字段

#### ⬜ 008 - BudgetAllocations
- **源文件**:
  - `m20251116_000007_enhance_budget_for_family.rs` (创建此关联表)
- **依赖**: Budget, FamilyMember

#### ⬜ 009 - InstallmentPlans
- **源文件**:
  - `m20250116_000000_create_installment_tables.rs` (创建两个表)

#### ⬜ 010 - InstallmentDetails
- **源文件**:
  - `m20250116_000000_create_installment_tables.rs` (创建两个表)

---

### 🟢 优先级2: 家庭账本核心 (5个)

#### ⬜ 011 - FamilyLedger
- **源文件**:
  - `m20250803_132219_create_family_ledger.rs` (创建)
  - `m20251112_000001_enhance_family_ledger_fields.rs` (扩展字段)
  - `m20251115_000000_add_settlement_day_to_family_ledger.rs` (添加结算日)
  - `m20251115_000007_change_family_ledger_counts_to_integer.rs` (修改计数类型)
  - `m20251116_000001_add_family_ledger_financial_stats.rs` (添加财务统计)
- **复杂度**: ⭐⭐⭐⭐ 有4次修改，字段较多

#### ⬜ 012 - FamilyMember
- **源文件**:
  - `m20250803_132113_create_family_member.rs` (创建)
  - `m20251112_000002_enhance_family_member_fields.rs` (扩展字段)
  - `m20251116_add_unique_constraint_family_member_name.rs` (添加唯一约束)
- **重要**: name 字段需唯一约束

#### ⬜ 013 - FamilyLedgerAccount
- **源文件**:
  - `m20250803_132247_create_family_ledger_account.rs`

#### ⬜ 014 - FamilyLedgerTransaction
- **源文件**:
  - `m20250803_132301_create_family_ledger_transaction.rs`

#### ⬜ 015 - FamilyLedgerMember
- **源文件**:
  - `m20250803_132314_create_family_ledger_member.rs`

---

### 🟡 优先级3: 费用分摊与结算 (6个)

#### ⬜ 016 - SplitRules
- **源文件**:
  - `m20251112_000003_create_split_rules_table.rs`

#### ⬜ 017 - SplitRecords
- **源文件**:
  - `m20251112_000004_create_split_records_table.rs`
  - `m20251116_drop_split_members.rs` (删除 split_members 字段)
- **注意**: 不包含 split_members 字段

#### ⬜ 018 - SplitRecordDetails
- **源文件**:
  - `m20251116_create_split_record_details.rs`

#### ⬜ 019 - DebtRelations
- **源文件**:
  - `m20251112_000005_create_debt_relations_table.rs`

#### ⬜ 020 - SettlementRecords
- **源文件**:
  - `m20251112_000006_create_settlement_records_table.rs`

#### ⬜ 021 - BilReminder
- **源文件**:
  - `m20250803_132329_create_bil_reminder.rs` (创建)
  - `m20250115_000002_enhance_bil_reminder_fields.rs` (扩展提醒字段)
  - `m20250924_184622_create_bil_reminder_alter.rs` (添加预警字段)
- **复杂度**: ⭐⭐⭐ 有2次扩展

---

### 🟣 优先级4: 待办事项系统 (8个)

#### ⬜ 022 - Project
- **源文件**: `m20250803_122206_create_projects.rs`

#### ⬜ 023 - Tag
- **源文件**: `m20250803_122150_create_tags.rs`

#### ⬜ 024 - Todo
- **源文件**:
  - `m20250803_124210_create_todo.rs` (创建)
  - `m20250115_000001_enhance_todo_reminder_fields.rs` (扩展提醒字段)
  - `m20250929_120022_create_todo_drop.rs` (删除字段?)
  - `m20250929_110022_create_todo_alert.rs` (添加预警字段)
  - `m20250929_121722_create_todo_repeat_period_type.rs` (添加重复周期)
- **复杂度**: ⭐⭐⭐⭐ 有4次修改

#### ⬜ 025 - TodoProject
- **源文件**: `m20250803_124220_create_todo_project.rs`

#### ⬜ 026 - TodoTag
- **源文件**: `m20250803_124230_create_todo_tag.rs`

#### ⬜ 027 - TaskDependency
- **源文件**: `m20250803_131019_create_task_dependency.rs`

#### ⬜ 028 - Attachment
- **源文件**: `m20250803_131035_create_task_attachment.rs`

#### ⬜ 029 - Reminder
- **源文件**:
  - `m20250803_131055_create_reminder.rs` (创建)
  - `m20250115_000003_enhance_reminder_fields.rs` (扩展字段)

---

### 🔶 优先级5: 通知系统 (3个)

#### ⬜ 030 - NotificationLogs
- **源文件**: `m20250115_000004_create_notification_tables.rs` (3个表在一个文件)

#### ⬜ 031 - NotificationSettings
- **源文件**: `m20250115_000004_create_notification_tables.rs`

#### ⬜ 032 - BatchReminders
- **源文件**: `m20250115_000004_create_notification_tables.rs`

---

### 🟤 优先级6: 健康周期系统 (6个)

#### ⬜ 033 - PeriodRecords
- **源文件**: `m20250803_124310_create_health_period.rs`

#### ⬜ 034 - PeriodSettings
- **源文件**: `m20250914_212312_create_health_period_settings.rs`

#### ⬜ 035 - PeriodDailyRecords
- **源文件**: `m20250803_125402_create_health_period_daily_records.rs`

#### ⬜ 036 - PeriodSymptoms
- **源文件**: `m20250803_125420_create_health_period_symptoms.rs`

#### ⬜ 037 - PeriodPmsRecords
- **源文件**: `m20250803_125442_create_health_period_pms_records.rs`

#### ⬜ 038 - PeriodPmsSymptoms
- **源文件**: `m20250803_125454_create_health_period_pms_symptoms.rs`

---

### ⚪ 优先级7: 系统表 (1个)

#### ⬜ 039 - OperationLog
- **源文件**: `m20250803_124248_create_operation_log.rs`

---

## 创建步骤模板

### 单表单文件案例
```bash
1. 读取原始创建文件
2. 读取所有修改文件
3. 合并所有字段到一个 CREATE TABLE
4. 合并所有索引
5. 合并所有初始数据
6. 编写新的迁移文件
```

### 单文件多表案例 (如 Notification 表)
```bash
1. 读取包含多个表的原始文件
2. 拆分为独立的迁移文件
3. 保持索引和关联关系
```

### 多文件多表案例 (如 Installment 表)
```bash
1. 读取包含多个表的原始文件
2. 拆分为独立的迁移文件
3. 确定表的依赖顺序
```

---

## 批量创建建议

### 方案A: 手动逐个创建
- **优点**: 可以仔细检查每个表
- **缺点**: 耗时较长(预计3-4小时)
- **适用**: 复杂表(如 Todo, FamilyLedger, Transactions)

### 方案B: 脚本辅助创建
- **优点**: 快速批量处理简单表
- **缺点**: 需要编写脚本
- **适用**: 简单表(如关联表、无修改的表)

### 方案C: 混合方案(推荐)
1. **手动创建**: 复杂表(优先级1-3)
2. **批量创建**: 简单表(优先级4-7)

---

## 注意事项

### ⚠️ 高风险表
1. **Transactions** - 3次修改，字段众多，业务核心
2. **FamilyLedger** - 4次修改，逻辑复杂
3. **Todo** - 4次修改，提醒系统集成
4. **Budget** - 2次修改，家庭预算扩展
5. **SubCategories** - 4次数据插入，需要合并

### 🔍 需要特别确认的点
1. **SplitRecords**: 确认不包含 split_members JSON字段
2. **Transactions**: 确认不包含 split_config JSON字段
3. **FamilyMember.name**: 确认添加了唯一约束
4. **Currency.IsDefault**: 确认 CNY 设为默认值
5. **Account**: 确认包含 is_virtual 字段

### 📝 字段合并检查清单
- [ ] 所有 CREATE TABLE 语句收集完整
- [ ] 所有 ALTER TABLE ADD COLUMN 语句已整合
- [ ] 所有 CREATE INDEX 语句已包含
- [ ] 所有 INSERT 初始数据已合并
- [ ] 外键约束正确设置
- [ ] 默认值与原始迁移一致

---

## 下一步行动

### 立即行动(推荐顺序)
1. ✅ 完成基础表: Users, Currency, Account
2. ⬜ 创建核心业务表: Categories, SubCategories, Transactions, Budget
3. ⬜ 创建家庭账本核心表: FamilyLedger, FamilyMember + 3个关联表
4. ⬜ 创建费用分摊表: SplitRules, SplitRecords, SplitRecordDetails + 债务结算表
5. ⬜ 创建待办事项系统表
6. ⬜ 创建通知和健康周期表
7. ⬜ 更新 lib.rs 注册新迁移
8. ⬜ 测试验证

### 验证清单
- [ ] 所有表的依赖顺序正确
- [ ] 外键约束能够成功创建
- [ ] 初始数据插入成功
- [ ] 索引创建成功
- [ ] 在测试数据库运行成功
- [ ] Down 迁移能够正确回滚

---

## 进度追踪

- **总表数**: 39
- **已完成**: 3 (Users, Currency, Account)
- **待完成**: 36
- **完成度**: 7.7%

---

## 相关文档
- 📊 [迁移分析报告](./MIGRATION_REFACTOR_ANALYSIS.md) - 完整的表分析和依赖关系
- 📁 新迁移文件位置: `src-tauri/migration/src/new/`
- 📁 原迁移文件位置: `src-tauri/migration/src/`
