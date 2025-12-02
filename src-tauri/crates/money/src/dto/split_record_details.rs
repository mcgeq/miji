use chrono::{DateTime, FixedOffset};
use common::utils::{date::DateUtils, uuid::McgUuid};
use sea_orm::prelude::Decimal;
use sea_orm::ActiveValue::Set;
use serde::{Deserialize, Serialize};
use validator::Validate;

/// 分摊记录明细响应 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordDetailResponse {
    pub serial_num: String,
    pub split_record_serial_num: String,
    pub member_serial_num: String,
    pub member_name: Option<String>, // 从关联查询获取
    pub amount: Decimal,
    pub percentage: Option<Decimal>,
    pub weight: Option<i32>,
    pub is_paid: bool,
    pub paid_at: Option<DateTime<FixedOffset>>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl From<entity::split_record_details::Model> for SplitRecordDetailResponse {
    fn from(model: entity::split_record_details::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            split_record_serial_num: model.split_record_serial_num,
            member_serial_num: model.member_serial_num,
            member_name: None, // 需要在服务层填充
            amount: model.amount,
            percentage: model.percentage,
            weight: model.weight,
            is_paid: model.is_paid,
            paid_at: model.paid_at,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

/// 创建分摊记录明细请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordDetailCreate {
    #[validate(length(min = 1, message = "成员ID不能为空"))]
    pub member_serial_num: String,
    
    pub member_name: String, // 用于显示，不存储
    
    pub amount: Decimal,
    
    pub percentage: Option<Decimal>,
    
    pub weight: Option<i32>,
    
    pub is_paid: bool,
}

/// 更新分摊记录明细请求 DTO
#[derive(Debug, Clone, Serialize, Deserialize, Validate, Default)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordDetailUpdate {
    pub amount: Option<Decimal>,
    pub percentage: Option<Decimal>,
    pub weight: Option<i32>,
    pub is_paid: Option<bool>,
    pub paid_at: Option<DateTime<FixedOffset>>,
}

impl SplitRecordDetailCreate {
    /// 转换为ActiveModel
    pub fn to_active_model(
        &self,
        split_record_serial_num: String,
    ) -> entity::split_record_details::ActiveModel {
        let now = DateUtils::local_now();
        let serial_num = McgUuid::uuid(38);

        entity::split_record_details::ActiveModel {
            serial_num: Set(serial_num),
            split_record_serial_num: Set(split_record_serial_num),
            member_serial_num: Set(self.member_serial_num.clone()),
            amount: Set(self.amount),
            percentage: Set(self.percentage),
            weight: Set(self.weight),
            is_paid: Set(self.is_paid),
            paid_at: Set(if self.is_paid { Some(now) } else { None }),
            created_at: Set(now),
            updated_at: Set(None),
        }
    }
}

impl SplitRecordDetailUpdate {
    pub fn apply_to_model(self, model: &mut entity::split_record_details::ActiveModel) {
        let now = DateUtils::local_now();

        if let Some(amount) = self.amount {
            model.amount = Set(amount);
        }
        if let Some(percentage) = self.percentage {
            model.percentage = Set(Some(percentage));
        }
        if let Some(weight) = self.weight {
            model.weight = Set(Some(weight));
        }
        if let Some(is_paid) = self.is_paid {
            model.is_paid = Set(is_paid);
            if is_paid && model.paid_at.as_ref() == &None {
                model.paid_at = Set(Some(now));
            } else if !is_paid {
                model.paid_at = Set(None);
            }
        }
        if let Some(paid_at) = self.paid_at {
            model.paid_at = Set(Some(paid_at));
        }

        model.updated_at = Set(Some(now));
    }
}

/// 完整的分摊记录（包含主记录和明细）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordWithDetails {
    pub serial_num: String,
    pub transaction_serial_num: String,
    pub family_ledger_serial_num: String,
    pub rule_type: String,
    pub total_amount: Decimal,
    pub currency: String,
    pub payer_member_serial_num: Option<String>,
    pub payer_member_name: Option<String>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
    pub details: Vec<SplitRecordDetailResponse>,
}

/// 创建完整的分摊记录请求
#[derive(Debug, Clone, Serialize, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordWithDetailsCreate {
    #[validate(length(min = 1, message = "交易ID不能为空"))]
    pub transaction_serial_num: String,
    
    #[validate(length(min = 1, message = "账本ID不能为空"))]
    pub family_ledger_serial_num: String,
    
    #[validate(length(min = 1, message = "分摊类型不能为空"))]
    pub rule_type: String, // EQUAL, PERCENTAGE, FIXED_AMOUNT, WEIGHTED
    
    pub total_amount: Decimal,
    
    #[validate(length(min = 1, max = 3, message = "货币代码长度必须为3位"))]
    pub currency: String,
    
    pub payer_member_serial_num: Option<String>,
    
    #[validate(length(min = 1, message = "分摊明细不能为空"))]
    pub details: Vec<SplitRecordDetailCreate>,
}

