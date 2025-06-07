// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           money_scheme.rs
// Description:    About Bookkeeping
// Create   Date:  2025-05-27 10:09:48
// Last Modified:  2025-06-07 21:21:50
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use sea_orm_migration::prelude::*;

// 家庭成员
#[derive(DeriveIden)]
pub enum FamilyMember {
    Table,
    SerialNum,
    Name,
    Role,
    IsPrimary,
    Permissions,
    CreatedAt,
    UpdatedAt,
}

// 账户
#[derive(DeriveIden)]
pub enum Account {
    Table,
    Name,
    SerialNum,
    Description,
    Balance,
    Currency,
    IsShared,
    OwnerId,
    IsActive,
    CreatedAt,
    UpdatedAt,
}

// 个人/家庭记账交易
#[derive(DeriveIden)]
pub enum Transaction {
    Table,
    SerialNum,
    TransactionType,
    TransactionStatus,
    Date,
    Amount,
    Currency,
    Description,
    Notes,
    AccountSerialNum,
    Category,
    SubCategory,
    Tags,
    SplitMembers,
    PaymentMethod,
    ActualPayerAccount,
    CreatedAt,
    UpdatedAt,
}

// 货币类型
#[derive(DeriveIden)]
pub enum Currency {
    Table,
    Code,
    Symbol,
}

// 家庭预算
#[derive(DeriveIden)]
pub enum Budget {
    Table,
    SerialNum,
    AccountSerialNum,
    Name,
    Category,
    Amount,
    RepeatPeriod,
    StartDate,
    EndDate,
    UsedAmount,
    IsActive,
    CreatedAt,
    UpdatedAt,
}

// 家庭记账本
#[derive(DeriveIden)]
pub enum FamilyLedger {
    Table,
    SerialNum,
    Description,
    BaseCurrency,
    Members,
    Accounts,
    Transactions,
    Budgets,
    AuditLogs,
    CreatedAt,
    UpdatedAt,
}
// 账单提醒
#[derive(DeriveIden)]
pub enum BilReminder {
    Table,
    SerialNum,
    Name,
    Amount,
    DueDate,
    RepeatPeriod,
    IsPaid,
    RelatedTransactionSerialNum,
    CreatedAt,
    UpdatedAt,
}
