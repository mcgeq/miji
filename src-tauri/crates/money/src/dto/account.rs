use std::{fmt, str::FromStr};

use chrono::{DateTime, FixedOffset};
use common::{
    error::AppError,
    utils::{date::DateUtils, uuid::McgUuid},
};
use entity::account;
use sea_orm::{ActiveValue::Set, FromQueryResult, prelude::Decimal};
use serde::{Deserialize, Serialize};
use validator::{Validate, ValidationError};

use crate::dto::currency::CurrencyResponse;

#[derive(Debug, Clone, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct AccountCreate {
    #[validate(length(min = 1, max = 100, message = "账户名称长度必须在1-100字符之间"))]
    pub name: String,
    #[validate(length(max = 1000, message = "描述长度不能超过1000字符"))]
    pub description: String,
    #[validate(length(min = 1, max = 50, message = "账户类型长度必须在1-50字符之间"))]
    pub r#type: String,
    #[validate(custom(function = "validate_non_negative_amount", message = "金额必须非负数"))]
    pub initial_balance: Decimal,
    #[validate(length(min = 3, max = 3, message = "货币代码必须是3个字符"))]
    pub currency: String,
    #[validate(required(message = "是否共享必须指定"))]
    pub is_shared: Option<bool>,
    #[validate(length(max = 38, message = "所有者ID长度不能超过38字符"))]
    pub owner_id: Option<String>,
    #[validate(length(max = 7, message = "颜色代码长度不能超过7字符"))]
    pub color: Option<String>,
    pub is_virtual: Option<bool>,
}

#[derive(Debug, Clone, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct AccountUpdate {
    #[validate(custom(function = "validate_non_negative_amount", message = "金额必须非负数"))]
    pub initial_balance: Option<Decimal>,
    #[validate(length(min = 1, max = 100, message = "账户名称长度必须在1-100字符之间"))]
    pub name: Option<String>,
    #[validate(length(max = 1000, message = "描述长度不能超过1000字符"))]
    pub description: Option<String>,
    #[validate(length(min = 1, max = 50, message = "账户类型长度必须在1-50字符之间"))]
    pub r#type: Option<String>,
    #[validate(length(min = 3, max = 3, message = "货币代码必须是3个字符"))]
    pub currency: Option<String>,
    pub is_shared: Option<bool>,
    #[validate(length(max = 38, message = "所有者ID长度不能超过38字符"))]
    pub owner_id: Option<String>,
    #[validate(length(max = 7, message = "颜色代码长度不能超过7字符"))]
    pub color: Option<String>,
    pub is_active: Option<bool>,
    pub is_virtual: Option<bool>,
}

/// 资产汇总统计结果
#[derive(Debug, Deserialize, Serialize, FromQueryResult)]
#[serde(rename_all = "camelCase")]
pub struct AccountBalanceSummary {
    #[sea_orm(alias = "bank_savings_balance")]
    pub bank_savings_balance: Decimal, // 银行/储蓄余额
    #[sea_orm(alias = "cash_balance")]
    pub cash_balance: Decimal, // 现金余额
    #[sea_orm(alias = "credit_card_balance")]
    pub credit_card_balance: Decimal, // 信用卡余额（绝对值）
    #[sea_orm(alias = "investment_balance")]
    pub investment_balance: Decimal, // 投资余额
    #[sea_orm(alias = "alipay_balance")]
    pub alipay_balance: Decimal, // 支付宝余额
    #[sea_orm(alias = "wechat_balance")]
    pub wechat_balance: Decimal, // 微信余额
    #[sea_orm(alias = "cloud_quick_pass_balance")]
    pub cloud_quick_pass_balance: Decimal, // 云闪付余额
    #[sea_orm(alias = "other_balance")]
    pub other_balance: Decimal, // 其他余额
    #[sea_orm(alias = "total_balance")]
    pub total_balance: Decimal, // 总余额
    #[sea_orm(alias = "adjusted_net_worth")]
    pub adjusted_net_worth: Decimal, // 调整后净资产（信用卡负向计算）
    #[sea_orm(alias = "total_assets")]
    pub total_assets: Decimal, // 总资产（不含信用卡）
}

