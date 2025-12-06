// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           scheduler_manager.rs
// Description:    统一的定时任务管理器
// Create   Date:  2025-11-11
// -----------------------------------------------------------------------------

use common::{AppState, SchedulerConfigService};
use std::collections::HashMap;
use std::sync::Arc;
use tauri::{AppHandle, Emitter, Manager};
use tokio::sync::Mutex;
use tokio::task::JoinHandle;
use tokio::time::{Duration, interval};

use crate::{InstallmentProcessFailedEvent, InstallmentProcessedEvent};

#[cfg(any(target_os = "android", target_os = "ios"))]
use crate::mobiles::system_monitor::SystemMonitor;

/// 定时任务类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum SchedulerTask {
    /// 交易处理任务（每2小时）
    Transaction,
    /// 待办自动创建任务（每2小时）
    Todo,
    /// 待办提醒任务（桌面60秒，移动300秒）
    TodoNotification,
    /// 账单提醒任务（桌面60秒，移动300秒）
    BilReminder,
    /// 经期提醒任务（每天一次）
    PeriodReminder,
    /// 预算自动创建任务（每2小时）
    Budget,
}

impl SchedulerTask {
    /// 获取任务执行间隔
    pub fn interval(&self) -> Duration {
        match self {
            Self::Transaction => Duration::from_secs(60 * 60 * 2), // 2小时
            Self::Todo => Duration::from_secs(60 * 60 * 2),        // 2小时
            Self::TodoNotification => {
                if cfg!(any(target_os = "android", target_os = "ios")) {
                    Duration::from_secs(300) // 移动端5分钟
                } else {
                    Duration::from_secs(60) // 桌面端1分钟
                }
            }
            Self::BilReminder => {
                if cfg!(any(target_os = "android", target_os = "ios")) {
                    Duration::from_secs(300) // 移动端5分钟
                } else {
                    Duration::from_secs(60) // 桌面端1分钟
                }
            }
            Self::PeriodReminder => Duration::from_secs(60 * 60 * 24), // 每天一次
            Self::Budget => Duration::from_secs(60 * 60 * 2), // 2小时
        }
    }

    /// 获取任务名称（对应数据库task_type）
    pub fn task_type(&self) -> &'static str {
        match self {
            Self::Transaction => "TransactionProcess",
            Self::Todo => "TodoAutoCreate",
            Self::TodoNotification => "TodoReminderCheck",
            Self::BilReminder => "BillReminderCheck",
            Self::PeriodReminder => "PeriodReminderCheck",
            Self::Budget => "BudgetAutoCreate",
        }
    }

    /// 获取任务名称（用于日志）
    pub fn name(&self) -> &'static str {
        match self {
            Self::Transaction => "transaction",
            Self::Todo => "todo",
            Self::TodoNotification => "todo_notification",
            Self::BilReminder => "bil_reminder",
            Self::PeriodReminder => "period_reminder",
            Self::Budget => "budget",
        }
    }
}

/// 任务句柄
struct TaskHandle {
    handle: JoinHandle<()>,
    task_type: SchedulerTask,
}

/// 调度器管理器
pub struct SchedulerManager {
    tasks: Arc<Mutex<HashMap<SchedulerTask, TaskHandle>>>,
    config_service: SchedulerConfigService,
}

impl SchedulerManager {
    /// 创建新的调度器管理器
    pub fn new() -> Self {
        Self {
            tasks: Arc::new(Mutex::new(HashMap::new())),
            config_service: SchedulerConfigService::new(),
        }
    }

    /// 启动所有定时任务
    pub async fn start_all(&self, app: AppHandle) {
        log::info!("Starting all scheduler tasks...");

        self.start_task(SchedulerTask::Transaction, app.clone())
            .await;
        self.start_task(SchedulerTask::Todo, app.clone()).await;
        self.start_task(SchedulerTask::TodoNotification, app.clone())
            .await;
        self.start_task(SchedulerTask::BilReminder, app.clone())
            .await;
        self.start_task(SchedulerTask::PeriodReminder, app.clone())
            .await;
        self.start_task(SchedulerTask::Budget, app.clone()).await;

        log::info!("All scheduler tasks started successfully");
    }

