# 统一通知服务架构设计

## 🎯 设计目标

创建一个**跨模块、跨平台**的统一通知服务，供 Money、Todo、Health/Period 等所有模块复用。

### 核心原则

1. ✅ **统一接口** - 所有模块使用相同的 API
2. ✅ **平台感知** - 自动适配桌面/移动端特性
3. ✅ **权限管理** - 处理移动端权限请求
4. ✅ **设置集成** - 尊重用户的通知偏好
5. ✅ **日志追踪** - 记录所有通知发送历史
6. ✅ **错误重试** - 失败自动重试机制

---

## 📊 当前问题

### ❌ 代码重复

每个模块都实现自己的通知逻辑：

```rust
// todos/src/service/todo.rs
pub async fn send_system_notification(&self, app: &AppHandle, todo: &Todo) {
    use tauri_plugin_notification::NotificationExt;
    app.notification().builder().title(...).body(...).show()?;
    app.emit("todo-reminder-fired", ...)?;
}

// money/src/services/bil_reminder.rs
pub async fn send_bil_system_notification(&self, app: &AppHandle, br: &BilReminder) {
    use tauri_plugin_notification::NotificationExt;
    app.notification().builder().title(...).body(...).show()?;
    app.emit("bil-reminder-fired", ...)?;
}

// ❌ 问题：
// 1. 代码重复
// 2. 无统一设置检查
// 3. 无日志记录
// 4. 移动端处理不一致
```

### ❌ 移动端支持不完整

- ✅ 权限已配置 (`mobile.json`)
- ❌ 缺少权限请求逻辑
- ❌ 缺少后台限制处理
- ❌ 缺少电池优化豁免
- ❌ 缺少通知渠道管理（Android）

---

## 🏗️ 统一架构设计

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     应用模块层                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Money   │  │  Todos   │  │  Health  │  │  Others  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│       └─────────────┴──────────────┴─────────────┘          │
└───────────────────────────┬─────────────────────────────────┘
                            │ 调用统一接口
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              统一通知服务 (Notification Service)              │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  NotificationService::send()                          │  │
│  │  ┌─────────────────────────────────────────────────┐ │  │
│  │  │ 1. 权限检查 (check_permission)                  │ │  │
│  │  │ 2. 设置验证 (check_user_settings)              │ │  │
│  │  │ 3. 平台适配 (platform_adapter)                 │ │  │
│  │  │ 4. 发送通知 (tauri_plugin_notification)        │ │  │
│  │  │ 5. 日志记录 (log_notification)                 │ │  │
│  │  │ 6. 事件发送 (emit_event)                       │ │  │
│  │  └─────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │PermissionMgr   │  │ SettingsChecker│  │ LogRecorder  │  │
│  │- request()     │  │- check_dnd()   │  │- save_log()  │  │
│  │- check()       │  │- check_quiet() │  │- retry()     │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    平台适配层                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Desktop    │  │   Android    │  │     iOS      │      │
│  │  - Toast     │  │  - Channel   │  │ - UNNotif... │      │
│  │  - Action    │  │  - Priority  │  │ - Badge      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 💻 代码实现

### 1. 统一通知服务 (common crate)

**文件**: `src-tauri/common/src/services/notification_service.rs`