impl Default for AccountBalanceSummary {
    fn default() -> Self {
        Self {
            bank_savings_balance: Decimal::ZERO,
            cash_balance: Decimal::ZERO,
            credit_card_balance: Decimal::ZERO,
            investment_balance: Decimal::ZERO,
            alipay_balance: Decimal::ZERO,
            wechat_balance: Decimal::ZERO,
            cloud_quick_pass_balance: Decimal::ZERO,
            other_balance: Decimal::ZERO,
            total_balance: Decimal::ZERO,
            adjusted_net_worth: Decimal::ZERO,
            total_assets: Decimal::ZERO,
        }
    }
}

/// 简单的账户响应（不包含关联信息）
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct AccountResponse {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub r#type: String,
    pub balance: Decimal,
    pub initial_balance: Decimal,
    pub currency: String,
    /// 币种详细信息（包含符号、区域等）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub currency_detail: Option<CurrencyResponse>,
    pub is_shared: Option<bool>,
    pub owner_id: Option<String>,
    pub color: Option<String>,
    pub is_active: bool,
    pub is_virtual: bool,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

impl From<entity::account::Model> for AccountResponse {
    fn from(model: entity::account::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            name: model.name,
            description: model.description,
            r#type: model.r#type,
            balance: model.balance,
            initial_balance: model.initial_balance,
            currency: model.currency,
            currency_detail: None, // 在 service 层填充
            is_shared: model.is_shared,
            owner_id: model.owner_id,
            color: model.color,
            is_active: model.is_active,
            is_virtual: model.is_virtual,
            created_at: model.created_at,
            updated_at: model.updated_at,
        }
    }
}

/// 包含完整关联信息的账户响应
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct AccountResponseWithRelations {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub r#type: String,
    pub balance: Decimal,
    pub initial_balance: Decimal,
    pub currency: CurrencyResponse,
    pub is_shared: Option<bool>,
    pub owner_id: Option<String>,
    pub owner: Option<OwnerInfo>,
    pub color: Option<String>,
    pub is_active: bool,
    pub is_virtual: bool,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}

/// 所有者信息
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct OwnerInfo {
    pub serial_num: String,
    pub name: String,
    pub role: Option<String>,
}

/// ---------------------------------------------
/// 账户关联结构
/// ---------------------------------------------
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountWithRelations {
    pub account: entity::account::Model,
    pub currency: entity::currency::Model,
    pub owner: Option<entity::family_member::Model>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccountType {
    Savings,
    Bank,
    Cash,
    CreditCard,
    Investment,
    Alipay,
    WeChat,
    CloudQuickPass,
    Other,
}

impl AsRef<str> for AccountType {
    fn as_ref(&self) -> &str {
        match self {
            AccountType::Savings => "Savings",
            AccountType::Bank => "Bank",
            AccountType::Cash => "Cash",
            AccountType::CreditCard => "CreditCard",
            AccountType::Investment => "Investment",
            AccountType::Alipay => "Alipay",
            AccountType::WeChat => "WeChat",
            AccountType::CloudQuickPass => "CloudQuickPass",
            AccountType::Other => "Other",
        }
    }
}

impl fmt::Display for AccountType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_ref())
    }
}

impl FromStr for AccountType {
    type Err = AppError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Savings" => Ok(AccountType::Savings),
            "Bank" => Ok(AccountType::Bank),
            "Cash" => Ok(AccountType::Cash),
            "CreditCard" => Ok(AccountType::CreditCard),
            "Investment" => Ok(AccountType::Investment),
            "Alipay" => Ok(AccountType::Alipay),
            "WeChat" => Ok(AccountType::WeChat),
            "CloudQuickPass" => Ok(AccountType::CloudQuickPass),
            "Other" => Ok(AccountType::Other),
            _ => Err(AppError::simple(
                common::BusinessCode::MoneyInvalidAmount,
                format!("无效的账户类型: {}", s),
            )),
        }
    }
}

