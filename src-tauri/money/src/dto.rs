// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           dto.rs
// Description:    About Money DTO
// Create   Date:  2025-06-06 13:19:58
// Last Modified:  2025-06-06 22:25:55
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{NaiveDate, NaiveDateTime};
use common::entity::sea_orm_active_enums::{
    AccountType, Category, PaymentMethod, ReminderType, RepeatPeriod, TransactionStatus,
    TransactionType,
};
use sea_orm::prelude::{DateTimeWithTimeZone, Decimal, Json};
use serde::{Deserialize, Serialize};
use validator::Validate;

// Existing DTOs
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
    pub repeat_period: Option<RepeatPeriod>, // Adjusted to Option to match flexibility
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub used_amount: Decimal,
    pub is_active: bool,
    // Note: 'name' from entity is missing here; assuming intentional exclusion
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
    #[validate(length(min = 1, max = 100))]
    pub name: String,
    #[validate(length(max = 500))]
    pub description: String,
    pub is_shared: bool,
    pub balance: Decimal,
    #[validate(length(min = 3, max = 3))]
    pub currency: String,
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

// New DTOs for Transaction
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct TransactionCore {
    pub transaction_type: TransactionType,
    pub transaction_status: TransactionStatus,
    pub date: NaiveDate,
    pub amount: Decimal,
    #[validate(length(min = 3, max = 3))]
    pub currency: String,
    #[validate(length(max = 1000, message = "description must be at most 1000 characters"))]
    pub description: String,
    pub notes: Option<String>,
    pub account_serial_num: String,
    pub category: Category,
    pub sub_category: Option<String>,
    pub tags: Option<Json>,
    pub split_members: Option<Json>,
    pub payment_method: PaymentMethod,
    pub actual_payer_account: AccountType,
}

#[derive(Debug, Serialize, Validate)]
pub struct TransactionDto {
    #[serde(flatten)]
    pub core: TransactionCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct TransactionResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: TransactionCore,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

// New DTOs for Reminder
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct ReminderCore {
    pub todo_serial_num: String,
    pub remind_at: DateTimeWithTimeZone,
    pub r#type: Option<ReminderType>,
    pub is_sent: bool,
}

#[derive(Debug, Serialize, Validate)]
pub struct ReminderDto {
    #[serde(flatten)]
    pub core: ReminderCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct ReminderResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: ReminderCore,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

// New DTOs for FamilyMember
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct FamilyMemberCore {
    pub name: String,
    pub role: String,
    pub is_primary: bool,
    pub permissions: Json,
}

#[derive(Debug, Serialize, Validate)]
pub struct FamilyMemberDto {
    #[serde(flatten)]
    pub core: FamilyMemberCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct FamilyMemberResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: FamilyMemberCore,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

// New DTOs for FamilyLedger
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct FamilyLedgerCore {
    pub description: String,
    pub base_currency: String,
    pub members: Json,
    pub accounts: Json,
    pub transactions: Json,
    pub budgets: Json,
    pub audit_logs: Json,
}

#[derive(Debug, Serialize, Validate)]
pub struct FamilyLedgerDto {
    #[serde(flatten)]
    pub core: FamilyLedgerCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct FamilyLedgerResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: FamilyLedgerCore,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

// New DTOs for BilReminder
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct BilReminderCore {
    pub name: String,
    pub amount: Decimal,
    pub due_date: NaiveDateTime,
    pub repeat_period: RepeatPeriod,
    pub is_paid: bool,
    pub related_transaction_serial_num: Option<String>,
}

#[derive(Debug, Serialize, Validate)]
pub struct BilReminderDto {
    #[serde(flatten)]
    pub core: BilReminderCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct BilReminderResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: BilReminderCore,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}