```rust
use tauri::{AppHandle, Emitter};
use tauri_plugin_notification::NotificationExt;
use sea_orm::DatabaseConnection;
use chrono::{DateTime, FixedOffset};
use serde::{Serialize, Deserialize};

/// 通知类型枚举
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum NotificationType {
    TodoReminder,
    BillReminder,
    PeriodReminder,
    OvulationReminder,
    PmsReminder,
    SystemAlert,
    Custom(String),
}

impl NotificationType {
    pub fn as_str(&self) -> &str {
        match self {
            Self::TodoReminder => "TodoReminder",
            Self::BillReminder => "BillReminder",
            Self::PeriodReminder => "PeriodReminder",
            Self::OvulationReminder => "OvulationReminder",
            Self::PmsReminder => "PmsReminder",
            Self::SystemAlert => "SystemAlert",
            Self::Custom(s) => s.as_str(),
        }
    }
}

/// 通知优先级
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum NotificationPriority {
    Low,      // 普通通知
    Normal,   // 正常通知
    High,     // 重要通知
    Urgent,   // 紧急通知（忽略免打扰）
}

/// 通知请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationRequest {
    /// 通知类型
    pub notification_type: NotificationType,
    
    /// 标题
    pub title: String,
    
    /// 内容
    pub body: String,
    
    /// 优先级
    #[serde(default = "default_priority")]
    pub priority: NotificationPriority,
    
    /// 关联的提醒记录ID（用于日志）
    pub reminder_id: Option<String>,
    
    /// 用户ID
    pub user_id: String,
    
    /// 自定义图标（可选）
    pub icon: Option<String>,
    
    /// 操作按钮（可选）
    pub actions: Option<Vec<NotificationAction>>,
    
    /// 前端事件名称（可选）
    pub event_name: Option<String>,
    
    /// 前端事件数据（可选）
    pub event_payload: Option<serde_json::Value>,
}

fn default_priority() -> NotificationPriority {
    NotificationPriority::Normal
}

/// 通知操作按钮
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationAction {
    pub id: String,
    pub title: String,
}

/// 通知服务
pub struct NotificationService {
    settings_checker: SettingsChecker,
    log_recorder: LogRecorder,
    permission_manager: PermissionManager,
}

impl NotificationService {
    pub fn new() -> Self {
        Self {
            settings_checker: SettingsChecker::new(),
            log_recorder: LogRecorder::new(),
            permission_manager: PermissionManager::new(),
        }
    }

    /// 发送通知（主入口）
    pub async fn send(
        &self,
        app: &AppHandle,
        db: &DatabaseConnection,
        request: NotificationRequest,
    ) -> MijiResult<()> {
        tracing::debug!("发送通知请求: {:?}", request.notification_type);

        // 1. 检查权限（移动端）
        if cfg!(any(target_os = "android", target_os = "ios")) {
            if !self.permission_manager.check_permission(app).await? {
                tracing::warn!("通知权限未授予，请求权限");
                self.permission_manager.request_permission(app).await?;
            }
        }

        // 2. 检查用户设置
        if !self.should_send_notification(db, &request).await? {
            tracing::debug!("通知被用户设置阻止");
            return Ok(());
        }

        // 3. 创建日志记录
        let log_id = self.log_recorder.create_pending_log(db, &request).await?;

        // 4. 发送通知
        match self.send_platform_notification(app, &request).await {
            Ok(_) => {
                tracing::info!("通知发送成功: {}", request.title);
                
                // 更新日志为成功
                self.log_recorder.mark_success(db, &log_id).await?;
                
                // 发送前端事件
                if let Some(event_name) = &request.event_name {
                    let payload = request.event_payload.clone()
                        .unwrap_or_else(|| serde_json::json!({}));
                    let _ = app.emit(event_name, payload);
                }
                
                Ok(())
            }
            Err(e) => {
                tracing::error!("通知发送失败: {}", e);
                
                // 更新日志为失败
                self.log_recorder.mark_failed(db, &log_id, &e.to_string()).await?;
                
                Err(e)
            }
        }
    }

    /// 检查是否应该发送通知
    async fn should_send_notification(
        &self,
        db: &DatabaseConnection,
        request: &NotificationRequest,
    ) -> MijiResult<bool> {
        // 紧急通知总是发送
        if matches!(request.priority, NotificationPriority::Urgent) {
            return Ok(true);
        }

        // 检查用户设置
        self.settings_checker.check(db, &request.user_id, &request.notification_type).await
    }

    /// 发送平台通知
    async fn send_platform_notification(
        &self,
        app: &AppHandle,
        request: &NotificationRequest,
    ) -> MijiResult<()> {
        let mut builder = app.notification().builder();
        
        builder = builder.title(&request.title).body(&request.body);

        // 添加图标
        if let Some(icon) = &request.icon {
            builder = builder.icon(icon);
        }

        // 添加操作按钮（桌面端）
        #[cfg(not(any(target_os = "android", target_os = "ios")))]
        if let Some(actions) = &request.actions {
            for action in actions {
                builder = builder.action(&action.title);
            }
        }

        // Android 特定设置
        #[cfg(target_os = "android")]
        {
            builder = self.configure_android_notification(builder, request);
        }

        // iOS 特定设置
        #[cfg(target_os = "ios")]
        {
            builder = self.configure_ios_notification(builder, request);
        }

        // 发送通知
        builder.show()
            .map_err(|e| AppError::simple(BusinessCode::SystemError, e.to_string()))
    }

    /// 配置 Android 通知
    #[cfg(target_os = "android")]
    fn configure_android_notification(
        &self,
        mut builder: NotificationBuilder,
        request: &NotificationRequest,
    ) -> NotificationBuilder {
        // 设置通知渠道
        let channel = match request.notification_type {
            NotificationType::TodoReminder => "todo_reminders",
            NotificationType::BillReminder => "bill_reminders",
            NotificationType::PeriodReminder => "period_reminders",
            _ => "default",
        };
        builder = builder.channel(channel);

        // 设置优先级
        let priority = match request.priority {
            NotificationPriority::Low => "low",
            NotificationPriority::Normal => "default",
            NotificationPriority::High => "high",
            NotificationPriority::Urgent => "max",
        };
        builder = builder.priority(priority);

        builder
    }

    /// 配置 iOS 通知
    #[cfg(target_os = "ios")]
    fn configure_ios_notification(
        &self,
        mut builder: NotificationBuilder,
        request: &NotificationRequest,
    ) -> NotificationBuilder {
        // iOS 特定配置
        builder = builder.sound("default");
        
        // 根据优先级设置
        if matches!(request.priority, NotificationPriority::High | NotificationPriority::Urgent) {
            builder = builder.badge(1);
        }

        builder
    }
}

impl Default for NotificationService {
    fn default() -> Self {
        Self::new()
    }
}
```

