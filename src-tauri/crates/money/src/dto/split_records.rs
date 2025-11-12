use chrono::{DateTime, FixedOffset, NaiveDate};
use common::utils::{date::DateUtils, uuid::McgUuid};
use common::paginations::Filter;
use sea_orm::prelude::Decimal;
use sea_orm::{ActiveValue::{self, Set}, Condition};
use serde::{Deserialize, Serialize};
use validator::Validate;

/// 分摊记录响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordResponse {
    pub serial_num: String,
    pub transaction_serial_num: String,
    pub family_ledger_serial_num: String,
    pub split_rule_serial_num: Option<String>,
    pub payer_member_serial_num: String,
    pub owe_member_serial_num: String,
    pub total_amount: Decimal,
    pub split_amount: Decimal,
    pub split_percentage: Option<Decimal>,
    pub currency: String,
    pub status: String,
    pub split_type: String,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub confirmed_at: Option<DateTime<FixedOffset>>,
    pub paid_at: Option<DateTime<FixedOffset>>,
    pub due_date: Option<NaiveDate>,
    pub reminder_sent: bool,
    pub last_reminder_at: Option<DateTime<FixedOffset>>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
    // 关联信息
    pub payer_name: Option<String>,
    pub owe_member_name: Option<String>,
    pub transaction_description: Option<String>,
}

impl From<entity::split_records::Model> for SplitRecordResponse {
    fn from(model: entity::split_records::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            transaction_serial_num: model.transaction_serial_num,
            family_ledger_serial_num: model.family_ledger_serial_num,
            split_rule_serial_num: model.split_rule_serial_num,
            payer_member_serial_num: model.payer_member_serial_num,
            owe_member_serial_num: model.owe_member_serial_num,
            total_amount: model.total_amount,
            split_amount: model.split_amount,
            split_percentage: model.split_percentage,
            currency: model.currency,
            status: model.status,
            split_type: model.split_type,
            description: model.description,
            notes: model.notes,
            confirmed_at: model.confirmed_at,
            paid_at: model.paid_at,
            due_date: model.due_date,
            reminder_sent: model.reminder_sent,
            last_reminder_at: model.last_reminder_at,
            created_at: model.created_at,
            updated_at: model.updated_at,
            // 关联信息需要在服务层填充
            payer_name: None,
            owe_member_name: None,
            transaction_description: None,
        }
    }
}

/// 创建分摊记录请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordCreate {
    #[validate(length(min = 1, message = "交易ID不能为空"))]
    pub transaction_serial_num: String,
    
    pub split_rule_serial_num: Option<String>,
    
    #[validate(length(min = 1, message = "付款人ID不能为空"))]
    pub payer_member_serial_num: String,
    
    #[validate(length(min = 1, message = "欠款人ID不能为空"))]
    pub owe_member_serial_num: String,
    
    pub total_amount: Decimal,
    
    pub split_amount: Decimal,
    
    pub split_percentage: Option<Decimal>,
    
    #[validate(length(min = 1, max = 3, message = "货币代码长度必须为3位"))]
    pub currency: String,
    
    #[validate(length(min = 1, message = "分摊类型不能为空"))]
    pub split_type: String,
    
    #[validate(length(max = 500, message = "描述长度不能超过500字符"))]
    pub description: Option<String>,
    
    pub notes: Option<String>,
    pub due_date: Option<NaiveDate>,
}

/// 更新分摊记录请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordUpdate {
    pub split_amount: Option<Decimal>,
    pub split_percentage: Option<Decimal>,
    pub status: Option<String>,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub due_date: Option<NaiveDate>,
}

/// 确认分摊记录请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordConfirm {
    pub serial_nums: Vec<String>,
    pub notes: Option<String>,
}

/// 支付分摊记录请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordPayment {
    pub serial_nums: Vec<String>,
    pub payment_method: Option<String>,
    pub notes: Option<String>,
}

impl TryFrom<SplitRecordCreate> for entity::split_records::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: SplitRecordCreate) -> Result<Self, Self::Error> {
        request.validate()?;
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        Ok(entity::split_records::ActiveModel {
            serial_num: Set(serial_num),
            transaction_serial_num: Set(request.transaction_serial_num),
            family_ledger_serial_num: ActiveValue::NotSet, // 需要在服务层设置
            split_rule_serial_num: Set(request.split_rule_serial_num),
            payer_member_serial_num: Set(request.payer_member_serial_num),
            owe_member_serial_num: Set(request.owe_member_serial_num),
            total_amount: Set(request.total_amount),
            split_amount: Set(request.split_amount),
            split_percentage: Set(request.split_percentage),
            currency: Set(request.currency),
            status: Set("Pending".to_string()),
            split_type: Set(request.split_type),
            description: Set(request.description),
            notes: Set(request.notes),
            confirmed_at: Set(None),
            paid_at: Set(None),
            due_date: Set(request.due_date),
            reminder_sent: Set(false),
            last_reminder_at: Set(None),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl SplitRecordUpdate {
    pub fn apply_to_model(self, model: &mut entity::split_records::ActiveModel) {
        let now = DateUtils::local_now();

        if let Some(split_amount) = self.split_amount {
            model.split_amount = Set(split_amount);
        }
        if let Some(split_percentage) = self.split_percentage {
            model.split_percentage = Set(Some(split_percentage));
        }
        if let Some(status) = self.status {
            model.status = Set(status);
        }
        if let Some(description) = self.description {
            model.description = Set(Some(description));
        }
        if let Some(notes) = self.notes {
            model.notes = Set(Some(notes));
        }
        if let Some(due_date) = self.due_date {
            model.due_date = Set(Some(due_date));
        }

        model.updated_at = Set(Some(now));
    }
}

/// 分摊记录查询参数
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordQuery {
    pub family_ledger_serial_num: Option<String>,
    pub transaction_serial_num: Option<String>,
    pub payer_member_serial_num: Option<String>,
    pub owe_member_serial_num: Option<String>,
    pub status: Option<String>,
    pub split_type: Option<String>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

/// 分摊统计响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordStats {
    pub total_records: i64,
    pub pending_records: i64,
    pub confirmed_records: i64,
    pub paid_records: i64,
    pub total_amount: Decimal,
    pub pending_amount: Decimal,
    pub paid_amount: Decimal,
}

/// 成员分摊汇总 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberSplitSummary {
    pub member_serial_num: String,
    pub member_name: String,
    pub total_paid: Decimal,
    pub total_owed: Decimal,
    pub net_balance: Decimal,
    pub pending_amount: Decimal,
}

// Filter trait 实现
impl Filter<entity::split_records::Entity> for SplitRecordCreate {
    fn to_condition(&self) -> Condition {
        Condition::all() // 创建 DTO 不需要过滤条件
    }
}
