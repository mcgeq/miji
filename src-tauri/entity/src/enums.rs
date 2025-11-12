//! 家庭账本相关的枚举类型定义

use serde::{Deserialize, Serialize};
use strum::{Display, EnumIter, EnumString};

/// 账本类型
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum LedgerType {
    #[strum(serialize = "Personal")]
    Personal,
    #[strum(serialize = "Family")]
    Family,
    #[strum(serialize = "Project")]
    Project,
    #[strum(serialize = "Business")]
    Business,
}

/// 结算周期
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum SettlementCycle {
    #[strum(serialize = "Weekly")]
    Weekly,
    #[strum(serialize = "Monthly")]
    Monthly,
    #[strum(serialize = "Quarterly")]
    Quarterly,
    #[strum(serialize = "Yearly")]
    Yearly,
    #[strum(serialize = "Manual")]
    Manual,
}

/// 账本状态
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum LedgerStatus {
    #[strum(serialize = "Active")]
    Active,
    #[strum(serialize = "Archived")]
    Archived,
    #[strum(serialize = "Suspended")]
    Suspended,
}

/// 成员角色
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum MemberRole {
    #[strum(serialize = "Owner")]
    Owner,
    #[strum(serialize = "Admin")]
    Admin,
    #[strum(serialize = "Member")]
    Member,
    #[strum(serialize = "Viewer")]
    Viewer,
}

/// 成员状态
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum MemberStatus {
    #[strum(serialize = "Active")]
    Active,
    #[strum(serialize = "Inactive")]
    Inactive,
    #[strum(serialize = "Suspended")]
    Suspended,
}

/// 分摊规则类型
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum SplitRuleType {
    #[strum(serialize = "Equal")]
    Equal,
    #[strum(serialize = "Percentage")]
    Percentage,
    #[strum(serialize = "FixedAmount")]
    FixedAmount,
    #[strum(serialize = "Weighted")]
    Weighted,
    #[strum(serialize = "Custom")]
    Custom,
}

/// 分摊记录状态
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum SplitRecordStatus {
    #[strum(serialize = "Pending")]
    Pending,
    #[strum(serialize = "Confirmed")]
    Confirmed,
    #[strum(serialize = "Paid")]
    Paid,
    #[strum(serialize = "Cancelled")]
    Cancelled,
}

/// 债务关系状态
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum DebtStatus {
    #[strum(serialize = "Active")]
    Active,
    #[strum(serialize = "Settled")]
    Settled,
    #[strum(serialize = "Cancelled")]
    Cancelled,
}

/// 结算类型
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum SettlementType {
    #[strum(serialize = "Manual")]
    Manual,
    #[strum(serialize = "Automatic")]
    Automatic,
    #[strum(serialize = "Partial")]
    Partial,
    #[strum(serialize = "Full")]
    Full,
}

/// 结算状态
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum SettlementStatus {
    #[strum(serialize = "Pending")]
    Pending,
    #[strum(serialize = "InProgress")]
    InProgress,
    #[strum(serialize = "Completed")]
    Completed,
    #[strum(serialize = "Cancelled")]
    Cancelled,
}

/// 权限类型
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, EnumString, Display, EnumIter)]
pub enum Permission {
    // 账本权限
    #[strum(serialize = "ledger:view")]
    LedgerView,
    #[strum(serialize = "ledger:edit")]
    LedgerEdit,
    #[strum(serialize = "ledger:delete")]
    LedgerDelete,
    #[strum(serialize = "ledger:manage")]
    LedgerManage,
    
    // 成员权限
    #[strum(serialize = "member:view")]
    MemberView,
    #[strum(serialize = "member:add")]
    MemberAdd,
    #[strum(serialize = "member:edit")]
    MemberEdit,
    #[strum(serialize = "member:remove")]
    MemberRemove,
    
    // 交易权限
    #[strum(serialize = "transaction:view")]
    TransactionView,
    #[strum(serialize = "transaction:add")]
    TransactionAdd,
    #[strum(serialize = "transaction:edit")]
    TransactionEdit,
    #[strum(serialize = "transaction:delete")]
    TransactionDelete,
    
    // 分摊权限
    #[strum(serialize = "split:view")]
    SplitView,
    #[strum(serialize = "split:create")]
    SplitCreate,
    #[strum(serialize = "split:edit")]
    SplitEdit,
    #[strum(serialize = "split:confirm")]
    SplitConfirm,
    
    // 结算权限
    #[strum(serialize = "settlement:view")]
    SettlementView,
    #[strum(serialize = "settlement:initiate")]
    SettlementInitiate,
    #[strum(serialize = "settlement:complete")]
    SettlementComplete,
    
    // 统计权限
    #[strum(serialize = "stats:view")]
    StatsView,
    #[strum(serialize = "stats:export")]
    StatsExport,
}