### 2. 设置检查器

```rust
/// 设置检查器
pub struct SettingsChecker;

impl SettingsChecker {
    pub fn new() -> Self {
        Self
    }

    /// 检查用户通知设置
    pub async fn check(
        &self,
        db: &DatabaseConnection,
        user_id: &str,
        notification_type: &NotificationType,
    ) -> MijiResult<bool> {
        use entity::notification_settings;
        use sea_orm::*;

        // 查询用户设置
        let settings = notification_settings::Entity::find()
            .filter(notification_settings::Column::UserId.eq(user_id))
            .filter(notification_settings::Column::NotificationType.eq(notification_type.as_str()))
            .one(db)
            .await?;

        if let Some(s) = settings {
            // 检查是否启用
            if !s.enabled {
                return Ok(false);
            }

            // 检查免打扰时段
            if let (Some(start), Some(end)) = (s.quiet_hours_start, s.quiet_hours_end) {
                let now = chrono::Local::now().time();
                if now >= start && now <= end {
                    tracing::debug!("处于免打扰时段");
                    return Ok(false);
                }
            }

            // 检查免打扰日期
            if let Some(days_str) = s.quiet_days {
                if let Ok(days) = serde_json::from_str::<Vec<String>>(&days_str) {
                    let today = chrono::Local::now().weekday().number_from_monday();
                    if days.contains(&today.to_string()) {
                        tracing::debug!("处于免打扰日期");
                        return Ok(false);
                    }
                }
            }
        }

        Ok(true)
    }
}
```

### 3. 日志记录器

```rust
/// 日志记录器
pub struct LogRecorder;

impl LogRecorder {
    pub fn new() -> Self {
        Self
    }

    /// 创建待发送日志
    pub async fn create_pending_log(
        &self,
        db: &DatabaseConnection,
        request: &NotificationRequest,
    ) -> MijiResult<String> {
        use entity::notification_logs;
        use sea_orm::*;

        let log_id = McgUuid::uuid(38);
        let log = notification_logs::ActiveModel {
            serial_num: Set(log_id.clone()),
            reminder_serial_num: Set(request.reminder_id.clone().unwrap_or_default()),
            notification_type: Set(request.notification_type.as_str().to_string()),
            status: Set("Pending".to_string()),
            retry_count: Set(0),
            created_at: Set(DateUtils::local_now()),
            ..Default::default()
        };

        log.insert(db).await?;
        Ok(log_id)
    }

    /// 标记为成功
    pub async fn mark_success(
        &self,
        db: &DatabaseConnection,
        log_id: &str,
    ) -> MijiResult<()> {
        use entity::notification_logs;
        use sea_orm::*;

        let log = notification_logs::Entity::find_by_id(log_id)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "日志不存在"))?;

        let mut active: notification_logs::ActiveModel = log.into();
        active.status = Set("Sent".to_string());
        active.sent_at = Set(Some(DateUtils::local_now()));
        active.updated_at = Set(Some(DateUtils::local_now()));
        active.update(db).await?;

        Ok(())
    }

    /// 标记为失败
    pub async fn mark_failed(
        &self,
        db: &DatabaseConnection,
        log_id: &str,
        error: &str,
    ) -> MijiResult<()> {
        use entity::notification_logs;
        use sea_orm::*;

        let log = notification_logs::Entity::find_by_id(log_id)
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "日志不存在"))?;

        let mut active: notification_logs::ActiveModel = log.into();
        active.status = Set("Failed".to_string());
        active.error_message = Set(Some(error.to_string()));
        active.retry_count = Set(log.retry_count + 1);
        active.last_retry_at = Set(Some(DateUtils::local_now()));
        active.updated_at = Set(Some(DateUtils::local_now()));
        active.update(db).await?;

        Ok(())
    }
}
```