    /// 启动单个任务（使用配置）
    async fn start_task(&self, task_type: SchedulerTask, app: AppHandle) {
        let app_state = app.state::<AppState>();
        let db = app_state.db.clone();

        // 从数据库加载配置
        let config = match self
            .config_service
            .get_config(&db, task_type.task_type(), None)
            .await
        {
            Ok(cfg) => cfg,
            Err(e) => {
                log::error!(
                    "加载任务配置失败，使用默认配置: {} - {}",
                    task_type.name(),
                    e
                );
                SchedulerConfigService::default_config(task_type.task_type())
            }
        };

        // 检查是否启用
        if !config.enabled {
            log::info!("任务已禁用，跳过: {}", task_type.name());
            return;
        }

        log::info!(
            "启动任务: {} (间隔: {:?}秒)",
            task_type.name(),
            config.interval.as_secs()
        );

        let mut tasks = self.tasks.lock().await;

        // 如果任务已存在，先停止
        if let Some(old_task) = tasks.remove(&task_type) {
            old_task.handle.abort();
            log::warn!("任务已在运行，重新启动: {}", task_type.name());
        }

        // 根据任务类型启动对应的任务（传入配置）
        let handle = match task_type {
            SchedulerTask::Transaction => {
                tokio::spawn(Self::run_task_with_config(
                    app.clone(),
                    task_type,
                    config,
                    Self::execute_transaction_task,
                ))
            }
            SchedulerTask::Todo => {
                tokio::spawn(Self::run_task_with_config(
                    app.clone(),
                    task_type,
                    config,
                    Self::execute_todo_task,
                ))
            }
            SchedulerTask::TodoNotification => {
                tokio::spawn(Self::run_task_with_config(
                    app.clone(),
                    task_type,
                    config,
                    Self::execute_todo_notification_task,
                ))
            }
            SchedulerTask::BilReminder => {
                tokio::spawn(Self::run_task_with_config(
                    app.clone(),
                    task_type,
                    config,
                    Self::execute_bil_reminder_task,
                ))
            }
            SchedulerTask::PeriodReminder => {
                tokio::spawn(Self::run_task_with_config(
                    app.clone(),
                    task_type,
                    config,
                    Self::execute_period_reminder_task,
                ))
            }
            SchedulerTask::Budget => {
                tokio::spawn(Self::run_task_with_config(
                    app.clone(),
                    task_type,
                    config,
                    Self::execute_budget_task,
                ))
            }
        };

        tasks.insert(task_type, TaskHandle { handle, task_type });
        log::info!("任务已启动: {}", task_type.name());
    }

    /// 使用配置运行任务
    async fn run_task_with_config<F>(
        app: AppHandle,
        task_type: SchedulerTask,
        config: common::SchedulerConfig,
        executor: F,
    ) where
        F: Fn(AppHandle) + Send + 'static,
    {
        let mut ticker = interval(config.interval);

        loop {
            ticker.tick().await;

            // 检查活动时段
            if let Some((start, end)) = config.active_hours {
                let now = chrono::Local::now().time();
                if now < start || now > end {
                    log::debug!(
                        "当前不在活动时段，跳过任务: {} ({:?} - {:?})",
                        task_type.name(),
                        start,
                        end
                    );
                    continue;
                }
            }

            // 移动端条件检查
            #[cfg(any(target_os = "android", target_os = "ios"))]
            {
                // 电量检查
                if let Some(threshold) = config.battery_threshold {
                    if Self::battery_level() < threshold {
                        log::debug!(
                            "电量低于阈值，跳过任务: {} (阈值: {}%)",
                            task_type.name(),
                            threshold
                        );
                        continue;
                    }
                }

                // 网络检查
                if config.network_required && !Self::has_network() {
                    log::debug!("无网络连接，跳过任务: {}", task_type.name());
                    continue;
                }

                if config.wifi_only && !Self::is_wifi() {
                    log::debug!("非Wi-Fi连接，跳过任务: {}", task_type.name());
                    continue;
                }
            }

            // 执行实际任务
            executor(app.clone());
        }
    }

    // ==================== 移动端辅助方法 ====================

    /// 获取电池电量（移动端）
    #[cfg(any(target_os = "android", target_os = "ios"))]
    fn battery_level() -> i32 {
        SystemMonitor::battery_level()
    }

    /// 检查是否有网络连接
    #[cfg(any(target_os = "android", target_os = "ios"))]
    fn has_network() -> bool {
        SystemMonitor::has_network()
    }

    /// 检查是否为Wi-Fi连接
    #[cfg(any(target_os = "android", target_os = "ios"))]
    fn is_wifi() -> bool {
        SystemMonitor::is_wifi()
    }

    /// 停止所有任务
    pub async fn stop_all(&self) {
        let mut tasks = self.tasks.lock().await;
        for (task_type, task_handle) in tasks.drain() {
            task_handle.handle.abort();
            log::info!("Stopped scheduler task: {}", task_type.name());
        }
    }

