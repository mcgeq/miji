use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use macros::{set_active_value_opt, set_active_value_t};
use sea_orm::{ActiveValue, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BilReminderBase {
    pub name: String,
    pub enabled: bool,
    pub r#type: String,
    pub description: Option<String>,
    pub category: String,
    pub amount: Option<Decimal>,
    pub currency: Option<String>,
    pub due_at: DateTime<FixedOffset>,
    pub bill_date: Option<DateTime<FixedOffset>>,
    pub remind_date: DateTime<FixedOffset>,
    pub repeat_period: serde_json::Value,
    pub is_paid: bool,
    pub priority: String,
    pub advance_value: Option<i32>,
    pub advance_unit: Option<String>,
    pub related_transaction_serial_num: Option<String>,
    pub color: Option<String>,
    pub is_deleted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BilReminder {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[serde(flatten)]
    pub core: BilReminderBase,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BilReminderCreate {
    #[serde(flatten)]
    pub core: BilReminderBase,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BilReminderUpdate {
    pub name: Option<String>,
    pub enabled: Option<bool>,
    pub r#type: Option<String>,
    pub description: Option<String>,
    pub category: Option<String>,
    pub amount: Option<Decimal>,
    pub currency: Option<String>,
    pub due_at: Option<DateTime<FixedOffset>>,
    pub bill_date: Option<DateTime<FixedOffset>>,
    pub remind_date: Option<DateTime<FixedOffset>>,
    pub repeat_period: Option<serde_json::Value>,
    pub is_paid: Option<bool>,
    pub priority: Option<String>,
    pub advance_value: Option<i32>,
    pub advance_unit: Option<String>,
    pub related_transaction_serial_num: Option<String>,
    pub color: Option<String>,
    pub is_deleted: Option<bool>,
}

impl TryFrom<BilReminderCreate> for entity::bil_reminder::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: BilReminderCreate) -> Result<Self, Self::Error> {
        let now = DateUtils::local_now();
        Ok(entity::bil_reminder::ActiveModel {
            serial_num: ActiveValue::Set(McgUuid::uuid(38)),
            name: ActiveValue::Set(value.core.name),
            description: ActiveValue::Set(value.core.description),
            enabled: ActiveValue::Set(value.core.enabled),
            r#type: ActiveValue::Set(value.core.r#type),
            category: ActiveValue::Set(value.core.category),
            amount: ActiveValue::Set(value.core.amount),
            currency: ActiveValue::Set(value.core.currency),
            due_at: ActiveValue::Set(value.core.due_at),
            bill_date: ActiveValue::Set(value.core.bill_date),
            remind_date: ActiveValue::Set(value.core.remind_date),
            repeat_period: ActiveValue::Set(value.core.repeat_period),
            is_paid: ActiveValue::Set(value.core.is_paid),
            priority: ActiveValue::Set(value.core.priority),
            advance_value: ActiveValue::Set(value.core.advance_value),
            advance_unit: ActiveValue::Set(value.core.advance_unit),
            related_transaction_serial_num: ActiveValue::Set(
                value.core.related_transaction_serial_num,
            ),
            color: ActiveValue::Set(value.core.color),
            is_deleted: ActiveValue::Set(value.core.is_deleted),
            created_at: ActiveValue::Set(now),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<BilReminderUpdate> for entity::bil_reminder::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: BilReminderUpdate) -> Result<Self, Self::Error> {
        Ok(entity::bil_reminder::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            enabled: value.enabled.map_or(ActiveValue::NotSet, ActiveValue::Set),
            r#type: value.r#type.map_or(ActiveValue::NotSet, ActiveValue::Set),
            description: value
                .description
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            category: value.category.map_or(ActiveValue::NotSet, ActiveValue::Set),
            amount: value
                .amount
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            currency: value
                .currency
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            due_at: value.due_at.map_or(ActiveValue::NotSet, ActiveValue::Set),
            bill_date: value
                .bill_date
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            remind_date: value
                .remind_date
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            repeat_period: value
                .repeat_period
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            related_transaction_serial_num: value
                .related_transaction_serial_num
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            is_deleted: value
                .is_deleted
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_paid: value.is_paid.map_or(ActiveValue::NotSet, ActiveValue::Set),
            advance_value: value
                .advance_value
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            advance_unit: value
                .advance_unit
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            priority: value.priority.map_or(ActiveValue::NotSet, ActiveValue::Set),
            color: value
                .color
                .map_or(ActiveValue::NotSet, |v| ActiveValue::Set(Some(v))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_now())),
        })
    }
}

impl BilReminderUpdate {
    pub fn apply_to_model(self, model: &mut entity::bil_reminder::ActiveModel) {
        set_active_value_t!(model, self, name);
        set_active_value_t!(model, self, enabled);
        set_active_value_t!(model, self, r#type);
        set_active_value_opt!(model, self, description);
        set_active_value_t!(model, self, category);
        set_active_value_opt!(model, self, amount);
        set_active_value_opt!(model, self, currency);
        set_active_value_t!(model, self, due_at);
        set_active_value_opt!(model, self, bill_date);
        set_active_value_t!(model, self, remind_date);
        set_active_value_t!(model, self, repeat_period);
        set_active_value_t!(model, self, is_paid);
        set_active_value_t!(model, self, priority);
        set_active_value_t!(model, self, is_deleted);
        set_active_value_opt!(model, self, advance_unit);
        set_active_value_opt!(model, self, advance_value);
        set_active_value_opt!(model, self, related_transaction_serial_num);
        set_active_value_opt!(model, self, color);
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_now()));
    }
}

impl From<entity::bil_reminder::Model> for BilReminder {
    fn from(value: entity::bil_reminder::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: BilReminderBase {
                name: value.name,
                description: value.description,
                enabled: value.enabled,
                r#type: value.r#type,
                category: value.category,
                amount: value.amount,
                currency: value.currency,
                due_at: value.due_at,
                bill_date: value.bill_date,
                remind_date: value.remind_date,
                repeat_period: value.repeat_period,
                is_paid: value.is_paid,
                priority: value.priority,
                advance_value: value.advance_value,
                advance_unit: value.advance_unit,
                related_transaction_serial_num: value.related_transaction_serial_num,
                color: value.color,
                is_deleted: value.is_deleted,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
