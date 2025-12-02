use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::set_active_value_opt;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BatchReminderBase {
    pub name: String,
    pub description: Option<String>,
    pub scheduled_at: DateTime<FixedOffset>,
    pub status: String,
    pub total_count: i32,
    pub sent_count: i32,
    pub failed_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BatchReminder {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: BatchReminderBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BatchReminderCreate {
    #[serde(flatten)]
    pub core: BatchReminderBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BatchReminderUpdate {
    pub name: Option<String>,
    pub description: Option<Option<String>>,
    pub scheduled_at: Option<DateTime<FixedOffset>>,
    pub status: Option<String>,
    pub total_count: Option<i32>,
    pub sent_count: Option<i32>,
    pub failed_count: Option<i32>,
}

impl TryFrom<BatchReminderCreate> for entity::batch_reminders::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: BatchReminderCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::batch_reminders::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            name: ActiveValue::Set(value.core.name),
            description: ActiveValue::Set(value.core.description),
            scheduled_at: ActiveValue::Set(value.core.scheduled_at),
            status: ActiveValue::Set(value.core.status),
            total_count: ActiveValue::Set(value.core.total_count),
            sent_count: ActiveValue::Set(value.core.sent_count),
            failed_count: ActiveValue::Set(value.core.failed_count),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<BatchReminderUpdate> for entity::batch_reminders::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: BatchReminderUpdate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::batch_reminders::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: set_active_value_opt!(value.name),
            description: set_active_value_opt!(value.description),
            scheduled_at: set_active_value_opt!(value.scheduled_at),
            status: set_active_value_opt!(value.status),
            total_count: set_active_value_opt!(value.total_count),
            sent_count: set_active_value_opt!(value.sent_count),
            failed_count: set_active_value_opt!(value.failed_count),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

