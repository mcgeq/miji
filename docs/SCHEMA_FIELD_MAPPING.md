# Schema字段映射表

**用途**: 修正新迁移文件以匹配schema.rs

---

## BilReminder

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| AccountSerialNum | ❌ 删除此字段 | 删除 |
| ReminderDate | RemindDate | 改名 |
| IsActive | Enabled | 改名 |
| Notes | Description | 改名 |
| AutoPayEnabled | AutoReschedule 或 PaymentReminderEnabled | 检查 |
| PaymentMethodConfig | ❌ 删除 | 删除 |

---

## Todo

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| RepeatPeriod | Repeat | 改名 |
| IsRecurring | ❌ 删除 | 删除 |

---

## TaskDependency

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| TodoSerialNum | TaskSerialNum | 改名 |
| DependsOnTodoSerialNum | DependsOnTaskSerialNum | 改名 |

---

## Attachment

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| FileSize | Size | 改名 |
| FileType | MimeType | 改名 |

---

## NotificationLogs

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| Type | NotificationType | 改名 |
| TargetId | ❌ 删除 | 删除 |
| Title | ❌ 删除 | 删除 |
| Content | ❌ 删除 | 删除 |

---

## NotificationSettings

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| IsEnabled | Enabled | 改名 |
| Config | ❌ 删除 | 删除 |

---

## BatchReminders

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| BatchType | ❌ 删除 | 删除 |
| ItemsCount | TotalCount | 改名 |
| CompletedAt | ❌ 删除 | 删除 |

---

## PeriodRecords

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| CycleLength | ❌ 删除 | 删除 |
| FlowLevel | ❌ 移动到PeriodDailyRecords | 删除 |

---

## PeriodSettings

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| ReminderEnabled | ❌ 删除 | 删除 |
| ReminderDaysBefore | ReminderDays | 改名 |

---

## PeriodDailyRecords

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| PeriodRecordSerialNum | PeriodSerialNum | 改名 |

---

## PeriodSymptoms

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| PeriodRecordSerialNum | PeriodDailyRecordsSerialNum | 改名 |
| Symptom | SymptomType | 改名 |
| Severity | Intensity | 改名 |

---

## PeriodPmsRecords

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| PeriodRecordSerialNum | PeriodSerialNum | 改名 |
| Date | StartDate, EndDate | 拆分 |
| Notes | ❌ 删除 | 删除 |

---

## PeriodPmsSymptoms

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| PmsRecordSerialNum | PeriodPmsRecordsSerialNum | 改名 |
| Symptom | SymptomType | 改名 |
| Severity | Intensity | 改名 |

---

## OperationLog

| 新迁移使用 | Schema.rs | 修改 |
|-----------|-----------|------|
| UserId | ActorId | 改名 |
| TargetType | TargetTable | 改名 |
| TargetId | RecordId | 改名 |
| Details | ChangesJson | 改名 |
| IpAddress | ❌ 删除 | 删除 |
| UserAgent | ❌ 删除 | 删除 |
| CreatedAt | RecordedAt | 改名 |
