use std::sync::Arc;
/// Tauri 命令：提醒调度器管理
use tauri::State;
use tauri_plugin_notification::NotificationExt;
use tokio::sync::RwLock;

use crate::scheduler::ReminderScheduler;

/// 调度器状态响应
#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SchedulerStateResponse {
    pub is_running: bool,
    pub last_scan_at: Option<String>,
    pub pending_tasks: usize,
    pub executed_today: usize,
    pub failed_today: usize,
}

/// 获取调度器状态
#[tauri::command]
pub async fn reminder_scheduler_get_state(
    scheduler: State<'_, Arc<RwLock<ReminderScheduler>>>,
) -> Result<SchedulerStateResponse, String> {
    let scheduler = scheduler.read().await;
    let state = scheduler.get_state().await;

    // 调试日志
    tracing::info!(
        "🔍 查询调度器状态: is_running={}, pending={}, executed={}, failed={}",
        state.is_running,
        state.pending_tasks,
        state.executed_today,
        state.failed_today
    );

    Ok(SchedulerStateResponse {
        is_running: state.is_running,
        last_scan_at: state.last_scan_at.map(|dt| dt.to_rfc3339()),
        pending_tasks: state.pending_tasks,
        executed_today: state.executed_today,
        failed_today: state.failed_today,
    })
}

/// 启动调度器
#[tauri::command]
pub async fn reminder_scheduler_start(
    scheduler: State<'_, Arc<RwLock<ReminderScheduler>>>,
) -> Result<(), String> {
    let scheduler = scheduler.read().await;
    scheduler.start().await
}

/// 停止调度器
#[tauri::command]
pub async fn reminder_scheduler_stop(
    scheduler: State<'_, Arc<RwLock<ReminderScheduler>>>,
) -> Result<(), String> {
    let scheduler = scheduler.read().await;
    scheduler.stop().await
}

/// 手动触发扫描
#[tauri::command]
pub async fn reminder_scheduler_scan_now(
    scheduler: State<'_, Arc<RwLock<ReminderScheduler>>>,
) -> Result<usize, String> {
    let scheduler = scheduler.read().await;
    let tasks = scheduler.scan_pending_reminders().await?;
    let count = tasks.len();

    // 执行所有任务
    for task in tasks {
        if let Err(e) = scheduler.execute_task(&task).await {
            tracing::error!("执行任务失败: {}", e);
        }
    }

    Ok(count)
}

/// 测试通知
#[tauri::command]
pub async fn reminder_scheduler_test_notification(
    title: String,
    body: String,
    app: tauri::AppHandle,
) -> Result<(), String> {
    app.notification()
        .builder()
        .title(&title)
        .body(&body)
        .show()
        .map_err(|e| format!("发送通知失败: {}", e))?;

    Ok(())
}
