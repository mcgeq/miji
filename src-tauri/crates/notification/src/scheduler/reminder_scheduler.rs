/// 统一提醒调度器实现
use chrono::{DateTime, Utc};
use common::utils::date::DateUtils;
use sea_orm::DatabaseConnection;
use std::collections::HashMap;
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tauri_plugin_notification::NotificationExt;
use tokio::sync::RwLock;

use super::event::ReminderEvent;
use super::task::{ReminderMethods, ReminderTask, TaskExecutionResult, TaskPriority};

/// 调度器状态
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerState {
    pub is_running: bool,
    pub last_scan_at: Option<DateTime<Utc>>,
    #[allow(dead_code)]
    pub pending_tasks: usize,
    #[allow(dead_code)]
    pub executed_today: usize,
    #[allow(dead_code)]
    pub failed_today: usize,
}

/// 统一提醒调度器
pub struct ReminderScheduler {
    db: Arc<DatabaseConnection>,
    state: Arc<RwLock<SchedulerState>>,
    app_handle: Option<AppHandle>,
    #[allow(dead_code)]
    tasks: Arc<RwLock<HashMap<String, ReminderTask>>>,
}

impl ReminderScheduler {
    /// 创建新的调度器
    pub fn new(db: Arc<DatabaseConnection>) -> Self {
        Self {
            db,
            app_handle: None,
            state: Arc::new(RwLock::new(SchedulerState {
                is_running: false,
                last_scan_at: None,
                pending_tasks: 0,
                executed_today: 0,
                failed_today: 0,
            })),
            tasks: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 设置 Tauri App Handle (用于发送事件)
    pub fn set_app_handle(&mut self, handle: AppHandle) {
        self.app_handle = Some(handle);
    }

    /// 获取调度器状态
    pub async fn get_state(&self) -> SchedulerState {
        self.state.read().await.clone()
    }

    /// 启动调度器
    pub async fn start(&self) -> Result<(), String> {
        let mut state = self.state.write().await;
        if state.is_running {
            return Err("Scheduler is already running".to_string());
        }

        state.is_running = true;
        tracing::info!("✅ 提醒调度器已启动");
        Ok(())
    }

    /// 停止调度器
    pub async fn stop(&self) -> Result<(), String> {
        let mut state = self.state.write().await;
        if !state.is_running {
            return Err("Scheduler is not running".to_string());
        }

        state.is_running = false;
        tracing::info!("⏸️ 提醒调度器已停止");
        Ok(())
    }

    /// 扫描所有模块的待执行提醒
    pub async fn scan_pending_reminders(&self) -> Result<Vec<ReminderTask>, String> {
        let mut state = self.state.write().await;
        state.last_scan_at = Some(Utc::now());

        tracing::debug!("🔍 扫描待执行提醒...");

        let mut all_tasks = Vec::new();

        // 1. 扫描 Todo 提醒
        match self.scan_todo_reminders().await {
            Ok(tasks) => {
                tracing::debug!("  - Todo: {} 个待执行", tasks.len());
                all_tasks.extend(tasks);
            }
            Err(e) => tracing::error!("  - Todo 扫描失败: {}", e),
        }

        // 2. 扫描账单提醒
        match self.scan_bill_reminders().await {
            Ok(tasks) => {
                tracing::debug!("  - Bill: {} 个待执行", tasks.len());
                all_tasks.extend(tasks);
            }
            Err(e) => tracing::error!("  - Bill 扫描失败: {}", e),
        }

        // 3. 扫描经期提醒
        match self.scan_period_reminders().await {
            Ok(tasks) => {
                tracing::debug!("  - 经期提醒: {} 个待执行", tasks.len());
                all_tasks.extend(tasks);
            }
            Err(e) => tracing::error!("  - 经期提醒扫描失败: {}", e),
        }

        // 4. 扫描排卵期提醒
        match self.scan_ovulation_reminders().await {
            Ok(tasks) => {
                tracing::debug!("  - 排卵期提醒: {} 个待执行", tasks.len());
                all_tasks.extend(tasks);
            }
            Err(e) => tracing::error!("  - 排卵期提醒扫描失败: {}", e),
        }

        // 5. 扫描PMS提醒
        match self.scan_pms_reminders().await {
            Ok(tasks) => {
                tracing::debug!("  - PMS提醒: {} 个待执行", tasks.len());
                all_tasks.extend(tasks);
            }
            Err(e) => tracing::error!("  - PMS提醒扫描失败: {}", e),
        }

        // 按优先级和时间排序
        all_tasks.sort_by(|a, b| {
            b.priority
                .cmp(&a.priority)
                .then(a.scheduled_at.cmp(&b.scheduled_at))
        });

        state.pending_tasks = all_tasks.len();

        tracing::info!("✅ 扫描完成，共 {} 个待执行提醒", all_tasks.len());

        // 发送扫描完成事件通知前端
        if let Some(app_handle) = &self.app_handle {
            tracing::info!("📡 发送扫描完成事件到前端");
            if let Err(e) = app_handle.emit("scheduler-scan-completed", ()) {
                tracing::error!("❌ 发送扫描完成事件失败: {}", e);
            } else {
                tracing::info!("✅ 扫描完成事件已发送");
            }
        } else {
            tracing::warn!("⚠️ AppHandle 未设置，无法发送事件");
        }

        Ok(all_tasks)
    }

    /// 执行提醒任务
    pub async fn execute_task(&self, task: &ReminderTask) -> Result<TaskExecutionResult, String> {
        tracing::info!("📢 执行提醒: {} [{}]", task.title, task.notification_type);

        let now = Utc::now();

        // 检查是否过期
        if task.is_expired(now) {
            let error = "提醒已过期 (超过1小时)".to_string();
            tracing::warn!("  ⏰ {}", error);
            return Ok(TaskExecutionResult::failure(task.id.clone(), error));
        }

        let mut sent_channels = Vec::new();
        let mut failed_channels = Vec::new();

        // 1. 发送系统通知 (Desktop/Mobile)
        if task.methods.desktop || task.methods.mobile {
            match self.send_system_notification(task).await {
                Ok(_) => {
                    if task.methods.desktop {
                        sent_channels.push("desktop".to_string());
                    }
                    if task.methods.mobile {
                        sent_channels.push("mobile".to_string());
                    }
                }
                Err(e) => {
                    tracing::error!("  - 系统通知失败: {}", e);
                    if task.methods.desktop {
                        failed_channels.push("desktop".to_string());
                    }
                    if task.methods.mobile {
                        failed_channels.push("mobile".to_string());
                    }
                }
            }
        }

        // 2. 发送邮件通知
        if task.methods.email {
            match self.send_email_notification(task).await {
                Ok(_) => sent_channels.push("email".to_string()),
                Err(e) => {
                    tracing::error!("  - 邮件通知失败: {}", e);
                    failed_channels.push("email".to_string());
                }
            }
        }

        // 3. 发送短信通知
        if task.methods.sms {
            match self.send_sms_notification(task).await {
                Ok(_) => sent_channels.push("sms".to_string()),
                Err(e) => {
                    tracing::error!("  - 短信通知失败: {}", e);
                    failed_channels.push("sms".to_string());
                }
            }
        }

        // 4. 发送前端事件
        if let Err(e) = self.emit_reminder_event(task).await {
            tracing::error!("  - 前端事件发送失败: {}", e);
        }

        // 5. 更新提醒状态（双写逻辑）
        if !sent_channels.is_empty() {
            if let Err(e) = self.update_reminder_state(task, &sent_channels).await {
                tracing::error!("  - 更新提醒状态失败: {}", e);
            }
        }

        // 6. 更新统计
        let mut state = self.state.write().await;
        if !sent_channels.is_empty() {
            state.executed_today += 1;
            tracing::info!("  ✅ 发送成功: {:?}", sent_channels);
        } else {
            state.failed_today += 1;
            tracing::error!("  ❌ 全部失败: {:?}", failed_channels);
        }

        Ok(TaskExecutionResult::partial(
            task.id.clone(),
            sent_channels,
            failed_channels,
        ))
    }

    /// 发送系统通知
    async fn send_system_notification(&self, task: &ReminderTask) -> Result<(), String> {
        if !task.methods.desktop && !task.methods.mobile {
            return Ok(());
        }

        let app_handle = self.app_handle.as_ref().ok_or("App handle not set")?;

        tracing::debug!("  📱 发送系统通知: {}", task.title);

        // 使用 Tauri 的通知 API
        // 构建通知
        let notification_result = app_handle
            .notification()
            .builder()
            .title(&task.title)
            .body(&task.body)
            .show();

        match notification_result {
            Ok(_) => {
                tracing::info!("  ✅ 系统通知已发送: {}", task.title);
                Ok(())
            }
            Err(e) => {
                let error_msg = format!("发送系统通知失败: {}", e);
                tracing::error!("  ❌ {}", error_msg);
                Err(error_msg)
            }
        }
    }

    /// 发送邮件通知
    async fn send_email_notification(&self, task: &ReminderTask) -> Result<(), String> {
        // TODO: 实现邮件发送
        tracing::debug!("  ✉️ 发送邮件: {}", task.title);
        Err("邮件功能暂未实现".to_string())
    }

    /// 发送短信通知
    async fn send_sms_notification(&self, task: &ReminderTask) -> Result<(), String> {
        // TODO: 实现短信发送
        tracing::debug!("  💬 发送短信: {}", task.title);
        Err("短信功能暂未实现".to_string())
    }

    /// 发送前端事件
    async fn emit_reminder_event(&self, task: &ReminderTask) -> Result<(), String> {
        let app_handle = self
            .app_handle
            .as_ref()
            .ok_or("App handle not set".to_string())?;

        // 解析 metadata
        let metadata: Option<serde_json::Value> = task
            .metadata
            .as_ref()
            .and_then(|m| serde_json::from_str(m).ok());

        let event = ReminderEvent::from_notification_type(
            &task.notification_type,
            task.reminder_id.clone(),
            task.title.clone(),
            task.body.clone(),
            metadata,
        );

        let event_name = event.event_name();

        app_handle
            .emit(event_name, event)
            .map_err(|e| format!("Failed to emit event: {}", e))?;

        tracing::debug!("  📡 前端事件已发送: {}", event_name);
        Ok(())
    }

    /// 扫描 Todo 提醒
    async fn scan_todo_reminders(&self) -> Result<Vec<ReminderTask>, String> {
        use entity::todo;
        use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};

        let now = Utc::now();

        // 查询需要提醒的 Todo
        let todos = todo::Entity::find()
            .filter(todo::Column::ReminderEnabled.eq(true))
            .filter(todo::Column::DueAt.is_not_null())
            .filter(todo::Column::Status.ne(todo::Status::Completed))
            .all(self.db.as_ref())
            .await
            .map_err(|e| format!("查询 Todo 提醒失败: {}", e))?;

        tracing::debug!("找到 {} 个可能需要提醒的 Todo", todos.len());

        // 转换为 ReminderTask
        let tasks = todos
            .into_iter()
            .filter_map(|todo_item| {
                // 计算提醒时间
                let due_at = todo_item.due_at;

                // 计算提前提醒时间
                let remind_at = if let (Some(advance_value), Some(advance_unit)) = (
                    todo_item.reminder_advance_value,
                    todo_item.reminder_advance_unit.as_ref(),
                ) {
                    let mut remind_time = due_at;
                    match advance_unit.as_str() {
                        "minutes" => remind_time -= chrono::Duration::minutes(advance_value as i64),
                        "hours" => remind_time -= chrono::Duration::hours(advance_value as i64),
                        "days" => remind_time -= chrono::Duration::days(advance_value as i64),
                        "weeks" => remind_time -= chrono::Duration::weeks(advance_value as i64),
                        _ => {}
                    }
                    remind_time
                } else {
                    due_at
                };

                // 检查是否到达提醒时间
                if remind_at > now {
                    return None;
                }

                // 检查是否推迟
                if let Some(snooze_until) = todo_item.snooze_until {
                    if snooze_until > now {
                        tracing::debug!("Todo {} 已推迟到 {}", todo_item.serial_num, snooze_until);
                        return None;
                    }
                }

                // 解析提醒方式
                let methods = if let Some(methods_json) = &todo_item.reminder_methods {
                    match serde_json::from_value::<serde_json::Value>(methods_json.clone()) {
                        Ok(val) => ReminderMethods {
                            desktop: val.get("desktop").and_then(|v| v.as_bool()).unwrap_or(true),
                            mobile: val.get("mobile").and_then(|v| v.as_bool()).unwrap_or(true),
                            email: val.get("email").and_then(|v| v.as_bool()).unwrap_or(false),
                            sms: val.get("sms").and_then(|v| v.as_bool()).unwrap_or(false),
                        },
                        Err(_) => ReminderMethods {
                            desktop: true,
                            mobile: true,
                            email: false,
                            sms: false,
                        },
                    }
                } else {
                    ReminderMethods {
                        desktop: true,
                        mobile: true,
                        email: false,
                        sms: false,
                    }
                };

                // 构建提醒内容
                let title = format!("待办提醒: {}", todo_item.title);
                let body = if let Some(desc) = &todo_item.description {
                    format!("{}\n到期时间: {}", desc, due_at.format("%Y-%m-%d %H:%M"))
                } else {
                    format!("到期时间: {}", due_at.format("%Y-%m-%d %H:%M"))
                };

                // 获取优先级字符串
                let priority_str = match todo_item.priority {
                    todo::Priority::Low => "Low",
                    todo::Priority::Medium => "Medium",
                    todo::Priority::High => "High",
                    todo::Priority::Urgent => "Urgent",
                };

                // 构建元数据
                let metadata = serde_json::json!({
                    "due_at": due_at,
                    "priority": priority_str,
                    "status": format!("{:?}", todo_item.status),
                    "location": todo_item.location,
                });

                Some(build_reminder_task(
                    format!("todo-{}", todo_item.serial_num),
                    "todo",
                    todo_item.serial_num.clone(),
                    "TodoReminder",
                    remind_at.with_timezone(&chrono::Utc),
                    priority_str,
                    title,
                    body,
                    methods,
                    Some(metadata.to_string()),
                ))
            })
            .collect();

        Ok(tasks)
    }

    /// 扫描账单提醒
    async fn scan_bill_reminders(&self) -> Result<Vec<ReminderTask>, String> {
        use entity::bil_reminder;
        use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};

        let now = Utc::now();

        // 查询需要提醒的账单
        let reminders = bil_reminder::Entity::find()
            .filter(bil_reminder::Column::Enabled.eq(true))
            .filter(bil_reminder::Column::IsPaid.eq(false))
            .filter(bil_reminder::Column::IsDeleted.eq(false))
            .filter(bil_reminder::Column::RemindDate.lte(now))
            .all(self.db.as_ref())
            .await
            .map_err(|e| format!("查询账单提醒失败: {}", e))?;

        tracing::debug!("找到 {} 个待提醒账单", reminders.len());

        // 转换为 ReminderTask
        let tasks = reminders
            .into_iter()
            .filter_map(|reminder| {
                // 检查是否推迟
                if let Some(snooze_until) = reminder.snooze_until {
                    if snooze_until > now {
                        tracing::debug!("账单 {} 已推迟到 {}", reminder.serial_num, snooze_until);
                        return None;
                    }
                }

                // 解析提醒方式
                let methods = if let Some(methods_json) = &reminder.reminder_methods {
                    match serde_json::from_value::<serde_json::Value>(methods_json.clone()) {
                        Ok(val) => ReminderMethods {
                            desktop: val.get("desktop").and_then(|v| v.as_bool()).unwrap_or(true),
                            mobile: val.get("mobile").and_then(|v| v.as_bool()).unwrap_or(true),
                            email: val.get("email").and_then(|v| v.as_bool()).unwrap_or(false),
                            sms: val.get("sms").and_then(|v| v.as_bool()).unwrap_or(false),
                        },
                        Err(_) => ReminderMethods {
                            desktop: true,
                            mobile: true,
                            email: false,
                            sms: false,
                        },
                    }
                } else {
                    ReminderMethods {
                        desktop: true,
                        mobile: true,
                        email: false,
                        sms: false,
                    }
                };

                // 构建提醒内容
                let title = format!("账单提醒: {}", reminder.name);
                let body = if let Some(amount) = reminder.amount {
                    let currency = reminder.currency.as_deref().unwrap_or("CNY");
                    format!(
                        "{}\n金额: {} {}\n到期时间: {}",
                        reminder.description.as_deref().unwrap_or(""),
                        amount,
                        currency,
                        reminder.due_at.format("%Y-%m-%d %H:%M")
                    )
                } else {
                    reminder.description.clone().unwrap_or_default()
                };

                // 构建元数据
                let metadata = serde_json::json!({
                    "amount": reminder.amount,
                    "currency": reminder.currency,
                    "category": reminder.category,
                    "due_at": reminder.due_at,
                    "priority": reminder.priority,
                });

                Some(build_reminder_task(
                    format!("bill-{}", reminder.serial_num),
                    "bill",
                    reminder.serial_num.clone(),
                    "BillReminder",
                    reminder.remind_date.with_timezone(&chrono::Utc),
                    &reminder.priority,
                    title,
                    body,
                    methods,
                    Some(metadata.to_string()),
                ))
            })
            .collect();

        Ok(tasks)
    }

