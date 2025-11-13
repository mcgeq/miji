use entity::family_ledger;
use serde::{Deserialize, Serialize};

/// 家庭账本创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerCreate {
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
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyLedgerUpdate {
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
            description: if model.description.is_empty() { None } else { Some(model.description) },
            base_currency: model.base_currency,
            ledger_type: model.ledger_type,
            settlement_cycle: model.settlement_cycle,
            auto_settlement: model.auto_settlement,
            settlement_day: 1, // 默认值，因为数据库中没有这个字段
            total_income: Some(0.0), // TODO: 实现真实统计
            total_expense: Some(0.0), // TODO: 实现真实统计
            shared_expense: Some(0.0), // TODO: 实现真实统计
            personal_expense: Some(0.0), // TODO: 实现真实统计
            pending_settlement: Some(0.0), // TODO: 实现真实统计
            member_count: Some(0), // TODO: 实现真实统计
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
