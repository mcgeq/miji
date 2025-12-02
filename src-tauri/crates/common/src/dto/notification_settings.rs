use chrono::{DateTime, FixedOffset, NaiveTime};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::set_active_value_opt;
use sea_orm::{ActiveValue, Json};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationSettingsBase {
    pub user_id: String,
    pub notification_type: String,
    pub enabled: bool,
    pub quiet_hours_start: Option<NaiveTime>,
    pub quiet_hours_end: Option<NaiveTime>,
    pub quiet_days: Option<Json>,
    pub sound_enabled: bool,
    pub vibration_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationSettings {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: NotificationSettingsBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationSettingsCreate {
    #[serde(flatten)]
    pub core: NotificationSettingsBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct NotificationSettingsUpdate {
    pub user_id: Option<String>,
    pub notification_type: Option<String>,
    pub enabled: Option<bool>,
    pub quiet_hours_start: Option<Option<NaiveTime>>,
    pub quiet_hours_end: Option<Option<NaiveTime>>,
    pub quiet_days: Option<Option<Json>>,
    pub sound_enabled: Option<bool>,
    pub vibration_enabled: Option<bool>,
}

impl TryFrom<NotificationSettingsCreate> for entity::notification_settings::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: NotificationSettingsCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::notification_settings::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            user_id: ActiveValue::Set(value.core.user_id),
            notification_type: ActiveValue::Set(value.core.notification_type),
            enabled: ActiveValue::Set(value.core.enabled),
            quiet_hours_start: ActiveValue::Set(value.core.quiet_hours_start),
            quiet_hours_end: ActiveValue::Set(value.core.quiet_hours_end),
            quiet_days: ActiveValue::Set(value.core.quiet_days),
            sound_enabled: ActiveValue::Set(value.core.sound_enabled),
            vibration_enabled: ActiveValue::Set(value.core.vibration_enabled),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<NotificationSettingsUpdate> for entity::notification_settings::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: NotificationSettingsUpdate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::notification_settings::ActiveModel {
            serial_num: ActiveValue::NotSet,
            user_id: set_active_value_opt!(value.user_id),
            notification_type: set_active_value_opt!(value.notification_type),
            enabled: set_active_value_opt!(value.enabled),
            quiet_hours_start: set_active_value_opt!(value.quiet_hours_start),
            quiet_hours_end: set_active_value_opt!(value.quiet_hours_end),
            quiet_days: set_active_value_opt!(value.quiet_days),
            sound_enabled: set_active_value_opt!(value.sound_enabled),
            vibration_enabled: set_active_value_opt!(value.vibration_enabled),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