    /// 扫描经期提醒
    async fn scan_period_reminders(&self) -> Result<Vec<ReminderTask>, String> {
        use entity::{period_records, period_settings};
        use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder};

        let now = Utc::now();
        let mut tasks = Vec::new();

        // 查询启用了经期提醒的设置
        let settings_list = period_settings::Entity::find()
            .filter(period_settings::Column::PeriodReminder.eq(true))
            .all(self.db.as_ref())
            .await
            .map_err(|e| format!("查询经期设置失败: {}", e))?;

        for settings in settings_list {
            // 获取最近的经期记录
            let last_record = period_records::Entity::find()
                .filter(period_records::Column::SerialNum.eq(&settings.serial_num))
                .order_by_desc(period_records::Column::StartDate)
                .one(self.db.as_ref())
                .await
                .map_err(|e| format!("查询经期记录失败: {}", e))?;

            if let Some(record) = last_record {
                let cycle_length = settings.average_cycle_length;
                let reminder_days = settings.reminder_days;

                // 计算下次经期预计日期
                let next_period_date =
                    record.start_date + chrono::Duration::days(cycle_length as i64);

                let remind_date = next_period_date - chrono::Duration::days(reminder_days as i64);
                let remind_datetime = remind_date
                    .date_naive()
                    .and_hms_opt(9, 0, 0)
                    .map(|dt| dt.and_utc())
                    .unwrap_or(now);

                if remind_datetime <= now && remind_datetime > now - chrono::Duration::days(1) {
                    tasks.push(build_reminder_task(
                        format!("period-{}", settings.serial_num),
                        "period",
                        settings.serial_num.clone(),
                        "PeriodReminder",
                        remind_datetime,
                        "Medium",
                        "🌸 经期提醒".to_string(),
                        format!("预计 {} 天后将迎来下次经期", reminder_days),
                        ReminderMethods {
                            desktop: true,
                            mobile: true,
                            email: false,
                            sms: false,
                        },
                        Some(
                            serde_json::json!({
                                "reminder_type": "period",
                                "next_period_date": next_period_date,
                                "cycle_length": cycle_length,
                            })
                            .to_string(),
                        ),
                    ));
                }
            }
        }

