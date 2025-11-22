# 迁移文件字段完整性分析

**分析时间**: 2025-11-22 16:50
**状态**: 发现多处字段遗漏问题 ⚠️

---

## 🔴 严重问题清单

### 1. Transactions表 ✅ 已修正
- **问题**: 包含了已废弃的 `split_members` 字段
- **状态**: ✅ 已删除
- **废弃字段**:
  - `split_members` (JSON) - 已删除
  - `split_config` (JSON) - 原本就未包含

---

### 2. Todo表 ⚠️ 严重遗漏
**当前状态**: 只有12个基础字段
**应有状态**: 至少38个字段（基础 + 提醒 + 其他扩展）

#### 原始字段（m20250803_124210_create_todo.rs）
1. SerialNum
2. Title
3. Description
4. CreatedAt
5. UpdatedAt
6. DueAt
7. Priority
8. Status
9. Repeat (后被删除)
10. CompletedAt
11. AssigneeId
12. Progress
13. Location
14. OwnerId
15. IsArchived
16. IsPinned
17. EstimateMinutes
18. ReminderCount
19. ParentId
20. SubtaskOrder

#### 提醒扩展字段（m20250115_000001_enhance_todo_reminder_fields.rs）
21. ReminderEnabled
22. ReminderAdvanceValue
23. ReminderAdvanceUnit
24. LastReminderSentAt
25. ReminderFrequency
26. SnoozeUntil
27. ReminderMethods (JSON)
28. Timezone
29. SmartReminderEnabled
30. LocationBasedReminder
31. WeatherDependent
32. PriorityBoostEnabled
33. BatchReminderId

#### 字段变更（m20250929_*.rs）
- **删除**: `Repeat` (字符串类型)
- **添加**: `Repeat` (JSON类型) → 后又删除
- **添加**: `RepeatPeriod` (JSON)
- **添加**: `RepeatPeriodType` (字符串)
- **添加**: `IsRecurring` (布尔)

#### 当前创建的表 ❌ 不完整
只包含：
1. SerialNum
2. Title
3. Description
4. Status
5. Priority
6. DueDate (应该是 DueAt)
7. CompletedAt
8. RepeatPeriod
9. RepeatPeriodType
10. IsRecurring
11. ParentTodoSerialNum (应该是 ParentId)
12. CreatedAt
13. UpdatedAt

**缺失的字段**: 约20+个字段

---

### 3. BilReminder表 ⚠️ 遗漏字段
**当前状态**: 基础字段
**应有状态**: 基础 + 提醒扩展 + 预警字段

#### 原始字段（m20250803_132329_create_bil_reminder.rs）
1. SerialNum
2. AccountSerialNum
3. Name
4. Category
5. Amount
6. Currency
7. ReminderDate
8. RepeatPeriod
9. IsActive
10. Notes
11. CreatedAt
12. UpdatedAt

#### 提醒扩展字段（m20250115_000002_enhance_bil_reminder_fields.rs）
13. LastReminderSentAt
14. ReminderFrequency
15. SnoozeUntil
16. ReminderMethods (JSON)
17. EscalationEnabled
18. EscalationAfterHours
19. Timezone
20. SmartReminderEnabled
21. AutoPayEnabled
22. PaymentMethodConfig (JSON)
23. BatchReminderId

#### 预警字段（m20250924_184622_create_bil_reminder_alter.rs）
24. RepeatPeriodType

#### 当前创建的表 ❌ 不完整
只包含：
1. SerialNum
2. AccountSerialNum
3. Name
4. Category
5. Amount
6. Currency
7. ReminderDate
8. RepeatPeriod
9. RepeatPeriodType
10. IsActive
11. Notes
12. CreatedAt
13. UpdatedAt

**缺失的字段**: 约11个提醒扩展字段

---

### 4. Reminder表 ⚠️ 可能遗漏
**当前状态**: 基础字段
**应检查**: m20250115_000003_enhance_reminder_fields.rs

#### 原始字段（m20250803_131055_create_reminder.rs）
1. SerialNum
2. TodoSerialNum
3. RemindAt
4. Type
5. IsSent
6. CreatedAt
7. UpdatedAt

#### 可能的扩展字段（需要确认）
- 提醒方法
- 时区
- 智能提醒
- 等等

---

## 📋 完整的字段映射表

### Todo表完整字段列表

