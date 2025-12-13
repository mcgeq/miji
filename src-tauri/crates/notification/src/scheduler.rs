pub mod event;
pub mod executor;
/// 统一提醒调度器模块
///
/// 负责：
/// - 扫描所有模块的提醒记录
/// - 计算下次触发时间
/// - 发送通知
/// - 触发前端事件
/// - 记录执行历史
pub mod reminder_scheduler;
pub mod task;

pub use event::ReminderEvent;
pub use executor::{ExecutorConfig, ReminderExecutor, start_reminder_executor};
pub use reminder_scheduler::ReminderScheduler;
pub use task::{ReminderTask, TaskPriority};