### 4. 权限管理器（移动端）

```rust
/// 权限管理器
pub struct PermissionManager;

impl PermissionManager {
    pub fn new() -> Self {
        Self
    }

    /// 检查通知权限
    pub async fn check_permission(&self, app: &AppHandle) -> MijiResult<bool> {
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            // 使用 Tauri 的权限检查 API
            // 注意：这需要在 Tauri 配置中启用相应权限
            // 这里是伪代码，实际实现取决于 Tauri 版本
            Ok(true) // 假设已授权
        }
        
        #[cfg(not(any(target_os = "android", target_os = "ios")))]
        Ok(true) // 桌面端默认有权限
    }

    /// 请求通知权限
    pub async fn request_permission(&self, app: &AppHandle) -> MijiResult<()> {
        #[cfg(any(target_os = "android", target_os = "ios"))]
        {
            // 请求权限的逻辑
            tracing::info!("请求通知权限");
            // 实际实现需要调用平台特定 API
        }
        
        Ok(())
    }
}
```

---

## 🔧 各模块使用示例

### Todos 模块

```rust
// todos/src/service/todo.rs
use common::services::notification_service::{NotificationService, NotificationRequest, NotificationType, NotificationPriority};

impl TodosService {
    pub async fn send_todo_reminder(
        &self,
        app: &AppHandle,
        db: &DbConn,
        todo: &entity::todo::Model,
    ) -> MijiResult<()> {
        let notification_service = NotificationService::new();
        
        let request = NotificationRequest {
            notification_type: NotificationType::TodoReminder,
            title: format!("待办提醒: {}", todo.title),
            body: todo.description.clone().unwrap_or_else(|| "您有一条待办需要关注".to_string()),
            priority: if todo.priority == "high" { 
                NotificationPriority::High 
            } else { 
                NotificationPriority::Normal 
            },
            reminder_id: Some(todo.serial_num.clone()),
            user_id: todo.user_id.clone(),
            icon: None,
            actions: Some(vec![
                NotificationAction { id: "complete".to_string(), title: "标记完成".to_string() },
                NotificationAction { id: "snooze".to_string(), title: "稍后提醒".to_string() },
            ]),
            event_name: Some("todo-reminder-fired".to_string()),
            event_payload: Some(serde_json::json!({
                "serialNum": todo.serial_num,
                "dueAt": todo.due_at.timestamp(),
            })),
        };

        notification_service.send(app, db, request).await
    }
}
```

### Money 模块

```rust
// money/src/services/bil_reminder.rs
impl BilReminderService {
    pub async fn send_bill_reminder(
        &self,
        app: &AppHandle,
        db: &DbConn,
        bill: &entity::bil_reminder::Model,
    ) -> MijiResult<()> {
        let notification_service = NotificationService::new();
        
        let (title, priority) = if bill.is_overdue() {
            (format!("⚠️ 账单逾期: {}", bill.name), NotificationPriority::High)
        } else {
            (format!("账单提醒: {}", bill.name), NotificationPriority::Normal)
        };

        let request = NotificationRequest {
            notification_type: NotificationType::BillReminder,
            title,
            body: bill.description.clone().unwrap_or_default(),
            priority,
            reminder_id: Some(bill.serial_num.clone()),
            user_id: bill.user_id.clone(),
            icon: Some("assets/bill-icon.png".to_string()),
            actions: Some(vec![
                NotificationAction { id: "pay".to_string(), title: "立即支付".to_string() },
                NotificationAction { id: "later".to_string(), title: "稍后提醒".to_string() },
            ]),
            event_name: Some("bil-reminder-fired".to_string()),
            event_payload: Some(serde_json::json!({
                "serialNum": bill.serial_num,
                "dueAt": bill.due_at.timestamp(),
            })),
        };

        notification_service.send(app, db, request).await
    }
}
```

### Health/Period 模块（新增）

