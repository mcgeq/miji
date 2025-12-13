//! 提醒任务定义
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// 提醒任务优先级
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum TaskPriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Urgent = 3,
}

impl From<&str> for TaskPriority {
    fn from(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "low" => TaskPriority::Low,
            "normal" => TaskPriority::Normal,
            "high" => TaskPriority::High,
            "urgent" => TaskPriority::Urgent,
            _ => TaskPriority::Normal,
        }
    }
}

/// 提醒任务
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReminderTask {
    /// 任务ID
    pub id: String,

    /// 提醒类型 (todo, bill, period)
    pub reminder_type: String,

    /// 提醒记录ID
    pub reminder_id: String,

    /// 通知类型 (TodoReminder, BillReminder, PeriodReminder, etc.)
    pub notification_type: String,

    /// 计划执行时间
    pub scheduled_at: DateTime<Utc>,

    /// 优先级
    pub priority: TaskPriority,

    /// 提醒标题
    pub title: String,

    /// 提醒内容
    pub body: String,

    /// 提醒方式
    pub methods: ReminderMethods,

    /// 额外数据 (JSON)
    pub metadata: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReminderMethods {
    pub desktop: bool,
    pub mobile: bool,
    pub email: bool,
    pub sms: bool,
}

impl ReminderTask {
    /// 是否应该执行（时间已到且未过期）
    pub fn should_execute(&self, now: DateTime<Utc>) -> bool {
        self.scheduled_at <= now
    }

    /// 是否已过期（超过1小时未执行）
    pub fn is_expired(&self, now: DateTime<Utc>) -> bool {
        now.signed_duration_since(self.scheduled_at).num_hours() > 1
    }

    /// 获取有效的提醒渠道
    pub fn active_channels(&self) -> Vec<String> {
        let mut channels = Vec::new();
        if self.methods.desktop {
            channels.push("desktop".to_string());
        }
        if self.methods.mobile {
            channels.push("mobile".to_string());
        }
        if self.methods.email {
            channels.push("email".to_string());
        }
        if self.methods.sms {
            channels.push("sms".to_string());
        }
        channels
    }
}

/// 任务执行结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskExecutionResult {
    pub task_id: String,
    pub success: bool,
    pub sent_channels: Vec<String>,
    pub failed_channels: Vec<String>,
    pub error: Option<String>,
    pub executed_at: DateTime<Utc>,
}

impl TaskExecutionResult {
    pub fn success(task_id: String, sent_channels: Vec<String>) -> Self {
        Self {
            task_id,
            success: true,
            sent_channels,
            failed_channels: Vec::new(),
            error: None,
            executed_at: Utc::now(),
        }
    }

    pub fn failure(task_id: String, error: String) -> Self {
        Self {
            task_id,
            success: false,
            sent_channels: Vec::new(),
            failed_channels: Vec::new(),
            error: Some(error),
            executed_at: Utc::now(),
        }
    }

    pub fn partial(
        task_id: String,
        sent_channels: Vec<String>,
        failed_channels: Vec<String>,
    ) -> Self {
        Self {
            task_id,
            success: !sent_channels.is_empty(),
            sent_channels,
            failed_channels,
            error: None,
            executed_at: Utc::now(),
        }
    }
}