/// 实现从 AccountWithRelations 到 AccountResponseWithRelations 的转换
impl From<AccountWithRelations> for AccountResponseWithRelations {
    fn from(data: AccountWithRelations) -> Self {
        Self {
            serial_num: data.account.serial_num,
            name: data.account.name,
            description: data.account.description,
            r#type: data.account.r#type,
            balance: data.account.balance,
            initial_balance: data.account.initial_balance,
            currency: CurrencyResponse::from(data.currency),
            is_shared: data.account.is_shared,
            owner_id: data.account.owner_id,
            owner: data.owner.map(OwnerInfo::from),
            color: data.account.color,
            is_active: data.account.is_active,
            is_virtual: data.account.is_virtual,
            created_at: data.account.created_at,
            updated_at: data.account.updated_at,
        }
    }
}

/// 实现从 family_member model 到 OwnerInfo 的转换
impl From<entity::family_member::Model> for OwnerInfo {
    fn from(member: entity::family_member::Model) -> Self {
        Self {
            serial_num: member.serial_num,
            name: member.name,
            role: Some(member.role),
        }
    }
}

impl TryFrom<AccountCreate> for account::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(dto: AccountCreate) -> Result<Self, Self::Error> {
        dto.validate()?;
        // 生成唯一序列号
        let serial_num = McgUuid::uuid(38);

        // 获取当前时间
        let now = DateUtils::local_now();

        Ok(account::ActiveModel {
            serial_num: Set(serial_num),
            name: Set(dto.name),
            description: Set(Some(dto.description)),
            r#type: Set(dto.r#type),
            balance: Set(dto.initial_balance),
            initial_balance: Set(dto.initial_balance),
            currency: Set(dto.currency),
            is_shared: Set(dto.is_shared),
            owner_id: Set(dto.owner_id),
            color: Set(dto.color),
            is_active: Set(true), // 默认激活
            is_virtual: Set(dto.is_virtual.unwrap_or(false)), // 默认非虚拟账户
            created_at: Set(now),
            updated_at: Set(Some(now)),
        })
    }
}

impl TryFrom<AccountUpdate> for account::ActiveModel {
    type Error = validator::ValidationErrors;

    fn try_from(request: AccountUpdate) -> Result<Self, Self::Error> {
        // 验证 DTO
        request.validate()?;

        Ok(entity::account::ActiveModel {
            serial_num: sea_orm::ActiveValue::NotSet,
            name: request
                .name
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            description: request
                .description
                .map_or(sea_orm::ActiveValue::NotSet, |val| {
                    sea_orm::ActiveValue::Set(Some(val))
                }),
            r#type: request
                .r#type
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            balance: sea_orm::ActiveValue::NotSet, // 余额不能直接通过更新请求修改
            initial_balance: request
                .initial_balance
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            currency: request
                .currency
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            is_shared: request
                .is_shared
                .map_or(sea_orm::ActiveValue::NotSet, |val| {
                    sea_orm::ActiveValue::Set(Some(val))
                }),
            owner_id: match request.owner_id {
                Some(id) => sea_orm::ActiveValue::Set(Some(id)),
                None => sea_orm::ActiveValue::NotSet,
            },
            color: match request.color {
                Some(color) => sea_orm::ActiveValue::Set(Some(color)),
                None => sea_orm::ActiveValue::NotSet,
            },
            is_active: sea_orm::ActiveValue::NotSet,
            is_virtual: request
                .is_virtual
                .map_or(sea_orm::ActiveValue::NotSet, sea_orm::ActiveValue::Set),
            created_at: sea_orm::ActiveValue::NotSet,
            updated_at: sea_orm::ActiveValue::Set(
                Some(common::utils::date::DateUtils::local_now()),
            ),
        })
    }
}

fn validate_non_negative_amount(amount: &Decimal) -> Result<(), ValidationError> {
    if amount.is_sign_negative() {
        return Err(ValidationError::new("non_negative"));
    }
    Ok(())
}