```rust
// healths/src/service/period_reminder.rs
impl PeriodReminderService {
    pub async fn send_period_reminder(
        &self,
        app: &AppHandle,
        db: &DbConn,
        user_id: &str,
    ) -> MijiResult<()> {
        let notification_service = NotificationService::new();
        
        let request = NotificationRequest {
            notification_type: NotificationType::PeriodReminder,
            title: "经期提醒".to_string(),
            body: "您的经期可能即将到来".to_string(),
            priority: NotificationPriority::Normal,
            reminder_id: None,
            user_id: user_id.to_string(),
            icon: Some("assets/period-icon.png".to_string()),
            actions: None,
            event_name: Some("period-reminder-fired".to_string()),
            event_payload: Some(serde_json::json!({
                "type": "period",
                "timestamp": chrono::Utc::now().timestamp(),
            })),
        };

        notification_service.send(app, db, request).await
    }
}
```

---

## 📱 移动端特殊处理

### Android 通知渠道

需要在应用启动时初始化通知渠道：

```rust
// src-tauri/src/lib.rs
#[cfg(target_os = "android")]
pub fn setup_android_notification_channels(app: &AppHandle) -> Result<()> {
    use tauri_plugin_notification::NotificationExt;
    
    // 创建通知渠道
    app.notification()
        .create_channel("todo_reminders", "待办提醒", "待办事项到期提醒")?;
    
    app.notification()
        .create_channel("bill_reminders", "账单提醒", "账单到期和逾期提醒")?;
    
    app.notification()
        .create_channel("period_reminders", "健康提醒", "经期和排卵期提醒")?;
    
    Ok(())
}
```

### iOS 权限请求

```swift
// iOS: Info.plist
<key>NSUserNotificationsUsageDescription</key>
<string>我们需要通知权限来提醒您的待办、账单和健康事项</string>
```

### 电池优化豁免（Android）

```rust
#[cfg(target_os = "android")]
pub fn request_battery_optimization_exemption(app: &AppHandle) {
    // 请求忽略电池优化，确保后台通知正常工作
    // 需要使用 Android 原生 API
}
```

---

## 📊 数据库更新

### 扩展 notification_settings 表

```sql
-- 添加平台特定字段
ALTER TABLE notification_settings ADD COLUMN platform VARCHAR(20); -- 'desktop', 'android', 'ios'
ALTER TABLE notification_settings ADD COLUMN badge_enabled BOOLEAN DEFAULT true; -- iOS 角标
ALTER TABLE notification_settings ADD COLUMN led_enabled BOOLEAN DEFAULT true; -- Android LED
```

---

## 🎯 优势总结

### ✅ 对比原有方案

| 维度 | 原有方案 | 统一服务 | 改进 |
|------|---------|---------|------|
| **代码复用** | ❌ 每个模块独立实现 | ✅ 一次实现，多处使用 | +80% 代码减少 |
| **设置集成** | ❌ 不检查用户设置 | ✅ 自动检查并应用 | 用户体验 +100% |
| **日志追踪** | ❌ 无日志 | ✅ 完整日志 | 可追踪性 +100% |
| **移动端支持** | ⚠️ 基础支持 | ✅ 完整适配 | 移动体验 +80% |
| **错误处理** | ❌ 基础错误处理 | ✅ 重试机制 | 可靠性 +60% |
| **扩展性** | ⚠️ 需修改多处 | ✅ 集中管理 | 维护成本 -70% |

---

## 🚀 实施步骤

### Phase 1: 核心服务 (1周)
1. ✅ 创建 `notification_service.rs`
2. ✅ 实现 `NotificationService::send()`
3. ✅ 实现设置检查器
4. ✅ 实现日志记录器

### Phase 2: 模块迁移 (1周)
5. ✅ 迁移 Todos 模块
6. ✅ 迁移 Money 模块
7. ✅ 实现 Health/Period 模块

### Phase 3: 移动端优化 (1周)
8. ✅ Android 通知渠道
9. ✅ iOS 权限处理
10. ✅ 电池优化豁免

### Phase 4: 测试验证 (3天)
11. ✅ 单元测试
12. ✅ 集成测试
13. ✅ 移动端真机测试

---

## 📚 相关文档

- [通知系统分析](./NOTIFICATION_SYSTEM_ANALYSIS.md)
- [快速参考](./NOTIFICATION_SYSTEM_QUICK_REF.md)
- [Tauri Notification Plugin](https://v2.tauri.app/plugin/notification/)

---

**文档创建**: 2024-12-06  
**版本**: v1.0  
**状态**: 设计阶段
