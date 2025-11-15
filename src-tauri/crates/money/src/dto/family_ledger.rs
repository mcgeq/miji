use common::utils::{date::DateUtils, uuid::McgUuid};
use entity::family_ledger;
use sea_orm::ActiveValue::{self, Set};
use serde::{Deserialize, Serialize};
use validator::Validate;

/// 家庭账本创建请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerCreate {
    #[validate(length(min = 3))]
    pub name: String,
    pub description: Option<String>,
    pub base_currency: String,
    pub members: Option<serde_json::Value>,
    pub accounts: Option<serde_json::Value>,
    pub transactions: Option<serde_json::Value>,
    pub budgets: Option<serde_json::Value>,
    pub ledger_type: Option<String>,
    pub settlement_cycle: Option<String>,
    pub auto_settlement: Option<bool>,
    pub settlement_day: Option<i32>,
    pub default_split_rule: Option<serde_json::Value>,
}

/// 家庭账本更新请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerUpdate {
    #[validate(length(min = 3))]
    pub name: Option<String>,
    pub description: Option<String>,
    pub base_currency: Option<String>,
    pub members: Option<serde_json::Value>,
    pub accounts: Option<serde_json::Value>,
    pub transactions: Option<serde_json::Value>,
    pub budgets: Option<serde_json::Value>,
    pub ledger_type: Option<String>,
    pub settlement_cycle: Option<String>,
    pub auto_settlement: Option<bool>,
    pub settlement_day: Option<i32>,
    pub default_split_rule: Option<serde_json::Value>,
}

impl TryFrom<FamilyLedgerCreate> for family_ledger::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: FamilyLedgerCreate) -> Result<Self, Self::Error> {
        value.validate()?;
        Ok(Self {
            serial_num: Set(McgUuid::uuid(38)),
            name: Set(Some(value.name)),
            description: Set(value.description.unwrap_or_default()),
            base_currency: Set(value.base_currency),
            members: Set(value
                .members
                .map(|v| serde_json::to_string(&v).unwrap_or("[]".to_string()))),
            accounts: Set(value
                .accounts
                .map(|v| serde_json::to_string(&v).unwrap_or("[]".to_string()))),
            transactions: Set(value
                .transactions
                .map(|v| serde_json::to_string(&v).unwrap_or("[]".to_string()))),
            budgets: Set(value
                .budgets
                .map(|v| serde_json::to_string(&v).unwrap_or("[]".to_string()))),
            audit_logs: Set("[]".to_string()),
            ledger_type: Set(value.ledger_type.unwrap_or_else(|| "Family".to_string())),
            settlement_cycle: Set(value
                .settlement_cycle
                .unwrap_or_else(|| "Monthly".to_string())),
            settlement_day: Set(value.settlement_day.unwrap_or(1)),
            auto_settlement: Set(value.auto_settlement.unwrap_or(false)),
            default_split_rule: Set(value
                .default_split_rule
                .or_else(|| Some(serde_json::json!([])))),
            last_settlement_at: Set(None),
            next_settlement_at: Set(None),
            status: Set("Active".to_string()),
            created_at: Set(DateUtils::local_now()),
            updated_at: Set(None),
        })
    }
}

