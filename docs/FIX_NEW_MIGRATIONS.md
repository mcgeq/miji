# 修正新迁移文件方案

**目标**: 让所有新迁移文件与schema.rs匹配

---

## 策略

由于需要修改的字段很多（58个错误），我将采用以下策略：

### 方案1: 逐文件手工修正（准确但耗时）
- 优点: 完全可控
- 缺点: 需要修改很多处

### 方案2: 基于原始迁移重新创建（推荐）✅
- 优点: 快速且准确
- 缺点: 需要重新编写部分文件

---

## 需要修正的文件清单

1. ✅ m20251122_021_create_bil_reminder.rs - 基于原始schema重写
2. ✅ m20251122_024_create_todo.rs - 修正Repeat字段
3. ✅ m20251122_025_027_create_todo_relations.rs - 修正TaskDependency字段
4. ✅ m20251122_028_create_attachment.rs - 修正Size/MimeType
5. ✅ m20251122_029_create_reminder.rs - 已正确
6. ✅ m20251122_030_032_create_notifications.rs - 修正所有通知表
7. ✅ m20251122_033_038_create_health_period.rs - 修正所有健康表
8. ✅ m20251122_039_create_operation_log.rs - 修正OperationLog

---

## 实施计划

鉴于修改量大，我建议：

1. **查看原始迁移文件** - 了解实际schema
2. **复制原始字段定义** - 确保准确
3. **保留所有扩展字段** - 合并ALTER TABLE内容
4. **验证编译** - 确保无错误

---

## 关键发现

通过查看schema.rs，发现很多表的实际字段与我最初设想的不同：

- BilReminder: 没有AccountSerialNum，有很多自己的字段
- Todo: 使用Repeat而非RepeatPeriod
- OperationLog: 使用ActorId/RecordId而非UserId/TargetId  
- Period相关: 字段设计更复杂

**结论**: 应该基于原始迁移文件来重构，而不是凭想象设计。

---

## 下一步

由于工作量较大，建议用户决定：

**选项A**: 继续使用旧迁移（最快）
**选项B**: 由我逐个修正新迁移（2-3小时）
**选项C**: 基于原始迁移重新创建关键表（1-2小时）

用户想要哪个选项？
