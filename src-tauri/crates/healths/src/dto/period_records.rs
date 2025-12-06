use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::{set_active_value_opt, set_active_value_t};
use sea_orm::ActiveValue::{self, Set};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodRecordsBase {
    pub notes: Option<String>,
    pub start_date: DateTime<FixedOffset>,
    pub end_date: DateTime<FixedOffset>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodRecordsCreate {
    #[serde(flatten)]
    pub core: PeriodRecordsBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodRecordsUpdate {
    pub notes: Option<String>,
    pub start_date: Option<DateTime<FixedOffset>>,
    pub end_date: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodRecords {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: PeriodRecordsBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl TryFrom<PeriodRecordsCreate> for entity::period_records::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: PeriodRecordsCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::period_records::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            notes: Set(value.core.notes),
            start_date: Set(value.core.start_date),
            end_date: Set(value.core.end_date),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl TryFrom<PeriodRecordsUpdate> for entity::period_records::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: PeriodRecordsUpdate) -> Result<Self, Self::Error> {
        Ok(entity::period_records::ActiveModel {
            serial_num: ActiveValue::NotSet,
            notes: value
                .notes
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            start_date: value
                .start_date
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            end_date: value.end_date.map_or(ActiveValue::NotSet, ActiveValue::Set),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl PeriodRecordsUpdate {
    pub fn apply_to_model(self, model: &mut entity::period_records::ActiveModel) {
        set_active_value_opt!(model, self, notes);
        set_active_value_t!(model, self, start_date);
        set_active_value_t!(model, self, end_date);
    }
}

impl From<entity::period_records::Model> for PeriodRecords {
    fn from(value: entity::period_records::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: PeriodRecordsBase {
                notes: value.notes,
                start_date: value.start_date,
                end_date: value.end_date,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
