// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           money_scheme.rs
// Description:    About Bookkeeping
// Create   Date:  2025-05-27 10:09:48
// Last Modified:  2025-05-27 12:21:55
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use sea_orm_migration::prelude::*;

#[derive(DeriveIden)]
pub enum RepeatPeriod {
    #[sea_orm(iden = "repeat_period")]
    Type, // 在迁移中用作枚举类型名称
}

#[derive(DeriveIden)]
pub enum AccountType {
    #[sea_orm(iden = "account_type")]
    Type, // 在迁移中用作枚举类型名称
}

#[derive(DeriveIden)]
pub enum TransactionStatus {
    #[sea_orm(iden = "transaction_status")]
    Type,
}

#[derive(DeriveIden)]
pub enum TransactionType {
    #[sea_orm(iden = "transaction_type")]
    Type,
}

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
    SerialNum,
    #[sea_orm(iden = "account_type")]
    AccountType,
    Description,
    Balance,
    Currency,
    IsShared,
    OwnerId,
    CreatedAt,
    UpdatedAt,
}

// 个人/家庭记账交易
#[derive(DeriveIden)]
pub enum Transaction {
    Table,
    SerialNum,
    #[sea_orm(iden = "transaction_type")]
    TransactionType,
    #[sea_orm(iden = "transaction_status")]
    TransactionStatus,
    Date,
    Amount,
    Currency,
    Description,
    Notes,
    AccountSerialNum,
    CounterpartyAccountId,
    Category,
    SubCategory,
    Tags,
    SplitMembers,
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
    Name,
    Category,
    Amount,
    #[sea_orm(iden = "repeat_period")]
    RepeatPeriod,
    StartDate,
    EndDate,
    UsedAmount,
    IsActive,
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
    #[sea_orm(iden = "repeat_period")]
    RepeatPeriod,
    IsPaid,
    RelatedTransactionSerialNum,
    CreatedAt,
    UpdatedAt,
}