impl TryFrom<FamilyLedgerUpdate> for entity::family_ledger::ActiveModel {
    type Error = validator::ValidationErrors;
    fn try_from(value: FamilyLedgerUpdate) -> Result<Self, Self::Error> {
        value.validate()?;
        let now = DateUtils::local_now();
        Ok(entity::family_ledger::ActiveModel {
            serial_num: ActiveValue::NotSet,
            name: value
                .name
                .map_or(ActiveValue::NotSet, |val| ActiveValue::Set(Some(val))),
            description: value
                .description
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            base_currency: value
                .base_currency
                .map_or(ActiveValue::NotSet, ActiveValue::Set),
            members: value.members.map_or(ActiveValue::NotSet, |v| {
                Set(Some(serde_json::to_string(&v).unwrap_or("[]".to_string())))
            }),
            accounts: value.accounts.map_or(ActiveValue::NotSet, |v| {
                Set(Some(serde_json::to_string(&v).unwrap_or("[]".to_string())))
            }),
            transactions: value.transactions.map_or(ActiveValue::NotSet, |v| {
                Set(Some(serde_json::to_string(&v).unwrap_or("[]".to_string())))
            }),
            budgets: value.budgets.map_or(ActiveValue::NotSet, |v| {
                Set(Some(serde_json::to_string(&v).unwrap_or("[]".to_string())))
            }),
            audit_logs: ActiveValue::NotSet,
            ledger_type: value
                .ledger_type
                .map_or(ActiveValue::NotSet, |v| Set(normalize_ledger_type(&v))),
            settlement_cycle: value
                .settlement_cycle
                .map_or(ActiveValue::NotSet, |v| Set(normalize_settlement_cycle(&v))),
            settlement_day: value.settlement_day.map_or(ActiveValue::NotSet, Set),
            auto_settlement: value.auto_settlement.map_or(ActiveValue::NotSet, Set),
            default_split_rule: value
                .default_split_rule
                .map_or(ActiveValue::NotSet, |v| Set(Some(v))),
            last_settlement_at: ActiveValue::NotSet,
            next_settlement_at: ActiveValue::NotSet,
            status: ActiveValue::NotSet,
            created_at: ActiveValue::NotSet,
            updated_at: Set(Some(now)),
        })
    }
}

/// 家庭账本响应
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerResponse {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub base_currency: String,
    pub ledger_type: String,
    pub settlement_cycle: String,
    pub auto_settlement: bool,
    pub settlement_day: i32,
    pub total_income: Option<f64>,
    pub total_expense: Option<f64>,
    pub shared_expense: Option<f64>,
    pub personal_expense: Option<f64>,
    pub pending_settlement: Option<f64>,
    pub member_count: Option<i32>,
    pub active_transaction_count: Option<i32>,
    pub last_settlement_at: Option<String>,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<family_ledger::Model> for FamilyLedgerResponse {
    fn from(model: family_ledger::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            name: model.name.unwrap_or_else(|| "未命名账本".to_string()),
            description: if model.description.is_empty() {
                None
            } else {
                Some(model.description)
            },
            base_currency: model.base_currency,
            ledger_type: model.ledger_type,
            settlement_cycle: model.settlement_cycle,
            auto_settlement: model.auto_settlement,
            settlement_day: model.settlement_day,
            total_income: Some(0.0),           // TODO: 实现真实统计
            total_expense: Some(0.0),          // TODO: 实现真实统计
            shared_expense: Some(0.0),         // TODO: 实现真实统计
            personal_expense: Some(0.0),       // TODO: 实现真实统计
            pending_settlement: Some(0.0),     // TODO: 实现真实统计
            member_count: Some(0),             // TODO: 实现真实统计
            active_transaction_count: Some(0), // TODO: 实现真实统计
            last_settlement_at: model.last_settlement_at.map(|dt| dt.to_rfc3339()),
            created_at: model.created_at.to_rfc3339(),
            updated_at: model.updated_at.map(|dt| dt.to_rfc3339()),
        }
    }
}

/// 家庭账本统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerStats {
    pub family_ledger_serial_num: String,
    pub total_income: f64,
    pub total_expense: f64,
    pub shared_expense: f64,
    pub personal_expense: f64,
    pub pending_settlement: f64,
    pub member_count: i32,
    pub active_transaction_count: i32,
    pub member_stats: Vec<MemberStats>,
}

/// 成员统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberStats {
    pub member_serial_num: String,
    pub member_name: String,
    pub total_paid: f64,
    pub total_owed: f64,
    pub balance: f64,
}

pub fn normalize_ledger_type(s: &str) -> String {
    match s.to_uppercase().as_str() {
        "PERSONAL" => "Personal".to_string(),
        "FAMILY" => "Family".to_string(),
        "PROJECT" => "Project".to_string(),
        "BUSINESS" => "Business".to_string(),
        _ => "Family".to_string(),
    }
}

pub fn normalize_settlement_cycle(s: &str) -> String {
    match s.to_uppercase().as_str() {
        "WEEKLY" => "Weekly".to_string(),
        "MONTHLY" => "Monthly".to_string(),
        "QUARTERLY" => "Quarterly".to_string(),
        "YEARLY" => "Yearly".to_string(),
        "MANUAL" => "Manual".to_string(),
        _ => "Monthly".to_string(),
    }
}
