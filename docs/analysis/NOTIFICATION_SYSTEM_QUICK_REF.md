# 通知系统快速参考

## 📌 关键信息

### 技术栈
- **插件**: `tauri-plugin-notification` v2
- **调度**: Tokio async intervals
- **数据库**: SQLite (SeaORM)

### 通知类型
1. **待办提醒** (TodoNotification) - 每60秒扫描
2. **账单提醒** (BilReminder) - 每60秒扫描

---

## 🔧 使用方式

### 后端发送通知

```rust
use tauri_plugin_notification::NotificationExt;

// 基础用法
app.notification()
    .builder()
    .title("标题")
    .body("内容")
    .show()?;

// 带事件回流
app.notification()
    .builder()
    .title("待办提醒")
    .body("您有一条待办到期")
    .show()?;

app.emit("todo-reminder-fired", json!({
    "serialNum": "...",
    "dueAt": 1234567890,
}))?;
```

### 前端监听事件

```typescript
import { listen } from '@tauri-apps/api/event';

listen('todo-reminder-fired', (event) => {
  console.log('待办提醒:', event.payload);
});

listen('bil-reminder-fired', (event) => {
  console.log('账单提醒:', event.payload);
});
```

---

## 📁 关键文件

| 文件 | 说明 |
|------|------|
| `src-tauri/src/plugins.rs` | 插件初始化 |
| `src-tauri/src/scheduler_manager.rs` | 定时任务管理器 |
| `src-tauri/crates/todos/src/service/todo.rs` | 待办通知服务 |
| `src-tauri/crates/money/src/services/bil_reminder.rs` | 账单通知服务 |
| `src/features/settings/views/NotificationSettings.vue` | 通知设置UI |
| `src-tauri/capabilities/default.json` | 权限配置 |

---

## 🗄️ 数据库表

### notification_settings
用户通知偏好设置（**UI已实现，后端未集成**）

```sql
CREATE TABLE notification_settings (
    serial_num VARCHAR(38) PRIMARY KEY,
    user_id VARCHAR(38) NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    quiet_days JSON,
    sound_enabled BOOLEAN NOT NULL DEFAULT true,
    vibration_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

### notification_logs
通知发送日志（**表已建，未使用**）

```sql
CREATE TABLE notification_logs (
    serial_num VARCHAR(38) PRIMARY KEY,
    reminder_serial_num VARCHAR(38) NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    sent_at TIMESTAMP WITH TIME ZONE,
    error_message VARCHAR(500),
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_retry_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

---

## 🚦 调度任务配置

```rust
pub enum SchedulerTask {
    TodoNotification,    // 60秒 (桌面) / 300秒 (移动)
    BilReminder,         // 60秒 (桌面) / 300秒 (移动)
    Transaction,         // 2小时
    Todo,                // 2小时
    Budget,              // 2小时
}
```

---

## ⚠️ 已知问题

### 🔴 严重问题

1. **通知设置未生效**
   - 前端设置保存了，但后端不检查
   - 免打扰、静音等功能无效
   
2. **缺少日志记录**
   - notification_logs 表未使用
   - 无法追踪通知发送历史

### 🟡 需要改进

3. **无通知优先级**
   - 所有通知同等对待
   - 无法区分紧急/普通

4. **功能基础**
   - 不支持富通知（图片、按钮）
   - 不支持通知分组
   - 不支持延迟发送

---

## 🎯 快速修复指南

### 修复1: 集成通知设置检查

**文件**: `src-tauri/crates/todos/src/service/todo.rs`

```rust
// 在发送前检查设置
pub async fn send_system_notification(
    &self,
    app: &tauri::AppHandle,
    db: &DbConn,
    todo: &entity::todo::Model,
) -> MijiResult<()> {
    // 1. 检查用户设置
    let settings = NotificationSettings::find()
        .filter(notification_settings::Column::UserId.eq(&todo.user_id))
        .filter(notification_settings::Column::NotificationType.eq("TodoReminder"))
        .one(db)
        .await?;
    
    if let Some(s) = settings {
        if !s.enabled {
            log::debug!("通知已禁用: {}", todo.serial_num);
            return Ok(());
        }
        
        // 检查免打扰
        if let (Some(start), Some(end)) = (s.quiet_hours_start, s.quiet_hours_end) {
            let now = Local::now().time();
            if now >= start && now <= end {
                log::debug!("处于免打扰时段: {}", todo.serial_num);
                return Ok(());
            }
        }
    }
    
    // 2. 发送通知
    use tauri_plugin_notification::NotificationExt;
    app.notification()
        .builder()
        .title(format!("待办提醒: {}", todo.title))
        .body(todo.description.clone().unwrap_or_default())
        .show()?;
    
    Ok(())
}
```

### 修复2: 添加日志记录

```rust
pub async fn send_with_log(
    app: &AppHandle,
    db: &DbConn,
    reminder_id: &str,
    title: String,
    body: String,
) -> MijiResult<()> {
    // 创建日志
    let log = notification_logs::ActiveModel {
        serial_num: Set(McgUuid::uuid(38)),
        reminder_serial_num: Set(reminder_id.to_string()),
        notification_type: Set("App".to_string()),
        status: Set("Pending".to_string()),
        created_at: Set(DateUtils::local_now()),
        ..Default::default()
    };
    let log_model = log.insert(db).await?;
    
    // 发送通知
    match app.notification().builder().title(title).body(body).show() {
        Ok(_) => {
            // 更新为成功
            let mut log: notification_logs::ActiveModel = log_model.into();
            log.status = Set("Sent".to_string());
            log.sent_at = Set(Some(DateUtils::local_now()));
            log.update(db).await?;
        }
        Err(e) => {
            // 更新为失败
            let mut log: notification_logs::ActiveModel = log_model.into();
            log.status = Set("Failed".to_string());
            log.error_message = Set(Some(e.to_string()));
            log.update(db).await?;
            return Err(e.into());
        }
    }
    
    Ok(())
}
```

---

## 🔍 调试技巧

### 查看定时任务状态

```rust
// 检查任务是否运行
let is_running = scheduler_manager.is_running(SchedulerTask::TodoNotification).await;
log::info!("TodoNotification 任务运行中: {}", is_running);
```

### 查看通知设置

```sql
-- 查看用户的通知设置
SELECT * FROM notification_settings 
WHERE user_id = 'user_serial_num';

-- 查看所有通知日志
SELECT * FROM notification_logs 
ORDER BY created_at DESC 
LIMIT 100;
```

### 测试通知

```rust
// 直接发送测试通知
app.notification()
    .builder()
    .title("测试通知")
    .body("这是一条测试通知")
    .show()?;
```

---

## 📚 相关文档

- [完整分析文档](./NOTIFICATION_SYSTEM_ANALYSIS.md)
- [数据库表文档 - notification_settings](../database/system/notification_settings.md)
- [数据库表文档 - notification_logs](../database/system/notification_logs.md)
- [Tauri Plugin Notification 官方文档](https://v2.tauri.app/plugin/notification/)

---

**更新时间**: 2024-12-06  
**版本**: v1.0
