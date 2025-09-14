use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::set_active_value_t;
use sea_orm::ActiveValue;
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PeriodSettingsBase {
    pub average_cycle_length: i32,
    pub average_period_length: i32,
    pub notifications: Notifications,
    pub privacy: Privacy,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Notifications {
    pub period_reminder: bool,
    pub ovulation_reminder: bool,
    pub pms_reminder: bool,
    pub reminder_days: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Privacy {
    pub data_sync: bool,
    pub analytics: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodSettingsCreate {
    #[serde(flatten)]
    pub core: PeriodSettingsBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodSettingsUpdate {
    pub average_cycle_length: Option<i32>,
    pub average_period_length: Option<i32>,
    pub notifications: Option<Notifications>,
    pub privacy: Option<Privacy>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PeriodSettings {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: PeriodSettingsBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl TryFrom<PeriodSettingsCreate> for entity::period_settings::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: PeriodSettingsCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::period_settings::ActiveModel {
            serial_num: sea_orm::ActiveValue::Set(McgUuid::uuid(38)),
            average_cycle_length: ActiveValue::Set(value.core.average_cycle_length),
            average_period_length: ActiveValue::Set(value.core.average_period_length),
            period_reminder: ActiveValue::Set(value.core.notifications.period_reminder),
            ovulation_reminder: ActiveValue::Set(value.core.notifications.ovulation_reminder),
            pms_reminder: ActiveValue::Set(value.core.notifications.pms_reminder),
            reminder_days: ActiveValue::Set(value.core.notifications.reminder_days),
            data_sync: ActiveValue::Set(value.core.privacy.data_sync),
            analytics: ActiveValue::Set(value.core.privacy.analytics),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<PeriodSettingsUpdate> for entity::period_settings::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: PeriodSettingsUpdate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        // 辅助函数，将 Option<bool> 映射到 ActiveValue
        fn map_bool(opt: Option<bool>) -> ActiveValue<bool> {
            opt.map_or(ActiveValue::NotSet, ActiveValue::Set)
        }

        // 辅助函数，将 Option<i32> 映射到 ActiveValue
        fn map_i32(opt: Option<i32>) -> ActiveValue<i32> {
            opt.map_or(ActiveValue::NotSet, ActiveValue::Set)
        }
        Ok(entity::period_settings::ActiveModel {
            serial_num: ActiveValue::NotSet,
            average_cycle_length: map_i32(value.average_cycle_length),
            average_period_length: map_i32(value.average_period_length),
            period_reminder: map_bool(value.notifications.as_ref().map(|n| n.period_reminder)),
            ovulation_reminder: map_bool(
                value.notifications.as_ref().map(|n| n.ovulation_reminder),
            ),
            pms_reminder: map_bool(value.notifications.as_ref().map(|n| n.pms_reminder)),
            reminder_days: map_i32(value.notifications.as_ref().map(|n| n.reminder_days)),
            data_sync: map_bool(value.privacy.as_ref().map(|p| p.data_sync)),
            analytics: map_bool(value.privacy.as_ref().map(|p| p.analytics)),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl PeriodSettingsUpdate {
    pub fn apply_to_model(self, model: &mut entity::period_settings::ActiveModel) {
        set_active_value_t!(model, self, average_cycle_length);
        set_active_value_t!(model, self, average_period_length);
    }
}

impl From<entity::period_settings::Model> for PeriodSettings {
    fn from(value: entity::period_settings::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: PeriodSettingsBase {
                average_cycle_length: value.average_cycle_length,
                average_period_length: value.average_period_length,
                notifications: Notifications {
                    period_reminder: value.period_reminder,
                    ovulation_reminder: value.ovulation_reminder,
                    pms_reminder: value.pms_reminder,
                    reminder_days: value.reminder_days,
                },
                privacy: Privacy {
                    data_sync: value.data_sync,
                    analytics: value.analytics,
                },
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
