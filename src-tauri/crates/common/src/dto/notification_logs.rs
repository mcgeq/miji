use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::set_active_value_t;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLogBase {
    pub reminder_serial_num: String,
    pub notification_type: String,
    pub status: String,
    pub sent_at: Option<DateTime<FixedOffset>>,
    pub error_message: Option<String>,
    pub retry_count: i32,
    pub last_retry_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLog {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: NotificationLogBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLogCreate {
    #[serde(flatten)]
    pub core: NotificationLogBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationLogUpdate {
    pub reminder_serial_num: Option<String>,
    pub notification_type: Option<String>,
    pub status: Option<String>,
    pub sent_at: Option<Option<DateTime<FixedOffset>>>,
    pub error_message: Option<Option<String>>,
    pub retry_count: Option<i32>,
    pub last_retry_at: Option<Option<DateTime<FixedOffset>>>,
}

impl TryFrom<NotificationLogCreate> for entity::notification_logs::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: NotificationLogCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::notification_logs::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            reminder_serial_num: ActiveValue::Set(value.core.reminder_serial_num),
            notification_type: ActiveValue::Set(value.core.notification_type),
            status: ActiveValue::Set(value.core.status),
            sent_at: ActiveValue::Set(value.core.sent_at),
            error_message: ActiveValue::Set(value.core.error_message),
            retry_count: ActiveValue::Set(value.core.retry_count),
            last_retry_at: ActiveValue::Set(value.core.last_retry_at),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<NotificationLogUpdate> for entity::notification_logs::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: NotificationLogUpdate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::notification_logs::ActiveModel {
            serial_num: ActiveValue::NotSet,
            reminder_serial_num: set_active_value_opt!(value.reminder_serial_num),
            notification_type: set_active_value_opt!(value.notification_type),
            status: set_active_value_opt!(value.status),
            sent_at: set_active_value_opt!(value.sent_at),
            error_message: set_active_value_opt!(value.error_message),
            retry_count: set_active_value_opt!(value.retry_count),
            last_retry_at: set_active_value_opt!(value.last_retry_at),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

