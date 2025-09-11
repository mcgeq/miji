use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::{set_active_value_opt, set_active_value_t};
use sea_orm::ActiveValue::{self, Set};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodDailyRecordBase {
    pub period_serial_num: String,
    pub date: DateTime<FixedOffset>,
    pub flow_level: Option<String>,
    pub exercise_intensity: String,
    pub sexual_activity: bool,
    pub contraception_method: Option<String>,
    pub diet: String,
    pub mood: Option<String>,
    pub water_intake: Option<i32>,
    pub sleep_hours: Option<i32>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodDailyRecordCreate {
    #[serde(flatten)]
    pub core: PeriodDailyRecordBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodDailyRecord{
    pub serial_num: String,
    #[serde(flatten)]
    pub core: PeriodDailyRecordBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct PeriodDailyRecordUpdate{
    pub period_serial_num: Option<String>,
    pub date: Option<DateTime<FixedOffset>>,
    pub flow_level: Option<String>,
    pub exercise_intensity: Option<String>,
    pub sexual_activity: Option<bool>,
    pub contraception_method: Option<String>,
    pub diet: Option<String>,
    pub mood: Option<String>,
    pub water_intake: Option<i32>,
    pub sleep_hours: Option<i32>,
    pub notes: Option<String>,
}

impl TryFrom<PeriodDailyRecordCreate> for entity::period_daily_records::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: PeriodDailyRecordCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::period_daily_records::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            period_serial_num: Set(value.core.period_serial_num),
            date: Set(value.core.date),
            flow_level: Set(value.core.flow_level),
            exercise_intensity: Set(value.core.exercise_intensity),
            sleep_hours: Set(value.core.sleep_hours),
            contraception_method: Set(value.core.contraception_method),
            sexual_activity: Set(value.core.sexual_activity),
            diet: Set(value.core.diet),
            mood: Set(value.core.mood),
            water_intake: Set(value.core.water_intake),
            notes: Set(value.core.notes),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl TryFrom<PeriodDailyRecordUpdate> for entity::period_daily_records::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: PeriodDailyRecordUpdate) -> Result<Self, Self::Error> {
        Ok(entity::period_daily_records::ActiveModel {
            serial_num: ActiveValue::NotSet,
            period_serial_num: value.period_serial_num.map_or(ActiveValue::NotSet, ActiveValue::Set),
            date: value.date.map_or(ActiveValue::NotSet, ActiveValue::Set),
            flow_level: value.flow_level.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            exercise_intensity: value.exercise_intensity.map_or(ActiveValue::NotSet, ActiveValue::Set),
            contraception_method: value.contraception_method.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            diet: value.diet.map_or(ActiveValue::NotSet, ActiveValue::Set),
            sexual_activity: value.sexual_activity.map_or(ActiveValue::NotSet, ActiveValue::Set),
            mood: value.mood.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            water_intake: value.water_intake.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            sleep_hours: value.sleep_hours.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            notes: value.notes.map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl PeriodDailyRecordUpdate {
    pub fn apply_to_model(self, model: &mut entity::period_daily_records::ActiveModel) {
        set_active_value_t!(model, self, period_serial_num);
        set_active_value_t!(model, self, date);
        set_active_value_opt!(model, self, flow_level);
        set_active_value_t!(model, self, exercise_intensity);
        set_active_value_opt!(model, self, contraception_method);
        set_active_value_t!(model, self, diet);
        set_active_value_t!(model, self, sexual_activity);
        set_active_value_opt!(model, self, mood);
        set_active_value_opt!(model, self, water_intake);
        set_active_value_opt!(model, self, sleep_hours);
        set_active_value_opt!(model, self, notes);
    }
}

impl From<entity::period_daily_records::Model> for PeriodDailyRecord {
    fn from(value: entity::period_daily_records::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: PeriodDailyRecordBase {
            period_serial_num: value.period_serial_num,
            date: value.date,
            flow_level: value.flow_level,
            exercise_intensity: value.exercise_intensity,
            sexual_activity: value.sexual_activity,
            contraception_method: value.contraception_method,
            diet: value.diet,
            mood: value.mood,
            water_intake: value.water_intake,
            sleep_hours: value.sleep_hours,
            notes: value.notes,
        },
        created_at: value.created_at,
        updated_at: value.updated_at
        }
    }
}
