//! 家庭预算扩展 DTO 定义
//! 
//! 注意：家庭预算使用现有的 Budget 表，通过 family_ledger_serial_num 字段区分
//! - 如果 account_serial_num 有值 = 个人预算
//! - 如果 family_ledger_serial_num 有值 = 家庭预算

use sea_orm::prelude::Decimal;
use serde::{Deserialize, Serialize};

/// 预算分配响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetAllocationResponse {
    pub serial_num: String,
    pub budget_serial_num: String,
    pub category_serial_num: Option<String>,
    pub category_name: Option<String>,
    pub member_serial_num: Option<String>,
    pub member_name: Option<String>,
    pub allocated_amount: Decimal,
    pub used_amount: Decimal,
    pub remaining_amount: Decimal,
    pub usage_percentage: Decimal,
    pub percentage: Option<Decimal>,
    pub is_exceeded: bool,
    // 增强字段 - 分配规则
    pub allocation_type: String,
    pub rule_config: Option<serde_json::Value>,
    // 增强字段 - 超支控制
    pub allow_overspend: bool,
    pub overspend_limit_type: Option<String>,
    pub overspend_limit_value: Option<Decimal>,
    pub can_overspend_more: bool, // 是否还能继续超支
    // 增强字段 - 预警设置
    pub alert_enabled: bool,
    pub alert_threshold: i32,
    pub alert_config: Option<serde_json::Value>,
    pub is_warning: bool, // 是否已达到预警阈值
    // 增强字段 - 管理
    pub priority: i32,
    pub is_mandatory: bool,
    pub status: String,
    pub notes: Option<String>,
    pub created_at: String,
    pub updated_at: Option<String>,
}

/// 创建家庭预算请求 DTO（扩展现有Budget）
/// 注意：创建家庭预算时，设置 family_ledger_serial_num 而不是 account_serial_num
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyBudgetCreateRequest {
    pub family_ledger_serial_num: String, // 家庭账本序列号
    pub name: String,
    pub description: Option<String>,
    pub budget_type: String,  // 使用现有Budget的budget_type字段
    pub amount: Decimal,      // total_amount (使用Budget的amount字段)
    pub start_date: String,   // YYYY-MM-DD
    pub end_date: String,     // YYYY-MM-DD
    pub alert_threshold: Option<i32>, // 预警阈值，默认 80%
    pub currency: String,     // 币种
    pub created_by: String,   // 创建者
    pub allocations: Option<Vec<BudgetAllocationCreateRequest>>,
}

/// 创建预算分配请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetAllocationCreateRequest {
    pub category_serial_num: Option<String>,
    pub member_serial_num: Option<String>,
    pub allocated_amount: Option<Decimal>, // 指定金额
    pub percentage: Option<Decimal>,       // 或指定百分比
    // 增强字段 - 分配规则
    pub allocation_type: Option<String>, // FIXED_AMOUNT, PERCENTAGE, SHARED, DYNAMIC
    pub rule_config: Option<serde_json::Value>,
    // 增强字段 - 超支控制
    pub allow_overspend: Option<bool>,
    pub overspend_limit_type: Option<String>,
    pub overspend_limit_value: Option<Decimal>,
    // 增强字段 - 预警设置
    pub alert_enabled: Option<bool>,
    pub alert_threshold: Option<i32>,
    pub alert_config: Option<serde_json::Value>,
    // 增强字段 - 管理
    pub priority: Option<i32>,
    pub is_mandatory: Option<bool>,
    pub notes: Option<String>,
}

/// 更新家庭预算分配请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetAllocationUpdateRequest {
    pub allocated_amount: Option<Decimal>,
    pub percentage: Option<Decimal>,
    // 增强字段
    pub allocation_type: Option<String>,
    pub rule_config: Option<serde_json::Value>,
    pub allow_overspend: Option<bool>,
    pub overspend_limit_type: Option<String>,
    pub overspend_limit_value: Option<Decimal>,
    pub alert_enabled: Option<bool>,
    pub alert_threshold: Option<i32>,
    pub alert_config: Option<serde_json::Value>,
    pub priority: Option<i32>,
    pub is_mandatory: Option<bool>,
    pub status: Option<String>,
    pub notes: Option<String>,
}

/// 预算使用记录 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetUsageRequest {
    pub budget_serial_num: String,
    pub allocation_serial_num: Option<String>,
    pub amount: Decimal,
    pub transaction_serial_num: String,
}

/// 预算统计 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetStatisticsResponse {
    pub total_budgets: i64,
    pub active_budgets: i64,
    pub total_allocated: Decimal,
    pub total_used: Decimal,
    pub total_remaining: Decimal,
    pub overall_usage_percentage: Decimal,
    pub exceeded_count: i64,
    pub warning_count: i64,
    pub budget_breakdown: Vec<BudgetBreakdown>,
}

/// 预算分解统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetBreakdown {
    pub budget_type: String,
    pub count: i64,
    pub total_amount: Decimal,
    pub used_amount: Decimal,
    pub usage_percentage: Decimal,
}

/// 家庭预算列表查询参数（扩展Budget查询）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyBudgetListQuery {
    pub family_ledger_serial_num: String, // 按家庭账本筛选
    pub budget_type: Option<String>,
    pub is_active: Option<bool>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

impl Default for FamilyBudgetListQuery {
    fn default() -> Self {
        Self {
            family_ledger_serial_num: String::new(),
            budget_type: None,
            is_active: Some(true),
            page: Some(1),
            page_size: Some(20),
        }
    }
}

/// 预算提醒 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetAlertResponse {
    pub budget_serial_num: String,
    pub budget_name: String,
    pub alert_type: String, // WARNING, EXCEEDED
    pub usage_percentage: Decimal,
    pub remaining_amount: Decimal,
    pub message: String,
}

/// 预算调整建议 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BudgetAdjustmentSuggestion {
    pub budget_serial_num: String,
    pub current_amount: Decimal,
    pub suggested_amount: Decimal,
    pub reason: String,
    pub historical_usage: Decimal,
    pub projected_usage: Decimal,
}
