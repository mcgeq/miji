# 剩余迁移表创建指南

**当前进度**: 16/39 (41%)
**剩余**: 23个表

---

## 快速创建清单

由于剩余表数量较多，这里提供批量创建指南。每个表的源文件已在 `MIGRATION_REFACTOR_ANALYSIS.md` 中详细列出。

### 费用分摊 (5个) - 优先级最高

#### 017 - SplitRecords
- **源文件**: `m20251112_000004_create_split_records_table.rs` + `m20251116_drop_split_members.rs`
- **注意**: 不包含 `split_members` 字段（已废弃）
- **字段**: 22个（包含payer, owe, amount, status等）
- **外键**: Transactions, FamilyLedger, SplitRules, FamilyMember (payer/owe)
- **索引**: 5个

#### 018 - SplitRecordDetails
- **源文件**: `m20251116_create_split_record_details.rs`
- **字段**: 10个（member, amount, percentage, weight, isPaid等）
- **外键**: SplitRecords, FamilyMember
- **索引**: 3个

#### 019 - DebtRelations
- **源文件**: `m20251112_000005_create_debt_relations_table.rs`
- **字段**: 12个（creditor, debtor, amount, status等）
- **外键**: FamilyLedger, FamilyMember (creditor/debtor)
- **索引**: 4个 + unique(ledger+creditor+debtor)

#### 020 - SettlementRecords
- **源文件**: `m20251112_000006_create_settlement_records_table.rs`
- **字段**: 16个（type, period, amount, participants, status等）
- **外键**: FamilyLedger, FamilyMember (initiatedBy/completedBy)
- **索引**: 4个

#### 021 - BilReminder
- **源文件**: 3个文件需要整合
  - `m20250803_132329_create_bil_reminder.rs` (创建)
  - `m20250115_000002_enhance_bil_reminder_fields.rs` (扩展提醒字段)
  - `m20250924_184622_create_bil_reminder_alter.rs` (添加预警字段)
- **字段**: ~18个（category, amount, reminderDate, repeatPeriod等）
- **外键**: Account, Currency
- **复杂度**: ⭐⭐⭐

---

### 待办事项系统 (8个)

#### 022 - Project
- **源文件**: `m20250803_122206_create_projects.rs`
- **字段**: 简单表，约8个字段
- **复杂度**: ⭐

#### 023 - Tag  
- **源文件**: `m20250803_122150_create_tags.rs`
- **字段**: 简单表，约5个字段
- **复杂度**: ⭐

#### 024 - Todo (最复杂)
- **源文件**: 5个文件需要整合
  - `m20250803_124210_create_todo.rs`
  - `m20250115_000001_enhance_todo_reminder_fields.rs`
  - `m20250929_120022_create_todo_drop.rs`
  - `m20250929_110022_create_todo_alert.rs`
  - `m20250929_121722_create_todo_repeat_period_type.rs`
- **字段**: ~25个
- **复杂度**: ⭐⭐⭐⭐

#### 025-027 - 关联表
- TodoProject
- TodoTag
- TaskDependency
- **复杂度**: ⭐ (简单关联表)

#### 028 - Attachment
- **源文件**: `m20250803_131035_create_task_attachment.rs`
- **复杂度**: ⭐

#### 029 - Reminder
- **源文件**: 2个文件
  - `m20250803_131055_create_reminder.rs`
  - `m20250115_000003_enhance_reminder_fields.rs`
- **复杂度**: ⭐⭐

---

### 通知系统 (3个) - 一个文件包含3个表

#### 030-032 - Notification Tables
- **源文件**: `m20250115_000004_create_notification_tables.rs`
- **表**: NotificationLogs, NotificationSettings, BatchReminders
- **需要**: 拆分为3个独立的迁移文件
- **复杂度**: ⭐⭐

---

### 健康周期系统 (6个) - 简单表

#### 033 - PeriodRecords
- **源文件**: `m20250803_124310_create_health_period.rs`

#### 034 - PeriodSettings
- **源文件**: `m20250914_212312_create_health_period_settings.rs`

#### 035-038 - 周期相关表
- PeriodDailyRecords
- PeriodSymptoms
- PeriodPmsRecords
- PeriodPmsSymptoms
- **复杂度**: ⭐ (简单表，直接复制即可)

---

### 系统表 (1个)

#### 039 - OperationLog
- **源文件**: `m20250803_124248_create_operation_log.rs`
- **复杂度**: ⭐

---

## 创建策略

### 方案A: 手动逐个创建 (推荐复杂表)
适用于: Todo, BilReminder, SplitRecords等复杂表

### 方案B: 批量复制 (推荐简单表)
适用于: Project, Tag, 关联表, 健康系统表等

简单表可以直接从源文件复制，只需：
1. 更改文件名为新命名规范
2. 确认外键约束正确
3. 确认索引完整

### 方案C: 脚本辅助
为剩余23个表编写生成脚本（可选）

---

## SQLite 注意事项

1. **不支持 GIN 索引** - 移除 Budget 表中的 GIN 索引或标记为可选
2. **ALTER TABLE 限制** - SQLite 不支持某些 ALTER TABLE 操作
3. **JSON 字段** - 使用 `.json()` 而不是 `.json_binary()`
4. **外键** - 默认不启用，需要在连接时开启

---

## 下一步行动

### 立即创建（按优先级）
1. ✅ 017-020: 费用分摊表（SplitRecords, Details, Debt, Settlement）
2. ⬜ 021: BilReminder（3个文件整合）
3. ⬜ 024: Todo（5个文件整合）
4. ⬜ 022-023, 025-029: 待办系统其他表
5. ⬜ 030-032: 通知系统
6. ⬜ 033-039: 健康系统 + OperationLog

### 验证清单
- [ ] 所有表的外键依赖顺序正确
- [ ] SQLite特性兼容性检查
- [ ] 索引命名一致性
- [ ] 字段类型正确（特别是JSON）
- [ ] 默认值设置合理

---

## 工作量估算

- **费用分摊** (5个): 30分钟
- **待办系统** (8个): 45分钟
- **通知系统** (3个): 15分钟
- **健康+系统** (7个): 20分钟
- **总计**: 约2小时

---

## 文件模板

### 简单表模板
```rust
use sea_orm_migration::prelude::*;
use crate::schema::{TableName, RelatedTable};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.create_table(
            Table::create()
                .table(TableName::Table)
                .if_not_exists()
                // 添加列...
                .to_owned(),
        ).await?;
        
        // 添加索引...
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager.drop_table(Table::drop().table(TableName::Table).to_owned()).await?;
        Ok(())
    }
}
```

---

**建议**: 优先完成费用分摊表，这是系统核心功能。其他表可以根据需要按优先级创建。
