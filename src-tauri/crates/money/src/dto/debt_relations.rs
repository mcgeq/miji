use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use common::paginations::Filter;
use sea_orm::prelude::Decimal;
use sea_orm::{ActiveValue::{self, Set}, Condition};
use serde::{Deserialize, Serialize};
use validator::Validate;

/// 债务关系响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtRelationResponse {
    pub serial_num: String,
    pub family_ledger_serial_num: String,
    pub creditor_member_serial_num: String,
    pub debtor_member_serial_num: String,
    pub amount: Decimal,
    pub currency: String,
    pub status: String,
    pub last_updated_by: String,
    pub last_calculated_at: DateTime<FixedOffset>,
    pub settled_at: Option<DateTime<FixedOffset>>,
    pub notes: Option<String>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
    // 关联信息
    pub creditor_name: Option<String>,
    pub debtor_name: Option<String>,
}

impl From<entity::debt_relations::Model> for DebtRelationResponse {
    fn from(model: entity::debt_relations::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            family_ledger_serial_num: model.family_ledger_serial_num,
            creditor_member_serial_num: model.creditor_member_serial_num,
            debtor_member_serial_num: model.debtor_member_serial_num,
            amount: model.amount,
            currency: model.currency,
            status: model.status,
            last_updated_by: model.last_updated_by,
            last_calculated_at: model.last_calculated_at,
            settled_at: model.settled_at,
            notes: model.notes,
            created_at: model.created_at,
            updated_at: model.updated_at,
            // 关联信息需要在服务层填充
            creditor_name: None,
            debtor_name: None,
        }
    }
}

/// 创建债务关系请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct DebtRelationCreate {
    #[validate(length(min = 1, message = "债权人ID不能为空"))]
    pub creditor_member_serial_num: String,
    
    #[validate(length(min = 1, message = "债务人ID不能为空"))]
    pub debtor_member_serial_num: String,
    
    pub amount: Decimal,
    
    #[validate(length(min = 1, max = 3, message = "货币代码长度必须为3位"))]
    pub currency: String,
    
    pub notes: Option<String>,
}

/// 更新债务关系请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct DebtRelationUpdate {
    pub amount: Option<Decimal>,
    pub status: Option<String>,
    pub notes: Option<String>,
}

/// 结算债务请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtSettlement {
    pub debt_serial_nums: Vec<String>,
    pub settlement_method: Option<String>,
    pub notes: Option<String>,
}

impl TryFrom<DebtRelationCreate> for entity::debt_relations::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: DebtRelationCreate) -> Result<Self, Self::Error> {
        request.validate()?;
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        Ok(entity::debt_relations::ActiveModel {
            serial_num: Set(serial_num),
            family_ledger_serial_num: ActiveValue::NotSet, // 需要在服务层设置
            creditor_member_serial_num: Set(request.creditor_member_serial_num),
            debtor_member_serial_num: Set(request.debtor_member_serial_num),
            amount: Set(request.amount),
            currency: Set(request.currency),
            status: Set("Active".to_string()),
            last_updated_by: ActiveValue::NotSet, // 需要在服务层设置
            last_calculated_at: Set(now),
            settled_at: Set(None),
            notes: Set(request.notes),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl DebtRelationUpdate {
    pub fn apply_to_model(self, model: &mut entity::debt_relations::ActiveModel) {
        let now = DateUtils::local_now();

        if let Some(amount) = self.amount {
            model.amount = Set(amount);
        }
        if let Some(status) = self.status {
            model.status = Set(status.clone());
            if status == "Settled" {
                model.settled_at = Set(Some(now));
            }
        }
        if let Some(notes) = self.notes {
            model.notes = Set(Some(notes));
        }

        model.last_calculated_at = Set(now);
        model.updated_at = Set(Some(now));
    }
}

/// 债务关系查询参数
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct DebtRelationQuery {
    pub family_ledger_serial_num: Option<String>,
    pub creditor_member_serial_num: Option<String>,
    pub debtor_member_serial_num: Option<String>,
    pub status: Option<String>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}

/// 债务统计响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtStats {
    pub total_debts: i64,
    pub active_debts: i64,
    pub settled_debts: i64,
    pub total_amount: Decimal,
    pub active_amount: Decimal,
    pub settled_amount: Decimal,
}

/// 成员债务汇总 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberDebtSummary {
    pub member_serial_num: String,
    pub member_name: String,
    pub total_credit: Decimal,  // 作为债权人的总金额
    pub total_debt: Decimal,    // 作为债务人的总金额
    pub net_balance: Decimal,   // 净余额 (credit - debt)
    pub active_credits: i64,
    pub active_debts: i64,
}

/// 债务关系图谱节点 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtGraphNode {
    pub member_serial_num: String,
    pub member_name: String,
    pub avatar_url: Option<String>,
    pub color: Option<String>,
    pub net_balance: Decimal,
}

/// 债务关系图谱边 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtGraphEdge {
    pub from_member: String,
    pub to_member: String,
    pub amount: Decimal,
    pub currency: String,
    pub status: String,
}

/// 债务关系图谱 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtGraph {
    pub nodes: Vec<DebtGraphNode>,
    pub edges: Vec<DebtGraphEdge>,
    pub total_amount: Decimal,
    pub currency: String,
}

// Filter trait 实现
impl Filter<entity::debt_relations::Entity> for DebtRelationCreate {
    fn to_condition(&self) -> Condition {
        Condition::all() // 创建 DTO 不需要过滤条件
    }
}
