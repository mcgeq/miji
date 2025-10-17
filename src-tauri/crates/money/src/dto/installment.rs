use chrono::{DateTime, FixedOffset};
use common::utils::date::DateUtils;
use common::utils::uuid::McgUuid;
use sea_orm::Set;
use sea_orm::prelude::Decimal;
use serde::{Deserialize, Serialize};
use validator::Validate;

/// 分期付款计划创建请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentPlanCreate {
    #[validate(length(equal = 38, message = "transaction_serial_num is required"))]
    pub transaction_serial_num: String,
    #[validate(length(equal = 38, message = "account_serial_num is required"))]
    pub account_serial_num: String,
    #[validate(custom(function = "validate_positive_amount"))]
    pub total_amount: Decimal,
    pub total_periods: i32,
    #[validate(custom(function = "validate_positive_amount"))]
    pub installment_amount: Decimal,
    pub first_due_date: DateTime<FixedOffset>,
}

/// 分期付款计划更新请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentPlanUpdate {
    pub status: Option<String>,
}

/// 分期付款计划响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentPlanResponse {
    pub serial_num: String,
    pub transaction_serial_num: String,
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
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentDetailCreate {
    #[validate(length(equal = 1, message = "plan_serial_num is required"))]
    pub plan_serial_num: String,
    #[validate(length(equal = 38, message = "account_serial_num is required"))]
    pub account_serial_num: String,
    #[validate(range(min = 1, message = "period_number must be greater than zero"))]
    pub period_number: i32,
    pub due_date: DateTime<FixedOffset>,
    #[validate(custom(function = "validate_positive_amount"))]
    pub amount: Decimal,
}

/// 分期付款明细更新请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentDetailUpdate {
    pub status: Option<String>,
    pub paid_date: Option<DateTime<FixedOffset>>,
    #[validate(custom(function = "validate_positive_amount"))]
    pub paid_amount: Option<Decimal>,
}

/// 分期付款明细响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentDetailResponse {
    pub serial_num: String,
    pub plan_serial_num: String,
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
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct PayInstallmentCreate {
    #[validate(length(min = 1, message = "detail_serial_num is required"))]
    pub detail_serial_num: String,
    #[validate(custom(function = "validate_positive_amount"))]
    pub paid_amount: Decimal,
    pub paid_date: Option<DateTime<FixedOffset>>,
}

/// 分期付款计划查询请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentPlanQuery {
    pub transaction_serial_num: Option<String>,
    pub status: Option<String>,
    pub start_date: Option<DateTime<FixedOffset>>,
    pub end_date: Option<DateTime<FixedOffset>>,
}

/// 分期明细查询请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentDetailQuery {
    pub plan_serial_num: Option<String>,
    pub status: Option<String>,
    pub due_date_from: Option<DateTime<FixedOffset>>,
    pub due_date_to: Option<DateTime<FixedOffset>>,
}

/// 分期金额计算请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
pub struct InstallmentCalculationRequest {
    #[validate(custom(function = "validate_positive_amount"))]
    pub total_amount: Decimal,
    #[validate(range(min = 1, message = "total_periods must be greater than zero"))]
    pub total_periods: i32,
    pub first_due_date: DateTime<FixedOffset>,
}

/// 分期金额计算响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentCalculationResponse {
    pub installment_amount: Decimal,
    pub details: Vec<InstallmentCalculationDetail>,
}

/// 分期计算明细
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallmentCalculationDetail {
    pub period: i32,
    pub amount: Decimal,
    pub due_date: DateTime<FixedOffset>,
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

// From implementations for ActiveModel conversion
impl TryFrom<InstallmentPlanCreate> for entity::installment_plans::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(data: InstallmentPlanCreate) -> Result<Self, Self::Error> {
        data.validate()?;
        let now = DateUtils::local_now();
        Ok(entity::installment_plans::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            transaction_serial_num: Set(data.transaction_serial_num),
            account_serial_num: Set(data.account_serial_num),
            total_amount: Set(data.total_amount),
            total_periods: Set(data.total_periods),
            installment_amount: Set(data.installment_amount),
            first_due_date: Set(data.first_due_date),
            status: Set(InstallmentStatus::Active.to_string()),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl TryFrom<InstallmentPlanUpdate> for entity::installment_plans::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(value: InstallmentPlanUpdate) -> Result<Self, Self::Error> {
        value.validate()?;
        // 获取当前时间
        let now = DateUtils::local_now();

        let mut model = entity::installment_plans::ActiveModel {
            ..Default::default()
        };
        if let Some(status) = value.status {
            model.status = Set(status);
        }

        model.updated_at = Set(Some(now));

        Ok(model)
    }
}

// 分期明细的 TryFrom 实现
impl TryFrom<InstallmentDetailCreate> for entity::installment_details::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(data: InstallmentDetailCreate) -> Result<Self, Self::Error> {
        data.validate()?;
        let now = DateUtils::local_now();
        Ok(entity::installment_details::ActiveModel {
            serial_num: Set(McgUuid::uuid(38)),
            plan_serial_num: Set(data.plan_serial_num),
            account_serial_num: Set(data.account_serial_num),
            period_number: Set(data.period_number),
            due_date: Set(data.due_date),
            amount: Set(data.amount),
            status: Set(InstallmentDetailStatus::Pending.to_string()),
            paid_date: Set(None),
            paid_amount: Set(None),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl TryFrom<InstallmentDetailUpdate> for entity::installment_details::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(data: InstallmentDetailUpdate) -> Result<Self, Self::Error> {
        data.validate()?;
        let now = DateUtils::local_now();

        let mut model = entity::installment_details::ActiveModel {
            ..Default::default()
        };

        if let Some(status) = data.status {
            model.status = Set(status);
        }
        if let Some(paid_date) = data.paid_date {
            model.paid_date = Set(Some(paid_date));
        }
        if let Some(paid_amount) = data.paid_amount {
            model.paid_amount = Set(Some(paid_amount));
        }

        model.updated_at = Set(Some(now));

        Ok(model)
    }
}

// 验证金额必须为正数
fn validate_positive_amount(amount: &Decimal) -> Result<(), validator::ValidationError> {
    if *amount <= Decimal::ZERO {
        return Err(validator::ValidationError::new("amount_must_be_positive"));
    }
    Ok(())
}
