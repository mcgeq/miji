/// 提醒事件定义
///
/// 用于前端监听和响应
use serde::{Deserialize, Serialize};

/// 提醒事件类型
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum ReminderEvent {
    /// Todo 提醒触发
    TodoReminderFired {
        reminder_id: String,
        title: String,
        body: String,
        priority: String,
    },

    /// 账单提醒触发
    BillReminderFired {
        reminder_id: String,
        title: String,
        body: String,
        amount: f64,
        currency: String,
    },

    /// 经期提醒触发
    PeriodReminderFired {
        reminder_id: String,
        title: String,
        body: String,
        reminder_type: String, // period, ovulation, pms
    },

    /// 排卵期提醒触发
    OvulationReminderFired {
        reminder_id: String,
        title: String,
        body: String,
    },

    /// PMS 提醒触发
    PmsReminderFired {
        reminder_id: String,
        title: String,
        body: String,
    },

    /// 系统警报
    SystemAlert {
        title: String,
        body: String,
        severity: String,
    },
}

impl ReminderEvent {
    /// 获取事件名称（用于前端监听）
    pub fn event_name(&self) -> &'static str {
        match self {
            ReminderEvent::TodoReminderFired { .. } => "todo-reminder-fired",
            ReminderEvent::BillReminderFired { .. } => "bil-reminder-fired",
            ReminderEvent::PeriodReminderFired { .. } => "period-reminder-fired",
            ReminderEvent::OvulationReminderFired { .. } => "ovulation-reminder-fired",
            ReminderEvent::PmsReminderFired { .. } => "pms-reminder-fired",
            ReminderEvent::SystemAlert { .. } => "system-alert",
        }
    }

    /// 从通知类型创建事件
    pub fn from_notification_type(
        notification_type: &str,
        reminder_id: String,
        title: String,
        body: String,
        metadata: Option<serde_json::Value>,
    ) -> Self {
        match notification_type {
            "TodoReminder" => {
                let priority = metadata
                    .as_ref()
                    .and_then(|m| m.get("priority"))
                    .and_then(|p| p.as_str())
                    .unwrap_or("Medium")
                    .to_string();

                ReminderEvent::TodoReminderFired {
                    reminder_id,
                    title,
                    body,
                    priority,
                }
            }

            "BillReminder" => {
                let amount = metadata
                    .as_ref()
                    .and_then(|m| m.get("amount"))
                    .and_then(|a| a.as_f64())
                    .unwrap_or(0.0);

                let currency = metadata
                    .as_ref()
                    .and_then(|m| m.get("currency"))
                    .and_then(|c| c.as_str())
                    .unwrap_or("CNY")
                    .to_string();

                ReminderEvent::BillReminderFired {
                    reminder_id,
                    title,
                    body,
                    amount,
                    currency,
                }
            }

            "PeriodReminder" => {
                let reminder_type = metadata
                    .as_ref()
                    .and_then(|m| m.get("reminderType"))
                    .and_then(|t| t.as_str())
                    .unwrap_or("period")
                    .to_string();

                ReminderEvent::PeriodReminderFired {
                    reminder_id,
                    title,
                    body,
                    reminder_type,
                }
            }

            "OvulationReminder" => ReminderEvent::OvulationReminderFired {
                reminder_id,
                title,
                body,
            },

            "PmsReminder" => ReminderEvent::PmsReminderFired {
                reminder_id,
                title,
                body,
            },

            _ => ReminderEvent::SystemAlert {
                title,
                body,
                severity: "info".to_string(),
            },
        }
    }
}
