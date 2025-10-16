use chrono::{DateTime, FixedOffset};
use sea_orm::prelude::Decimal;
use serde::{Deserialize, Serialize};

/// 分期付款计划创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateInstallmentPlanRequest {
    pub transaction_id: String,
    pub total_amount: Decimal,
    pub total_periods: i32,
    pub installment_amount: Decimal,
    pub first_due_date: DateTime<FixedOffset>,
}

/// 分期付款计划响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentPlanResponse {
    pub id: String,
    pub transaction_id: String,
    pub total_amount: Decimal,
    pub total_periods: i32,
    pub installment_amount: Decimal,
    pub first_due_date: DateTime<FixedOffset>,
    pub status: String,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
    pub details: Vec<InstallmentDetailResponse>,
}

/// 分期付款明细创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateInstallmentDetailRequest {
    pub plan_id: String,
    pub period_number: i32,
    pub due_date: DateTime<FixedOffset>,
    pub amount: Decimal,
}

/// 分期付款明细响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentDetailResponse {
    pub id: String,
    pub plan_id: String,
    pub period_number: i32,
    pub due_date: DateTime<FixedOffset>,
    pub amount: Decimal,
    pub status: String,
    pub paid_date: Option<DateTime<FixedOffset>>,
    pub paid_amount: Option<Decimal>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

/// 分期付款还款请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PayInstallmentRequest {
    pub detail_id: String,
    pub paid_amount: Decimal,
    pub paid_date: Option<DateTime<FixedOffset>>,
}

/// 分期付款状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum InstallmentStatus {
    #[serde(rename = "ACTIVE")]
    Active,
    #[serde(rename = "COMPLETED")]
    Completed,
    #[serde(rename = "CANCELLED")]
    Cancelled,
}

/// 分期明细状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum InstallmentDetailStatus {
    #[serde(rename = "PENDING")]
    Pending,
    #[serde(rename = "PAID")]
    Paid,
    #[serde(rename = "OVERDUE")]
    Overdue,
}

impl std::fmt::Display for InstallmentStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InstallmentStatus::Active => write!(f, "ACTIVE"),
            InstallmentStatus::Completed => write!(f, "COMPLETED"),
            InstallmentStatus::Cancelled => write!(f, "CANCELLED"),
        }
    }
}

impl std::fmt::Display for InstallmentDetailStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InstallmentDetailStatus::Pending => write!(f, "PENDING"),
            InstallmentDetailStatus::Paid => write!(f, "PAID"),
            InstallmentDetailStatus::Overdue => write!(f, "OVERDUE"),
        }
    }
}
