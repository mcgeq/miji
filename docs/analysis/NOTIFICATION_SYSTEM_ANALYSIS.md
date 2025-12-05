# Miji 通知系统分析

## 📋 目录
- [系统概览](#系统概览)
- [技术架构](#技术架构)
- [核心组件](#核心组件)
- [通知流程](#通知流程)
- [数据库设计](#数据库设计)
- [前端实现](#前端实现)
- [优缺点分析](#优缺点分析)
- [改进建议](#改进建议)

---

## 系统概览

### 技术栈
- **后端插件**: `tauri-plugin-notification` v2.x
- **前端**: Vue 3 + TypeScript
- **调度**: Tokio 异步定时任务
- **数据库**: SQLite (SeaORM)

### 功能范围
当前通知系统支持以下场景：
1. ✅ **待办提醒** - Todo Reminder
2. ✅ **账单提醒** - Bill Reminder
3. 📋 **通知设置** - Notification Settings (UI已实现，后端未完全集成)
4. 📋 **通知日志** - Notification Logs (表结构已建，未完全使用)

---

## 技术架构

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        前端 (Vue)                             │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ NotificationSettings │       │  Toast/Modal   │          │
│  │    (设置界面)         │       │   (消息提示)    │          │
│  └──────────────────┘         └──────────────────┘          │
│                 ▲                        ▲                    │
│                 │ Settings API          │ Tauri Event       │
│                 │                        │                    │
└─────────────────┼────────────────────────┼───────────────────┘
                  │                        │
┌─────────────────┼────────────────────────┼───────────────────┐
│                 ▼                        │                    │
│              Tauri Backend               │                    │
│                                          │                    │
│  ┌─────────────────────────────────────┐│                    │
│  │  tauri-plugin-notification          ││                    │
│  │  ┌──────────────────────────────┐   ││                    │
│  │  │ notification().builder()     │   ││                    │
│  │  │   .title()                   │   ││                    │
│  │  │   .body()                    │   ││                    │
│  │  │   .show()                    │   ││                    │
│  │  └──────────────────────────────┘   ││                    │
│  └─────────────────────────────────────┘│                    │
│                                          │                    │
│  ┌─────────────────────────────────────┐│                    │
│  │  SchedulerManager                   ││                    │
│  │  ┌──────────────────────────────┐   ││                    │
│  │  │ TodoNotification (60s)       │   ││                    │
│  │  │ BilReminder (60s)            │   ││                    │
│  │  │ Transaction (2h)             │   ││                    │
│  │  │ Budget (2h)                  │   ││                    │
│  │  └──────────────────────────────┘   ││                    │
│  └─────────────────────────────────────┘│                    │
│                                          │                    │
│  ┌─────────────────────────────────────┐│                    │
│  │  Service Layer                      ││                    │
│  │  ┌──────────────────────────────┐   ││                    │
│  │  │ TodosService                 │   ││                    │
│  │  │   - process_due_reminders()  │   ││                    │
│  │  │   - send_system_notification()│  ││                    │
│  │  │                              │   ││                    │
│  │  │ BilReminderService           │   ││                    │
│  │  │   - process_due_bil_reminders()│ ││                    │
│  │  │   - send_bil_system_notification()│││                  │
│  │  └──────────────────────────────┘   ││                    │
│  └─────────────────────────────────────┘│                    │
│                                          │                    │
│  ┌─────────────────────────────────────┐│                    │
│  │  Database (SQLite)                  ││                    │
│  │  ┌──────────────────────────────┐   ││                    │
│  │  │ reminder                     │   ││                    │
│  │  │ notification_settings        │   ││                    │
│  │  │ notification_logs            │   ││                    │
│  │  │ todo                         │   ││                    │
│  │  │ bil_reminder                 │   ││                    │
│  │  └──────────────────────────────┘   ││                    │
│  └─────────────────────────────────────┘│                    │
└──────────────────────────────────────────┼───────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    系统原生通知                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Windows    │  │    macOS     │  │   Linux      │      │
│  │   Toast      │  │ Notification │  │   libnotify  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心组件

### 1. Tauri 插件配置

**文件**: `src-tauri/Cargo.toml`
```toml
[workspace.dependencies]
tauri-plugin-notification = "2"

[dependencies]
tauri-plugin-notification = { workspace = true }
```

**权限配置**: `src-tauri/capabilities/default.json`
```json
{
  "permissions": [
    "notification:default"
  ]
}
```

**插件初始化**: `src-tauri/src/plugins.rs`
```rust
pub fn generic_plugins(builder: Builder<Wry>) -> Builder<Wry> {
    builder
        .plugin(tauri_plugin_notification::init())
        // ... 其他插件
}
```

### 2. 调度管理器

**文件**: `src-tauri/src/scheduler_manager.rs`

```rust
pub enum SchedulerTask {
    Transaction,         // 2小时间隔
    Todo,                // 2小时间隔
    TodoNotification,    // 60秒 (桌面) / 300秒 (移动)
    BilReminder,         // 60秒 (桌面) / 300秒 (移动)
    Budget,              // 2小时间隔
}
```

**关键特性**:
- ✅ 独立的任务调度器，支持启动/停止单个任务
- ✅ 平台感知间隔（移动端5分钟，桌面端1分钟）
- ✅ 基于 Tokio 的异步定时器
- ✅ 启动时自动初始化所有任务

### 3. 通知服务实现

#### 3.1 待办提醒服务

**文件**: `src-tauri/crates/todos/src/service/todo.rs`

```rust
/// 发送系统通知
pub async fn send_system_notification(
    &self,
    app: &tauri::AppHandle,
    todo: &entity::todo::Model,
) -> MijiResult<()> {
    use tauri_plugin_notification::NotificationExt;
    
    app.notification()
        .builder()
        .title(format!("待办提醒: {}", todo.title))
        .body(todo.description.unwrap_or("您有一条待办需要关注".to_string()))
        .show()
        .map_err(|e| AppError::simple(BusinessCode::SystemError, e.to_string()))?;
    
    // 事件通知前端
    app.emit("todo-reminder-fired", json!({
        "serialNum": todo.serial_num,
        "dueAt": todo.due_at.timestamp(),
    }));
    
    Ok(())
}
```

**处理流程**:
```rust
pub async fn process_due_reminders(&self, app: &AppHandle, db: &DbConn) -> MijiResult<usize> {
    // 1. 查询到期待办
    let todos = self.find_due_reminder_todos(db, now).await?;
    
    // 2. 遍历发送通知
    for todo in todos {
        self.send_system_notification(app, &todo).await?;
        
        // 3. 标记已提醒
        self.mark_reminded(db, &todo.serial_num, now, batch_id.clone()).await?;
    }
    
    Ok(todos.len())
}
```

#### 3.2 账单提醒服务

**文件**: `src-tauri/crates/money/src/services/bil_reminder.rs`

```rust
pub async fn send_bil_system_notification(
    &self,
    app: &tauri::AppHandle,
    br: &entity::bil_reminder::Model,
) -> MijiResult<()> {
    use tauri_plugin_notification::NotificationExt;
    
    let is_overdue = now > br.due_at;
    let is_escalation = br.escalation_enabled && is_overdue;
    
    // 根据状态构建不同的标题和内容
    let (title, body) = if is_escalation {
        (format!("⚠️ {}账单升级提醒: {}", urgency, br.name), ...)
    } else if is_overdue && !br.is_paid {
        (format!("💰 账单逾期: {}", br.name), ...)
    } else {
        (format!("账单提醒: {}", br.name), ...)
    };
    
    app.notification()
        .builder()
        .title(title)
        .body(body)
        .show()?;
    
    app.emit("bil-reminder-fired", ...);
    
    Ok(())
}
```

**高级特性**:
- ✅ 升级提醒（escalation）
- ✅ 逾期提醒
- ✅ 支付确认提醒
- ✅ 自动重新安排 (auto_reschedule)

---

## 通知流程

### 完整流程图

```
┌─────────────────────────────────────────────────────────┐
│ 1. 应用启动                                               │
│    SchedulerManager::start_all()                         │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 2. 启动定时任务                                           │
│    - TodoNotification (每60秒)                           │
│    - BilReminder (每60秒)                                │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 3. 定时器触发                                             │
│    interval.tick().await                                 │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 4. 服务层处理                                             │
│    TodosService::process_due_reminders()                 │
│    BilReminderService::process_due_bil_reminders()       │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 5. 查询到期记录                                           │
│    SELECT * FROM todo/bil_reminder                       │
│    WHERE reminder_at <= now AND is_reminded = false      │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 6. 发送系统通知                                           │
│    app.notification().builder()                          │
│       .title("...")                                      │
│       .body("...")                                       │
│       .show()                                            │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 7. 更新数据库                                             │
│    UPDATE todo/bil_reminder                              │
│    SET is_reminded = true, reminded_at = now             │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 8. 发送前端事件                                           │
│    app.emit("todo-reminder-fired", {...})                │
│    app.emit("bil-reminder-fired", {...})                 │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 9. 前端接收事件 (可选)                                     │
│    listen("todo-reminder-fired", (event) => {...})       │
│    - 更新UI                                              │
│    - 显示 Toast                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 数据库设计

### 表结构关系

```
┌──────────────────┐
│      users       │
│  (用户表)        │
└────────┬─────────┘
         │ 1
         │
         │ N
┌────────┴─────────────────────┐
│  notification_settings       │
│  (通知设置表)                 │
│  ┌──────────────────────┐   │
│  │ serial_num (PK)      │   │
│  │ user_id (FK)         │   │
│  │ notification_type    │   │ ← 类型: TodoReminder, BillReminder...
│  │ enabled              │   │ ← 是否启用
│  │ quiet_hours_start    │   │ ← 免打扰开始
│  │ quiet_hours_end      │   │ ← 免打扰结束
│  │ quiet_days           │   │ ← 免打扰日期
│  │ sound_enabled        │   │ ← 声音开关
│  │ vibration_enabled    │   │ ← 震动开关
│  └──────────────────────┘   │
└──────────────────────────────┘


┌──────────────────┐
│     reminder     │
│  (通用提醒表)     │
└────────┬─────────┘
         │ 1
         │
         │ N
┌────────┴─────────────────────┐
│  notification_logs           │
│  (通知日志表)                 │
│  ┌──────────────────────┐   │
│  │ serial_num (PK)      │   │
│  │ reminder_serial_num  │   │ ← 关联 reminder
│  │ notification_type    │   │ ← App/Email/SMS
│  │ status               │   │ ← Pending/Sent/Failed
│  │ sent_at              │   │ ← 发送时间
│  │ error_message        │   │ ← 错误信息
│  │ retry_count          │   │ ← 重试次数
│  │ last_retry_at        │   │ ← 最后重试时间
│  └──────────────────────┘   │
└──────────────────────────────┘


┌──────────────────┐
│      todo        │
│  (待办表)        │
│  ┌──────────┐   │
│  │ reminder_at│  │ ← 提醒时间
│  │ is_reminded│  │ ← 是否已提醒
│  │ reminded_at│  │ ← 提醒时间
│  └──────────┘   │
└──────────────────┘


┌──────────────────┐
│  bil_reminder    │
│  (账单提醒表)     │
│  ┌──────────┐   │
│  │ due_at   │   │ ← 到期时间
│  │ is_reminded│  │ ← 是否已提醒
│  │ reminded_at│  │ ← 提醒时间
│  │ escalation_enabled│ ← 升级提醒开关
│  │ auto_reschedule│ ← 自动重排开关
│  └──────────┘   │
└──────────────────┘
```

### 迁移文件

**创建通知相关表**: `m20251122_030_032_create_notifications.rs`
- notification_settings
- notification_logs
- batch_reminders

---

## 前端实现

### 通知设置页面

**文件**: `src/features/settings/views/NotificationSettings.vue`

**功能模块**:
1. **通知偏好** (Notification Preferences)
   - 总开关 (Enable Notifications)
   - 通知类型配置:
     - 消息 (Messages)
     - 邮件 (Emails)
     - 警报 (Alerts)
     - 社交 (Social)
   - 每种类型支持多种通知方式:
     - 桌面通知 (Desktop)
     - 移动通知 (Mobile)
     - 邮件通知 (Email)

2. **推送设置** (Push Settings)
   - 免打扰模式 (Do Not Disturb)
     - 开始时间/结束时间
     - 重复日期选择
   - 声音选择 (Sound)
     - default, gentle, alert, chime, none
   - 通知持续时间 (Duration)
     - 3秒, 5秒, 10秒, 手动关闭

3. **邮件通知** (Email Notification)
   - 摘要频率 (Summary Frequency)
     - never, daily, weekly, monthly
   - 营销邮件开关 (Marketing Emails)

**数据持久化**:
使用 `useAutoSaveSettings` composable 自动保存到数据库:
```typescript
const { fields, isSaving, resetAll } = useAutoSaveSettings({
  moduleName: 'notification',
  fields: {
    notificationsEnabled: createDatabaseSetting({
      key: 'settings.notification.enabled',
      defaultValue: true,
    }),
    // ... 更多字段
  },
});
```

### 前端事件监听

```typescript
import { listen } from '@tauri-apps/api/event';

// 监听待办提醒
listen('todo-reminder-fired', (event) => {
  const { serialNum, dueAt } = event.payload;
  // 更新UI或显示 toast
  toast.info(`待办到期: ${serialNum}`);
});

// 监听账单提醒
listen('bil-reminder-fired', (event) => {
  const { serialNum, dueAt } = event.payload;
  toast.warning(`账单提醒: ${serialNum}`);
});
```

---

## 优缺点分析

### ✅ 优点

1. **跨平台原生支持**
   - Windows Toast Notifications
   - macOS Notification Center
   - Linux libnotify
   - Android/iOS 原生通知

2. **轻量级实现**
   - 使用官方 Tauri 插件，稳定可靠
   - 无需额外的通知服务器
   - 代码简洁清晰

3. **灵活的调度系统**
   - 独立的任务管理器
   - 支持动态启停任务
   - 平台感知间隔（移动端节能）

4. **完整的设置界面**
   - 用户友好的UI
   - 细粒度控制
   - 自动保存

5. **事件驱动架构**
   - 后端→前端事件通知
   - 支持实时UI更新

### ❌ 缺点

1. **通知设置未完全集成**
   - UI已实现，但后端服务未真正使用 `notification_settings` 表
   - 免打扰、静音等设置没有生效
   - 通知类型配置未与实际通知逻辑绑定

2. **通知日志未使用**
   - `notification_logs` 表已建但未记录
   - 缺少发送历史和失败追踪
   - 无法统计通知效果

3. **缺少通知优先级**
   - 所有通知一视同仁
   - 无法根据重要性调整行为

4. **功能有限**
   - 不支持富通知（图片、按钮）
   - 不支持通知分组
   - 不支持延迟/定时发送
   - 不支持通知撤回

5. **平台差异处理不足**
   - 未针对不同平台特性优化
   - 移动端权限管理未详细说明

6. **测试覆盖不足**
   - 通知功能难以自动化测试
   - 缺少模拟环境

---

## 跨模块使用需求 ⚠️

### 潜在使用场景

当前通知系统只在 Todo 和 Money 模块使用，但以下模块都有通知需求：

| 模块 | 通知场景 | 优先级 | 状态 |
|------|---------|--------|------|
| **Todos** | 待办到期提醒 | ✅ 高 | ✅ 已实现 |
| **Money** | 账单提醒、分期提醒 | ✅ 高 | ✅ 已实现 |
| **Health/Period** | 经期提醒、排卵期提醒、PMS 提醒 | 🟡 中 | ❌ 未实现 |
| **Budget** | 预算超支警告 | 🟡 中 | ❌ 未实现 |
| **FamilyLedger** | 分摊提醒、债务提醒、结算提醒 | 🟢 低 | ❌ 未实现 |
| **System** | 系统更新、备份提醒 | 🟢 低 | ❌ 未实现 |

### 代码重复问题

每个模块都独立实现通知逻辑，导致：

1. **代码重复率 80%+**
   ```rust
   // Todos 模块
   pub async fn send_system_notification(...) {
       use tauri_plugin_notification::NotificationExt;
       app.notification().builder()...
   }
   
   // Money 模块
   pub async fn send_bil_system_notification(...) {
       use tauri_plugin_notification::NotificationExt;
       app.notification().builder()...
   }
   
   // 几乎相同的代码！
   ```

2. **功能不一致**
   - Todos 模块：无设置检查、无日志记录
   - Money 模块：无设置检查、无日志记录
   - 未来模块：需要重新实现所有逻辑

3. **维护成本高**
   - 修改通知逻辑需要改多个地方
   - 添加新功能（如优先级）需要在每个模块实现
   - Bug 修复需要同步到所有模块

### 解决方案

**创建统一的通知服务**，供所有模块复用：

```rust
// 统一服务（common crate）
pub struct NotificationService {
    // 所有通用逻辑
}

// 各模块使用
impl TodosService {
    pub async fn send_reminder(...) {
        let service = NotificationService::new();
        service.send(request).await?;
    }
}
```

详见：[统一通知服务设计](./UNIFIED_NOTIFICATION_SERVICE_DESIGN.md)

---

## 移动端兼容性 📱

### 当前状态

#### ✅ 已支持
- 权限配置 (`mobile.json` 包含 `notification:default`)
- 平台感知间隔（移动端 5分钟 vs 桌面端 1分钟）
- 基础通知发送

#### ❌ 缺失功能

1. **Android 特性**
   - ❌ 通知渠道 (Notification Channels)
   - ❌ 通知优先级适配
   - ❌ LED 灯效和震动配置
   - ❌ 电池优化豁免
   - ❌ 后台限制处理

2. **iOS 特性**
   - ❌ 权限请求流程
   - ❌ 通知角标 (Badge)
   - ❌ 声音配置
   - ❌ 通知分组
   - ❌ 后台通知限制

3. **通用问题**
   - ❌ 无权限检查逻辑
   - ❌ 权限被拒绝后的处理
   - ❌ 移动端特定 UI 提示

### Android 通知渠道

Android 8.0+ 要求使用通知渠道，当前未实现：

```rust
// ❌ 当前：直接发送，无渠道配置
app.notification().builder().title("...").show()?;

// ✅ 应该：指定渠道
app.notification()
    .builder()
    .channel("todo_reminders")  // 指定渠道
    .priority("high")            // 设置优先级
    .title("...")
    .show()?;
```

**需要在启动时创建渠道**：
```rust
#[cfg(target_os = "android")]
fn setup_channels(app: &AppHandle) {
    app.notification()
        .create_channel("todo_reminders", "待办提醒", "待办事项到期提醒")?;
    app.notification()
        .create_channel("bill_reminders", "账单提醒", "账单到期和逾期提醒")?;
}
```

### iOS 权限管理

iOS 需要明确请求通知权限：

```rust
// ❌ 当前：假设有权限，直接发送
app.notification().builder().show()?;

// ✅ 应该：先检查权限
if !has_permission(app).await? {
    request_permission(app).await?;
}
app.notification().builder().show()?;
```

**Info.plist 配置**：
```xml
<key>NSUserNotificationsUsageDescription</key>
<string>我们需要通知权限来提醒您的待办、账单和健康事项</string>
```

### 电池优化问题

Android 后台限制可能导致通知不及时：

**问题**：
- 应用在后台时，系统可能限制通知
- 电池优化会暂停后台任务
- 用户可能手动关闭后台权限

**解决方案**：
1. 请求电池优化豁免
2. 使用前台服务（长期运行）
3. 提示用户手动配置

### 移动端测试覆盖

| 测试项 | Android | iOS | 状态 |
|--------|---------|-----|------|
| 通知显示 | ⚠️ | ⚠️ | 基础可用 |
| 通知渠道 | ❌ | N/A | 未实现 |
| 权限请求 | ❌ | ❌ | 未实现 |
| 后台通知 | ❌ | ❌ | 未测试 |
| 应用被杀死 | ❌ | ❌ | 未测试 |
| 电池优化 | ❌ | N/A | 未处理 |
| 锁屏通知 | ⚠️ | ⚠️ | 未测试 |

---

## 改进建议

### 🔴 高优先级（必须）

#### 0. 创建统一通知服务 ⭐

**问题**: 代码重复、功能不一致、维护困难

**方案**: 创建 `NotificationService` 统一服务
- 所有模块使用相同接口
- 集中管理设置、日志、权限
- 支持平台特性适配

**工作量**: 1周  
**收益**: 代码减少 80%，功能增强 100%

详见：[统一通知服务设计](./UNIFIED_NOTIFICATION_SERVICE_DESIGN.md)

#### 1. 集成通知设置到后端逻辑

**问题**: 前端设置保存了，但后端不检查

**方案**:
```rust
// 在发送通知前检查用户设置
pub async fn check_notification_settings(
    db: &DbConn,
    user_id: &str,
    notification_type: &str,
) -> MijiResult<bool> {
    // 查询 notification_settings
    let settings = NotificationSettings::find()
        .filter(notification_settings::Column::UserId.eq(user_id))
        .filter(notification_settings::Column::NotificationType.eq(notification_type))
        .one(db)
        .await?;
    
    if let Some(s) = settings {
        // 检查是否启用
        if !s.enabled {
            return Ok(false);
        }
        
        // 检查免打扰时段
        if let (Some(start), Some(end)) = (s.quiet_hours_start, s.quiet_hours_end) {
            let now = Local::now().time();
            if now >= start && now <= end {
                return Ok(false);
            }
        }
        
        // 检查免打扰日期
        if let Some(days) = s.quiet_days {
            let today = Local::now().weekday();
            if days.contains(&today.to_string()) {
                return Ok(false);
            }
        }
    }
    
    Ok(true)
}

// 修改发送逻辑
pub async fn send_system_notification(&self, app: &AppHandle, todo: &Todo) -> MijiResult<()> {
    // 1. 检查设置
    let can_send = check_notification_settings(db, &todo.user_id, "TodoReminder").await?;
    if !can_send {
        log::debug!("通知被设置阻止: {}", todo.serial_num);
        return Ok(());
    }
    
    // 2. 发送通知
    app.notification().builder()...
}
```

#### 2. 实现通知日志记录

**方案**:
```rust
pub async fn send_and_log_notification(
    app: &AppHandle,
    db: &DbConn,
    reminder_id: &str,
    notification: NotificationBuilder,
) -> MijiResult<()> {
    // 创建日志记录
    let log_id = McgUuid::uuid(38);
    let log = notification_logs::ActiveModel {
        serial_num: Set(log_id.clone()),
        reminder_serial_num: Set(reminder_id.to_string()),
        notification_type: Set("App".to_string()),
        status: Set("Pending".to_string()),
        retry_count: Set(0),
        created_at: Set(DateUtils::local_now()),
        ..Default::default()
    };
    log.insert(db).await?;
    
    // 发送通知
    match notification.show() {
        Ok(_) => {
            // 更新为成功
            let mut log: notification_logs::ActiveModel = 
                NotificationLogs::find_by_id(log_id).one(db).await?.unwrap().into();
            log.status = Set("Sent".to_string());
            log.sent_at = Set(Some(DateUtils::local_now()));
            log.update(db).await?;
            Ok(())
        }
        Err(e) => {
            // 更新为失败
            let mut log: notification_logs::ActiveModel = 
                NotificationLogs::find_by_id(log_id).one(db).await?.unwrap().into();
            log.status = Set("Failed".to_string());
            log.error_message = Set(Some(e.to_string()));
            log.retry_count = Set(1);
            log.last_retry_at = Set(Some(DateUtils::local_now()));
            log.update(db).await?;
            Err(e.into())
        }
    }
}
```

#### 3. 添加通知优先级

**数据库扩展**:
```rust
// reminder 表添加字段
priority: String, // low, normal, high, urgent
```

**发送逻辑**:
```rust
match priority {
    "urgent" => {
        // 忽略免打扰设置
        // 使用更醒目的样式
    }
    "high" => {
        // 部分忽略免打扰
    }
    _ => {
        // 正常检查设置
    }
}
```

### 🟡 中优先级

#### 4. 支持富通知

```rust
use tauri_plugin_notification::NotificationExt;

app.notification()
    .builder()
    .title("账单逾期")
    .body("您的信用卡账单已逾期3天")
    .icon("path/to/icon.png")      // 自定义图标
    .action("立即支付")             // 添加操作按钮
    .action("稍后提醒")
    .show()?;
```

#### 5. 通知分组

```rust
app.notification()
    .builder()
    .title("待办提醒")
    .body("您有3条待办到期")
    .group("todo-reminders")       // 分组
    .tag(format!("todo-{}", date)) // 标签
    .show()?;
```

#### 6. 延迟/定时发送

```rust
pub struct DelayedNotification {
    pub send_at: DateTime<FixedOffset>,
    pub notification: NotificationData,
}

impl SchedulerManager {
    async fn run_delayed_notification_task(app: AppHandle) {
        let mut ticker = interval(Duration::from_secs(10));
        loop {
            ticker.tick().await;
            // 检查延迟通知队列
            // 发送到期的通知
        }
    }
}
```

### 🟢 低优先级

#### 7. 通知统计面板

前端实现一个统计页面：
- 通知发送总数
- 成功率
- 失败原因分析
- 用户交互率

#### 8. 通知模板系统

```rust
pub struct NotificationTemplate {
    pub id: String,
    pub title_template: String,      // "账单提醒: {bill_name}"
    pub body_template: String,       // "金额: {amount}, 到期: {due_date}"
    pub priority: Priority,
}
```

#### 9. 移动端推送

对于 Android/iOS，集成 FCM/APNs:
- 后台通知
- 静默推送
- 数据同步

---

## 总结

### 当前状态评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **基础功能** | 8/10 | 基本的通知发送已实现且运行良好 |
| **设置系统** | 4/10 | UI完善但后端未集成 |
| **日志追踪** | 2/10 | 表结构已建但未使用 |
| **用户体验** | 6/10 | 简单直接但缺少高级功能 |
| **可扩展性** | 7/10 | 架构清晰，易于扩展 |
| **稳定性** | 8/10 | 使用官方插件，稳定可靠 |
| **文档完善** | 5/10 | 代码注释较少，缺少系统文档 |
| **整体** | **6/10** | 基础扎实，需要功能完善 |

### 核心痛点

1. **设置与实现脱节** - UI有但不生效
2. **缺少日志追踪** - 排查问题困难
3. **功能相对基础** - 无法满足复杂需求

### 下一步行动

**短期目标** (1-2周):
1. ✅ 集成通知设置检查逻辑
2. ✅ 实现通知日志记录
3. ✅ 添加通知优先级

**中期目标** (1个月):
1. 支持富通知和分组
2. 实现延迟/定时发送
3. 添加通知统计面板

**长期目标** (2-3个月):
1. 移动端推送集成
2. 通知模板系统
3. A/B测试框架

---

**文档创建时间**: 2024-12-06  
**分析人**: Cascade AI  
**版本**: v1.0