| 字段名 | 类型 | 来源文件 | 状态 | 是否包含 |
|--------|------|---------|------|---------|
| SerialNum | string(38) | 原始 | ✅ 保留 | ✅ |
| Title | string | 原始 | ✅ 保留 | ✅ |
| Description | text | 原始 | ✅ 保留 | ✅ |
| Status | string | 原始 | ✅ 保留 | ✅ |
| Priority | string | 原始 | ✅ 保留 | ✅ |
| DueAt | timestamp | 原始 | ⚠️ 改名DueDate | ⚠️ |
| CompletedAt | timestamp | 原始 | ✅ 保留 | ✅ |
| AssigneeId | string(38) | 原始 | ❌ 缺失 | ❌ |
| Progress | integer | 原始 | ❌ 缺失 | ❌ |
| Location | string | 原始 | ❌ 缺失 | ❌ |
| OwnerId | string(38) | 原始 | ⚠️ 改名ParentTodoSerialNum | ⚠️ |
| IsArchived | boolean | 原始 | ❌ 缺失 | ❌ |
| IsPinned | boolean | 原始 | ❌ 缺失 | ❌ |
| EstimateMinutes | integer | 原始 | ❌ 缺失 | ❌ |
| ReminderCount | integer | 原始 | ❌ 缺失 | ❌ |
| ParentId | string(38) | 原始 | ⚠️ 改名 | ⚠️ |
| SubtaskOrder | integer | 原始 | ❌ 缺失 | ❌ |
| RepeatPeriod | JSON | 新增 | ✅ 保留 | ✅ |
| RepeatPeriodType | string | 新增 | ✅ 保留 | ✅ |
| IsRecurring | boolean | 新增 | ✅ 保留 | ✅ |
| ReminderEnabled | boolean | 扩展 | ❌ 缺失 | ❌ |
| ReminderAdvanceValue | integer | 扩展 | ❌ 缺失 | ❌ |
| ReminderAdvanceUnit | string(20) | 扩展 | ❌ 缺失 | ❌ |
| LastReminderSentAt | timestamp | 扩展 | ❌ 缺失 | ❌ |
| ReminderFrequency | string(20) | 扩展 | ❌ 缺失 | ❌ |
| SnoozeUntil | timestamp | 扩展 | ❌ 缺失 | ❌ |
| ReminderMethods | JSON | 扩展 | ❌ 缺失 | ❌ |
| Timezone | string(50) | 扩展 | ❌ 缺失 | ❌ |
| SmartReminderEnabled | boolean | 扩展 | ❌ 缺失 | ❌ |
| LocationBasedReminder | boolean | 扩展 | ❌ 缺失 | ❌ |
| WeatherDependent | boolean | 扩展 | ❌ 缺失 | ❌ |
| PriorityBoostEnabled | boolean | 扩展 | ❌ 缺失 | ❌ |
| BatchReminderId | string(38) | 扩展 | ❌ 缺失 | ❌ |
| CreatedAt | timestamp | 原始 | ✅ 保留 | ✅ |
| UpdatedAt | timestamp | 原始 | ✅ 保留 | ✅ |

**统计**:
- ✅ 包含: 13个
- ❌ 缺失: 20个
- ⚠️ 字段名问题: 3个

---

## 🔧 修正方案

### 优先级1: 立即修正
1. **Todo表** - 添加所有缺失字段
2. **BilReminder表** - 添加提醒扩展字段

### 优先级2: 验证确认
3. **Reminder表** - 检查是否有扩展字段
4. **其他表** - 系统检查所有有ALTER TABLE操作的表

---

## 📊 受影响的迁移文件

### 需要重新创建
1. `m20251122_024_create_todo.rs` - 缺失20+字段
2. `m20251122_021_create_bil_reminder.rs` - 缺失11个字段
3. `m20251122_029_create_reminder.rs` - 待确认

---

## ⚠️ 风险评估

### 高风险
- Todo表字段不完整会导致应用功能异常
- 提醒功能完全无法工作

### 中风险
- BilReminder提醒功能不完整
- 数据迁移时可能出错

---

## 📝 下一步行动

1. ✅ 创建本分析文档
2. ⏳ 重新创建Todo表（完整版）
3. ⏳ 重新创建BilReminder表（完整版）
4. ⏳ 检查Reminder表
5. ⏳ 系统扫描所有表
6. ⏳ 更新文档

---

**结论**: 发现严重的字段遗漏问题，需要立即修正3个核心表。