    /// 停止单个任务
    pub async fn stop_task(&self, task_type: SchedulerTask) {
        let mut tasks = self.tasks.lock().await;
        if let Some(task_handle) = tasks.remove(&task_type) {
            task_handle.handle.abort();
            log::info!("Stopped scheduler task: {}", task_type.name());
        }
    }

    /// 获取任务状态
    pub async fn is_running(&self, task_type: SchedulerTask) -> bool {
        let tasks = self.tasks.lock().await;
        tasks.contains_key(&task_type)
    }

    // ==================== 具体任务实现 ====================

    /// 执行交易处理任务
    fn execute_transaction_task(app: AppHandle) {
        tokio::spawn(async move {
            let app_state = app.state::<AppState>();
            let db = app_state.db.clone();
            let installment_service = money::services::installment::InstallmentService::default();

            match installment_service.auto_process_due_installments(&db).await {
                Ok(processed_transactions) => {
                    if !processed_transactions.is_empty() {
                        log::info!("处理了 {} 笔到期交易", processed_transactions.len());

                        // 通知前端刷新数据
                        if let Err(e) = app.emit(
                            "installment-processed",
                            InstallmentProcessedEvent {
                                processed_count: processed_transactions.len(),
                                timestamp: chrono::Local::now().timestamp(),
                            },
                        ) {
                            log::error!("发送分期处理完成事件失败: {}", e);
                        }
                    }
                }
                Err(e) => {
                    log::error!("处理到期交易失败: {}", e);

                    // 通知前端处理失败
                    if let Err(emit_err) = app.emit(
                        "installment-process-failed",
                        InstallmentProcessFailedEvent {
                            error: e.to_string(),
                            timestamp: chrono::Utc::now().timestamp(),
                        },
                    ) {
                        log::error!("发送分期处理失败事件失败: {}", emit_err);
                    }
                }
            }
        });
    }

    /// 执行待办自动创建任务
    fn execute_todo_task(app: AppHandle) {
        tokio::spawn(async move {
            let app_state = app.state::<AppState>();
            let db = app_state.db.clone();

            if let Err(e) = todos::service::todo::TodosService::auto_process_create_todo(&db).await
            {
                log::error!("自动创建重复待办失败: {}", e);
            } else {
                log::info!("自动创建重复待办执行完成");
            }
        });
    }

    /// 执行待办提醒任务
    fn execute_todo_notification_task(app: AppHandle) {
        tokio::spawn(async move {
            let app_state = app.state::<AppState>();
            let db = app_state.db.clone();
            let todos_service = todos::service::todo::TodosService::default();

            match todos_service.process_due_reminders(&app, &db).await {
                Ok(n) if n > 0 => log::info!("发送 {} 条待办提醒", n),
                Ok(_) => {}
                Err(e) => log::error!("待办提醒处理失败: {}", e),
            }
        });
    }

    /// 执行账单提醒任务
    fn execute_bil_reminder_task(app: AppHandle) {
        tokio::spawn(async move {
            let app_state = app.state::<AppState>();
            let db = app_state.db.clone();
            let service = money::services::bil_reminder::BilReminderService::default();

            match service.process_due_bil_reminders(&app, &db).await {
                Ok(n) if n > 0 => log::info!("发送 {} 条账单提醒", n),
                Ok(_) => {}
                Err(e) => log::error!("账单提醒处理失败: {}", e),
            }
        });
    }

    /// 执行经期提醒任务
    fn execute_period_reminder_task(app: AppHandle) {
        tokio::spawn(async move {
            let app_state = app.state::<AppState>();
            let db = app_state.db.clone();
            let service = healths::service::period_reminder::PeriodReminderService::default();

            match service.process_period_reminders(&app, &db).await {
                Ok(n) if n > 0 => log::info!("发送 {} 条健康提醒", n),
                Ok(_) => {}
                Err(e) => log::error!("健康提醒处理失败: {}", e),
            }
        });
    }

    /// 执行预算自动创建任务
    fn execute_budget_task(app: AppHandle) {
        tokio::spawn(async move {
            let app_state = app.state::<AppState>();
            let db = app_state.db.clone();
            let service = money::services::bil_reminder::BilReminderService::default();

            match service.auto_create_recurring_budgets(&db).await {
                Ok(_) => {
                    log::info!("预算自动创建执行完成");
                }
                Err(e) => log::error!("自动创建重复预算失败: {}", e),
            }
        });
    }
}

impl Default for SchedulerManager {
    fn default() -> Self {
        Self::new()
    }
}
