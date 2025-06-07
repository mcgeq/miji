// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           dto.rs
// Description:    About Money DTO
// Create   Date:  2025-06-06 13:19:58
// Last Modified:  2025-06-07 23:05:43
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use chrono::{NaiveDate, NaiveDateTime};
use common::entity::{
    account, bil_reminder, budget, family_ledger, family_member,
    sea_orm_active_enums::{
        AccountType, Category, PaymentMethod, RepeatPeriod, TransactionStatus, TransactionType,
    },
    transaction,
};
use sea_orm::prelude::{DateTimeWithTimeZone, Decimal, Json};
use serde::{Deserialize, Serialize};
use validator::Validate;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct PaginationParams {
    #[validate(
        required(message = "page is required"),
        range(min = 1, message = "page must be greater than or equal to 1")
    )]
    pub page: Option<u64>,
    #[validate(
        required(message = "page_size is required"),
        range(min = 1, message = "page_size must be greater than or equal to 1")
    )]
    pub page_size: Option<u64>,
}

impl PaginationParams {
    pub fn page(&self) -> u64 {
        self.page.unwrap_or(1)
    }
    pub fn page_size(&self) -> u64 {
        self.page_size.unwrap_or(10)
    }
}

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

impl From<budget::Model> for BudgetResDto {
    fn from(value: budget::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: BudgetCore {
                category: value.category,
                amount: value.amount,
                repeat_period: Some(value.repeat_period),
                start_date: Some(value.start_date),
                end_date: Some(value.end_date),
                used_amount: value.used_amount,
                is_active: value.is_active,
            },
            create_at: value.created_at.naive_local(),
            update_at: Some(value.updated_at.unwrap().naive_local()),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct AccountCore {
    #[validate(length(min = 1, max = 100))]
    pub name: String,
    #[validate(length(max = 500))]
    pub description: String,
    pub is_shared: bool,

    pub is_active: bool,
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
impl From<account::Model> for AccountResDto {
    fn from(value: account::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: AccountCore {
                name: value.name,
                description: value.description,
                is_shared: value.is_shared,
                is_active: value.is_active,
                balance: value.balance,
                currency: value.currency,
            },
            create_at: value.created_at.naive_local(),
            update_at: Some(value.updated_at.unwrap().naive_local()),
        }
    }
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

#[derive(Debug, Serialize, Deserialize)]
pub struct PageResDto<T> {
    pub data: Vec<T>,
    pub total: u64,
    pub page: u64,
    pub page_size: u64,
}

impl From<transaction::Model> for TransactionResDto {
    fn from(value: transaction::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: TransactionCore {
                transaction_type: value.transaction_type,
                transaction_status: value.transaction_status,
                date: value.date,
                amount: value.amount,
                currency: value.currency,
                description: value.description,
                notes: value.notes,
                account_serial_num: value.account_serial_num,
                category: value.category,
                sub_category: value.sub_category,
                tags: value.tags,
                split_members: value.split_members,
                payment_method: value.payment_method,
                actual_payer_account: value.actual_payer_account,
            },
            created_at: value.created_at,
            updated_at: Some(value.updated_at.unwrap()),
        }
    }
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

impl From<family_member::Model> for FamilyMemberResDto {
    fn from(value: family_member::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: FamilyMemberCore {
                name: value.name,
                role: value.role,
                is_primary: value.is_primary,
                permissions: value.permissions,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
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

impl From<family_ledger::Model> for FamilyLedgerResDto {
    fn from(value: family_ledger::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: FamilyLedgerCore {
                description: value.description,
                base_currency: value.base_currency,
                members: value.members,
                accounts: value.accounts,
                transactions: value.transactions,
                budgets: value.budgets,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
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

impl From<bil_reminder::Model> for BilReminderResDto {
    fn from(value: bil_reminder::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: BilReminderCore {
                name: value.name,
                amount: value.amount,
                due_date: value.due_date.naive_local(),
                repeat_period: value.repeat_period,
                is_paid: value.is_paid,
                related_transaction_serial_num: value.related_transaction_serial_num,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}
