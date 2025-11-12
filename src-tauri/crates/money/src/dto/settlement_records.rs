use chrono::{DateTime, FixedOffset, NaiveDate};
use common::utils::{date::DateUtils, uuid::McgUuid};
use sea_orm::prelude::Decimal;
use sea_orm::ActiveValue::{self, Set};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use validator::Validate;

/// 结算记录响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettlementRecordResponse {
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub settlement_type: String,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    pub total_amount: Decimal,
    pub currency: String,
    pub participant_members: JsonValue,
    pub settlement_details: JsonValue,
    pub optimized_transfers: Option<JsonValue>,
    pub status: String,
    pub initiated_by: String,
    pub completed_by: Option<String>,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub completed_at: Option<DateTime<FixedOffset>>,
    pub cancelled_at: Option<DateTime<FixedOffset>>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
    // 关联信息
    pub initiated_by_name: Option<String>,
    pub completed_by_name: Option<String>,
}

impl From<entity::settlement_records::Model> for SettlementRecordResponse {
    fn from(model: entity::settlement_records::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            family_ledger_serial_num: model.family_ledger_serial_num,
            settlement_type: model.settlement_type,
            period_start: model.period_start,
            period_end: model.period_end,
            total_amount: model.total_amount,
            currency: model.currency,
            participant_members: model.participant_members,
            settlement_details: model.settlement_details,
            optimized_transfers: model.optimized_transfers,
            status: model.status,
            initiated_by: model.initiated_by,
            completed_by: model.completed_by,
            description: model.description,
            notes: model.notes,
            completed_at: model.completed_at,
            cancelled_at: model.cancelled_at,
            created_at: model.created_at,
            updated_at: model.updated_at,
            // 关联信息需要在服务层填充
            initiated_by_name: None,
            completed_by_name: None,
        }
    }
}

/// 创建结算记录请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SettlementRecordCreate {
    #[validate(length(min = 1, message = "结算类型不能为空"))]
    pub settlement_type: String,
    
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    
    #[validate(range(min = 0.0, message = "结算金额不能为负数"))]
    pub total_amount: Decimal,
    
    #[validate(length(min = 1, max = 3, message = "货币代码长度必须为3位"))]
    pub currency: String,
    
    pub participant_members: JsonValue,
    pub settlement_details: JsonValue,
    pub optimized_transfers: Option<JsonValue>,
    
    #[validate(length(max = 500, message = "描述长度不能超过500字符"))]
    pub description: Option<String>,
    
    pub notes: Option<String>,
}

/// 更新结算记录请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct SettlementRecordUpdate {
    pub status: Option<String>,
    pub optimized_transfers: Option<JsonValue>,
    pub description: Option<String>,
    pub notes: Option<String>,
}

/// 完成结算请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CompleteSettlement {
    pub settlement_serial_num: String,
    pub completion_notes: Option<String>,
}

/// 取消结算请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CancelSettlement {
    pub settlement_serial_num: String,
    pub cancellation_reason: Option<String>,
}

impl TryFrom<SettlementRecordCreate> for entity::settlement_records::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: SettlementRecordCreate) -> Result<Self, Self::Error> {
        request.validate()?;
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        Ok(entity::settlement_records::ActiveModel {
            serial_num: Set(serial_num),
            family_ledger_serial_num: ActiveValue::NotSet, // 需要在服务层设置
            settlement_type: Set(request.settlement_type),
            period_start: Set(request.period_start),
            period_end: Set(request.period_end),
            total_amount: Set(request.total_amount),
            currency: Set(request.currency),
            participant_members: Set(request.participant_members),
            settlement_details: Set(request.settlement_details),
            optimized_transfers: Set(request.optimized_transfers),
            status: Set("Pending".to_string()),
            initiated_by: ActiveValue::NotSet, // 需要在服务层设置
            completed_by: Set(None),
            description: Set(request.description),
            notes: Set(request.notes),
            completed_at: Set(None),
            cancelled_at: Set(None),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl SettlementRecordUpdate {
    pub fn apply_to_model(self, model: &mut entity::settlement_records::ActiveModel) {
        let now = DateUtils::local_now();

        if let Some(status) = self.status {
            model.status = Set(status.clone());
            if status == "Completed" {
                model.completed_at = Set(Some(now));
            } else if status == "Cancelled" {
                model.cancelled_at = Set(Some(now));
            }
        }
        if let Some(optimized_transfers) = self.optimized_transfers {
            model.optimized_transfers = Set(Some(optimized_transfers));
        }
        if let Some(description) = self.description {
            model.description = Set(Some(description));
        }
        if let Some(notes) = self.notes {
            model.notes = Set(Some(notes));
        }

        model.updated_at = Set(Some(now));
    }
}

/// 结算记录查询参数
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SettlementRecordQuery {
    pub family_ledger_serial_num: Option<String>,
    pub settlement_type: Option<String>,
    pub status: Option<String>,
    pub initiated_by: Option<String>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

/// 结算统计响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettlementStats {
    pub total_settlements: i64,
    pub pending_settlements: i64,
    pub completed_settlements: i64,
    pub cancelled_settlements: i64,
    pub total_amount: Decimal,
    pub completed_amount: Decimal,
}

/// 结算详情项 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettlementDetailItem {
    pub member_serial_num: String,
    pub member_name: String,
    pub total_paid: Decimal,
    pub total_owed: Decimal,
    pub net_balance: Decimal,
    pub transactions_count: i64,
}

/// 优化转账建议 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OptimizedTransfer {
    pub from_member: String,
    pub from_member_name: String,
    pub to_member: String,
    pub to_member_name: String,
    pub amount: Decimal,
    pub currency: String,
    pub description: Option<String>,
}

/// 结算建议响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SettlementSuggestion {
    pub family_ledger_serial_num: String,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    pub total_amount: Decimal,
    pub currency: String,
    pub participant_count: i32,
    pub settlement_details: Vec<SettlementDetailItem>,
    pub optimized_transfers: Vec<OptimizedTransfer>,
    pub transfer_count: i32,
    pub estimated_savings: Decimal, // 相比直接转账节省的次数
}

/// 自动结算配置 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AutoSettlementConfig {
    pub enabled: bool,
    pub settlement_cycle: String, // Weekly, Monthly, Quarterly
    pub min_amount_threshold: Decimal,
    pub auto_execute: bool, // 是否自动执行，还是仅生成建议
    pub notification_enabled: bool,
    pub notification_days_before: i32,
}
