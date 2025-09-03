use common::utils::{
    date::DateUtils,
    uuid::McgUuid,
    validate::{validate_color, validate_date_time},
};
use sea_orm::{ActiveValue, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::dto::account::{AccountResponseWithRelations, AccountWithRelations, CurrencyInfo};

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BudgetBase {
    #[validate(length(equal = 38))]
    pub serial_num: String,
    #[validate(length(equal = 38))]
    pub account_serial_num: String,
    #[validate(length(min = 2, max = 20))]
    pub name: String,
    pub description: Option<String>,
    pub category: String,
    pub amount: Decimal,
    pub repeat_period: String,
    #[validate(custom(function = "validate_date_time"))]
    pub start_date: String,
    #[validate(custom(function = "validate_date_time"))]
    pub end_date: String,
    pub used_amount: Decimal,
    pub is_active: bool,
    pub alert_enabled: bool,
    pub alert_threshold: Option<String>,
    #[validate(custom(function = "validate_color"))]
    pub color: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetWithAccount {
    pub budget: entity::budget::Model,
    pub account: AccountWithRelations,
    pub currency: entity::currency::Model,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct Budget {
    #[serde(flatten)]
    pub core: BudgetBase,
    pub account: AccountResponseWithRelations,
    pub currency: CurrencyInfo,
    pub created_at: String,
    pub updated_at: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BudgetCreate {
    #[serde(flatten)]
    pub core: BudgetBase,
    pub currency: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct BudgetUpdate {
    pub account_serial_num: Option<String>,
    pub name: Option<String>,
    pub description: Option<String>,
    pub category: Option<String>,
    pub amount: Option<Decimal>,
    pub currency: Option<String>,
    pub repeat_period: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub used_amount: Option<Decimal>,
    pub is_active: Option<bool>,
    pub alert_enabled: Option<bool>,
    pub alert_threshold: Option<String>,
    pub color: Option<String>,
}

impl BudgetUpdate {
    pub fn apply_to_model(self, model: &mut entity::budget::ActiveModel) {
        // Update fields if they have new values
        if let Some(account_serial_num) = self.account_serial_num {
            model.account_serial_num = ActiveValue::Set(account_serial_num);
        }
        if let Some(name) = self.name {
            model.name = ActiveValue::Set(name);
        }
        if let Some(category) = self.category {
            model.category = ActiveValue::Set(category);
        }
        if let Some(amount) = self.amount {
            model.amount = ActiveValue::Set(amount);
        }
        if let Some(currency) = self.currency {
            model.currency = ActiveValue::Set(currency);
        }
        if let Some(repeat_period) = self.repeat_period {
            model.repeat_period = ActiveValue::Set(repeat_period);
        }
        if let Some(start_date) = self.start_date {
            model.start_date = ActiveValue::Set(start_date);
        }
        if let Some(end_date) = self.end_date {
            model.end_date = ActiveValue::Set(end_date);
        }
        if let Some(used_amount) = self.used_amount {
            model.used_amount = ActiveValue::Set(used_amount);
        }
        if let Some(is_active) = self.is_active {
            model.is_active = ActiveValue::Set(is_active as i32);
        }
        if let Some(alert_enabled) = self.alert_enabled {
            model.alert_enabled = ActiveValue::Set(alert_enabled as i32);
        }
        if let Some(alert_threshold) = self.alert_threshold {
            model.alert_threshold = ActiveValue::Set(Some(alert_threshold));
        }
        if let Some(color) = self.color {
            model.color = ActiveValue::Set(Some(color));
        }
        model.updated_at = ActiveValue::Set(Some(DateUtils::local_rfc3339()))
    }
}

impl TryFrom<BudgetCreate> for entity::budget::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: BudgetCreate) -> Result<Self, Self::Error> {
        value.validate()?;
        let serial_num = McgUuid::uuid(38);
        let budget = value.core;
        let now = DateUtils::local_rfc3339();
        Ok(entity::budget::ActiveModel {
            serial_num: ActiveValue::Set(serial_num),
            account_serial_num: ActiveValue::Set(budget.account_serial_num),
            name: ActiveValue::Set(budget.name),
            category: ActiveValue::Set(budget.category),
            description: ActiveValue::Set(budget.description),
            amount: ActiveValue::Set(budget.amount),
            used_amount: ActiveValue::Set(budget.used_amount),
            currency: ActiveValue::Set(value.currency),
            repeat_period: ActiveValue::Set(budget.repeat_period),
            start_date: ActiveValue::Set(budget.start_date),
            end_date: ActiveValue::Set(budget.end_date),
            is_active: ActiveValue::Set(budget.is_active as i32),
            alert_enabled: ActiveValue::Set(budget.alert_enabled as i32),
            alert_threshold: ActiveValue::Set(budget.alert_threshold),
            color: ActiveValue::Set(budget.color),
            created_at: ActiveValue::Set(now.clone()),
            updated_at: ActiveValue::Set(Some(now)),
        })
    }
}

impl TryFrom<BudgetUpdate> for entity::budget::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: BudgetUpdate) -> Result<Self, Self::Error> {
        value.validate()?;
        Ok(entity::budget::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value.name.map_or(ActiveValue::NotSet, ActiveValue::Set),
            description: value
                .description
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            account_serial_num: value
                .account_serial_num
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            category: value.category.map_or(ActiveValue::NotSet, ActiveValue::Set),
            amount: value.amount.map_or(ActiveValue::NotSet, ActiveValue::Set),
            used_amount: value
                .used_amount
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            currency: value.currency.map_or(ActiveValue::NotSet, ActiveValue::Set),
            repeat_period: value
                .repeat_period
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            start_date: value
                .start_date
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            end_date: value.end_date.map_or(ActiveValue::NotSet, ActiveValue::Set),
            is_active: value
                .is_active
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(val as i32)),
            alert_enabled: value
                .alert_enabled
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(val as i32)),
            alert_threshold: value
                .alert_threshold
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            color: value
                .color
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            created_at: ActiveValue::NotSet,
            updated_at: ActiveValue::Set(Some(DateUtils::local_rfc3339())),
        })
    }
}

impl From<BudgetWithAccount> for Budget {
    fn from(value: BudgetWithAccount) -> Self {
        let budget = value.budget;
        let account = value.account;
        let cny = value.currency;
        Self {
            core: BudgetBase {
                serial_num: budget.serial_num,
                name: budget.name,
                description: budget.description,
                account_serial_num: budget.account_serial_num,
                category: budget.category,
                amount: budget.amount,
                used_amount: budget.used_amount,
                repeat_period: budget.repeat_period,
                start_date: budget.start_date,
                end_date: budget.end_date,
                is_active: budget.is_active != 0,
                alert_enabled: budget.alert_enabled != 0,
                alert_threshold: budget.alert_threshold,
                color: budget.color,
            },
            account: AccountResponseWithRelations::from(account),
            currency: CurrencyInfo::from(cny),
            created_at: budget.created_at,
            updated_at: budget.updated_at,
        }
    }
}
