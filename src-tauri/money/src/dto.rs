// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           dto.rs
// Description:    About Money DTO
// Create   Date:  2025-06-06 13:19:58
// Last Modified:  2025-06-06 16:15:26
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{NaiveDate, NaiveDateTime};
use common::entity::sea_orm_active_enums::RepeatPeriod;
use sea_orm::prelude::{DateTimeWithTimeZone, Decimal};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Debug, Serialize, Validate)]
pub struct IncomeDto {
    #[validate(length(max = 1000, message = "description must be at most 1000 characters"))]
    pub description: Option<String>,
    pub balance: Decimal,
    pub currency: String,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct BudgetCore {
    pub category: String,
    pub amount: Decimal,
    pub repeat_period: Option<RepeatPeriod>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub used_amount: Decimal,
    pub is_active: bool,
}

#[derive(Debug, Serialize, Validate)]
pub struct BudgetDto {
    #[serde(flatten)]
    pub core: BudgetCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct BudgetResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: BudgetCore,
    pub create_at: NaiveDateTime,
    pub update_at: Option<NaiveDateTime>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct AccountCore {
    pub name: String,
    pub description: String,
    pub is_shared: bool,
}

#[derive(Clone, Debug, Serialize, Validate)]
pub struct AccountDto {
    #[serde(flatten)]
    pub core: AccountCore,
}

#[derive(Clone, Debug, Deserialize)]
pub struct AccountResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: AccountCore,
    pub create_at: NaiveDateTime,
    pub update_at: Option<NaiveDateTime>,
}
