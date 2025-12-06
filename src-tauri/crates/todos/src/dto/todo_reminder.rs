use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::{set_active_value_opt, set_active_value_t};
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct ReminderBase {
    pub todo_serial_num: String,
    pub remind_at: DateTime<FixedOffset>,
    pub r#type: Option<i32>,
    pub is_sent: bool,
    // 新增提醒执行相关字段
    pub reminder_method: Option<String>,
    pub retry_count: i32,
    pub last_retry_at: Option<DateTime<FixedOffset>>,
    pub snooze_count: i32,
    pub escalation_level: i32,
    pub notification_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Reminder {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: ReminderBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct ReminderCreate {
    #[serde(flatten)]
    pub core: ReminderBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct ReminderUpdate {
    pub todo_serial_num: Option<String>,
    pub remind_at: Option<DateTime<FixedOffset>>,
    pub r#type: Option<Option<i32>>,
    pub is_sent: Option<bool>,
    // 新增提醒执行相关字段
    pub reminder_method: Option<String>,
    pub retry_count: Option<i32>,
    pub last_retry_at: Option<DateTime<FixedOffset>>,
    pub snooze_count: Option<i32>,
    pub escalation_level: Option<i32>,
    pub notification_id: Option<String>,
}

impl TryFrom<ReminderCreate> for entity::reminder::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: ReminderCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::reminder::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            todo_serial_num: ActiveValue::Set(value.core.todo_serial_num),
            remind_at: ActiveValue::Set(value.core.remind_at),
            r#type: ActiveValue::Set(value.core.r#type),
            is_sent: ActiveValue::Set(value.core.is_sent),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
            // 新增提醒执行相关字段
            reminder_method: ActiveValue::Set(value.core.reminder_method),
            retry_count: ActiveValue::Set(value.core.retry_count),
            last_retry_at: ActiveValue::Set(value.core.last_retry_at),
            snooze_count: ActiveValue::Set(value.core.snooze_count),
            escalation_level: ActiveValue::Set(value.core.escalation_level),
            notification_id: ActiveValue::Set(value.core.notification_id),
        })
    }
}

impl TryFrom<ReminderUpdate> for entity::reminder::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: ReminderUpdate) -> Result<Self, Self::Error> {
        Ok(entity::reminder::ActiveModel {
            serial_num: ActiveValue::NotSet,
            todo_serial_num: value
                .todo_serial_num
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            remind_at: value
                .remind_at
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            r#type: value.r#type.map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_sent: value.is_sent.map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
            // 新增提醒执行相关字段
            reminder_method: value
                .reminder_method
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            retry_count: value
                .retry_count
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            last_retry_at: value
                .last_retry_at
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            snooze_count: value
                .snooze_count
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            escalation_level: value
                .escalation_level
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            notification_id: value
                .notification_id
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
        })
    }
}

impl ReminderUpdate {
    pub fn apply_to_model(self, model: &mut entity::reminder::ActiveModel) {
        set_active_value_t!(model, self, todo_serial_num);
        set_active_value_t!(model, self, remind_at);
        set_active_value_t!(model, self, r#type);
        set_active_value_t!(model, self, is_sent);
        // 新增提醒执行相关字段
        set_active_value_opt!(model, self, reminder_method);
        set_active_value_t!(model, self, retry_count);
        set_active_value_opt!(model, self, last_retry_at);
        set_active_value_t!(model, self, snooze_count);
        set_active_value_t!(model, self, escalation_level);
        set_active_value_opt!(model, self, notification_id);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::reminder::Model> for Reminder {
    fn from(value: entity::reminder::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: ReminderBase {
                todo_serial_num: value.todo_serial_num,
                remind_at: value.remind_at,
                r#type: value.r#type,
                is_sent: value.is_sent,
                // 新增提醒执行相关字段
                reminder_method: value.reminder_method,
                retry_count: value.retry_count,
                last_retry_at: value.last_retry_at,
                snooze_count: value.snooze_count,
                escalation_level: value.escalation_level,
                notification_id: value.notification_id,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