        tracing::debug!("找到 {} 个经期提醒", tasks.len());
        Ok(tasks)
    }

    /// 扫描排卵期提醒
    async fn scan_ovulation_reminders(&self) -> Result<Vec<ReminderTask>, String> {
        use entity::{period_records, period_settings};
        use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder};

        let now = Utc::now();
        let mut tasks = Vec::new();

        // 查询启用了排卵期提醒的设置
        let settings_list = period_settings::Entity::find()
            .filter(period_settings::Column::OvulationReminder.eq(true))
            .all(self.db.as_ref())
            .await
            .map_err(|e| format!("查询排卵期设置失败: {}", e))?;

        for settings in settings_list {
            // 获取最近的经期记录
            let last_record = period_records::Entity::find()
                .filter(period_records::Column::SerialNum.eq(&settings.serial_num))
                .order_by_desc(period_records::Column::StartDate)
                .one(self.db.as_ref())
                .await
                .map_err(|e| format!("查询经期记录失败: {}", e))?;

            if let Some(record) = last_record {
                let cycle_length = settings.average_cycle_length;
                let reminder_days = settings.reminder_days;

                // 计算下次经期预计日期
                let next_period_date =
                    record.start_date + chrono::Duration::days(cycle_length as i64);

                // 排卵期通常在经期后14天左右
                let ovulation_date = next_period_date - chrono::Duration::days(14);
                let remind_date = ovulation_date - chrono::Duration::days(reminder_days as i64);
                let remind_datetime = remind_date
                    .date_naive()
                    .and_hms_opt(9, 0, 0)
                    .map(|dt| dt.and_utc())
                    .unwrap_or(now);

                if remind_datetime <= now && remind_datetime > now - chrono::Duration::days(1) {
                    tasks.push(build_reminder_task(
                        format!("ovulation-{}", settings.serial_num),
                        "ovulation",
                        settings.serial_num.clone(),
                        "OvulationReminder",
                        remind_datetime,
                        "Medium",
                        "💝 排卵期提醒".to_string(),
                        format!("预计 {} 天后将进入排卵期", reminder_days),
                        ReminderMethods {
                            desktop: true,
                            mobile: true,
                            email: false,
                            sms: false,
                        },
                        Some(
                            serde_json::json!({
                                "reminder_type": "ovulation",
                                "ovulation_date": ovulation_date,
                                "cycle_length": cycle_length,
                            })
                            .to_string(),
                        ),
                    ));
                }
            }
        }

        tracing::debug!("找到 {} 个排卵期提醒", tasks.len());
        Ok(tasks)
    }

    /// 扫描PMS提醒
    async fn scan_pms_reminders(&self) -> Result<Vec<ReminderTask>, String> {
        use entity::{period_records, period_settings};
        use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder};

        let now = Utc::now();
        let mut tasks = Vec::new();

        // 查询启用了PMS提醒的设置
        let settings_list = period_settings::Entity::find()
            .filter(period_settings::Column::PmsReminder.eq(true))
            .all(self.db.as_ref())
            .await
            .map_err(|e| format!("查询PMS设置失败: {}", e))?;

        for settings in settings_list {
            // 获取最近的经期记录
            let last_record = period_records::Entity::find()
                .filter(period_records::Column::SerialNum.eq(&settings.serial_num))
                .order_by_desc(period_records::Column::StartDate)
                .one(self.db.as_ref())
                .await
                .map_err(|e| format!("查询经期记录失败: {}", e))?;

            if let Some(record) = last_record {
                let cycle_length = settings.average_cycle_length;
                let reminder_days = settings.reminder_days;

                // 计算下次经期预计日期
                let next_period_date =
                    record.start_date + chrono::Duration::days(cycle_length as i64);

                // PMS通常在经期前7天左右
                let pms_start_date = next_period_date - chrono::Duration::days(7);
                let remind_date = pms_start_date - chrono::Duration::days(reminder_days as i64);
                let remind_datetime = remind_date
                    .date_naive()
                    .and_hms_opt(9, 0, 0)
                    .map(|dt| dt.and_utc())
                    .unwrap_or(now);

                if remind_datetime <= now && remind_datetime > now - chrono::Duration::days(1) {
                    tasks.push(build_reminder_task(
                        format!("pms-{}", settings.serial_num),
                        "pms",
                        settings.serial_num.clone(),
                        "PmsReminder",
                        remind_datetime,
                        "Medium",
                        "💆‍♀️ PMS提醒".to_string(),
                        "注意调节情绪，保持良好作息".to_string(),
                        ReminderMethods {
                            desktop: true,
                            mobile: true,
                            email: false,
                            sms: false,
                        },
                        Some(
                            serde_json::json!({
                                "reminder_type": "pms",
                                "pms_start_date": pms_start_date,
                                "cycle_length": cycle_length,
                            })
                            .to_string(),
                        ),
                    ));
                }
            }
        }

        tracing::debug!("找到 {} 个PMS提醒", tasks.len());
        Ok(tasks)
    }

    /// 更新提醒状态（双写逻辑）
    async fn update_reminder_state(
        &self,
        task: &ReminderTask,
        sent_channels: &[String],
    ) -> Result<(), String> {
        use entity::{notification_reminder_history, notification_reminder_state};
        use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set};

        let now = Utc::now();
        let state_id = format!("{}-{}", task.reminder_type, task.reminder_id);

        tracing::debug!("  💾 更新提醒状态: {}", state_id);

        // 1. 查询或创建 reminder_state 记录
        let existing_state = notification_reminder_state::Entity::find()
            .filter(notification_reminder_state::Column::ReminderType.eq(&task.reminder_type))
            .filter(notification_reminder_state::Column::ReminderSerialNum.eq(&task.reminder_id))
            .one(self.db.as_ref())
            .await
            .map_err(|e| format!("查询提醒状态失败: {}", e))?;

        let state_serial_num = if let Some(state) = existing_state {
            // 更新现有记录
            let now_fixed = DateUtils::local_now();
            let mut active: notification_reminder_state::ActiveModel = state.into();
            active.last_sent_at = Set(Some(now_fixed));
            active.sent_count = Set(active.sent_count.unwrap() + 1);
            active.status = Set("sent".to_string());
            active.updated_at = Set(now_fixed);

            let updated = active
                .update(self.db.as_ref())
                .await
                .map_err(|e| format!("更新提醒状态失败: {}", e))?;

            tracing::debug!("  ✅ 已更新状态记录");
            updated.serial_num
        } else {
            // 创建新记录
            let now_fixed = DateUtils::local_now();
            let new_state = notification_reminder_state::ActiveModel {
                serial_num: Set(state_id.clone()),
                reminder_type: Set(task.reminder_type.clone()),
                reminder_serial_num: Set(task.reminder_id.clone()),
                notification_type: Set(task.notification_type.clone()),
                next_scheduled_at: Set(None),
                last_sent_at: Set(Some(now_fixed)),
                snooze_until: Set(None),
                status: Set("sent".to_string()),
                retry_count: Set(0),
                fail_reason: Set(None),
                sent_count: Set(1),
                view_count: Set(0),
                response_time: Set(None),
                created_at: Set(now_fixed),
                updated_at: Set(now_fixed),
            };

            let inserted = new_state
                .insert(self.db.as_ref())
                .await
                .map_err(|e| format!("创建提醒状态失败: {}", e))?;

            tracing::debug!("  ✅ 已创建状态记录");
            inserted.serial_num
        };

        // 2. 记录到 history 表
        let now_fixed = DateUtils::local_now();
        let history_id = format!("history-{}-{}", state_serial_num, now.timestamp());
        let history = notification_reminder_history::ActiveModel {
            serial_num: Set(history_id),
            reminder_state_serial_num: Set(state_serial_num),
            reminder_type: Set(task.reminder_type.clone()),
            reminder_serial_num: Set(task.reminder_id.clone()),
            sent_at: Set(now_fixed),
            sent_methods: Set(serde_json::to_string(sent_channels).unwrap_or_default()),
            sent_channels: Set(Some(
                serde_json::to_string(sent_channels).unwrap_or_default(),
            )),
            status: Set("sent".to_string()),
            fail_reason: Set(None),
            viewed_at: Set(None),
            dismissed_at: Set(None),
            action_taken: Set(None),
            user_location: Set(None),
            device_info: Set(None),
            created_at: Set(now_fixed),
        };

        history
            .insert(self.db.as_ref())
            .await
            .map_err(|e| format!("记录提醒历史失败: {}", e))?;

        tracing::debug!("  ✅ 已记录历史");

        // 3. 可选：更新旧表（双写策略）
        match task.reminder_type.as_str() {
            "todo" => {
                // 更新 todos 表的 last_reminder_sent_at
                if let Err(e) = self.update_todo_last_sent(&task.reminder_id, now).await {
                    tracing::warn!("  ⚠️ 更新 todo 旧表失败: {}", e);
                }
            }
            "bill" => {
                // 更新 bil_reminders 表的 last_reminder_sent_at
                if let Err(e) = self.update_bill_last_sent(&task.reminder_id, now).await {
                    tracing::warn!("  ⚠️ 更新 bill 旧表失败: {}", e);
                }
            }
            "period" => {
                // period 不需要更新旧表，因为旧表没有状态字段
                tracing::debug!("  ℹ️ period 类型无需更新旧表");
            }
            _ => {}
        }

        Ok(())
    }

    /// 更新 todo 表的最后提醒时间
    async fn update_todo_last_sent(
        &self,
        todo_id: &str,
        _sent_at: DateTime<Utc>,
    ) -> Result<(), String> {
        use entity::todo;
        use sea_orm::{ActiveModelTrait, EntityTrait, Set};

        let todo = todo::Entity::find_by_id(todo_id.to_string())
            .one(self.db.as_ref())
            .await
            .map_err(|e| format!("查询 todo 失败: {}", e))?;

        if let Some(todo) = todo {
            let now_fixed = DateUtils::local_now();
            let mut active: todo::ActiveModel = todo.into();
            active.last_reminder_sent_at = Set(Some(now_fixed));
            active.updated_at = Set(Some(now_fixed));

            active
                .update(self.db.as_ref())
                .await
                .map_err(|e| format!("更新 todo 失败: {}", e))?;

            tracing::debug!("    ✅ 已更新 todo 旧表");
        }

        Ok(())
    }

    /// 更新 bil_reminder 表的最后提醒时间
    async fn update_bill_last_sent(
        &self,
        bill_id: &str,
        _sent_at: DateTime<Utc>,
    ) -> Result<(), String> {
        use entity::bil_reminder;
        use sea_orm::{ActiveModelTrait, EntityTrait, Set};

        let bill = bil_reminder::Entity::find_by_id(bill_id.to_string())
            .one(self.db.as_ref())
            .await
            .map_err(|e| format!("查询 bill 失败: {}", e))?;

        if let Some(bill) = bill {
            let now_fixed = DateUtils::local_now();
            let mut active: bil_reminder::ActiveModel = bill.into();
            active.last_reminder_sent_at = Set(Some(now_fixed));
            active.updated_at = Set(Some(now_fixed));

            active
                .update(self.db.as_ref())
                .await
                .map_err(|e| format!("更新 bill 失败: {}", e))?;

            tracing::debug!("    ✅ 已更新 bill 旧表");
        }

        Ok(())
    }
}

/// 构建提醒任务
#[allow(clippy::too_many_arguments)]
pub fn build_reminder_task(
    id: String,
    reminder_type: &str,
    reminder_id: String,
    notification_type: &str,
    scheduled_at: DateTime<Utc>,
    priority: &str,
    title: String,
    body: String,
    methods: ReminderMethods,
    metadata: Option<String>,
) -> ReminderTask {
    ReminderTask {
        id,
        reminder_type: reminder_type.to_string(),
        reminder_id,
        notification_type: notification_type.to_string(),
        scheduled_at,
        priority: TaskPriority::from(priority),
        title,
        body,
        methods,
        metadata,
    }
}