impl SplitRecordWithDetailsCreate {
    /// 验证分摊配置的合法性
    pub fn validate_split_logic(&self) -> Result<(), String> {
        if self.details.is_empty() {
            return Err("分摊成员不能为空".to_string());
        }

        match self.rule_type.as_str() {
            "EQUAL" => {
                // 均摊：所有金额应该相等（允许误差）
                let expected = self.total_amount / Decimal::from(self.details.len());
                for detail in &self.details {
                    if (detail.amount - expected).abs() > Decimal::from_f64_retain(0.01).unwrap() {
                        return Err(format!(
                            "均摊金额不均等: 期望{}, 实际{}",
                            expected, detail.amount
                        ));
                    }
                }
            }
            "PERCENTAGE" => {
                // 百分比：总和必须为100%
                let total_percentage: Decimal = self
                    .details
                    .iter()
                    .filter_map(|d| d.percentage)
                    .sum();
                if (total_percentage - Decimal::from(100)).abs()
                    > Decimal::from_f64_retain(0.01).unwrap()
                {
                    return Err(format!("比例总和必须为100%，当前为{}%", total_percentage));
                }
                
                // 验证金额计算正确性
                for detail in &self.details {
                    if let Some(percentage) = detail.percentage {
                        let expected = self.total_amount * percentage / Decimal::from(100);
                        if (detail.amount - expected).abs() > Decimal::from_f64_retain(0.01).unwrap() {
                            return Err(format!(
                                "比例金额计算错误: 期望{}, 实际{}",
                                expected, detail.amount
                            ));
                        }
                    }
                }
            }
            "FIXED_AMOUNT" => {
                // 固定金额：总和必须等于交易金额
                let calculated: Decimal = self.details.iter().map(|d| d.amount).sum();
                if (self.total_amount - calculated).abs() > Decimal::from_f64_retain(0.01).unwrap() {
                    return Err(format!(
                        "固定金额总和({})必须等于交易金额({})",
                        calculated, self.total_amount
                    ));
                }
            }
            "WEIGHTED" => {
                // 权重：验证权重总和大于0
                let total_weight: i32 = self.details.iter().filter_map(|d| d.weight).sum();
                if total_weight <= 0 {
                    return Err("权重总和必须大于0".to_string());
                }
                
                // 验证金额计算正确性
                for detail in &self.details {
                    if let Some(weight) = detail.weight {
                        let expected = self.total_amount * Decimal::from(weight)
                            / Decimal::from(total_weight);
                        if (detail.amount - expected).abs() > Decimal::from_f64_retain(0.01).unwrap() {
                            return Err(format!(
                                "权重金额计算错误: 期望{}, 实际{}",
                                expected, detail.amount
                            ));
                        }
                    }
                }
            }
            _ => {
                return Err(format!("不支持的分摊类型: {}", self.rule_type));
            }
        }

        Ok(())
    }
}

/// 分摊记录统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordStatistics {
    pub total_members: usize,
    pub paid_members: usize,
    pub unpaid_members: usize,
    pub total_amount: Decimal,
    pub paid_amount: Decimal,
    pub unpaid_amount: Decimal,
    pub paid_percentage: Decimal,
}

impl SplitRecordStatistics {
    pub fn from_details(details: &[SplitRecordDetailResponse]) -> Self {
        let total_members = details.len();
        let paid_members = details.iter().filter(|d| d.is_paid).count();
        let unpaid_members = total_members - paid_members;
        
        let paid_amount: Decimal = details
            .iter()
            .filter(|d| d.is_paid)
            .map(|d| d.amount)
            .sum();
        
        let total_amount: Decimal = details.iter().map(|d| d.amount).sum();
        let unpaid_amount = total_amount - paid_amount;
        
        let paid_percentage = if total_amount > Decimal::ZERO {
            (paid_amount / total_amount) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        Self {
            total_members,
            paid_members,
            unpaid_members,
            total_amount,
            paid_amount,
            unpaid_amount,
            paid_percentage,
        }
    }
}

/// 分摊记录查询参数
#[derive(Debug, Clone, Serialize, Deserialize, Default, Validate)]
#[serde(rename_all = "camelCase")]
pub struct SplitRecordWithDetailsQuery {
    pub family_ledger_serial_num: Option<String>,
    pub transaction_serial_num: Option<String>,
    pub member_serial_num: Option<String>, // 查询参与的成员
    pub rule_type: Option<String>,
    pub status: Option<String>, // all, pending(有未支付), completed(全部已支付)
    pub payer_member_serial_num: Option<String>,
    pub page: Option<u64>,
    pub page_size: Option<u64>,
}
