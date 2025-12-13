pub mod command;
/// 统一通知模块
///
/// 提供跨所有功能模块的通知服务
pub mod scheduler;

// 导出调度器相关类型
pub use scheduler::{
    event::ReminderEvent,
    executor::{start_reminder_executor, ExecutorConfig, ReminderExecutor},
    task::{ReminderMethods, ReminderTask, TaskPriority},
    ReminderScheduler,
};

// 导出命令
pub use command::{
    reminder_scheduler_get_state, reminder_scheduler_scan_now, reminder_scheduler_start,
    reminder_scheduler_stop, reminder_scheduler_test_notification,
};

/// 初始化通知模块
pub fn init() {
    tracing::info!("🔔 通知模块已加载");
}
